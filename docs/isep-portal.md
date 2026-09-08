# ISEP Portal integration

ClassSync uses a read-only adapter for the legacy ASP.NET WebForms Portal at
`https://portal.isep.ipp.pt/intranet/`. Portal credentials and cookies never
enter SQLite, diagnostics, the Cloudflare relay, or source control.

## Authentication and session flow

The public login flow verified on 2026-09-08 is:

1. `GET /intranet/` to receive the session cookie plus WebForms hidden state.
2. `POST /intranet/` as `application/x-www-form-urlencoded`, percent-encoded
   with the login page's ISO-8859-1 character set, including all hidden inputs
   and:
   - `ctl00$ContentPlaceHolderMain$txtLoginISEP`
   - `ctl00$ContentPlaceHolderMain$txtPasswordISEP`
   - the image-button `.x` and `.y` fields
3. Follow at most five same-host HTTPS redirects and keep cookies in memory for
   that sync.
4. Detect the named ISEP sign-in controls to identify an incomplete or expired
   login. The authenticated account dashboard also contains a password field;
   its presence alone is not evidence of a rejected login. Guest pages never
   count as successful account authentication.

Each connection test clears previous cookies and dashboard state and submits
to the form action resolved against the final login-page URL.

For a local interactive diagnostic, run `pwsh -STA -File
apps/client/tool/portal_login_probe.ps1` from the repository root after
`flutter pub get`. This Windows window invokes the actual Dart adapter and
shows request paths, statuses, cookie names, and the result code. Credentials
travel over the child process's standard input, never command-line arguments;
passwords, cookie values, response bodies, and profile data are not logged.

The submitted username is preserved exactly after trimming outer whitespace;
ClassSync does not add or remove the `@isep.ipp.pt` suffix. Portal pages declare
ISO-8859-1, so the adapter uses that charset for both login form submission and
response decoding before matching Portuguese navigation labels.
Browser-equivalent origin, referrer, language, and user-agent headers accompany
the login form.

The username and password are stored only in platform secure storage so a
background refresh can establish a new short-lived session. Login replays all
hidden WebForms fields, including `__VIEWSTATE` and `__EVENTVALIDATION` when
present. Both fields are required for the first connection. Later connection
tests may leave the password blank to reuse the device's stored password.
Academic-state-changing postbacks are not exposed in the UI.

## Feature route discovery

Authenticated route names differ by account role and Portal deployment. After
login, ClassSync discovers feature links from the authenticated navigation by
their Portuguese labels instead of spreading fragile paths through features.
Every implemented feature performs one authenticated `GET` to the same-host
HTTPS `href` selected from the dashboard by these labels; the resolved URL is
retained as provenance:

- enrolment: `unidades curriculares`, `disciplinas inscritas`, `inscrições`;
- timetable: `horário`, `horario`;
- exam schedule: `calendário de exames`, `exames`;
- registration context: `inscrição em exames`, `inscrições em exames`;
- current grades: `classificações parciais`, `classificações`, `notas`;
- history: `histórico académico`, `registo académico`, `histórico`;
- evaluation rules: `ficha de unidade curricular`, `FUC`, `método de avaliação`.
- official lesson summaries: `sumários`, `sumarios`;
- electronic notices: `notificações eletrónicas`, `notificações`;
- tuition and fees: `situação financeira`, `propinas`, `pagamentos`,
  `emolumentos`.

FUC tables are parsed into alternative weighted formulas and minimum-component
rules, plus versioned objectives, syllabus, bibliography, workload, teaching
methods, and lecturer context. Imported formulas remain disabled until the user
reviews and confirms them. Official lesson summaries are matched to local
lectures only when subject and time corroborate; a low lexical coverage score is
shown for review and never overwrites generated notes. Publicly verified Portal routes include `/intranet/`,
`/intranet/home/Guest.aspx`, and `/intranet/ver_horario/ver_horario.aspx`; the
last route is a public room calendar and is never treated as evidence of a
student's enrolment or exam registration.

## Parsing and failure behavior

All selectors, header aliases, date/decimal normalization, registration-state
mapping, and stable external IDs live in `IsepPortalParser`. Parser tests use
sanitized representative fixtures. If required columns disappear or no valid
rows can be produced, the adapter raises `portal_layout_changed`; ClassSync
keeps the last complete cache and never saves a partial replacement.

GET requests retry twice after transport failures. Responses are streamed with
a 2 MiB ceiling. Redirects and discovered links must remain on
`https://portal.isep.ipp.pt`; cookies are never attached to another host.

Portal refresh is independent from Fireflies → Gemini → Notion. A Portal
failure cannot stop lecture discovery, classification, summarization, or
publication.

Exam registration integration is deliberately read-only. ClassSync records the
Portal-reported state, opening/closing window, exam date, and fee when present,
but never interprets a timetable row as proof of registration and exposes no
generic Portal write action. Registration reminders point the student back to
the authoritative Portal page.

## Tuition, fees, and payments

ClassSync reads the authenticated Portal financial page when it is available.
It stores a stable charge identity, description, academic year, installment,
amount, outstanding balance, due/paid dates, state, and late-interest marker.
A changed amount, due date, or state is retained in local academic history
rather than duplicated.

Finance is strictly read-only. It opens the trusted Portal page and can schedule
local reminders before a due date or when a charge becomes overdue. A charge
reported paid or cancelled stops its scheduled reminder. ClassSync never starts
or guarantees a payment and never stores card or banking credentials.

Payment references are sensitive. Complete references never enter cached
records, device-sync payloads, the relay, or diagnostics. The UI keeps only a
masked final-four-character hint for recognising an item before opening Portal.

## Known limitations

- Authentication and account-only pages need validation against a real student
  account after each Portal deployment; no production credentials are used by
  automated tests.
- Pages requiring a course/year selection may need a WebForms postback before
  their result table is available. The adapter supports that protocol, but this
  release does not guess account-specific selection values.
- Portal is unofficial HTML integration. Layout changes are expected to fail
  closed until sanitized fixtures and centralized parsers are updated.

ISEP documents that Portal provides enrolment, exam registration, grades,
certificates, and payment references in its
[student welcome manual](https://www.isep.ipp.pt/files/isep_manual_acolhimento_25_26.pdf).
