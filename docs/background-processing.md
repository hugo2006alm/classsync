# Background processing

## Windows

Launch-at-login starts ClassSync with `--startup` (legacy `--background` entries
remain supported). **Settings → Automation** independently controls **Launch
with Windows** and **Start minimized**. The latter chooses a hidden tray window
or visible window at sign-in; manual shortcuts always show the window, and
incomplete setup stays visible. Both preferences are local to the device.
Named Windows mutex keeps one process; manual later launches activate the
existing window, while duplicate login launches leave its visibility alone.
Shared coordinator uses SQLite leases for startup recovery and periodic polling,
including while hidden.

## Android

FCM background callbacks enqueue expedited WorkManager work keyed by relay
event, so duplicate delivery is harmless without one pending event suppressing
another. Workers initialize their headless dependencies, synchronize account
state, persist discovered queue entries to the encrypted account snapshot
before expensive processing, and use durable leases and stage checkpoints.
This keeps Sync history recoverable on other devices even if Android stops a
worker after discovery or publication. Manual imports process immediately. The
FCM token remains registered whenever background automation is
enabled, independently from the preference for visible ClassSync alerts.
Android may defer/stop work, so app-resume recovery continues unfinished jobs.
The optional Android home-screen widget receives a bounded snapshot of cached
timetable slots when the app opens or its cache changes. The widget prioritises
ongoing lessons and offers navigation to the first future class in the same
four-day window as Overview. An inexact Android alarm requests a redraw at the
next start or end, with the normal launcher refresh as a fallback. The widget
reads its cache offline.
Foreground-service promotion is not yet implemented; oversized transcripts are
rejected and AI work is bounded to reduce execution risk.

A manually started request runs in the app process and can pause while Android
suspends that process in the background. Returning to ClassSync resumes normal
recovery. A processing lease that has genuinely expired is shown with a
**Recover** action after 30 minutes. Repeated-failure model prompts appear only
while the app is foregrounded; otherwise the durable retry plan continues.

## iOS and macOS

macOS has network-client entitlement and CI compile coverage, but remains
preview-only. The iOS SideStore configuration uses the existing launch and resume
pipeline and local notifications. It does not request APNs or background modes.
The separate App Group configuration adds a WidgetKit timeline for cached
timetable data. See [iOS distribution](ios.md).
