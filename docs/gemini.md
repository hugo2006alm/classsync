# Gemini

ClassSync calls the Gemini `generateContent` REST API with `responseMimeType: application/json` and explicit JSON schemas.

Default model is `gemini-3.8-flash` as of September 2026. Model names remain user-configurable because availability and retirement change.

Classification receives only active Notion subjects and representative transcript samples. Summary generation uses chunked structured notes followed by a final synthesis when a transcript exceeds the configured chunk size. Every returned subject ID is checked against the supplied candidate set.
