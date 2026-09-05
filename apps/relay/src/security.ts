const encoder = new TextEncoder();

function constantTimeEqual(left: string, right: string): boolean {
  const length = Math.max(left.length, right.length);
  let mismatch = left.length ^ right.length;
  for (let index = 0; index < length; index += 1) {
    mismatch |= (left.charCodeAt(index) || 0) ^ (right.charCodeAt(index) || 0);
  }
  return mismatch === 0;
}

export async function verifyFirefliesSignature(
  rawBody: string,
  signature: string | null,
  secret: string,
): Promise<boolean> {
  if (!signature?.startsWith("sha256=") || !secret) return false;

  const key = await crypto.subtle.importKey(
    "raw",
    encoder.encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const digest = await crypto.subtle.sign("HMAC", key, encoder.encode(rawBody));
  const hex = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return constantTimeEqual(signature.toLowerCase(), `sha256=${hex}`);
}

export function isDeviceAuthorized(request: Request, token: string): boolean {
  const authorization = request.headers.get("authorization") ?? "";
  const supplied = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : "";
  return token.length >= 32 && constantTimeEqual(supplied, token);
}

export async function sha256(value: string): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", encoder.encode(value));
  return Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export async function authenticatedDevice(
  request: Request,
  env: import("./types").Env,
): Promise<string | null> {
  const id = request.headers.get("x-classsync-device-id") ?? "";
  const authorization = request.headers.get("authorization") ?? "";
  const credential = authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length)
    : "";
  if (!/^[a-zA-Z0-9-]{8,80}$/.test(id) || credential.length < 32) return null;
  const row = await env.DB.prepare(
    "SELECT id, credential_hash, revoked_at FROM relay_device_auth WHERE id = ?",
  )
    .bind(id)
    .first<import("./types").RelayDeviceAuthRow>();
  if (!row || row.revoked_at) return null;
  return constantTimeEqual(await sha256(credential), row.credential_hash)
    ? row.id
    : null;
}
