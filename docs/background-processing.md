# Background processing

## Windows

Launch-at-login starts ClassSync with background flag. Named Windows mutex keeps
one process; later launches activate existing window. Shared coordinator uses
SQLite leases for startup recovery and periodic polling.

## Android

FCM background callbacks enqueue expedited WorkManager work keyed by relay
event, so duplicate delivery is harmless without one pending event suppressing
another. Workers initialize their headless dependencies, synchronize account
state, and use durable leases and stage checkpoints; manual imports process
immediately. The FCM token remains registered whenever background automation is
enabled, independently from the preference for visible ClassSync alerts.
Android may defer/stop work, so app-resume recovery continues unfinished jobs.
Foreground-service promotion is not yet implemented; oversized transcripts are
rejected and AI work is bounded to reduce execution risk.

A manually started request runs in the app process and can pause while Android
suspends that process in the background. Returning to ClassSync resumes normal
recovery. A processing lease that has genuinely expired is shown with a
**Recover** action after 30 minutes. Repeated-failure model prompts appear only
while the app is foregrounded; otherwise the durable retry plan continues.

## iOS and macOS

macOS has network-client entitlement and CI compile coverage, but remains
preview-only. iOS Firebase/background modes are not configured. No iOS
background-automation claim is made.
