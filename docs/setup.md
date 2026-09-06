# ClassSync first-run setup

## Updating without setting up again

Install a newer ClassSync build directly over the existing installation. The
local database, preferences, Notion mappings, and credentials in secure storage
remain in place because the Android package ID and Windows installer AppId stay
the same. Do not uninstall the app or clear its storage before updating. Android
also requires the update to use the same signing certificate as the installed
build.

ClassSync opens an eight-step setup guide on its first launch. You need four
credentials: a Fireflies API key, a Gemini API key, a Notion integration token,
and the ClassSync device API token.

You do **not** need to enter Firebase credentials, a Firebase project ID,
Cloudflare account details, or the production relay URL in the app. ClassSync
generates your account-specific Fireflies signing secret during setup.

## Before opening ClassSync

1. In Fireflies, open **Settings → Personal → Developer settings** and copy your
   API key.
2. In Google AI Studio, create or copy a Gemini API key.
3. Duplicate the [ClassSync Notion template](https://checker-dryer-7e3.notion.site/ClassSync-Template-3d387b0ef0908153a466c7aa2f8f7332)
   into your own workspace.
4. At `notion.so/my-integrations`, create an internal integration and copy its
   secret.
5. In Notion, open the copied ClassSync Template page, choose
   **••• → Connections**, and share
   it with the new integration.
6. Keep the current `DEVICE_API_TOKEN` ready. This is the long Cloudflare
   bootstrap token, not `FIREFLIES_WEBHOOK_SECRET`.

## The eight screens

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
6. **Account** creates a private account for one person, or joins that person's
   other devices with a recovery code. Copy its unique URL and signing secret
   into Fireflies Webhooks V2 and subscribe to `meeting.transcribed`.
7. **Automation** controls problem notifications and the platform-specific
   background option.
8. **Ready** reviews every verified connection before saving the credentials to
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

The bootstrap device API token authorizes creation of a random private account.
It cannot open an existing account. The recovery code contains separate relay
authentication and encryption secrets; store it in a password manager.

## Already configured outside the app

- Firebase project: `classsync-obl1vi0uzz`.
- Fireflies webhook base; the Account screen appends your private account ID.
- Cloudflare Worker, D1 database, Firebase service account, and relay secrets.

If the relay is temporarily unavailable, ClassSync still polls Fireflies with a
48-hour overlap so webhook loss does not lose lectures.
