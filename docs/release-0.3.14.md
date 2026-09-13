# ClassSync v0.3.14

- Render timetable tables with fixed 50-minute ISEP periods. A longer class now
  occupies each period it spans instead of creating a second overlapping range.
- Select the latest dated Portal academic-history curriculum and remove exact
  duplicate history rows, correcting earned progress from 180 to the Portal's
  verified 120 ECTS.
- Import the complete Portal payment plan, including future instalments through
  June 2027, while keeping finance read-only and payment references private.
- Add optional daily payment reminders from the due date at 09:00. Reminders are
  cancelled after a refresh reports the instalment paid or cancelled; the
  existing advance reminder remains available.
- Force one history refresh after upgrade so stale duplicated ECTS are replaced.

Validated against the DPAPI-protected Portal account without exposing
credentials or academic/payment contents: 65 timetable entries across five
weeks, 20 unique completed units totaling 120 ECTS, and 10 payment-plan rows.
Also validated with Flutter analyzer, focused regression tests, the full Flutter
and relay suites, coverage gate, a local Windows installer, and a locally signed
Android release build.
No GitHub Actions build is used.
