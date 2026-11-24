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

## Native WidgetKit experiments for Personal Teams

The **iOS package** Actions run builds two separate test artifacts. Each ZIP
contains an ARM64 device IPA and its SHA-256 file. The regular
`ClassSync-iOS` artifact remains the fallback and is the release input.
The experiments require iOS 17 or later for the extension.

| Artifact | What a physical test can establish |
| --- | --- |
| `ClassSync-iOS-widget-demo` | WidgetKit registration, extension execution, timeline changes, refresh and reboot without shared storage. The numbered **Demo class** changes on two-minute boundaries when iOS delivers the timeline. |
| `ClassSync-iOS-widget-app-group-test` | The same extension reads a snapshot written by ClassSync. With no upcoming classes, the app writes a marked **Snapshot test** fixture. With classes, it writes the real timetable. |

### Install and verify in order

1. Record iOS and SideStore versions, the Apple Account used for the current
   install and the reported remaining App IDs. Save the ClassSync recovery
   code and preserve any local-only data you need before experimenting.
   Confirm the current app opens and its timetable and settings are present.
2. Use a currently supported SideStore build. The release notes flag broken
   sign-in on 0.6.4 and earlier. Update SideStore first if needed. Keep the
   same signing account and installation method for the first comparison.
3. Extract the demo ZIP, verify SHA-256 with `Get-FileHash` as above and move
   its IPA to Files. Start LocalDevVPN. In SideStore **My Apps → +**, pick
   the demo IPA and install it over ClassSync. Keep the same app identity.
   When prompted, choose **Keep App Extensions (Register App ID for Each
   Extension)**. Some versions show an extension selection screen. Keep
   `ClassSyncWidget` and use its individual profile. If SideStore proposes
   a different identity or asks you to delete ClassSync, cancel the test.
4. Open ClassSync and verify existing settings and timetable access. On the
   Home Screen, hold an empty area, choose **Edit → Add Widget**, search
   **ClassSync**, and add Small, Medium and Large. On the Lock Screen, hold
   the wallpaper, choose **Customise → Lock Screen** and add ClassSync
   Rectangular below the clock and Inline above it. Record separately
   whether ClassSync appears, a numbered demo lesson renders, and the lesson
   changes after a boundary. Tap a widget to test the timetable deep link.
5. In SideStore **My Apps**, tap the days-left badge for ClassSync. Confirm
   the date resets and the widget still renders and advances. Restart the
   iPhone, unlock once, and check again. Repeat with light, dark and, where
   available on your iOS version, tinted and clear appearances. Check
   redaction with your Lock Screen privacy settings. WidgetKit controls
   update timing, so note the actual transition times.
6. Only after the demo renders, repeat steps 3–5 with the App Group IPA.
   Open ClassSync to publish a snapshot. Check that actual lesson details
   or **Snapshot test** appear instead of the demo counter. Sync a changed
   timetable, or reopen ClassSync with an empty timetable and compare the
   fixture time. Test again after refresh and restart, and in airplane mode
   after one successful sync. **Widget container unavailable** means no
   candidate passed the extension's container lookup. **Open ClassSync to
   sync timetable** means the extension found a container but could not
   read a valid snapshot. Report status and versions without sharing your
   timetable, Apple Account details, profile or certificate.
7. To roll back, install the regular **ClassSync-iOS** IPA over the same app
   with the same account and identity. The fallback has no embedded
   extension. If a sideloader offers only a fresh install, stop before
   deleting the installed app.

### Signing diagnosis and next options

Apple's Personal Team has seven-day provisioning, up to three test apps
per device and up to ten App IDs at a time, subject to what the account
already uses. An individual extension profile requires an extra App ID.
Both variants reuse `app.classsync.classsync` and
`app.classsync.classsync.widgets` before signing. The two builds are
sequential updates, so they need one extension ID between them per account
and signing identity. An App Group is a separate portal resource.
[Apple membership limits](https://developer.apple.com/help/account/membership/programs-overview/)

Apple's capability table describes supported program capabilities. It does
not guarantee that third-party Personal Team provisioning can grant App
Groups. SideStore's portal code attempts to register the requested group
with a team suffix and assign it to each App ID. The resolver tries the
matching `ALTAppGroups` hints, the suffix inferred from the rewritten
bundle ID, and the original group used for official signing. It accepts a
hint only when iOS returns a container URL. The app writes an atomic,
size-limited snapshot protected until first unlock and the extension must
successfully read it. The host and extension receive explicit ad-hoc
signatures during packaging so the requested entitlements are available
to the sideloader. Device provisioning and final signing happen in
SideStore.
[Apple capabilities](https://developer.apple.com/help/account/reference/supported-capabilities-ios/) ·
[SideStore App Group provisioning](https://github.com/SideStore/SideStore/blob/main/SideStore/Core/Operations/PipelineOperations/FetchProvisioningProfilesOperation.swift)

SideStore #1437 reports a WidgetKit App Group read failure even after the
author retried with 0.6.3. #1462 reports a Share Extension that registered
but did not execute on a free account with a 0.6.4 build. The reporter
observed different executable signing flags with iLoader, where the same
extension ran. That report also found that reusing the host profile left
the signed application identifier mismatched with the extension's
rewritten bundle ID. Issue closure alone does not establish behaviour
in the SideStore build installed on your phone.
[SideStore #1437](https://github.com/SideStore/SideStore/issues/1437) ·
[SideStore #1462](https://github.com/SideStore/SideStore/issues/1462) ·
[SideStore releases](https://github.com/SideStore/SideStore/releases) ·
[iLoader releases](https://github.com/nab138/iloader/releases)

When a sideloader supports exporting the re-signed IPA, keep it private.
On macOS, inspect both bundles with `codesign -d --entitlements - <bundle>`
and decode both `embedded.mobileprovision` files with
`security cms -D -i <profile>`. Compare each signed
`application-identifier` with its own profile and final
`CFBundleIdentifier`, and compare the authorized and signed
`com.apple.security.application-groups` on both binaries. The Actions
checks cover the original ad-hoc IPA. Successful snapshot display on
device provides the functional check for access after re-signing.

If demo runs but sharing fails, the next local test is a dedicated
`keychain-access-groups` value permitted by both profiles, queried with
`kSecAttrAccessGroup`. Use a separate group from ClassSync credentials
and test a small versioned payload with
`kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly` through refresh and reboot.
If demo fails to render with valid per-extension provisioning, compare
iLoader and AltStore Classic while preserving the original installation.
A relay fallback would require a separate encrypted widget enrolment and
revocation design, including how the extension obtains its own enrolment
credential, and a revised relay data decision. The experiments use local
storage and leave the Worker and D1 untouched.
[AltStore extension provisioning](https://github.com/altstoreio/AltStore/blob/develop/AltStore/Operations/FetchProvisioningProfilesOperation.swift) ·
[Keychain access groups](https://developer.apple.com/documentation/security/sharing-access-to-keychain-items-among-a-collection-of-apps) ·
[Relay ADR](architecture/adr-002-d1-relay.md)
