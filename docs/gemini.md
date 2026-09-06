# Gemini

ClassSync calls the Gemini `generateContent` REST API with `responseMimeType: application/json` and explicit JSON schemas.

Default model is `gemini-3.8-flash` as of September 2026. Model names remain user-configurable because availability and retirement change.

ClassSync validates a key with the model catalogue instead of spending a
`generateContent` request. If the configured model is retired, unavailable, or
temporarily overloaded, ClassSync tries the next supported stable Flash model
sequentially and remembers the first model that works for the rest of the app
session. It makes at most three generation attempts for one operation and only
one fallback for transient availability errors.

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
are limits, not reserved usage; actual returned output determines consumption.
