ClassSync 0.3.8 repairs the Academic hub's live ISEP data and makes refreshes faster to use.

- Connect Portal and Moodle with one ISEP login, with a separate Moodle-account option for external users.
- Load special-season exams from the authenticated Portal calendar, including times and rooms.
- Load progress and finance from the student record's read-only endpoints and reject Portal menu/script markup.
- Cache Moodle courses as soon as their first request completes, with clearer connected-but-empty guidance.
- Refresh academic data in stages. The visible section moves to the front between requests; opening Academic uses cached data instead of forcing a refresh.
- Show per-section last-updated status and keep refresh errors behind a compact details row.
- Put Timetable, Tasks, and Updates first; move evaluations, progress, finance, course context, and search into More.

All validation and release builds were run locally.
