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

## v0.3.9 clarification: explicit reprocessing

A completed claim can reopen only when an authenticated device supplies the
existing canonical page ID in `x-classsync-reprocess-page-id`. Atomic ownership
excludes competing reprocessors; the page ID survives reopening. Ordinary
retries still reconcile completed claims. Remote completion precedes clearing
the local processing lease, so a failed completion remains recoverable. Local
workers claim only the jobs they can immediately process.
