# Background processing

## Windows

Launch-at-login starts ClassSync with background flag. Named Windows mutex keeps
one process; later launches activate existing window. Shared coordinator uses
SQLite leases for startup recovery and periodic polling.

## Android

FCM background callback only enqueues unique WorkManager work. Workers use
durable leases and stage checkpoints; manual imports process immediately.
Android may defer/stop work, so app-resume recovery continues unfinished jobs.
Foreground-service promotion is not yet implemented; oversized transcripts are
rejected and AI work is bounded to reduce execution risk.

## iOS and macOS

macOS has network-client entitlement and CI compile coverage, but remains
preview-only. iOS Firebase/background modes are not configured. No iOS
background-automation claim is made.
