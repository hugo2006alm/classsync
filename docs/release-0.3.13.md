# ClassSync v0.3.13

- Load the selected timetable week and the following four weeks from Portal's
  official read-only calendar methods instead of repeating the current week.
- Automatically request that five-week window when an uncached selected week is
  empty; the timetable reload wheel uses the same selected window.
- Preserve cached timetable records outside the refreshed window so navigating
  between previously loaded weeks remains available offline.
- Support Portal's JavaScript date rollover across month boundaries while
  keeping strict bounds and never executing remote scripts.
- Verify the real saved-credential probe returns five distinct weeks, including
  rooms and teachers, without exposing credentials or timetable content.

Validated with the DPAPI-protected Portal probe, focused Flutter tests, Flutter
analyzer, full Flutter and relay test suites, coverage gate, and local signed
Windows/Android release builds. No GitHub Actions build is used.
