# Fireflies

ClassSync uses `https://api.fireflies.ai/graphql` with bearer authentication.

- Webhooks V2 event: `meeting.transcribed`.
- Signature: HMAC-SHA256 over the exact raw body in `X-Hub-Signature`.
- Recovery: query at most 50 transcripts per page using `skip` and `limit`.
- Cursor: last successful discovery time minus configurable overlap, 48 hours by default.
- Full transcript: requested only for queued work; sentences retain speaker and timing context.

Webhooks fire only for meetings owned by the configured Fireflies account. Polling remains mandatory recovery.

## Configure the webhook

1. In ClassSync setup, create or join your private account.
2. Copy the webhook URL and signing secret shown by ClassSync.
3. Open Fireflies → **Settings → Personal → Developer settings**.
4. Under **Webhooks V2**, select **Configure**.
5. Paste the account-specific URL and signing secret exactly.
6. Event: `meeting.transcribed` only.
7. Save, then run **Test Webhook**. A signed test returns `200` without being
   stored as a lecture.

Every person uses a different URL and secret. Devices belonging to the same
person use the same account and therefore the same webhook configuration.

Only transcripts completed after webhook setup generate webhook events.
ClassSync recovery polling discovers older or missed transcripts.
