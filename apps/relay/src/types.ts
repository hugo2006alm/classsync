export interface Env {
  DB: D1Database;
  FIREFLIES_WEBHOOK_SECRET: string;
  DEVICE_API_TOKEN: string;
  FIREBASE_PROJECT_ID?: string;
  FIREBASE_SERVICE_ACCOUNT_JSON?: string;
}

export interface RelayDeviceRow {
  id: string;
  push_token: string;
  platform: string;
}

export interface FirefliesWebhookPayload {
  event: "meeting.transcribed" | "meeting.summarized";
  timestamp: number;
  meeting_id: string;
  client_reference_id?: string;
}

export interface RelayEventRow {
  id: string;
  fireflies_transcript_id: string;
  event_type: string;
  received_at: string;
  acknowledged_at: string | null;
}
