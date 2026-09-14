CREATE TABLE account_webhook_activity (
  account_id TEXT PRIMARY KEY REFERENCES sync_accounts(id) ON DELETE CASCADE,
  last_received_at TEXT NOT NULL,
  last_event_type TEXT NOT NULL
);
