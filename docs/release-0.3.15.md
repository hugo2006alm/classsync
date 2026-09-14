# ClassSync v0.3.15

- Add multiple named Fireflies sources with stable source identities, independent
  polling, and account-scoped webhook activity.
- Carry Portal and Moodle credentials between the owner's devices inside the
  encrypted account snapshot while keeping device automation preferences local.
- Improve first-run and Settings flows for source setup, recovery, webhook
  status, and configurable public-site links.
- Update Riverpod 3, relay, and GitHub Actions dependencies; keep GoRouter,
  Workmanager, and build tooling on Dart 3.11/Flutter 3.41-compatible versions
  and repair the merged pnpm lockfile so frozen installs succeed.
- Add relay migration 0007 for account webhook activity and extend client and
  Worker regression coverage.

Validated locally with frozen dependency installation, the relay type check and
test suite, Flutter formatting/analyzer/tests with coverage, Windows release
build, locally signed Android release build, Android signing-certificate check,
and Inno Setup packaging. No GitHub Actions build is used.
