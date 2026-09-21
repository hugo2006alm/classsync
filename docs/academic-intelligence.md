# Academic intelligence and source-of-truth rules

The Academic hub is an offline-first view over typed records in the local Drift
cache. Portal and Moodle refreshes replace one source/kind atomically using
stable external IDs. Changed official fields retain a local change record;
failed or unrecognized pages leave the previous complete cache untouched.

## Lecture tasks

Gemini emits structured candidates only for explicit student work or
administrative instructions. Every candidate includes its source lecture,
confidence, supporting transcript segment, optional timestamp, and an ISO date
only when the teacher supplied enough date information. Ambiguous or undated
items are marked for review. Normalized title/date identities deduplicate a
lecture, while completion, dismissal, and user edits are preserved when the
same lecture is processed again. Task deadlines remain in Tasks. Evaluations
are reserved for graded assessments such as tests, exams, presentations, and
projects that directly contribute to a subject grade.

## Absences and school calendar

Absence data is read-only Portal data and remains separate from timetable
exceptions. When the Portal does not expose a complete denominator, ClassSync
matches the UC edition to the official timetable and counts every planned
class in the active teaching period, including future classes through its end.
The UI labels whether the ratio is measured in sessions or hours and does not
invent a percentage when a reliable full-period denominator is unavailable.
When Portal identifies TP and PL lesson types, ClassSync also shows how many
more TP + PL sessions or hours fit inside the one-third absence limit. Session
allowances round down because a student cannot miss a fraction of a class.

The school calendar is also read-only and is presented as an operational
timeline of teaching periods, breaks, exams, and other official date ranges.
Both sources retain their trusted Portal URL and stay in the local academic
cache; neither is sent through the relay.

Lecture tasks are account state. Their bounded title, description, due date,
subject, and lifecycle status synchronize inside the account's AES-256-GCM
snapshot. Supporting transcript evidence remains device-local.

## Course context and official lesson summaries

FUC records retain UC identity, academic year/version, lecturers, workload,
objectives, outcomes, syllabus, bibliography, methodologies, evaluation rules,
and the Portal source URL. Only a bounded set for the selected subject is sent
as context during summarization. It may name curriculum topics but cannot
override what the transcript says.

Portal `sumários` remain visibly official and separate from generated notes.
Matching requires the mapped UC plus a compatible date/time and stores its
confidence. Low content coverage is a review signal, not an instruction to
overwrite either source.

## Search and grounded answers

Keyword search is local and makes no Gemini request. It searches cached academic
records, generated summaries, and only those transcripts still present under
the configured retention policy. Filters cover subject, semester, date window,
and content type. “Ask from evidence” first retrieves locally, sends at most 12
matching excerpts, rejects invented citation IDs, and reports insufficient
evidence instead of asking Gemini when retrieval is empty.

## Portal safety

Electronic notices are cached with Portal provenance and a local-only read flag;
ClassSync never marks the remote notice read. Portal and Moodle alert preferences
are separate. Enrolment, history, ECTS, exam options, registration windows,
states, and fees are read-only. ClassSync never infers registration from an exam
schedule and implements no registration write endpoint.
