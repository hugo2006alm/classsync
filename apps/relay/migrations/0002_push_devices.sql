CREATE TABLE relay_devices (
  id TEXT PRIMARY KEY,
  push_token TEXT NOT NULL UNIQUE,
  platform TEXT NOT NULL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE INDEX relay_devices_platform_updated
  ON relay_devices (platform, updated_at DESC);
