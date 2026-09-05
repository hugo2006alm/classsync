# Fireflies

ClassSync uses `https://api.fireflies.ai/graphql` with bearer authentication.

- Webhooks V2 event: `meeting.transcribed`.
- Signature: HMAC-SHA256 over the exact raw body in `X-Hub-Signature`.
- Recovery: query at most 50 transcripts per page using `skip` and `limit`.
- Cursor: last successful discovery time minus configurable overlap, 48 hours by default.
- Full transcript: requested only for queued work; sentences retain speaker and timing context.

Webhooks fire only for meetings owned by the configured Fireflies account. Polling remains mandatory recovery.

## Configure the webhook

1. Copy the ClassSync webhook URL below.
2. Open Fireflies → **Settings → Personal → Developer settings**.
3. Under **Webhook**, select **Configure**.
4. URL: `https://classsync-relay.classsync-relay.workers.dev/webhooks/fireflies`.
5. Secret: same value stored as Cloudflare
   `FIREFLIES_WEBHOOK_SECRET`.
6. Event: **Transcription Completed** / `meeting.transcribed`.
7. Save.

Only transcripts completed after webhook setup generate webhook events.
ClassSync recovery polling discovers older or missed transcripts.
