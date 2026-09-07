# ISEP Portal integration

ClassSync uses a read-only adapter for the legacy ASP.NET WebForms Portal at
`https://portal.isep.ipp.pt/intranet/`. Portal credentials and cookies never
enter SQLite, diagnostics, the Cloudflare relay, or source control.

## Authentication and session flow

The public login flow verified on 2026-09-06 is:

1. `GET /intranet/` to receive the session cookie plus WebForms hidden state.
2. `POST /intranet/` as `application/x-www-form-urlencoded`, including all
   hidden inputs and:
   - `ctl00$ContentPlaceHolderMain$txtLoginISEP`
   - `ctl00$ContentPlaceHolderMain$txtPasswordISEP`
   - the image-button `.x` and `.y` fields
3. Follow at most five same-host HTTPS redirects and keep cookies in memory for
   that sync.
4. Treat any response containing the password/login controls as an expired or
   rejected session.

The username and password are stored only in platform secure storage so a
background refresh can establish a new short-lived session. Login replays all
hidden WebForms fields, including `__VIEWSTATE` and `__EVENTVALIDATION` when
present. Academic-state-changing postbacks are not exposed in the UI.

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

FUC tables are parsed into alternative weighted formulas and minimum-component
rules. Imported formulas remain disabled until the user reviews and confirms
them. Publicly verified Portal routes include `/intranet/`,
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
