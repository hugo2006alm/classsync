# Architecture

ClassSync is a local-first modular monolith plus a minimal coordination relay.

```mermaid
flowchart LR
  FF[Fireflies] -->|signed webhook metadata| Relay[Cloudflare Worker + D1]
  FF -->|GraphQL transcript| Client[ClassSync client]
  Relay -->|pending IDs| Client
  Client -->|structured prompts| Gemini[Gemini API]
  Client -->|subjects and summaries| Notion[Notion API]
  Client <--> SQLite[(Local Drift / SQLite)]
  Client --> Portal[ISEP Portal WebForms]
  Client --> Moodle[Moodle Web Services]
  Client --> Secure[OS secure storage]
```

## Client boundaries

- `app`: bootstrap, routing, adaptive application shell, theme.
- `core`: database, security, networking, diagnostics, background services.
- `domain/academic`: semesters, subjects, lectures, summaries.
- `domain/academic`: also normalized timetable, evaluations, provenance, and
  grade calculation rules; no Flutter or HTTP dependencies.
- `domain/sync`: durable jobs, transitions, retry policy, coordinator.
- `features`: overview, classes, sync, setup, settings.
- `platform`: Windows tray/autostart and mobile background hooks.

Features depend on domain contracts. Integration adapters depend on Dio and secure storage. Domain code does not import Flutter widgets or platform plugins.

## Data ownership

- Notion: canonical subjects and published summaries.
- Fireflies: canonical transcript source.
- Local SQLite: operational queue, academic offline cache/change history,
  preferences, diagnostics, corrections.
- Cloudflare D1: transcript-ready IDs, per-device acknowledgements, hashed
  device identity, processing claims, and bounded push-delivery metadata.
- OS secure storage: all credentials, including multiple named Fireflies keys.

Portal and Moodle are read-only academic sources. Their adapters normalize data
at one integration boundary. No Portal/Moodle academic content or plaintext
credentials enter relay storage. Moodle token and Portal login may travel only
inside account's opaque AES-256-GCM configuration snapshot. See
[Portal](isep-portal.md) and [Moodle](moodle.md).

See ADRs under `docs/architecture/` for trade-offs.
