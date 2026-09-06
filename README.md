# ClassSync

Local-first university manager and unattended lecture pipeline for Flutter.
ClassSync discovers completed Fireflies transcripts, classifies and summarizes
them with Gemini, and publishes structured study notes to Notion.

![ClassSync icon](apps/client/assets/classsync_icon.png)

## What is included

- Flutter client for Windows and Android; macOS receives compile coverage but
  remains preview-only. iOS automation is not configured.
- Durable Drift/SQLite queue with retries, review states, local cache, manual
  transcript import, and per-job timelines.
- Fireflies GraphQL pagination plus signed Webhooks V2 ingestion.
- Gemini structured classification and long-transcript summarization.
- Notion schema validation, subject filtering, D1-backed global processing
  claims, and retry-safe ClassSync-owned page sections.
- Controlled regenerate, reclassify, and republish actions update the existing
  Notion page instead of creating a duplicate.
- Minimal Cloudflare Worker + D1 relay storing IDs and timestamps only.
- Private per-person account namespaces with AES-256-GCM device sync for keys,
  shared preferences, and bounded lecture status metadata.
- In-app Notion Library grouped by academic semester, with readable summary
  pages and a direct Open in Notion action.
- Windows tray, close-to-tray, periodic polling, autostart, notifications, and
  an Inno Setup installer definition.
- Android WorkManager background sync and user-controlled notifications.
- Firebase Cloud Messaging fast-path using project
  `classsync-obl1vi0uzz`, with authenticated device registration.

## Architecture

```mermaid
flowchart LR
  F[Fireflies] -->|HMAC webhook metadata| R[Worker + D1]
  R -->|authenticated pending IDs| C[Flutter client]
  F -->|GraphQL transcripts| C
  C <--> D[(Drift / SQLite)]
  C -->|structured prompts| G[Gemini]
  C -->|subjects and summaries| N[Notion]
  C --> S[OS secure storage]
```

Notion and Fireflies remain the content systems of record. The relay never sees
transcripts or summaries. Credentials stay in OS secure storage; SQLite holds
operational state and user preferences. See [architecture](docs/architecture.md)
and [sync flow](docs/sync-flow.md).

## Run the client

Prerequisites: current Flutter stable, Visual Studio Desktop C++ tools for
Windows, and Android Studio/SDK for Android. On Windows, enable Developer Mode so
Flutter can create plugin symlinks.

```powershell
cd apps/client
flutter pub get
flutter run -d windows
# or
flutter run -d android
```

The first-run wizard links to the public
[ClassSync Notion template](https://checker-dryer-7e3.notion.site/ClassSync-Template-3d387b0ef0908153a466c7aa2f8f7332),
tests Fireflies, Gemini, and Notion; discovers the shared
Notion data sources; asks before adding the optional `Fireflies ID` property;
uses the hosted production relay URL by default; creates or joins a private
device account; shows its unique Fireflies webhook settings; and configures
automation.
See the [step-by-step setup guide](docs/setup.md). No private Fireflies, Gemini,
Notion, relay, or
Firebase service-account credential is compiled into the app. FlutterFire's
Firebase API key is a public client identifier and should still be restricted
to expected apps/APIs in Google Cloud.

Required Notion data-source properties:

- **Lista de Cadeiras:** `Nome` (or `Name`), `Ano`, `Semestre`,
  `Status`; optional `Aliases`, `Professores`, `Horário`.
- **Histórico de Resumos:** `Nome`, `Data`, `Cadeira`; optional
  `Fireflies ID`, which helps reconciliation after interrupted publication.

## Deploy the relay

```powershell
pnpm install
cd apps/relay
pnpm exec wrangler login
pnpm exec wrangler d1 create classsync-relay
# Paste the returned database_id into wrangler.jsonc.
pnpm exec wrangler d1 migrations apply classsync-relay --remote
pnpm exec wrangler secret put FIREFLIES_WEBHOOK_SECRET
pnpm exec wrangler secret put DEVICE_API_TOKEN
pnpm deploy
```

The setup wizard creates an account-specific `https://<worker>/webhooks/fireflies/<account>`
endpoint and shows its 32-character signing secret. Register those values in
Fireflies Webhooks V2 for `meeting.transcribed`. Legacy single-user installs can
continue using `/webhooks/fireflies`. Full details are in
[Cloudflare setup](docs/cloudflare.md) and [Fireflies setup](docs/fireflies.md).

## Verify and package

```powershell
pnpm relay:check
cd apps/client
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release
flutter build apk --release
```

After the Windows release build, compile
`packaging/windows/classsync.iss` with Inno Setup. CI performs checks without
real credentials and publishes a Windows installer artifact.

Pushing a `v*` tag validates both projects, requires Android and Windows signing
secrets, builds APK/AAB plus Authenticode-signed Windows installer, generates
checksums and provenance, then publishes every artifact in one gated job.

## Privacy and failure behavior

- Logs and diagnostics redact tokens, Authorization headers, transcripts, and
  generated summaries.
- Automatic cleanup can remove completed transcript payloads while retaining
  audit metadata.
- Relay loss falls back to overlap-window Fireflies polling.
- Ambiguous classes stop in **Needs review**; terminal and retryable failures are
  distinct.
- Generated Notion content lives in revision-marked ClassSync-owned toggles.
  Retries reconcile markers; regeneration never deletes user/template blocks.
- Transcript and summary checkpoints are plaintext inside OS-protected app data.
  Completed payloads are removed by default; abandoned content follows retention
  settings and can be purged manually.

See [background processing](docs/background-processing.md), integration guides
under [docs](docs), [Firebase setup](docs/firebase.md), and
[troubleshooting](docs/troubleshooting.md).
