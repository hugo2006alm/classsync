# ADR-006: Named Fireflies sources

## Status

Accepted

## Context

A Fireflies webhook carries transcript-ready metadata, not transcript content.
Fetching the transcript still requires an API key authorized for the Fireflies
account that owns or can access it. Giving a colleague a ClassSync recovery
code would expose every synchronized credential and is not an acceptable way to
collect that colleague's recordings.

## Decision

One ClassSync account may hold multiple named Fireflies connections. Each
connection has a stable ID, display name, and API key. Keys remain in OS secure
storage and travel between the owner's devices only inside the existing
AES-256-GCM encrypted configuration snapshot.

Polling runs independently for each named connection with its own durable
cursor. A webhook event has no source ID, so the client tries the named keys in
order until one can fetch the transcript, then records the winning connection
ID on the job. Fireflies transcript ID remains the global deduplication key.

Permitted colleagues configure the ClassSync owner's existing webhook URL and
signing secret in their Fireflies account. They do not join the ClassSync
account. The ClassSync owner adds each colleague's API key under a clear name.

The ClassSync account also has a synchronized display name. It is presentation
metadata, not authentication; recovery-code cryptographic fields remain
unchanged.

## Trade-offs

- Each colleague must explicitly share a Fireflies API key with the ClassSync
  owner; that key grants the access defined by Fireflies, not transcript-only
  access.
- Polling and unknown-source webhook resolution can make one API request per
  connection.
- Revoking or removing one key stops new fetches without affecting other
  sources or already-published summaries.
- Stable connection IDs preserve attribution when a connection is renamed.
