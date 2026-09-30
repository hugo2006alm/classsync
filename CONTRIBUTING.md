# Contributing to ClassSync

ClassSync is maintained by Hugo Almeida. Contributions are welcome under the [MIT license](LICENSE); retain its copyright and permission notice when distributing copies or substantial portions.

Before changing integration behavior, read [AGENTS.md](AGENTS.md), [CONTEXT.md](CONTEXT.md), the relevant integration guide in `docs/`, and accepted ADRs in `docs/architecture/`. Keep Notion and Fireflies ownership, durable queue recovery, and cross-device idempotency intact.

Open a focused pull request against `main`. Describe the behavior change and tests. Run `pnpm relay:check` from the repository root and `dart format --output=none --set-exit-if-changed lib test tool`, `flutter analyze`, and `flutter test` from `apps/client` for affected Flutter changes. CI runs relay, Flutter, and security checks. Platform builds need their respective SDKs.

Follow the [code of conduct](CODE_OF_CONDUCT.md) in project discussions.

Use mocks or emulators in tests. Never commit credentials, transcripts, recovery codes, personal academic records, local signing files, or generated diagnostics. Report suspected vulnerabilities through [private vulnerability reporting](SECURITY.md).
