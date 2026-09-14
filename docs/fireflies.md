# Fireflies

ClassSync uses `https://api.fireflies.ai/graphql` with bearer authentication.
A **Fireflies Source** is one Fireflies account this ClassSync account is
authorized to query. It is not a ClassSync account and does not own summaries.

- Webhooks V2 event: `meeting.transcribed`.
- Signature: HMAC-SHA256 over the exact raw body in `X-Hub-Signature`.
- Recovery: query at most 50 transcripts per page using `skip` and `limit` for
  every named Fireflies source.
- Cursor: one last-successful discovery time per named source minus the
  configurable overlap, 48 hours by default.
- Full transcript: requested only for queued work; sentences retain speaker and timing context.

Webhooks carry a transcript ID, not the transcript. ClassSync still needs an
API key that can access the owning Fireflies account. Polling remains mandatory
recovery.

## Add or manage a source

Open **Settings → Connections → Fireflies**. One source screen contains name,
API key validation, polling state, last successful poll, and account-level
realtime delivery. Validation reads Fireflies `user_id`, email, and name from
authenticated `user` query. ClassSync persists stable `user_id` to detect same
Fireflies account under a different display name. If Fireflies cannot return
that identity, validation fails safely instead of guessing from display name.

Polling alone is a complete operating mode. Missing realtime configuration
never blocks discovery or processing.

## Configure the webhook

1. In ClassSync setup, create or join your private account.
2. Copy the webhook URL and signing secret shown by ClassSync.
3. Open Fireflies → **Settings → Personal → Developer settings**.
4. Under **Webhooks V2**, select **Configure**.
5. Paste the account-specific URL and signing secret exactly.
6. Event: `meeting.transcribed` only.
7. Save, then run **Test Webhook**. A signed test returns `200`, updates account
   last-received status, and is never stored as a lecture.

As of 2026-09-14, Fireflies' public Webhooks V2 documentation requires setup in
Fireflies dashboard and documents no mutation for creating or updating saved
webhook. ClassSync therefore shows copyable URL/secret instructions in source
screen but does not claim automatic configuration.

Devices belonging to the same ClassSync owner use the same account and webhook
configuration. A permitted colleague recording for that owner may configure
the same URL and secret in their Fireflies account. Do not give the colleague a
ClassSync recovery code.

Under **Settings → Connections → Fireflies**, add one named source for each
Fireflies account whose recordings should be processed. The owner's key alone
works only when that key can fetch the colleague-owned transcript. A webhook by
itself is not enough. Keys remain in OS secure storage and in encrypted
cross-device snapshots. Stable source IDs survive rename and recovery, and each
SyncJob keeps source ID that discovered or fetched it.

Different ClassSync accounts may authorize same Fireflies source. Their queues,
Gemini requests, summaries, processing claims, and Notion pages remain separate
account namespaces.

Only transcripts completed after webhook setup generate webhook events.
ClassSync recovery polling discovers older or missed transcripts.
