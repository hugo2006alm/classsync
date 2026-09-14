# Moodle ISEP integration

ClassSync uses Moodle's official Web Services REST endpoint:

```text
https://moodle.isep.ipp.pt/webservice/rest/server.php
```

The REST endpoint and its `invalidtoken` response were verified on 2026-09-06.
ISEP documents one institutional password for Portal, Moodle, email, and Wi-Fi.
ClassSync therefore reuses the Portal login by default and offers a separate
Moodle account for external identities. It sends the password once, over HTTPS,
to Moodle's official `/login/token.php` endpoint with the
`moodle_mobile_app` service shortname. If ISEP enables that service, Moodle
returns a user-scoped Web Services token. ClassSync stores only that token in OS
secure storage and does not retain the password. Token may cross relay only
inside account's opaque AES-256-GCM configuration snapshot. Password never
does. Neither credential enters SQLite, logs, diagnostics, or relay plaintext.

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

The enrolled-course list is committed as soon as Moodle returns it, before the
slower assignment-status and forum requests complete. Automatic Moodle refresh
runs when its 30-minute cache age expires; opening Academic alone causes no
request. Manual Refresh bypasses the age check.

Course mapping uses exact normalized course names, short names, and Notion
aliases. One exact match is linked automatically. Zero or multiple matches stay
unmapped for review. The Moodle course chip opens an explicit subject picker,
and that choice is retained across refreshes and propagated to its deadlines
and announcements. ClassSync never silently merges ambiguous subjects.

Moodle assignments enter the same local evaluation model as Portal exams and
manual evaluations. News and assignment content remain local. Direct links
open on the trusted `isep.ipp.pt` host.

## Permissions

The Moodle administrator controls whether `moodle_mobile_app` can issue tokens
and which Web Service functions those tokens may use. If ISEP disables the
service, ClassSync reports that Moodle app access is unavailable. If one of the
functions above is not exposed to student tokens, that feature cannot
synchronize through the supported API. ClassSync does not scrape authenticated
Moodle pages and never retains the Moodle password.
