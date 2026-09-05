# ADR-003: Notion metadata for global idempotency

## Status

Accepted

## Context

Windows and Android may process the same Fireflies transcript independently. Local deduplication cannot prevent cross-device duplicates.

## Decision

Offer an additive `Fireflies ID` property during setup, after explicit confirmation. Query it before page creation and persist `notion_page_id` immediately after creation.

## Trade-offs

- Positive: stable cross-device identity and safe retries.
- Negative: requires one schema addition.
- Mitigation: app continues with weaker local-only deduplication if user declines.
