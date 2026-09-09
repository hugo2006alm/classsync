# ClassSync v0.3.9

- Restore an existing account directly from Welcome with **Use recovery code**.
  Saved Fireflies/Gemini/Notion configuration is restored without re-entering
  API keys or the bootstrap token; finishing setup preserves restored keys.
- Fix remote job status restore, concurrent lecture task loss, active worker
  lease handling, and regeneration of already-published lectures.
- Bound integration pagination and request bodies; improve manual import
  validation and preserve significant Portal password whitespace.
- Isolate account/legacy push registrations and delivery; persist failed and
  interrupted account pushes for retry. Update the affected build dependency.
- Add real Worker/D1 and native Windows UI regression coverage.

Locally built Windows installer and signed Android APK; SHA-256 checksums
included. No GitHub Actions build used. Windows installer remains unsigned,
consistent with previous local releases.

Relay operators: apply D1 migration 0006, then deploy the new Worker before
using the new regeneration/push behavior. GitHub release does not deploy it.
Android background/FCM and live external-account flows still require device
and credentialed QA. See `docs/audit-2026-09-09.md` for validation and limits.
