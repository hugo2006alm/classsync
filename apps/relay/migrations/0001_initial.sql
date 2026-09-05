CREATE TABLE relay_events (
  id TEXT PRIMARY KEY,
  fireflies_transcript_id TEXT NOT NULL,
  event_type TEXT NOT NULL,
  received_at TEXT NOT NULL,
  acknowledged_at TEXT
);

CREATE UNIQUE INDEX relay_events_fireflies_event_unique
  ON relay_events (fireflies_transcript_id, event_type);

CREATE INDEX relay_events_pending_received
  ON relay_events (acknowledged_at, received_at DESC);
