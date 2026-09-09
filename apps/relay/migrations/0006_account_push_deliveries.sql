CREATE TABLE account_push_deliveries (
  event_id TEXT NOT NULL REFERENCES account_relay_events(id) ON DELETE CASCADE,
  device_id TEXT NOT NULL REFERENCES relay_devices(id) ON DELETE CASCADE,
  status TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  next_attempt_at TEXT,
  last_status INTEGER,
  updated_at TEXT NOT NULL,
  PRIMARY KEY (event_id, device_id)
);

CREATE INDEX account_push_deliveries_retry
  ON account_push_deliveries(status, next_attempt_at);
