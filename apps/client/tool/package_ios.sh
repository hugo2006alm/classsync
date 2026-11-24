#!/usr/bin/env bash
set -euo pipefail

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
test -z "$(find "$app" -name '*.appex' -print)"
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
mkdir -p "$dist"
ditto -c -k --keepParent "$stage/Payload" "$dist/ClassSync-iOS.ipa"
cd "$dist"
unzip -tq ClassSync-iOS.ipa
shasum -a 256 ClassSync-iOS.ipa > ClassSync-iOS.ipa.sha256
