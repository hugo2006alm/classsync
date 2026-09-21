# Troubleshooting

## Relay unavailable

Verify authenticated `/session`, bootstrap token, Worker deployment, and D1
migrations. Fireflies polling continues while relay is down.

## Fireflies returns no meetings

Check API key, ownership, Webhooks V2 event, and overlap range. Webhooks are sent only for meetings owned by the account.

## Notion access denied

Share the ISEP page and both data sources with the Notion integration, then run discovery again.

## Gemini unavailable or a job appears stuck

Retryable Gemini failures retain their planned backoff. If the app is open on a
repeated failure, ClassSync can offer another named model; declining does not
cancel the scheduled retry. On Android, a manually started request can pause
while the app is backgrounded and resume when it is opened. After a processing
lease expires, use **Recover** on the job.

An old Gemini error must not remain on a completed job. Current releases clear
the stored error on progress/success and only render the red error panel for a
current failed state.

## A job looks different on another device

Cross-device sync intentionally transfers status metadata, selected class,
summary title, and the Notion link. It does not copy transcript text,
classification evidence, or generated summary content. The receiving device
therefore shows that the job completed elsewhere and directs the user to
Fireflies or Notion instead of claiming those local payloads were never created.
Lecture tasks do synchronize inside the encrypted account snapshot, excluding
their supporting transcript segment.

## A new Notion page fails on its first content append

ClassSync rechecks its generated-content marker and retries short-lived Notion
404, 409, network, and server failures inline. A persisted page remains the
checkpoint, so a later job retry never creates a second summary page.

## Windows plugin build fails with symlink error

Enable Windows Developer Mode, reopen the terminal, run `flutter clean`, then `flutter pub get`.

## Safe diagnostics

Exported diagnostics redact bearer tokens, API keys, webhook secrets, full transcripts, and generated summaries.
