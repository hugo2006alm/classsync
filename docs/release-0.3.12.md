# ClassSync v0.3.12

- Replace the desktop timetable record list with a time-by-weekday grid. Agenda
  remains the phone default, and either view can be selected on any device.
- Repeat Portal's regular weekly timetable template across selected weeks while
  preserving official dates for exceptional events.
- Keep Timetable and Tasks directly visible. Move Evaluations, Grades &
  progress, and Finance into a compact More menu; remove Search & ask.
- Restore labeled Academic Reload for every configured source and add a small
  page-scoped reload wheel beside every section title.
- Queue a manual page refresh behind an active background/global refresh so
  grades, history, finance, and other scoped requests are never silently lost.
- Extend the sanitized live Portal probe with timetable date-range diagnostics.

Validated with the saved DPAPI-protected Portal probe, Flutter analyzer, full
Flutter and relay test suites, coverage gate, and local Windows/Android release
builds. No GitHub Actions build is used.
