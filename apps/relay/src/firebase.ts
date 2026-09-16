import type { Env, PushDeliveryRow, RelayDeviceRow } from "./types";

interface FirebaseServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
  token_uri?: string;
}

let cachedAccessToken: { value: string; expiresAt: number } | undefined;

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replaceAll("+", "-").replaceAll("/", "_").replace(/=+$/, "");
}

function privateKeyBytes(pem: string): ArrayBuffer {
  const base64 = pem
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replaceAll(/\s/g, "");
  const binary = atob(base64);
  const bytes = new Uint8Array(binary.length);
  for (let index = 0; index < binary.length; index += 1) {
    bytes[index] = binary.charCodeAt(index);
  }
  return bytes.buffer;
}

async function accessToken(account: FirebaseServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedAccessToken && cachedAccessToken.expiresAt > now + 60) {
    return cachedAccessToken.value;
  }
  const header = base64Url(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const claims = base64Url(
    JSON.stringify({
      iss: account.client_email,
      scope: "https://www.googleapis.com/auth/firebase.messaging",
      aud: account.token_uri ?? "https://oauth2.googleapis.com/token",
      iat: now,
      exp: now + 3600,
    }),
  );
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    "pkcs8",
    privateKeyBytes(account.private_key),
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    key,
    new TextEncoder().encode(unsigned),
  );
  const assertion = `${unsigned}.${base64Url(new Uint8Array(signature))}`;
  const response = await fetch(
    account.token_uri ?? "https://oauth2.googleapis.com/token",
    {
      method: "POST",
      headers: { "content-type": "application/x-www-form-urlencoded" },
      body: new URLSearchParams({
        grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
        assertion,
      }),
    },
  );
  if (!response.ok) throw new Error(`Firebase OAuth failed: ${response.status}`);
  const payload = (await response.json()) as {
    access_token: string;
    expires_in?: number;
  };
  cachedAccessToken = {
    value: payload.access_token,
    expiresAt: now + (payload.expires_in ?? 3600),
  };
  return payload.access_token;
}

async function removeDevice(env: Env, id: string): Promise<void> {
  await env.DB.prepare("DELETE FROM relay_devices WHERE id = ?").bind(id).run();
}

async function sendToDevice(
  env: Env,
  accessTokenValue: string,
  projectId: string,
  device: { id: string; push_token: string },
  event: { id: string; transcriptId: string; eventType: string },
  attempt: number,
  table: "push_deliveries" | "account_push_deliveries" = "push_deliveries",
): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO ${table}
       (event_id, device_id, status, attempt_count, next_attempt_at, last_status, updated_at)
     VALUES (?, ?, 'sending', ?, NULL, NULL, ?)
     ON CONFLICT(event_id, device_id) DO UPDATE SET
       status = 'sending', attempt_count = excluded.attempt_count,
       next_attempt_at = NULL, updated_at = excluded.updated_at`,
  ).bind(event.id, device.id, attempt, now).run();
  const response = await fetch(
    `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
    {
      method: "POST",
      signal: AbortSignal.timeout(15_000),
      headers: {
        authorization: `Bearer ${accessTokenValue}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.push_token,
          data: {
            eventId: event.id,
            firefliesTranscriptId: event.transcriptId,
            eventType: event.eventType,
            wakeReason: "transcript_ready",
          },
          android: {
            priority: "high",
            ttl: "900s",
          },
        },
      }),
    },
  ).catch(() => null);
  if (response?.ok) {
    await env.DB.prepare(
      `UPDATE ${table}
       SET status = 'delivered', next_attempt_at = NULL, last_status = ?, updated_at = ?
       WHERE event_id = ? AND device_id = ?`,
    ).bind(response.status, new Date().toISOString(), event.id, device.id).run();
    return;
  }
  const errorText = response ? await response.text() : "";
  if (
    errorText.includes("UNREGISTERED")
  ) {
    await removeDevice(env, device.id);
    return;
  }
  const cappedAttempt = Math.min(attempt, 6);
  const nextAttempt = new Date(
    Date.now() + 60_000 * 2 ** cappedAttempt,
  ).toISOString();
  await env.DB.prepare(
    `UPDATE ${table}
     SET status = 'retry', next_attempt_at = ?, last_status = ?, updated_at = ?
     WHERE event_id = ? AND device_id = ?`,
  ).bind(
    nextAttempt,
    response?.status ?? 0,
    new Date().toISOString(),
    event.id,
    device.id,
  ).run();
  throw new Error(`FCM send failed: ${response?.status ?? "network"}`);
}

type DeliveryTable = "push_deliveries" | "account_push_deliveries";
type PushEvent = { id: string; transcriptId: string; eventType: string };

async function deliverBatch<T>(items: T[], action: (item: T) => Promise<void>): Promise<void> {
  for (let offset = 0; offset < items.length; offset += 10) {
    const outcomes = await Promise.allSettled(items.slice(offset, offset + 10).map(action));
    const failed = outcomes.filter((outcome) => outcome.status === "rejected").length;
    if (failed) console.error(`FCM transient failures: ${failed}`);
  }
}

async function notify(env: Env, event: PushEvent, accountId?: string): Promise<void> {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return;
  const table: DeliveryTable = accountId ? "account_push_deliveries" : "push_deliveries";
  const query = env.DB.prepare(
    `SELECT id, push_token, platform FROM relay_devices WHERE ${accountId ? "account_id = ?" : "account_id IS NULL"} ORDER BY id LIMIT 1000`,
  );
  const devices = await (accountId ? query.bind(accountId) : query).all<RelayDeviceRow>();
  const now = new Date().toISOString();
  // Persist before OAuth and FCM so transport failure or process death is recoverable.
  for (const device of devices.results ?? []) {
    await env.DB.prepare(
      `INSERT INTO ${table} (event_id, device_id, status, attempt_count, next_attempt_at, updated_at)
       VALUES (?, ?, 'retry', 0, ?, ?) ON CONFLICT(event_id, device_id) DO NOTHING`,
    ).bind(event.id, device.id, now, now).run();
  }
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON) as FirebaseServiceAccount;
  const token = await accessToken(account);
  await deliverBatch(devices.results ?? [], (device) => sendToDevice(
    env, token, env.FIREBASE_PROJECT_ID ?? account.project_id, device, event, 1, table,
  ));
}

export async function notifyDevices(env: Env, event: PushEvent): Promise<void> {
  await notify(env, event);
}

export async function notifyAccountDevices(env: Env, accountId: string, event: PushEvent): Promise<void> {
  await notify(env, event, accountId);
}

export async function retryPendingDeliveries(env: Env): Promise<void> {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return;
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON) as FirebaseServiceAccount;
  const projectId = env.FIREBASE_PROJECT_ID ?? account.project_id;
  const token = await accessToken(account);
  const now = new Date().toISOString();
  const stale = new Date(Date.now() - 15 * 60_000).toISOString();
  for (const table of ["push_deliveries", "account_push_deliveries"] as const) {
    const scoped = table === "account_push_deliveries";
    const pending = await env.DB.prepare(
      `SELECT p.event_id, p.device_id, d.push_token, p.attempt_count,
              e.fireflies_transcript_id, e.event_type
       FROM ${table} p
       JOIN relay_devices d ON d.id = p.device_id
       JOIN ${scoped ? "account_relay_events" : "relay_events"} e ON e.id = p.event_id
       WHERE ((p.status = 'retry' AND p.next_attempt_at <= ?)
         OR (p.status = 'sending' AND p.updated_at <= ?)) AND p.attempt_count < 7
         AND ${scoped ? "d.account_id = e.account_id" : "d.account_id IS NULL"}
       ORDER BY p.updated_at ASC LIMIT 100`,
    ).bind(now, stale).all<PushDeliveryRow>();
    await deliverBatch(pending.results ?? [], (row) => sendToDevice(
      env, token, projectId, { id: row.device_id, push_token: row.push_token },
      { id: row.event_id, transcriptId: row.fireflies_transcript_id, eventType: row.event_type },
      row.attempt_count + 1, table,
    ));
  }
}
