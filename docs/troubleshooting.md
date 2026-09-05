# Troubleshooting

## Relay unavailable

Verify `/health`, device token, Worker deployment, and D1 migration. Fireflies polling continues while relay is down.

## Fireflies returns no meetings

Check API key, ownership, Webhooks V2 event, and overlap range. Webhooks are sent only for meetings owned by the account.

## Notion access denied

Share the ISEP page and both data sources with the Notion integration, then run discovery again.

## Windows plugin build fails with symlink error

Enable Windows Developer Mode, reopen the terminal, run `flutter clean`, then `flutter pub get`.

## Safe diagnostics

Exported diagnostics redact bearer tokens, API keys, webhook secrets, full transcripts, and generated summaries.
