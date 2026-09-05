import { json, methodNotAllowed, notFound } from "./http";
import { notifyDevices } from "./firebase";
import { isDeviceAuthorized, verifyFirefliesSignature } from "./security";
import type { Env, FirefliesWebhookPayload, RelayEventRow } from "./types";

const allowedEvents = new Set(["meeting.transcribed", "meeting.summarized"]);

function validPayload(value: unknown): value is FirefliesWebhookPayload {
  if (!value || typeof value !== "object") return false;
  const item = value as Record<string, unknown>;
  return (
    typeof item.meeting_id === "string" &&
    item.meeting_id.length > 0 &&
    typeof item.timestamp === "number" &&
    typeof item.event === "string" &&
    allowedEvents.has(item.event)
  );
}

async function receiveWebhook(
  request: Request,
  env: Env,
  context?: ExecutionContext,
): Promise<Response> {
  const rawBody = await request.text();
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
  if (!validPayload(payload)) return json({ error: "invalid_payload" }, 400);

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

async function registerDevice(request: Request, env: Env): Promise<Response> {
  if (!isDeviceAuthorized(request, env.DEVICE_API_TOKEN)) {
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
    await env.DB.prepare("DELETE FROM relay_devices WHERE push_token = ?")
      .bind(value.pushToken)
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
  await env.DB.prepare(
    `INSERT INTO relay_devices (id, push_token, platform, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(push_token) DO UPDATE SET
       platform = excluded.platform,
       updated_at = excluded.updated_at`,
  )
    .bind(id, value.pushToken, value.platform, now, now)
    .run();
  return json({ registered: true, id });
}

async function listEvents(request: Request, env: Env): Promise<Response> {
  if (!isDeviceAuthorized(request, env.DEVICE_API_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }
  const url = new URL(request.url);
  const requestedLimit = Number.parseInt(url.searchParams.get("limit") ?? "50", 10);
  const limit = Number.isFinite(requestedLimit)
    ? Math.min(Math.max(requestedLimit, 1), 100)
    : 50;
  const result = await env.DB.prepare(
    `SELECT id, fireflies_transcript_id, event_type, received_at, acknowledged_at
     FROM relay_events
     WHERE acknowledged_at IS NULL
     ORDER BY received_at ASC
     LIMIT ?`,
  )
    .bind(limit)
    .all<RelayEventRow>();
  return json({ events: result.results ?? [] });
}

async function acknowledgeEvent(
  request: Request,
  env: Env,
  id: string,
): Promise<Response> {
  if (!isDeviceAuthorized(request, env.DEVICE_API_TOKEN)) {
    return json({ error: "unauthorized" }, 401);
  }
  const result = await env.DB.prepare(
    `UPDATE relay_events
     SET acknowledged_at = COALESCE(acknowledged_at, ?)
     WHERE id = ?`,
  )
    .bind(new Date().toISOString(), id)
    .run();
  if ((result.meta.changes ?? 0) === 0) return json({ error: "not_found" }, 404);
  return json({ acknowledged: true, id });
}

export default {
  async fetch(
    request: Request,
    env: Env,
    context?: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);

    if (url.pathname === "/health") {
      return request.method === "GET"
        ? json({ service: "ClassSync Relay", status: "ok" })
        : methodNotAllowed();
    }
    if (url.pathname === "/webhooks/fireflies") {
      return request.method === "POST"
        ? receiveWebhook(request, env, context)
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
    return notFound();
  },
} satisfies ExportedHandler<Env>;
