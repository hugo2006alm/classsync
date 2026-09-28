## What's changed

- **Next class at a glance** — Overview prioritizes a class starting within the
  next four days, including time, room, subject, lesson type, and teacher.
- **Faster timetable reading** — desktop and mobile now open on the structured
  time-by-weekday table, while agenda remains available on demand.
- **More resilient Portal imports** — attendance preserves Portuguese accents,
  and exam registration accepts the live titled-grid layout plus the official
  no-active-period response without mistaking navigation for data.
- **Recoverable background jobs** — Android persists discovered transcript jobs
  to encrypted account sync before expensive processing, keeping history and
  recovery visible across devices after process interruption.
- **More stable Gemini output** — structured generation uses bounded thinking,
  handles finish reasons and token exhaustion explicitly, and retries one
  malformed response before entering durable backoff.

## Release notes

- No local database or relay migration is required for this release.
- Relay code is unchanged from v0.3.22.
- Built and validated locally without GitHub Actions.
