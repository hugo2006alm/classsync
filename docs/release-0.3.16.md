# ClassSync v0.3.16

- Add manual class selection to every eligible sync job and allow correcting an
  AI-selected class without creating a second Notion page.
- Add an account-synced setting to disable automatic AI class identification;
  use Gemini 3.1 Flash-Lite as the lighter classification default.
- Replace raw Gemini model inputs with named dropdowns in setup, Settings, and
  the repeated-failure recovery prompt.
- Keep normal backoff after Gemini failures while offering a foreground model
  switch on repeated attempts, and restore a Recover action for expired jobs.
- Add a full-screen mobile transcript reader.
- Clear obsolete failure data when a job progresses or completes and make
  cross-device status, transcript, classification, and summary messages agree
  with the relay's metadata-only privacy boundary.
- Add database migration and regression coverage for recovery, manual subject
  replacement, AI-disabled review, model prompting, device settings sync, and
  mobile transcript display.

Validated locally with frozen dependency installation, relay checks, Flutter
formatting/analyzer/tests with coverage, Windows and signed Android release
builds, signing-certificate verification, and Inno Setup packaging. No GitHub
Actions build is used.
