# Fireflies

ClassSync uses `https://api.fireflies.ai/graphql` with bearer authentication.

- Webhooks V2 event: `meeting.transcribed`.
- Signature: HMAC-SHA256 over the exact raw body in `X-Hub-Signature`.
- Recovery: query at most 50 transcripts per page using `skip` and `limit` for
  every named Fireflies connection.
- Cursor: one last-successful discovery time per named connection minus the
  configurable overlap, 48 hours by default.
- Full transcript: requested only for queued work; sentences retain speaker and timing context.

Webhooks carry a transcript ID, not the transcript. ClassSync still needs an
API key that can access the owning Fireflies account. Polling remains mandatory
recovery.

## Configure the webhook

1. In ClassSync setup, create or join your private account.
2. Copy the webhook URL and signing secret shown by ClassSync.
3. Open Fireflies → **Settings → Personal → Developer settings**.
4. Under **Webhooks V2**, select **Configure**.
5. Paste the account-specific URL and signing secret exactly.
6. Event: `meeting.transcribed` only.
7. Save, then run **Test Webhook**. A signed test returns `200` without being
   stored as a lecture.

Devices belonging to the same ClassSync owner use the same account and webhook
configuration. A permitted colleague recording for that owner may configure
the same URL and secret in their Fireflies account. Do not give the colleague a
ClassSync recovery code.

Under **Settings → Connections → Fireflies**, add one named API key for each
Fireflies account whose recordings should be processed. The owner's key alone
works only when that key can fetch the colleague-owned transcript. A webhook by
itself is not enough. Keys remain in OS secure storage and in encrypted
cross-device snapshots.

Only transcripts completed after webhook setup generate webhook events.
ClassSync recovery polling discovers older or missed transcripts.
