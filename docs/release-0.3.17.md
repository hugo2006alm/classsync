# ClassSync v0.3.17

- Support hosted relay registration policies, including open, invite, and
  token-based account registration.
- Harden Fireflies GraphQL connection validation and surface provider errors.
- Improve setup, Settings, and synced-job screens for relay registration and
  remote Notion summary status.
- Add D1 migration `0008_registration_invites.sql` and relay coverage for
  registration-policy discovery.
- Correct the credential-tile regression test after Moodle and ISEP became one
  combined integration tile.

Validated locally with frozen dependency installation, relay checks, Flutter
formatting/analyzer/tests with coverage, Windows and signed Android APK/AAB
release builds, signing-certificate verification, and Inno Setup packaging.
No GitHub Actions build is used.
