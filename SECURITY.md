# Security policy

## Report a vulnerability

Please use [GitHub private vulnerability reporting](https://github.com/hugo2006alm/classsync/security/advisories/new) for a suspected security issue. Do not open a public issue or pull request with exploit details, credentials, recovery codes, transcripts, or personal academic records.

Include affected version or commit, reproduction steps, and impact. Use synthetic data and redact all credentials. The maintainer will acknowledge the report and coordinate a fix and disclosure through the private advisory.

## Supported versions

Security fixes target the latest release and current `main`. Older releases may require an update to receive a fix.

## Public Firebase configuration

The generated FlutterFire client configuration contains a Firebase API key. Firebase uses it to identify the project; it is not a private Gemini API key or a Firebase service-account credential. It must be restricted to required Firebase APIs in Google Cloud. Never add the Generative Language API to its allowlist. Keep Gemini, Fireflies, Notion, relay, and Firebase service-account credentials out of source and issue reports. See [Firebase configuration](docs/firebase.md).
