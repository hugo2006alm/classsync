# ADR-002: D1-only relay persistence

## Status

Accepted

## Context

Webhook delivery needs durable deduplication and pending-event retrieval. Transcript content must remain off Cloudflare.

## Decision

Use one Worker with one D1 binding. Store event type, Fireflies ID, receipt time, and acknowledgement time.

## Trade-offs

- Positive: SQL uniqueness gives deterministic duplicate handling; local development mirrors production.
- Negative: D1 is more setup than KV.
- Mitigation: migration and deployment commands are included.
