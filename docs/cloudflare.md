# Cloudflare relay

## Setup

1. `cd apps/relay && pnpm install`
2. `pnpm exec wrangler login`
3. `pnpm exec wrangler d1 create classsync-relay`
4. Put returned database ID in `wrangler.jsonc`.
5. `pnpm run db:migrate:remote`
6. `pnpm exec wrangler secret put FIREFLIES_WEBHOOK_SECRET`
7. `pnpm exec wrangler secret put DEVICE_API_TOKEN`
8. `pnpm exec wrangler secret put FIREBASE_SERVICE_ACCOUNT_JSON`
9. `pnpm run deploy`

Configure Fireflies Webhooks V2 with:

```text
https://classsync-relay.classsync-relay.workers.dev/webhooks/fireflies
```

Subscribe only to `meeting.transcribed` and use same signing secret. Enter
bootstrap token once in ClassSync. Client creates random per-device credential;
Worker stores only its SHA-256 hash. Lost device can be revoked by setting
`revoked_at` in `relay_device_auth`.

Fireflies' signed synthetic Test Webhook receives `200` but is not stored or
sent to devices. Production `meeting.transcribed` deliveries receive `202`.

## Multiple people and devices

The current app creates a private relay account during setup. The account page
shows a unique webhook URL and a 32-character Fireflies signing secret. Each
person must create a different account and use that person's values in
Fireflies. A recovery code joins that same person's other devices.

D1 migration `0005_account_sync.sql` adds account-scoped events, claims, and
opaque snapshots. Apply it before installing a client that uses account sync.
The Worker stores a hash of the account authentication secret. API keys and
shared preferences reach D1 only as AES-256-GCM ciphertext.

The global `DEVICE_API_TOKEN` is now also the account-creation setup code. It
does not grant access to an existing account or decrypt its snapshots.

The relay stores no transcript, prompt, summary, or Notion content.
FCM tokens are stored only for authenticated Android devices. See
`docs/firebase.md`.

Scheduled cleanup runs daily: fully acknowledged events expire after 30 days,
stale push registrations/revoked identities after 90 days. Cloudflare dashboard
rate limiting should protect `/webhooks/fireflies`, `/devices/enroll`, and device
API paths; this account-level control is not represented by repository code.
