# Academic regression repair: v0.3.10

## Confirmed issues

| Severity | Root cause | Correction |
| --- | --- | --- |
| High correctness | Money parsing removed `/` from `2026/2027`, producing a fictitious 20,262,027 charge. | Accept numeric monetary syntax only; require transaction evidence and reject interface labels. |
| Medium | Earlier bad Portal records survived the one-time cleanup marker and offline upgrades. | Repair on startup and sync; cancel reminders, remove invalid record history, expire affected stage cursors. Retry failed cancellations without showing bad records. |
| Medium | Plausible table headers allowed payment form labels to become unknown exam registrations. | Validate registration evidence and reject known interface text before persistence. |
| Medium | `Por pagar` matched the paid-state substring. | Check unpaid/partial/overdue/cancelled states before paid. |
| Medium | Search indexed raw payload JSON, including accidental form records and internal metadata. | Exclude invalid records and index readable content fields only. |
| Low | Search filters overflowed a desktop row; missing history looked like confirmed zero credits. | Expand dropdowns within their bounds and explicitly label uncached Finance/Progress data. |

These are parsing/cache/QA corrections, not a claim of a new remotely exploitable
security vulnerability. Search evidence no longer includes internal JSON fields
or payment-reference hints. No relay, authentication, or schema changes.

## Reproduction and validation

- Regression tests failed before fixes for cached noise, form-label exam rows,
  the exact academic-year amount conversion, and JSON search excerpts.
- Full Flutter suite: **151 tests passed**; analyzer clean; formatting passed.
  Handwritten line coverage: **60.6%**, exceeding the existing 50% threshold.
- Finance, Progress, and local `DTO` search pass at 400 and 1280 pixel widths.
  Desktop QA reproduced a 33-pixel dropdown overflow before its fix.
- Native Windows integration test passed: all main navigation tabs, Finance,
  Progress, local search, empty Sync state, and import cancellation. No Flutter
  runtime exceptions in the tested flows.
- Cache tests cover an existing v1 cleanup marker, offline operation,
  cancellation failure/retry, repeated repair, change-history removal, cursor
  invalidation, valid charges/notices, and preservation of manual task state.
- `pnpm relay:check`: TypeScript, local Worker dry build, and **19 tests passed**.
  `pnpm audit --audit-level=low`: no known vulnerabilities reported.
- Fixtures use synthetic records and no production credentials or copied
  personal address. No workflow files were changed or dispatched.

## Rollout and limits

Local release builds passed for Windows and Android. Inno Setup produced the
Windows installer; the executable reports `0.3.10+18`, installer `0.3.10`.
APK metadata reports `app.classsync.classsync`, version `0.3.10`/18, minSdk 24,
targetSdk 36, ARM32/ARM64/x64. APK v2 signature verification and ZIP CRC checks
passed; the signing certificate matches previous releases. Existing Android
Gradle/AGP/Kotlin support and SDK XML warnings remain; no bypass was used.

Locally generated artifact SHA-256 values:

```text
d294f6d33237cbc3740a4554b8eb7e26a92bd5f45e49ca6bc88f601dd3fd5f0f  ClassSync-Android.apk
37532903cc94280d2b35c9c6afe6433a9e3b8b09da92768153ae505fe2dc3c25  ClassSync-Setup-0.3.10.exe
```

Release commit/tag use `[skip ci]`. All artifacts above were built locally;
GitHub Actions was not used to generate them.

Install over the previous version and reopen the app. Repair works without a
network connection; Academic **Refresh** then requests current data. No new
Cloudflare deployment, D1 migration, account reset, or key setup is needed.

Live student-account pages were not accessed with private credentials. The
fixes reproduce screenshot-shaped records and use sanitized HTML fixtures;
unknown Portal layouts continue to fail closed. No Android device/emulator was
available for OS/background/FCM testing. Windows installer remains unsigned,
following the existing release convention.
