## What's changed

- **Reliable task state across devices** — completing, reopening, dismissing,
  or restoring a task now triggers an immediate best-effort account sync.
- **Last task action wins** — task status has its own mutation timestamp, so a
  newer summary refresh can no longer overwrite an explicit action made on
  another device.
- **Concurrent-device safety** — encrypted snapshot revision conflicts are
  re-read and retried before falling back to the normal later sync.
- **Clearer task priority** — pending tasks appear before completed and
  dismissed history, while deadlines continue to order tasks within each
  state.

## Release notes

- Existing tasks remain compatible; their first explicit status action adds
  the new synchronization timestamp automatically.
- No local database or relay migration is required for this release.
- Built and validated locally without GitHub Actions.
