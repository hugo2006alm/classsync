import { boundedBody, json, methodNotAllowed, notFound } from "./http";
import { notifyAccountDevices, notifyDevices, retryPendingDeliveries } from "./firebase";
import {
  accountWebhookSecret,
  authenticatedAccount,
  authenticatedDevice,
  isDeviceAuthorized,
  sha256,
  randomSecret,
  verifyFirefliesSignature,
} from "./security";
import type {
  Env,
  AccountSnapshotRow,
  FirefliesWebhookPayload,
  ProcessingClaimRow,
  RelayEventRow,
} from "./types";

const allowedEvents = new Set(["meeting.transcribed"]);
const maxWebhookBytes = 64 * 1024;
const webhookSkewMs = 5 * 60 * 1000;
const snapshotScopes = new Set(["config", "jobs"]);
const maxSnapshotBytes = 700 * 1024;

function validPayload(value: unknown): value is FirefliesWebhookPayload {
  if (!value || typeof value !== "object") return false;
  const item = value as Record<string, unknown>;
  return (
    typeof item.meeting_id === "string" &&
    item.meeting_id.length > 0 &&
    item.meeting_id.length <= 256 &&
    typeof item.timestamp === "number" &&
    typeof item.event === "string" &&
    allowedEvents.has(item.event)
  );
}

function isFirefliesTestPayload(value: unknown): boolean {
  if (!value || typeof value !== "object") return false;
  const event = (value as Record<string, unknown>).event;
  return event === "test" || event === "webhook.test";
}

async function receiveWebhook(
  request: Request,
  env: Env,
  context?: ExecutionContext,
): Promise<Response> {
  const declaredLength = Number.parseInt(
    request.headers.get("content-length") ?? "0",
    10,
  );
  if (declaredLength > maxWebhookBytes) {
    return json({ error: "payload_too_large" }, 413);
  }
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maxWebhookBytes) {
    return json({ error: "payload_too_large" }, 413);
  }
  const validSignature = await verifyFirefliesSignature(
    rawBody,
    request.headers.get("x-hub-signature"),
    env.FIREFLIES_WEBHOOK_SECRET,
  );
  if (!validSignature) return json({ error: "invalid_signature" }, 401);

  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  // Fireflies' Test Webhook uses a signed synthetic event without a meeting.
  // Acknowledge it, but never persist or deliver it as production work.
  if (isFirefliesTestPayload(payload)) {
    return json({ accepted: true, test: true });
  }
  if (!validPayload(payload)) return json({ error: "invalid_payload" }, 400);
  const timestampMs = payload.timestamp < 10_000_000_000
    ? payload.timestamp * 1000
    : payload.timestamp;
  if (Math.abs(Date.now() - timestampMs) > webhookSkewMs) {
    return json({ error: "stale_webhook" }, 401);
  }

  const id = `${payload.event}:${payload.meeting_id}`;
  const receivedAt = new Date().toISOString();
  const inserted = await env.DB.prepare(
    `INSERT INTO relay_events
       (id, fireflies_transcript_id, event_type, received_at, acknowledged_at)
     VALUES (?, ?, ?, ?, NULL)
     ON CONFLICT(fireflies_transcript_id, event_type) DO NOTHING`,
  )
    .bind(id, payload.meeting_id, payload.event, receivedAt)
    .run();
  if ((inserted.meta.changes ?? 0) > 0) {
    context?.waitUntil(
      notifyDevices(env, {
        id,
        transcriptId: payload.meeting_id,
        eventType: payload.event,
      }),
    );
  }

  return json({ accepted: true, id }, 202);
}

async function createAccount(request: Request, env: Env): Promise<Response> {
  if (!isDeviceAuthorized(request, env.DEVICE_API_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }
  const id = crypto.randomUUID();
  const authSecret = randomSecret(48);
  await env.DB.prepare(
    `INSERT INTO sync_accounts (id, auth_hash, created_at, revoked_at)
     VALUES (?, ?, ?, NULL)`,
  ).bind(id, await sha256(authSecret), new Date().toISOString()).run();
  return json({ accountId: id, authSecret, protocolVersion: 3 }, 201);
}

async function accountSession(request: Request, env: Env): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  return accountId
    ? json({ service: "ClassSync Relay", protocolVersion: 3, accountId })
    : json({ error: "unauthorized" }, 401);
}

async function accountWebhookConfig(
  request: Request,
  env: Env,
): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  if (!accountId) return json({ error: "unauthorized" }, 401);
  const url = new URL(request.url);
  return json({
    webhookUrl: `${url.origin}/webhooks/fireflies/${encodeURIComponent(accountId)}`,
    signingSecret: await accountWebhookSecret(
      accountId,
      env.FIREFLIES_WEBHOOK_SECRET,
    ),
  });
}

async function receiveAccountWebhook(
  request: Request,
  env: Env,
  accountId: string,
  context?: ExecutionContext,
): Promise<Response> {
  if (!/^[a-zA-Z0-9-]{20,80}$/.test(accountId)) {
    return json({ error: "not_found" }, 404);
  }
  const account = await env.DB.prepare(
    "SELECT id FROM sync_accounts WHERE id = ? AND revoked_at IS NULL",
  ).bind(accountId).first<{ id: string }>();
  if (!account) return json({ error: "not_found" }, 404);
  const rawBody = await request.text();
  if (new TextEncoder().encode(rawBody).byteLength > maxWebhookBytes) {
    return json({ error: "payload_too_large" }, 413);
  }
  const secret = await accountWebhookSecret(
    accountId,
    env.FIREFLIES_WEBHOOK_SECRET,
  );
  if (!(await verifyFirefliesSignature(
    rawBody,
    request.headers.get("x-hub-signature"),
    secret,
  ))) {
    return json({ error: "invalid_signature" }, 401);
  }
  let payload: unknown;
  try {
    payload = JSON.parse(rawBody);
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (isFirefliesTestPayload(payload)) {
    return json({ accepted: true, test: true });
  }
  if (!validPayload(payload)) return json({ error: "invalid_payload" }, 400);
  const timestampMs = payload.timestamp < 10_000_000_000
    ? payload.timestamp * 1000
    : payload.timestamp;
  if (Math.abs(Date.now() - timestampMs) > webhookSkewMs) {
    return json({ error: "stale_webhook" }, 401);
  }
  const id = `${accountId}:${payload.event}:${payload.meeting_id}`;
  const inserted = await env.DB.prepare(
    `INSERT INTO account_relay_events
       (id, account_id, fireflies_transcript_id, event_type, received_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(account_id, fireflies_transcript_id, event_type) DO NOTHING`,
  ).bind(
    id,
    accountId,
    payload.meeting_id,
    payload.event,
    new Date().toISOString(),
  ).run();
  if ((inserted.meta.changes ?? 0) > 0) {
    context?.waitUntil(notifyAccountDevices(env, accountId, {
      id,
      transcriptId: payload.meeting_id,
      eventType: payload.event,
    }));
  }
  return json({ accepted: true, id }, 202);
}

function accountDeviceId(request: Request): string | null {
  const value = request.headers.get("x-classsync-device-id") ?? "";
  return /^[a-zA-Z0-9-]{8,80}$/.test(value) ? value : null;
}

async function listAccountEvents(request: Request, env: Env): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  const deviceId = accountDeviceId(request);
  if (!accountId || !deviceId) return json({ error: "unauthorized" }, 401);
  const result = await env.DB.prepare(
    `SELECT e.id, e.fireflies_transcript_id, e.event_type, e.received_at,
            a.acknowledged_at
     FROM account_relay_events e
     LEFT JOIN account_event_acks a
       ON a.event_id = e.id AND a.device_id = ?
     WHERE e.account_id = ? AND a.event_id IS NULL
     ORDER BY e.received_at ASC LIMIT 100`,
  ).bind(deviceId, accountId).all<RelayEventRow>();
  return json({ events: result.results ?? [] });
}

async function registerAccountDevice(
  request: Request,
  env: Env,
): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  const deviceId = accountDeviceId(request);
  if (!accountId || !deviceId) return json({ error: "unauthorized" }, 401);
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const value = body as Record<string, unknown>;
  if (
    !value || typeof value.pushToken !== "string" ||
    value.pushToken.length < 32 || value.pushToken.length > 4096 ||
    value.platform !== "android"
  ) return json({ error: "invalid_payload" }, 400);
  if (request.method === "DELETE") {
    await env.DB.prepare(
      "DELETE FROM relay_devices WHERE push_token = ? AND account_id = ? AND device_id = ?",
    ).bind(value.pushToken, accountId, deviceId).run();
    return json({ registered: false });
  }
  const id = await sha256(value.pushToken);
  const now = new Date().toISOString();
  const result = await env.DB.prepare(
    `INSERT INTO relay_devices
       (id, push_token, platform, created_at, updated_at, device_id, account_id)
     VALUES (?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(push_token) DO UPDATE SET platform = excluded.platform,
       updated_at = excluded.updated_at, device_id = excluded.device_id,
       account_id = excluded.account_id
     WHERE relay_devices.account_id = excluded.account_id
       AND relay_devices.device_id = excluded.device_id`,
  ).bind(id, value.pushToken, value.platform, now, now, deviceId, accountId).run();
  if ((result.meta.changes ?? 0) !== 1) return json({ error: "registration_not_owned" }, 409);
  return json({ registered: true, id });
}

async function acknowledgeAccountEvent(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  const deviceId = accountDeviceId(request);
  if (!accountId || !deviceId) return json({ error: "unauthorized" }, 401);
  const event = await env.DB.prepare(
    "SELECT id FROM account_relay_events WHERE id = ? AND account_id = ?",
  ).bind(id, accountId).first<{ id: string }>();
  if (!event) return json({ error: "not_found" }, 404);
  await env.DB.prepare(
    `INSERT INTO account_event_acks (event_id, device_id, acknowledged_at)
     VALUES (?, ?, ?) ON CONFLICT(event_id, device_id) DO NOTHING`,
  ).bind(id, deviceId, new Date().toISOString()).run();
  return json({ acknowledged: true, id });
}

async function claimAccountTranscript(
  request: Request,
  env: Env,
  transcriptId: string,
): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  const deviceId = accountDeviceId(request);
  if (!accountId || !deviceId) return json({ error: "unauthorized" }, 401);
  if (!transcriptId || transcriptId.length > 256) {
    return json({ error: "invalid_id" }, 400);
  }
  const now = new Date();
  const nowIso = now.toISOString();
  const expires = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
  await env.DB.prepare(
    `INSERT INTO account_processing_claims
       (account_id, fireflies_transcript_id, device_id, lease_expires_at,
        status, notion_page_id, updated_at)
     VALUES (?, ?, ?, ?, 'processing', NULL, ?)
     ON CONFLICT(account_id, fireflies_transcript_id) DO NOTHING`,
  ).bind(accountId, transcriptId, deviceId, expires, nowIso).run();
  await env.DB.prepare(
    `UPDATE account_processing_claims
     SET device_id = ?, lease_expires_at = ?, status = 'processing', updated_at = ?
     WHERE account_id = ? AND fireflies_transcript_id = ?
       AND ((status != 'completed' AND (device_id = ? OR lease_expires_at <= ?))
         OR (status = 'completed' AND notion_page_id = ?))`,
  ).bind(deviceId, expires, nowIso, accountId, transcriptId, deviceId, nowIso,
    request.headers.get("x-classsync-reprocess-page-id")).run();
  const claim = await env.DB.prepare(
    `SELECT fireflies_transcript_id, device_id, lease_expires_at, status,
            notion_page_id, updated_at
     FROM account_processing_claims
     WHERE account_id = ? AND fireflies_transcript_id = ?`,
  ).bind(accountId, transcriptId).first<ProcessingClaimRow>();
  return json({
    acquired: claim?.device_id === deviceId && claim.status === "processing",
    completed: claim?.status === "completed",
    notionPageId: claim?.notion_page_id ?? null,
    leaseExpiresAt: claim?.lease_expires_at ?? null,
  });
}

async function completeAccountTranscript(
  request: Request,
  env: Env,
  transcriptId: string,
): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  const deviceId = accountDeviceId(request);
  if (!accountId || !deviceId) return json({ error: "unauthorized" }, 401);
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const notionPageId = (body as Record<string, unknown>)?.notionPageId;
  if (typeof notionPageId !== "string" || notionPageId.trim().length === 0 || notionPageId.length > 128) {
    return json({ error: "invalid_payload" }, 400);
  }
  const result = await env.DB.prepare(
    `UPDATE account_processing_claims
     SET status = 'completed', notion_page_id = ?, updated_at = ?
     WHERE account_id = ? AND fireflies_transcript_id = ? AND device_id = ?`,
  ).bind(
    notionPageId,
    new Date().toISOString(),
    accountId,
    transcriptId,
    deviceId,
  ).run();
  return (result.meta.changes ?? 0) === 1
    ? json({ completed: true })
    : json({ error: "claim_not_owned" }, 409);
}

async function accountSnapshot(
  request: Request,
  env: Env,
  scope: string,
): Promise<Response> {
  const accountId = await authenticatedAccount(request, env);
  const deviceId = accountDeviceId(request);
  if (!accountId || !deviceId) return json({ error: "unauthorized" }, 401);
  if (!snapshotScopes.has(scope)) return json({ error: "invalid_scope" }, 400);
  if (request.method === "GET") {
    const row = await env.DB.prepare(
      `SELECT revision, ciphertext, nonce, schema_version, updated_at, device_id
       FROM account_sync_snapshots WHERE account_id = ? AND scope = ?`,
    ).bind(accountId, scope).first<AccountSnapshotRow>();
    return row ? json(row) : json({ revision: 0 });
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const value = body as Record<string, unknown>;
  if (
    !value ||
    !Number.isInteger(value.baseRevision) ||
    typeof value.ciphertext !== "string" ||
    typeof value.nonce !== "string" ||
    !Number.isInteger(value.schemaVersion) ||
    value.ciphertext.length > maxSnapshotBytes ||
    value.nonce.length > 64
  ) return json({ error: "invalid_payload" }, 400);
  const current = await env.DB.prepare(
    "SELECT revision FROM account_sync_snapshots WHERE account_id = ? AND scope = ?",
  ).bind(accountId, scope).first<{ revision: number }>();
  const baseRevision = value.baseRevision as number;
  if ((current?.revision ?? 0) !== baseRevision) {
    return json({ error: "revision_conflict", revision: current?.revision ?? 0 }, 409);
  }
  const nextRevision = baseRevision + 1;
  const now = new Date().toISOString();
  if (current) {
    const changed = await env.DB.prepare(
      `UPDATE account_sync_snapshots
       SET revision = ?, ciphertext = ?, nonce = ?, schema_version = ?,
           updated_at = ?, device_id = ?
       WHERE account_id = ? AND scope = ? AND revision = ?`,
    ).bind(
      nextRevision,
      value.ciphertext,
      value.nonce,
      value.schemaVersion,
      now,
      deviceId,
      accountId,
      scope,
      baseRevision,
    ).run();
    if ((changed.meta.changes ?? 0) !== 1) {
      return json({ error: "revision_conflict" }, 409);
    }
  } else {
    const inserted = await env.DB.prepare(
      `INSERT INTO account_sync_snapshots
       (account_id, scope, revision, ciphertext, nonce, schema_version,
        updated_at, device_id) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(account_id, scope) DO NOTHING`,
    ).bind(
      accountId,
      scope,
      nextRevision,
      value.ciphertext,
      value.nonce,
      value.schemaVersion,
      now,
      deviceId,
    ).run();
    if ((inserted.meta.changes ?? 0) !== 1) {
      return json({ error: "revision_conflict" }, 409);
    }
  }
  return json({ revision: nextRevision, updatedAt: now });
}

async function registerDevice(request: Request, env: Env): Promise<Response> {
  const deviceId = await authenticatedDevice(request, env);
  if (!deviceId) {
    return json({ error: "unauthorized" }, 401);
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  if (!body || typeof body !== "object") {
    return json({ error: "invalid_payload" }, 400);
  }
  const value = body as Record<string, unknown>;
  if (
    typeof value.pushToken !== "string" ||
    value.pushToken.length < 32 ||
    value.pushToken.length > 4096 ||
    value.platform !== "android"
  ) {
    return json({ error: "invalid_payload" }, 400);
  }
  if (request.method === "DELETE") {
    await env.DB.prepare("DELETE FROM relay_devices WHERE push_token = ? AND device_id = ? AND account_id IS NULL")
      .bind(value.pushToken, deviceId)
      .run();
    return json({ registered: false });
  }
  const digest = await crypto.subtle.digest(
    "SHA-256",
    new TextEncoder().encode(value.pushToken),
  );
  const id = Array.from(new Uint8Array(digest))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  const now = new Date().toISOString();
  const result = await env.DB.prepare(
    `INSERT INTO relay_devices (id, push_token, platform, created_at, updated_at, device_id)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(push_token) DO UPDATE SET
       platform = excluded.platform,
       updated_at = excluded.updated_at,
       device_id = excluded.device_id
     WHERE relay_devices.device_id = excluded.device_id
       AND relay_devices.account_id IS NULL`,
  )
    .bind(id, value.pushToken, value.platform, now, now, deviceId)
    .run();
  if ((result.meta.changes ?? 0) !== 1) return json({ error: "registration_not_owned" }, 409);
  return json({ registered: true, id });
}

async function listEvents(request: Request, env: Env): Promise<Response> {
  const deviceId = await authenticatedDevice(request, env);
  if (!deviceId) {
    return json({ error: "unauthorized" }, 401);
  }
  const url = new URL(request.url);
  const requestedLimit = Number.parseInt(url.searchParams.get("limit") ?? "50", 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 50;
  const result = await env.DB.prepare(
    `SELECT e.id, e.fireflies_transcript_id, e.event_type, e.received_at,
            a.acknowledged_at
     FROM relay_events e
     LEFT JOIN relay_event_acks a
       ON a.event_id = e.id AND a.device_id = ?
     WHERE a.event_id IS NULL
     ORDER BY e.received_at ASC
     LIMIT ?`,
  )
    .bind(deviceId, limit)
    .all<RelayEventRow>();
  return json({ events: result.results ?? [] });
}

async function acknowledgeEvent(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  const deviceId = await authenticatedDevice(request, env);
  if (!deviceId) {
    return json({ error: "unauthorized" }, 401);
  }
  const exists = await env.DB.prepare("SELECT id FROM relay_events WHERE id = ?")
    .bind(id)
    .first<{ id: string }>();
  if (!exists) return json({ error: "not_found" }, 404);
  await env.DB.prepare(
    `INSERT INTO relay_event_acks (event_id, device_id, acknowledged_at)
     VALUES (?, ?, ?)
     ON CONFLICT(event_id, device_id) DO NOTHING`,
  )
    .bind(id, deviceId, new Date().toISOString())
    .run();
  return json({ acknowledged: true, id });
}

async function enrollDevice(request: Request, env: Env): Promise<Response> {
  if (!isDeviceAuthorized(request, env.DEVICE_API_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const value = body as Record<string, unknown>;
  if (
    !value ||
    typeof value.deviceId !== "string" ||
    !/^[a-zA-Z0-9-]{8,80}$/.test(value.deviceId) ||
    typeof value.credential !== "string" ||
    value.credential.length < 32 ||
    value.credential.length > 256
  ) {
    return json({ error: "invalid_payload" }, 400);
  }
  const now = new Date().toISOString();
  await env.DB.prepare(
    `INSERT INTO relay_device_auth
       (id, credential_hash, created_at, updated_at, revoked_at)
     VALUES (?, ?, ?, ?, NULL)
     ON CONFLICT(id) DO UPDATE SET
       credential_hash = excluded.credential_hash,
       updated_at = excluded.updated_at,
       revoked_at = NULL`,
  )
    .bind(value.deviceId, await sha256(value.credential), now, now)
    .run();
  return json({ enrolled: true, deviceId: value.deviceId, protocolVersion: 2 });
}

async function session(request: Request, env: Env): Promise<Response> {
  if (isDeviceAuthorized(request, env.DEVICE_API_TOKEN)) {
    return json({ service: "ClassSync Relay", protocolVersion: 2, role: "bootstrap" });
  }
  const deviceId = await authenticatedDevice(request, env);
  return deviceId
    ? json({ service: "ClassSync Relay", protocolVersion: 2, role: "device", deviceId })
    : json({ error: "unauthorized" }, 401);
}

async function revokeDevice(request: Request, env: Env): Promise<Response> {
  const deviceId = await authenticatedDevice(request, env);
  if (!deviceId) return json({ error: "unauthorized" }, 401);
  const now = new Date().toISOString();
  await env.DB.prepare(
    "UPDATE relay_device_auth SET revoked_at = ?, updated_at = ? WHERE id = ?",
  ).bind(now, now, deviceId).run();
  await env.DB.prepare("DELETE FROM relay_devices WHERE device_id = ? AND account_id IS NULL")
    .bind(deviceId)
    .run();
  return json({ revoked: true, deviceId });
}

async function claimTranscript(
  request: Request,
  env: Env,
  transcriptId: string,
): Promise<Response> {
  const deviceId = await authenticatedDevice(request, env);
  if (!deviceId) return json({ error: "unauthorized" }, 401);
  if (!transcriptId || transcriptId.length > 256) {
    return json({ error: "invalid_id" }, 400);
  }
  const now = new Date();
  const nowIso = now.toISOString();
  const expires = new Date(now.getTime() + 30 * 60 * 1000).toISOString();
  await env.DB.prepare(
    `INSERT INTO processing_claims
       (fireflies_transcript_id, device_id, lease_expires_at, status, notion_page_id, updated_at)
     VALUES (?, ?, ?, 'processing', NULL, ?)
     ON CONFLICT(fireflies_transcript_id) DO NOTHING`,
  )
    .bind(transcriptId, deviceId, expires, nowIso)
    .run();
  await env.DB.prepare(
    `UPDATE processing_claims
     SET device_id = ?, lease_expires_at = ?, status = 'processing', updated_at = ?
     WHERE fireflies_transcript_id = ?
       AND ((status != 'completed' AND (device_id = ? OR lease_expires_at <= ?))
         OR (status = 'completed' AND notion_page_id = ?))`,
  )
    .bind(deviceId, expires, nowIso, transcriptId, deviceId, nowIso,
      request.headers.get("x-classsync-reprocess-page-id"))
    .run();
  const claim = await env.DB.prepare(
    `SELECT fireflies_transcript_id, device_id, lease_expires_at, status,
            notion_page_id, updated_at
     FROM processing_claims WHERE fireflies_transcript_id = ?`,
  )
    .bind(transcriptId)
    .first<ProcessingClaimRow>();
  return json({
    acquired: claim?.device_id === deviceId && claim.status === "processing",
    completed: claim?.status === "completed",
    notionPageId: claim?.notion_page_id ?? null,
    leaseExpiresAt: claim?.lease_expires_at ?? null,
  });
}

async function completeTranscript(
  request: Request,
  env: Env,
  transcriptId: string,
): Promise<Response> {
  const deviceId = await authenticatedDevice(request, env);
  if (!deviceId) return json({ error: "unauthorized" }, 401);
  let body: unknown;
  try {
    body = await request.json();
  } catch {
    return json({ error: "invalid_json" }, 400);
  }
  const notionPageId = (body as Record<string, unknown>)?.notionPageId;
  if (typeof notionPageId !== "string" || notionPageId.trim().length === 0 || notionPageId.length > 128) {
    return json({ error: "invalid_payload" }, 400);
  }
  const result = await env.DB.prepare(
    `UPDATE processing_claims
     SET status = 'completed', notion_page_id = ?, updated_at = ?
     WHERE fireflies_transcript_id = ? AND device_id = ?`,
  )
    .bind(notionPageId, new Date().toISOString(), transcriptId, deviceId)
    .run();
  return (result.meta.changes ?? 0) === 1
    ? json({ completed: true })
    : json({ error: "claim_not_owned" }, 409);
}

export default {
  async fetch(
    request: Request,
    env: Env,
    context?: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    try {
      decodeURIComponent(url.pathname);
    } catch {
      return json({ error: "invalid_path" }, 400);
    }
    if (request.body) {
      const limit = url.pathname.startsWith("/account/sync/")
        ? maxSnapshotBytes + 4096 : maxWebhookBytes;
      const body = await boundedBody(request, limit);
      if (body === null) return json({ error: "payload_too_large" }, 413);
      request = new Request(request, { body });
    }

    if (url.pathname === "/health") {
      return request.method === "GET"
        ? json({ service: "ClassSync Relay", status: "ok" })
        : methodNotAllowed();
    }
    if (url.pathname === "/session") {
      if (request.method === "GET") return session(request, env);
      if (request.method === "DELETE") return revokeDevice(request, env);
      return methodNotAllowed();
    }
    if (url.pathname === "/accounts") {
      return request.method === "POST"
        ? createAccount(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/account/session") {
      return request.method === "GET"
        ? accountSession(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/account/webhook-config") {
      return request.method === "GET"
        ? accountWebhookConfig(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/account/events") {
      return request.method === "GET"
        ? listAccountEvents(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/account/devices/register") {
      return request.method === "POST" || request.method === "DELETE"
        ? registerAccountDevice(request, env)
        : methodNotAllowed();
    }
    const accountAcknowledgement = url.pathname.match(
      /^\/account\/events\/([^/]+)\/ack$/,
    );
    if (accountAcknowledgement) {
      return request.method === "POST"
        ? acknowledgeAccountEvent(
            request,
            env,
            decodeURIComponent(accountAcknowledgement[1]!),
          )
        : methodNotAllowed();
    }
    const accountCompletion = url.pathname.match(
      /^\/account\/claims\/([^/]+)\/complete$/,
    );
    if (accountCompletion) {
      return request.method === "POST"
        ? completeAccountTranscript(
            request,
            env,
            decodeURIComponent(accountCompletion[1]!),
          )
        : methodNotAllowed();
    }
    const accountClaim = url.pathname.match(/^\/account\/claims\/([^/]+)$/);
    if (accountClaim) {
      return request.method === "POST"
        ? claimAccountTranscript(
            request,
            env,
            decodeURIComponent(accountClaim[1]!),
          )
        : methodNotAllowed();
    }
    const snapshot = url.pathname.match(/^\/account\/sync\/([^/]+)$/);
    if (snapshot) {
      return request.method === "GET" || request.method === "PUT"
        ? accountSnapshot(request, env, decodeURIComponent(snapshot[1]!))
        : methodNotAllowed();
    }
    if (url.pathname === "/devices/enroll") {
      return request.method === "POST"
        ? enrollDevice(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/webhooks/fireflies") {
      return request.method === "POST"
        ? receiveWebhook(request, env, context)
        : methodNotAllowed();
    }
    const accountWebhook = url.pathname.match(
      /^\/webhooks\/fireflies\/([^/]+)$/,
    );
    if (accountWebhook) {
      return request.method === "POST"
        ? receiveAccountWebhook(
            request,
            env,
            decodeURIComponent(accountWebhook[1]!),
            context,
          )
        : methodNotAllowed();
    }
    if (url.pathname === "/devices/register") {
      return request.method === "POST" || request.method === "DELETE"
        ? registerDevice(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/events") {
      return request.method === "GET" ? listEvents(request, env) : methodNotAllowed();
    }
    const acknowledgement = url.pathname.match(/^\/events\/([^/]+)\/ack$/);
    if (acknowledgement) {
      return request.method === "POST"
        ? acknowledgeEvent(request, env, decodeURIComponent(acknowledgement[1]!))
        : methodNotAllowed();
    }
    const completion = url.pathname.match(/^\/claims\/([^/]+)\/complete$/);
    if (completion) {
      return request.method === "POST"
        ? completeTranscript(request, env, decodeURIComponent(completion[1]!))
        : methodNotAllowed();
    }
    const claim = url.pathname.match(/^\/claims\/([^/]+)$/);
    if (claim) {
      return request.method === "POST"
        ? claimTranscript(request, env, decodeURIComponent(claim[1]!))
        : methodNotAllowed();
    }
    return notFound();
  },
  async scheduled(_controller: ScheduledController, env: Env): Promise<void> {
    await retryPendingDeliveries(env);
    const now = Date.now();
    const eventCutoff = new Date(now - 30 * 24 * 60 * 60 * 1000).toISOString();
    const deviceCutoff = new Date(now - 90 * 24 * 60 * 60 * 1000).toISOString();
    await env.DB.prepare(
      `DELETE FROM relay_events
       WHERE received_at < ?
         AND NOT EXISTS (
           SELECT 1 FROM relay_device_auth d
           WHERE d.revoked_at IS NULL AND NOT EXISTS (
             SELECT 1 FROM relay_event_acks a
             WHERE a.event_id = relay_events.id AND a.device_id = d.id
           )
         )`,
    ).bind(eventCutoff).run();
    await env.DB.prepare("DELETE FROM relay_devices WHERE updated_at < ?")
      .bind(deviceCutoff)
      .run();
    await env.DB.prepare(
      `DELETE FROM relay_device_auth WHERE revoked_at IS NOT NULL AND updated_at < ?
       AND NOT EXISTS (SELECT 1 FROM processing_claims WHERE device_id = relay_device_auth.id)`,
    ).bind(deviceCutoff).run();
    const claimCutoff = new Date(now - 180 * 24 * 60 * 60 * 1000).toISOString();
    await env.DB.prepare(
      "DELETE FROM processing_claims WHERE status = 'completed' AND updated_at < ?",
    ).bind(claimCutoff).run();
    await env.DB.prepare(
      "DELETE FROM account_relay_events WHERE received_at < ?",
    ).bind(eventCutoff).run();
    await env.DB.prepare(
      `DELETE FROM account_processing_claims
       WHERE status = 'completed' AND updated_at < ?`,
    ).bind(claimCutoff).run();
  },
} satisfies ExportedHandler<Env>;
