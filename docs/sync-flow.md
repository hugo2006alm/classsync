# Sync flow

`SyncCoordinator.run(reason)` performs the same sequence for every trigger:

1. Read pending relay events.
2. Query Fireflies from durable cursor minus overlap.
3. Merge and deduplicate by Fireflies transcript ID.
4. Persist jobs before fetching full transcripts.
5. Fetch transcript and refresh active Notion subjects.
6. Classify against active subjects only.
7. Generate or reuse structured summary.
8. Pause for review when thresholds require it.
9. Query Notion by `Fireflies ID`, then create or resume existing page.
10. Acknowledge relay event after durable local discovery.

Retryable failures use exponential backoff with jitter and `Retry-After`. Configuration failures stop until settings change.
