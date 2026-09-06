# Sync flow

`SyncCoordinator.run(reason)` performs the same sequence for every trigger:

1. Independently read relay events and poll Fireflies recovery window.
2. Persist/deduplicate jobs, then acknowledge relay event for this device.
3. Refresh Notion subjects when available; cached active subjects remain usable.
4. Atomically claim runnable or stale-processing row with SQLite lease.
5. Fetch/reuse transcript, then acquire D1 cross-device processing claim.
6. Classify or apply exact local correction.
7. Generate lecture-faithful structured notes in the teacher's order,
   persisting partial checkpoints. Teacher emphasis, important side details,
   Q&A, tasks, deadlines, examples, formulas, code, and uncertainties remain
   separate so synthesis cannot silently flatten them.
8. Pause for review when thresholds require it.
9. Reconcile Notion `Fireflies ID`, publish revision-marked owned chunks, and
   preserve all user/template blocks.
10. Complete D1 claim with Notion page ID and finish local job.

Retryable failures use exponential backoff with jitter and `Retry-After`. Configuration failures stop until settings change.
