# ClassSync first-run setup

## Updating without setting up again

Install a newer ClassSync build directly over the existing installation. The
local database, preferences, Notion mappings, and credentials in secure storage
remain in place because the Android package ID and Windows installer AppId stay
the same. Do not uninstall the app or clear its storage before updating. Android
also requires the update to use the same signing certificate as the installed
build.

ClassSync opens a seven-step setup guide on its first launch. You need four
credentials: a Fireflies API key, a Gemini API key, a Notion integration token,
and the ClassSync device API token.

You do **not** need to enter Firebase credentials, a Firebase project ID,
Cloudflare account details, a Fireflies webhook secret, or the production relay
URL in the app.

## Before opening ClassSync

1. In Fireflies, open **Settings → Personal → Developer settings** and copy your
   API key.
2. In Google AI Studio, create or copy a Gemini API key.
3. At `notion.so/my-integrations`, create an internal integration and copy its
   secret.
4. In Notion, open the parent ISEP page, choose **••• → Connections**, and share
   it with the new integration.
5. Keep the current `DEVICE_API_TOKEN` ready. This is the long Cloudflare
   bootstrap token, not `FIREFLIES_WEBHOOK_SECRET`.

## The seven screens

1. **Welcome** lists everything needed and explains what stays local.
2. **Fireflies** accepts the API key and tests it before continuing.
3. **Gemini** accepts the API key and tests the recommended model. The model is
   under Advanced because most users should not change it.
4. **Notion** discovers every database shared with the integration. Select
   `Lista de Cadeiras` and `Histórico de Resumos`. Keep the recommended
   `Fireflies ID` option enabled for reliable cross-device duplicate detection.
5. **Relay** already uses
   `https://classsync-relay.classsync-relay.workers.dev`. Paste only the device
   API token. A different URL can be entered under **Use a different relay** for
   self-hosting or staging.
6. **Automation** controls problem notifications and the platform-specific
   background option.
7. **Ready** reviews every verified connection before saving the credentials to
   OS secure storage.

## Notion database requirements

- `Lista de Cadeiras`: `Nome` (or `Name`), `Ano`, `Semestre`, and `Status`.
- `Histórico de Resumos`: `Nome`, `Data`, and `Cadeira`.
- Only subjects whose `Status` is `In progress` are classification candidates.

ClassSync can add an optional rich-text `Fireflies ID` property to
`Histórico de Resumos`. It does not rename or delete existing properties.

## Relay URL and updates

Normal Worker code deployments, secret rotations, and D1 migrations do not
change the production Worker URL. Change the URL in ClassSync only when moving
to another Worker name, Cloudflare account, custom domain, or staging relay.

The bootstrap device API token is used to enroll each installation. ClassSync
then creates and securely stores a random per-device credential for ordinary
relay calls. Rotating `DEVICE_API_TOKEN` affects new enrollment and
re-enrollment; it does not change the relay URL.

## Already configured outside the app

- Firebase project: `classsync-obl1vi0uzz`.
- Fireflies webhook:
  `https://classsync-relay.classsync-relay.workers.dev/webhooks/fireflies`.
- Cloudflare Worker, D1 database, Firebase service account, and relay secrets.

If the relay is temporarily unavailable, ClassSync still polls Fireflies with a
48-hour overlap so webhook loss does not lose lectures.
