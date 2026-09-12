# ClassSync v0.3.11

- Repair the authenticated ISEP timetable route and parse its real calendar
  payload, including every reported class, room, and teacher.
- Present the timetable as a desktop-first table or agenda. Phones default to
  agenda and can switch to a horizontally scrollable table.
- Repair current grades, previous academic history, and Finance against the
  live student Portal formats. The integration remains read-only and
  fail-closed.
- Focus Academic navigation on Timetable, Tasks, Evaluations, Search & ask,
  Grades & progress, and Finance. Remove non-working placeholder destinations.
- Add a compact page-scoped reload control; refreshing Timetable no longer
  reloads unrelated academic data.
- Add an optional Windows DPAPI-encrypted repeat probe. Credentials stay local,
  are never command-line arguments or diagnostics, and can be deleted with
  `-ForgetSaved`.

Validation includes the full Flutter and relay suites, analyzer, coverage gate,
live read-only Portal route/count probing, and local Windows/Android release
builds. No GitHub Actions build is used.
