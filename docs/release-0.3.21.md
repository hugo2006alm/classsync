## What's changed

- **Absences** — Academic now shows the Portal attendance record by subject and,
  when the official data can be matched reliably, the percentage against every
  planned class through the end of the teaching period, plus the remaining
  TP + PL allowance under the one-third rule.
- **School calendar** — official teaching periods, breaks, and exam windows are
  available from Academic's compact More menu as an upcoming-first timeline.
- **Clearer Tasks and Evaluations** — task deadlines remain under Tasks;
  Evaluations are reserved for graded tests, exams, presentations, and projects.
  Tasks now synchronize across every device paired to the same account.
- **Clearer Grades & progress** — assessment weights can be added explicitly,
  their purpose is explained in context, and official history stays distinct
  from current grade planning.
- **Quieter, safer imports** — unavailable optional Portal/Moodle sources no
  longer dominate the screen, and repeated Portal navigation text is rejected
  instead of being displayed as exam registration data.
- **More reliable Notion publishing** — transient first-append failures on a
  newly created page retry inline using the existing idempotent content marker.
- **Reliable Android wake-ups** — transcript-ready pushes now create expedited,
  per-event background work; background automation retains its FCM token even
  when visible alerts are disabled, initializes all headless dependencies, and
  includes the current WorkManager Android 16 handshake fix.

## Release notes

- Portal and Moodle data remain read-only and locally cached.
- No local database or relay migration is required for this release.
- Built and validated locally without GitHub Actions.
