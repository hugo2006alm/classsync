# Moodle ISEP integration

ClassSync uses Moodle's official Web Services REST endpoint:

```text
https://moodle.isep.ipp.pt/webservice/rest/server.php
```

The endpoint and its `invalidtoken` response were verified on 2026-09-06.
ClassSync requires a user-scoped Web Services token and never stores a Moodle
password. The token stays in OS secure storage and is sent only to the HTTPS
Moodle host. It never enters the relay, SQLite, logs, or diagnostics.

## Read-only functions

- `core_webservice_get_site_info`: validate token and obtain user ID.
- `core_enrol_get_users_courses`: list enrolled courses.
- `mod_assign_get_assignments`: import assignment deadlines.
- `mod_assign_get_submission_status`: read the connected student's submission
  state when the token role permits it; otherwise status remains unknown.
- `mod_forum_get_forums_by_courses`: find course news forums.
- `mod_forum_get_forum_discussions_paginated`: import bounded recent news.

Sync is bounded to 100 courses, 300 assignments, 100 news forums, 20 recent
discussions per forum, and 300 cached announcements per refresh. Stable Moodle
IDs prevent duplicates. Expired or revoked tokens return an actionable
reconnect message while the last complete cache remains available offline.
Responses are streamed with a 2 MiB ceiling and transport calls retry twice.
After the initial full import, assignment `timemodified` and discussion
timestamps drive incremental merges; the cursor is advanced only after the
local cache succeeds.

Course mapping uses exact normalized course names, short names, and Notion
aliases. One exact match is linked automatically. Zero or multiple matches stay
unmapped for review. The Moodle course chip opens an explicit subject picker,
and that choice is retained across refreshes and propagated to its deadlines
and announcements. ClassSync never silently merges ambiguous subjects.

Moodle assignments enter the same local evaluation model as Portal exams and
manual evaluations. News and assignment content remain local. Direct links
open on the trusted `isep.ipp.pt` host.

## Permissions

The Moodle administrator controls which Web Service functions a token may use.
If ISEP does not expose one of the functions above to student tokens, that
feature cannot synchronize through the supported API; ClassSync does not fall
back to password scraping.
