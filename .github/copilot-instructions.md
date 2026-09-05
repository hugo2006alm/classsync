# ClassSync Copilot instructions

Read `/AGENTS.md` and `/CONTEXT.md` before proposing or editing code. They define repository commands, architecture, domain vocabulary, security rules, and product invariants.

Keep domain logic shared across Windows and Android. Use `SyncCoordinator.run(reason)` for every trigger. Preserve crash recovery, bounded retries, local-first behavior, additive confirmed Notion schema changes, minimal relay data, secure credential storage, and cross-device idempotency. Never hardcode subjects, semester values, installation IDs, or secrets.

After changes, regenerate Drift code when needed, format, analyze, run relevant Flutter tests, run `pnpm relay:check` for Worker changes, and build affected platforms when tooling permits. Update user docs and ADRs when behavior or architecture changes.

