import type { Env, RelayDeviceRow } from "./types";

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

  await Promise.allSettled(
    (devices.results ?? []).map(async (device) => {
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
      if (response.ok) return;
      const errorText = await response.text();
      if (
        response.status === 404 ||
        errorText.includes("UNREGISTERED") ||
        errorText.includes("INVALID_ARGUMENT")
      ) {
        await removeDevice(env, device.id);
        return;
      }
      throw new Error(`FCM send failed: ${response.status}`);
    }),
  );
}
