CREATE TABLE relay_device_auth (
  id TEXT PRIMARY KEY,
  credential_hash TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  revoked_at TEXT
);

CREATE TABLE relay_event_acks (
  event_id TEXT NOT NULL REFERENCES relay_events(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL REFERENCES relay_device_auth(id) ON DELETE CASCADE,
  acknowledged_at TEXT NOT NULL,
  PRIMARY KEY (event_id, device_id)
);

CREATE TABLE processing_claims (
  fireflies_transcript_id TEXT PRIMARY KEY,
  device_id TEXT NOT NULL REFERENCES relay_device_auth(id),
  lease_expires_at TEXT NOT NULL,
  status TEXT NOT NULL,
  notion_page_id TEXT,
  updated_at TEXT NOT NULL
);

ALTER TABLE relay_devices ADD COLUMN device_id TEXT;

CREATE INDEX relay_event_acks_device ON relay_event_acks(device_id, acknowledged_at);
CREATE INDEX processing_claims_expiry ON processing_claims(status, lease_expires_at);
