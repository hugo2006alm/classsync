# ADR-004: Local content protection and retention

## Status

Accepted

## Decision

Credentials remain in OS secure storage. Resume checkpoints remain in Drift
SQLite stored inside Android app sandbox or current Windows/macOS user app-data
directory. Database encryption is deferred: current Drift desktop/mobile stack
does not provide one portable, migration-safe encrypted backend, and removing
checkpoints would reduce crash safety.

Completed transcript payloads are removed by default. Review/terminal/corrupt
payloads expire using diagnostics-retention window. Settings provides explicit
purge of transcripts, partial AI work, and local summaries. Diagnostics exports
contain bounded metadata only.

## Consequences

- OS account/device compromise can expose local lecture content.
- Full-disk encryption and locked OS account remain recommended.
- Encrypted SQLite stays future option once migration, key recovery, Windows,
  Android, and background-isolate behavior can be tested together.
