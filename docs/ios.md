# iOS preview on SideStore

ClassSync's iOS preview uses the shared Flutter client and a device IPA built on
GitHub's macOS runners. The macOS workflow packages an unsigned ARM64 build.
SideStore signs it with your Apple Account before installation. The bundle ID in
the IPA is `app.classsync.classsync`. Keep the same Apple Account and SideStore
app identity for in-place updates.

## Install from Windows

1. On your iPhone, install LocalDevVPN and allow its VPN configuration. Connect
   the phone to Wi-Fi. On 64-bit Windows, install iTunes and iloader using the
   [SideStore prerequisites](https://docs.sidestore.io/docs/installation/prerequisites).
2. Connect the iPhone by USB, unlock it, and tap **Trust** if prompted. In
   iloader, sign in with your Apple Account, select the phone, and choose
   **Install SideStore (Stable)**.
3. On the iPhone, go to **Settings → General → VPN & Device Management** and
   trust the developer associated with that Apple Account. On iOS 16 and later,
   turn on **Settings → Privacy & Security → Developer Mode** and confirm after
   the restart. Follow the prompts for your OS version in the
   [SideStore installation guide](https://docs.sidestore.io/docs/installation/install).
4. Connect LocalDevVPN, open SideStore, and sign in with the Apple Account used
   in iloader. Go to **My Apps** and tap the days-left badge to refresh SideStore.
5. Download `ClassSync-iOS.ipa` from GitHub Releases or extract it from the
   **ClassSync-iOS** GitHub Actions artifact for a test build. Verify SHA-256
   against the release's `SHA256SUMS.txt` or the Actions checksum artifact. In
   PowerShell, use `Get-FileHash .\ClassSync-iOS.ipa -Algorithm SHA256`.
6. Save the IPA to Files on the iPhone. With LocalDevVPN running, open SideStore,
   go to **My Apps**, tap **+**, and select the IPA. Open ClassSync and join your
   existing account using your recovery code, or complete setup on the device.

A free Personal Team profile lasts seven days. Refresh SideStore and ClassSync
before the counters expire. Personal Teams have limited app slots and App IDs,
and extensions can use additional IDs. Read the limits shown by SideStore and
Apple's [developer account overview](https://developer.apple.com/help/account/membership/programs-overview/).

## Update and recover

ClassSync checks GitHub for an iOS release. Open the release from the prompt or
**Settings → App updates**, then install the new IPA over the existing app
through SideStore. Checksum verification is manual on iOS. The release workflow
also generates a source at
[GitHub Releases](https://github.com/hugo2006alm/classsync/releases/latest/download/sidestore-source.json).
This URL becomes available after the first release containing the iOS assets.
Add it under **Sources** in SideStore or keep using the IPA directly.

If ClassSync expires, restore SideStore with iloader if necessary and refresh
ClassSync in place with the same Apple Account. If Apple invalidates the pairing
record after a device update or reset, follow the
[SideStore pairing guide](https://docs.sidestore.io/docs/advanced/pairing-file).
Uninstalling removes the app's local database. Changing the app identity or the
signing team can also make the existing database and Keychain inaccessible.
Keep your ClassSync recovery code in a password manager before changing signing
identities. Recovery restores account data covered by encrypted device sync.
Local-only transcripts and unsynced data require separate preservation.

## Platform capabilities

| Capability | Android | iOS SideStore | iOS widget configuration |
| --- | --- | --- | --- |
| Shared processing, Library, Recordings, SQLite | Shared client | Shared client, device validation pending | Shared client |
| Pairing and encrypted device sync | Supported | Shared foreground sync, device validation pending | Same |
| Local notifications | Supported | Supported by the adapter, device validation pending | Same |
| Automatic work | FCM and WorkManager | Launch and resume, subject to user settings | Same |
| Push and scheduled background processing | FCM and WorkManager | Unavailable in the current build | Future integration |
| Timetable widget | Home screen | Unavailable in the free IPA | WidgetKit with a provisioned App Group |
| Themes | Follows system | System, Light, Dark | Widget follows system rendering |
| Updates | Verified APK and Android installer | IPA via SideStore | Depends on signing and distribution |

The free IPA has no WidgetKit extension, App Group, or APNs entitlement. Its
foreground processing, local notifications and Keychain access use the standard
client adapters. Windows can continue unattended processing independently of
the phone.

For an App Group build, run `ruby tool/enable_ios_widgets.rb` from
`apps/client` before building on macOS. The script adds the extension to the
local Xcode project. Provision both the app and extension under the same team
and register `group.app.classsync.classsync`. This configuration targets iOS
17 or later and shares a bounded, atomically written timetable cache with the
widget. No credentials, transcript content, or summaries enter the container.
The small and Lock Screen widgets prioritise the current class. Medium shows
current and next together. Large shows today's remaining classes. Timelines
mark start and end transitions subject to WidgetKit scheduling. The system
controls widget tint and Liquid Glass rendering. The Flutter app retains its
existing navigation and does not use native Liquid Glass controls.

## iPhone validation checklist

- Install the ARM64 IPA and finish setup with a test account. Kill the app and
  reopen it to verify settings, Keychain access, and offline startup. Refresh
  the signature and install a newer IPA over it. Repeat those checks.
- Pair against a test device. Verify foreground sync, recovery, one Notion
  publication per transcript, a local notification, and permission denial.
- Test a recording published elsewhere and a duplicate with a page ID only.
  Open Library from list and detail, then return. Try a removed or inaccessible
  note. Cancel a discard, confirm a different discard, and check published and
  busy recordings remain protected.
- Check system, light and dark settings, larger text, landscape, keyboard and
  back gestures. Test Overview at an exact start and end and when resuming.
- On the App Group build, test Home Screen and Lock Screen layouts with light,
  dark, tinted and clear appearances. Confirm fresh and offline timetable
  transitions, long class names, deep links, and refresh after timetable edits.

References: [Flutter on iOS](https://docs.flutter.dev/deployment/ios),
[WidgetKit](https://developer.apple.com/documentation/widgetkit/),
[Widgets HIG](https://developer.apple.com/design/human-interface-guidelines/widgets),
[Liquid Glass](https://developer.apple.com/documentation/technologyoverviews/liquid-glass),
[Apple capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios/),
and [SideStore sources](https://docs.sidestore.io/docs/advanced/app-sources).
