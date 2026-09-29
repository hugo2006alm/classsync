# ClassSync v0.3.25

## What's changed since v0.3.24

- New accounts can leave ISEP Portal and Moodle disabled during setup. Enable or disable both later under **Settings → Connections**.
- When disabled, ClassSync stops ISEP imports and hides imported Academic sections, cached imported records, search hits, and next-class widget data. Local tasks and manual evaluations remain available.
- Existing accounts keep ISEP imports enabled after upgrading. The preference follows encrypted account recovery and device sync. Stored credentials and cached records remain available if the sources are enabled again.

## Upgrade notes

- Flutter version: `0.3.25+33`.
- Local database schema 8 adds the academic-source preference with an enabled default for existing installations. No relay migration is required.
- Android updates require the same signing certificate as existing installations.
