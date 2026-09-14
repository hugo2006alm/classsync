# ADR-005: Private account namespaces and encrypted device sync

## Status

Accepted

## Context

Several people may use one hosted relay, while each person owns a different
Fireflies account, Gemini key, and Notion workspace. One person may also use
several Windows and Android devices. Firebase Authentication for Flutter on
Windows remains beta and is not intended for production use.

## Decision

ClassSync uses platform-neutral, passwordless account pairing. The first device
creates a random account ID, relay authentication secret, and independent
256-bit encryption key. A recovery code contains all three values and is the
only way to join another device.

The Worker stores only the SHA-256 hash of the authentication secret. Client
configuration and bounded job metadata are encrypted with AES-256-GCM before
upload. The encryption key never appears in an API request by itself. D1 rows,
webhook events, acknowledgements, and processing claims are scoped by account.
Each account receives a distinct Fireflies webhook URL and a deterministic
32-character signing secret derived inside the Worker.

Full transcripts, prompts, generated summaries, and Notion page content remain
off the relay. Platform behavior such as Windows launch-at-login, Android
background execution, notifications, and local retention is not synchronized.

## Trade-offs

- No paid identity provider is required and Windows/Android share one flow.
- The recovery code is a high-value secret and must be kept in a password
  manager. There is intentionally no email recovery.
- Account identity is device-oriented, not a social profile. Invitations and
  shared workspaces would require a later authorization model.
- Snapshot writes use optimistic revisions; concurrent clients merge job
  metadata and retry on the next sync after a conflict.

## v0.3.9 recovery and delivery clarification

Welcome offers account recovery before API-key setup. Recovery reads and
validates a saved configuration without uploading defaults; finishing setup
preserves restored secrets. Joined account credentials authorize processing
without the account-creation bootstrap token. Account push retries use their
own durable delivery table and cannot fan out through legacy recipients.

## Configuration schema v3 clarification

Encrypted account configuration schema v3 adds every named Fireflies source,
Gemini and Notion credentials/settings, Moodle app token, and Portal
username/password. Moodle password is never retained after token exchange.
Portal needs its login to create new sessions, so no narrower credential is
available. Older snapshots remain valid and absent optional fields never erase
valid local credentials.

Device ID, FCM token, notification permission/preferences, platform background
settings, leases, caches, diagnostics, and bootstrap Device API token remain
device-local and outside configuration snapshots. Relay stores ciphertext,
nonce, schema number, revisions, and coordination metadata; encryption key
remains only in recovery code and devices.
