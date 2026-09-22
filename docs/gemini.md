# Gemini

ClassSync calls the Gemini `generateContent` REST API with `responseMimeType: application/json` and explicit JSON schemas.

Class identification defaults to the lower-cost `gemini-3.1-flash-lite` model;
structured summary generation defaults to `gemini-3.8-flash` as of September
2026. Settings and first-run setup present supported models by product name in
dropdowns rather than requiring raw model IDs. Legacy saved IDs remain visible
until the user selects a supported model.

Automatic AI identification is account-configurable. When disabled, ClassSync
still applies an exact saved correction for a matching lecture title; otherwise
it pauses at **Needs review** with the active Notion subjects for manual choice.
Manual choices are persisted as local corrections. A user may also change an
AI-selected class after publication: ClassSync regenerates subject-dependent
content and replaces only its owned Notion section on the existing page.

ClassSync validates a key with the model catalogue instead of spending a
`generateContent` request. If the configured model is retired, unavailable, or
temporarily overloaded, ClassSync tries the next supported stable Flash model
sequentially and remembers the first model that works for the rest of the app
session. It tries at most three model candidates for one operation and only one
fallback for transient availability errors. A malformed structured generation
is retried once immediately before the durable job is released to backoff.

After repeated Gemini failures (attempt 3, attempt 6, and the final attempt), an
open foreground app offers a named model dropdown. Accepting switches the model
for that operation and retries immediately. Declining, or having no foreground
app, leaves exponential backoff unchanged.

Authentication failures, timeouts, and HTTP 429 quota responses never trigger
model hopping. Quota responses honor the server's retry delay with a minimum
one-minute cooldown, because switching models usually does not bypass a
project-level limit. Successful chunk checkpoints are reused so a later retry
does not regenerate completed sections.

Classification receives only active Notion subjects and a representative
transcript sample. It uses a 2,048-token output ceiling. Every returned subject
ID is checked against the supplied candidate set.

Summary generation treats the transcript as untrusted source material, not as
instructions. Notes preserve the teacher's topic order and every distinct
teaching point. Structured output has dedicated fields for:

- teacher emphasis;
- small but important details and side remarks;
- student questions with the teacher's answers;
- assignments, deadlines, reading, assessment instructions, and notices;
- definitions, formulas, code, algorithms, examples, warnings, edge cases, and
  uncertainties.

Only greetings, verbal filler, off-topic chatter, and exact repetition are
removed. Missing or unreliable facts are never completed by guesswork.

Long transcripts use chunked structured notes and resumable checkpoints,
followed by hierarchical synthesis. Every synthesis request must preserve
chronology and every specialized list. Output ceilings scale with detail mode:
6,144 tokens for concise, 10,240 for balanced, and 16,384 for detailed. These
are limits shared by model thinking and visible output, not reserved usage.
ClassSync requests `minimal` thinking from Gemini 3 Flash-Lite and `low`
thinking from other Gemini 3 text models so structured JSON is not crowded out
by hidden reasoning tokens. It also reads the response finish reason and
reports token exhaustion separately from malformed JSON.
