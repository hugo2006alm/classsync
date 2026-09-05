# ADR-003: D1 processing claims for global idempotency

## Status

Accepted

## Context

Windows and Android may process the same Fireflies transcript independently. Local deduplication cannot prevent cross-device duplicates.

## Decision

Relay issues hashed per-device credentials. Before Gemini or Notion work, a
device atomically acquires a time-bounded D1 claim keyed by Fireflies transcript
ID. Owner renews claim at long-stage checkpoints and completes it with final
Notion page ID. Another device defers, takes over expired claim, or reconciles
completed page ID. `Fireflies ID` query remains recovery check, not uniqueness
primitive.

## Trade-offs

- Positive: one publisher across Windows/Android plus recoverable ownership.
- Negative: global guarantee depends on relay availability/configuration.
- Mitigation: local SQLite lease still prevents same-device/process overlap;
  Notion metadata reconciles response loss. Manual imports stay device-local.
