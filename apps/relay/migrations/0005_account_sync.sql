CREATE TABLE sync_accounts (
  id TEXT PRIMARY KEY,
  auth_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  revoked_at TEXT
);

CREATE TABLE account_relay_events (
  id TEXT PRIMARY KEY,
  account_id TEXT NOT NULL REFERENCES sync_accounts(id) ON DELETE CASCADE,
  fireflies_transcript_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  received_at TEXT NOT NULL,
  UNIQUE(account_id, fireflies_transcript_id, event_type)
);

CREATE TABLE account_event_acks (
  event_id TEXT NOT NULL REFERENCES account_relay_events(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL,
  acknowledged_at TEXT NOT NULL,
  PRIMARY KEY (event_id, device_id)
);

CREATE TABLE account_processing_claims (
  account_id TEXT NOT NULL REFERENCES sync_accounts(id) ON DELETE CASCADE,
  fireflies_transcript_id TEXT NOT NULL,
  device_id TEXT NOT NULL,
  lease_expires_at TEXT NOT NULL,
  status TEXT NOT NULL,
  notion_page_id TEXT,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (account_id, fireflies_transcript_id)
);

CREATE TABLE account_sync_snapshots (
  account_id TEXT NOT NULL REFERENCES sync_accounts(id) ON DELETE CASCADE,
  scope TEXT NOT NULL,
  revision INTEGER NOT NULL,
  ciphertext TEXT NOT NULL,
  nonce TEXT NOT NULL,
  schema_version INTEGER NOT NULL,
  updated_at TEXT NOT NULL,
  device_id TEXT NOT NULL,
  PRIMARY KEY (account_id, scope)
);

CREATE INDEX account_events_pending
  ON account_relay_events(account_id, received_at DESC);
CREATE INDEX account_claims_expiry
  ON account_processing_claims(account_id, status, lease_expires_at);

ALTER TABLE relay_devices ADD COLUMN account_id TEXT;
CREATE INDEX relay_devices_account_updated
  ON relay_devices(account_id, updated_at DESC);
