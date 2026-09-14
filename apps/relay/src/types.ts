export interface Env {
  DB: D1Database;
  FIREFLIES_WEBHOOK_SECRET: string;
  DEVICE_API_TOKEN: string;
  ACCOUNT_REGISTRATION_MODE?: string;
  ACCOUNT_REGISTRATION_TOKEN?: string;
  RELAY_ADMIN_TOKEN?: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_SERVICE_ACCOUNT_JSON?: string;
}

export interface RelayDeviceRow {
  id: string;
  push_token: string;
  platform: string;
}

export interface RelayDeviceAuthRow {
  id: string;
  credential_hash: string;
  revoked_at: string | null;
}

export interface FirefliesWebhookPayload {
  event: "meeting.transcribed";
  timestamp: number;
  meeting_id: string;
  client_reference_id?: string;
}

export interface ProcessingClaimRow {
  fireflies_transcript_id: string;
  device_id: string;
  lease_expires_at: string;
  status: string;
  notion_page_id: string | null;
  updated_at: string;
}

export interface PushDeliveryRow {
  event_id: string;
  device_id: string;
  push_token: string;
  attempt_count: number;
  fireflies_transcript_id: string;
  event_type: string;
}

export interface RelayEventRow {
  id: string;
  fireflies_transcript_id: string;
  event_type: string;
  received_at: string;
  acknowledged_at: string | null;
}

export interface SyncAccountRow {
  id: string;
  auth_hash: string;
  revoked_at: string | null;
}

export interface AccountSnapshotRow {
  revision: number;
  ciphertext: string;
  nonce: string;
  schema_version: number;
  updated_at: string;
  device_id: string;
}
