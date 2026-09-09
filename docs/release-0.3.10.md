# ClassSync v0.3.10

- Fix Portal form/menu text appearing as Finance charges, exam registrations,
  and local search results. Repair affected cached records automatically on
  startup, including offline and after the previous cleanup already ran.
- Prevent academic years from becoming financial amounts and keep `Por pagar`
  charges unpaid. Reject unrecognized finance/registration rows before caching.
- Search readable academic content instead of raw JSON metadata. Preserve valid
  study content, financial records, and manual tasks during cache repair.
- Clarify uncached Finance/Progress states and fix Search dropdown overflow.

Validation: 151 Flutter tests, native Windows UI QA, and 19 relay tests pass;
Flutter analyzer and dependency audit are clean. Finance/Progress/Search
regressions are covered at phone and desktop widths.

Install over the existing version, then reopen ClassSync. Academic **Refresh**
fetches current Portal records. No Cloudflare deployment, D1 migration, API-key
change, or account reset is required for this patch.

Windows installer and signed Android APK are built locally; SHA-256 checksums
included. No GitHub Actions build used. Windows installer remains unsigned.
Live student-account pages and Android background/FCM behavior require separate
credentialed/device QA; automated tests use sanitized fixtures.
