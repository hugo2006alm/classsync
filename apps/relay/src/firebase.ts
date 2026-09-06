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
): Promise<void> {
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO push_deliveries
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
      headers: {
        authorization: `Bearer ${accessTokenValue}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({
        message: {
          token: device.push_token,
          notification: {
            title: "ClassSync",
            body: "Nova aula pronta para sincronizar.",
          },
          data: {
            eventId: event.id,
            firefliesTranscriptId: event.transcriptId,
            eventType: event.eventType,
          },
          android: { priority: "high" },
        },
      }),
    },
  );
  if (response.ok) {
    await env.DB.prepare(
      `UPDATE push_deliveries
       SET status = 'delivered', next_attempt_at = NULL, last_status = ?, updated_at = ?
       WHERE event_id = ? AND device_id = ?`,
    ).bind(response.status, new Date().toISOString(), event.id, device.id).run();
    return;
  }
  const errorText = await response.text();
  if (
    response.status === 404 ||
    errorText.includes("UNREGISTERED") ||
    errorText.includes("INVALID_ARGUMENT")
  ) {
    await removeDevice(env, device.id);
    return;
  }
  const cappedAttempt = Math.min(attempt, 6);
  const nextAttempt = new Date(
    Date.now() + 60_000 * 2 ** cappedAttempt,
  ).toISOString();
  await env.DB.prepare(
    `UPDATE push_deliveries
     SET status = 'retry', next_attempt_at = ?, last_status = ?, updated_at = ?
     WHERE event_id = ? AND device_id = ?`,
  ).bind(
    nextAttempt,
    response.status,
    new Date().toISOString(),
    event.id,
    device.id,
  ).run();
  throw new Error(`FCM send failed: ${response.status}`);
}

export async function notifyDevices(
  env: Env,
  event: { id: string; transcriptId: string; eventType: string },
): Promise<void> {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return;
  const account = JSON.parse(
    env.FIREBASE_SERVICE_ACCOUNT_JSON,
  ) as FirebaseServiceAccount;
  const projectId = env.FIREBASE_PROJECT_ID ?? account.project_id;
  const token = await accessToken(account);
  const devices = await env.DB.prepare(
    "SELECT id, push_token, platform FROM relay_devices",
  ).all<RelayDeviceRow>();

  const outcomes = await Promise.allSettled(
    (devices.results ?? []).map(async (device) => {
      await sendToDevice(
        env,
        token,
        projectId,
        device,
        event,
        1,
      );
    }),
  );
  const failed = outcomes.filter((outcome) => outcome.status === "rejected").length;
  if (failed > 0) console.error(`FCM transient failures: ${failed}`);
}

export async function notifyAccountDevices(
  env: Env,
  accountId: string,
  event: { id: string; transcriptId: string; eventType: string },
): Promise<void> {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return;
  const account = JSON.parse(
    env.FIREBASE_SERVICE_ACCOUNT_JSON,
  ) as FirebaseServiceAccount;
  const projectId = env.FIREBASE_PROJECT_ID ?? account.project_id;
  const token = await accessToken(account);
  const devices = await env.DB.prepare(
    `SELECT id, push_token, platform FROM relay_devices
     WHERE account_id = ?`,
  ).bind(accountId).all<RelayDeviceRow>();
  await Promise.allSettled((devices.results ?? []).map(async (device) => {
    const response = await fetch(
      `https://fcm.googleapis.com/v1/projects/${encodeURIComponent(projectId)}/messages:send`,
      {
        method: "POST",
        headers: {
          authorization: `Bearer ${token}`,
          "content-type": "application/json",
        },
        body: JSON.stringify({
          message: {
            token: device.push_token,
            notification: {
              title: "ClassSync",
              body: "Nova aula pronta para sincronizar.",
            },
            data: {
              eventId: event.id,
              firefliesTranscriptId: event.transcriptId,
              eventType: event.eventType,
            },
            android: { priority: "high" },
          },
        }),
      },
    );
    if (response.status === 404 || (await response.text()).includes("UNREGISTERED")) {
      await removeDevice(env, device.id);
    }
  }));
}

export async function retryPendingDeliveries(env: Env): Promise<void> {
  if (!env.FIREBASE_SERVICE_ACCOUNT_JSON) return;
  const account = JSON.parse(env.FIREBASE_SERVICE_ACCOUNT_JSON) as FirebaseServiceAccount;
  const projectId = env.FIREBASE_PROJECT_ID ?? account.project_id;
  const token = await accessToken(account);
  const pending = await env.DB.prepare(
    `SELECT p.event_id, p.device_id, d.push_token, p.attempt_count,
            e.fireflies_transcript_id, e.event_type
     FROM push_deliveries p
     JOIN relay_devices d ON d.id = p.device_id
     JOIN relay_events e ON e.id = p.event_id
     WHERE p.status = 'retry' AND p.next_attempt_at <= ? AND p.attempt_count < 7
     ORDER BY p.next_attempt_at ASC LIMIT 100`,
  ).bind(new Date().toISOString()).all<PushDeliveryRow>();
  await Promise.allSettled((pending.results ?? []).map((row) =>
    sendToDevice(
      env,
      token,
      projectId,
      { id: row.device_id, push_token: row.push_token },
      {
        id: row.event_id,
        transcriptId: row.fireflies_transcript_id,
        eventType: row.event_type,
      },
      row.attempt_count + 1,
    ),
  ));
}
