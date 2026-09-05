# ClassSync implementation plan

## Delivery order

1. Foundation: monorepo, responsive Flutter shell, theme, Drift, secure storage, settings, setup.
2. Academic model: Notion discovery, active-subject cache, semester derivation, class screens.
3. Sync pipeline: relay merge, Fireflies overlap polling, durable job state machine.
4. AI and publishing: Gemini JSON schemas, chunk synthesis, Notion block rendering, idempotency.
5. Automation: tray, startup, polling, local notifications, Android WorkManager.
6. Hardening: diagnostics, manual import, packaging, full CI and mocked integration tests.

## Definition of done

- One pipeline serves startup, manual, periodic, relay, resume, and mobile triggers.
- Every external side effect has a persisted checkpoint and an idempotency check.
- Full transcript content never enters relay storage and is removed locally after success by default.
- Healthy operation stays quiet; review and failures link to exact job.
- Windows and Android builds share all domain and integration code.
