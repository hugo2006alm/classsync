#!/usr/bin/env bash
set -euo pipefail

mode=${1:-stable}
case "$mode" in
  stable) name=ClassSync-iOS ;;
  demo|app-group-test) name="ClassSync-iOS-widget-$mode" ;;
  *) echo "Unknown iOS package mode: $mode" >&2; exit 2 ;;
esac

app=build/ios/iphoneos/Runner.app
plist="$app/Info.plist"
dist="$PWD/build/ios/dist"
version=$(awk '/^version:/{print $2}' pubspec.yaml)
value() { /usr/libexec/PlistBuddy -c "Print :$1" "$plist"; }

test "$(value CFBundleIdentifier)" = app.classsync.classsync
test "$(value CFBundleShortVersionString)" = "${version%+*}"
test "$(value CFBundleVersion)" = "${version#*+}"
test "$(value CFBundleSupportedPlatforms:0)" = iPhoneOS
test ! -e "$app/embedded.mobileprovision"
test "$(value MinimumOSVersion)" = 15.0
if [[ "$mode" == stable ]]; then
  test -z "$(find "$app" -name '*.appex' -print)"
fi
executable="$app/$(value CFBundleExecutable)"
test "$(lipo -archs "$executable")" = arm64
xcrun vtool -show-build "$executable" | grep -Eq 'platform IOS$'
for executable in "$app"/Frameworks/App.framework/App "$app"/Frameworks/Flutter.framework/Flutter; do
  lipo "$executable" -verify_arch arm64
  xcrun vtool -show-build "$executable" | grep -Eq 'platform IOS$'
done

stage=$(mktemp -d)
trap 'rm -rf "$stage"' EXIT
mkdir "$stage/Payload"
ditto "$app" "$stage/Payload/Runner.app"
if [[ "$mode" != stable ]]; then
  host="$stage/Payload/Runner.app"
  widget="$host/PlugIns/ClassSyncWidget.appex"
  widget_plist="$widget/Info.plist"
  widget_value() { /usr/libexec/PlistBuddy -c "Print :$1" "$widget_plist"; }
  test "$(find "$host" -name '*.appex' -print)" = "$widget"
  test "$(widget_value CFBundleIdentifier)" = "$(value CFBundleIdentifier).widgets"
  test "$(widget_value CFBundleExecutable)" = ClassSyncWidget
  test "$(widget_value CFBundlePackageType)" = 'XPC!'
  test "$(widget_value NSExtension:NSExtensionPointIdentifier)" = com.apple.widgetkit-extension
  test "$(widget_value CFBundleShortVersionString)" = "$(value CFBundleShortVersionString)"
  test "$(widget_value CFBundleVersion)" = "$(value CFBundleVersion)"
  test "$(widget_value CFBundleSupportedPlatforms:0)" = iPhoneOS
  test ! -e "$widget/embedded.mobileprovision"
  test -x "$widget/ClassSyncWidget"
  test "$(lipo -archs "$widget/ClassSyncWidget")" = arm64
  xcrun vtool -show-build "$widget/ClassSyncWidget" | grep -Eq 'platform IOS$'

  while IFS= read -r -d '' framework; do
    codesign --force --sign - "$framework"
  done < <(find "$host" -depth -name '*.framework' -type d -print0)

  for bundle in "$widget" "$host"; do
    if [[ "$mode" == app-group-test ]]; then
      codesign --force --sign - --entitlements ios/ClassSyncWidget/AppGroup.entitlements "$bundle"
    else
      codesign --force --sign - "$bundle"
    fi
    codesign -d --entitlements - --xml "$bundle" > "$stage/entitlements.plist"
    python3 - "$mode" "$stage/entitlements.plist" <<'PY'
import plistlib
import sys
from pathlib import Path

mode, file = sys.argv[1:]
data = Path(file).read_bytes()
entitlements = plistlib.loads(data) if data else {}
expected = (
    {"com.apple.security.application-groups": ["group.app.classsync.classsync"]}
    if mode == "app-group-test" else {}
)
if entitlements != expected:
    raise SystemExit(f"Unexpected requested entitlements in {mode} package")
PY
  done
  codesign --verify --deep --strict "$host"
fi

mkdir -p "$dist"
ditto -c -k --keepParent "$stage/Payload" "$dist/$name.ipa"
cd "$dist"
unzip -tq "$name.ipa"
shasum -a 256 "$name.ipa" > "$name.ipa.sha256"
