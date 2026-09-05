# Background processing

## Windows

Launch-at-login starts ClassSync with a background flag. The window stays hidden, tray remains active, and the shared coordinator performs startup recovery plus periodic polling. Closing the window hides it; Quit stops the process.

## Android

WorkManager provides best-effort periodic discovery. Manual Sync persists work before processing. Android may defer or stop background work; queued jobs resume next launch. Long foreground processing must display a notification.

## iOS and macOS

Code remains compatible, but iOS execution is opportunistic. ClassSync never promises guaranteed long-running background work.
