## What’s changed

- **Per-transcript summary language** — keep the normal ClassSync default unchanged and choose a different language for an individual transcript. Existing summaries can be regenerated in the selected language and update the same published Library entry.
- **Discard invalid transcripts** — bad or irrelevant recordings can now be discarded from Sync before publishing. ClassSync keeps an ignored local tombstone so the same Fireflies transcript is not queued again when the recovery window sees it later.
- **Library-first navigation** — completed items in Sync and recent summaries on a class page now open inside the ClassSync Library first. The underlying Notion page remains available from the Library when needed.

## Release notes

- Default summary language is unchanged.
- No database schema migration is required for this release.
- Discarding is only available before a summary has been published; published notes remain available through Library.
