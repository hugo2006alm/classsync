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

Classification receives only active Notion subjects and representative transcript samples. Summary generation uses chunked structured notes followed by a final synthesis when a transcript exceeds the configured chunk size. Every returned subject ID is checked against the supplied candidate set.
