CREATE TABLE registration_invites (
  id TEXT PRIMARY KEY,
  code_hash TEXT NOT NULL UNIQUE,
  created_at TEXT NOT NULL,
  expires_at TEXT,
  used_at TEXT,
  revoked_at TEXT
);

CREATE INDEX registration_invites_code_hash_idx
  ON registration_invites(code_hash);
