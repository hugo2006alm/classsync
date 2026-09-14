import legacyHandler from "./index";
import { json, methodNotAllowed } from "./http";
import { isDeviceAuthorized, randomSecret, sha256 } from "./security";
import type { Env } from "./types";

type RegistrationMode = "open" | "invite" | "token";

function registrationMode(env: Env): RegistrationMode {
  const configured = env.ACCOUNT_REGISTRATION_MODE?.trim().toLowerCase();
  if (configured === "open" || configured === "invite" || configured === "token") {
    return configured;
  }
  return "token";
}

function bearer(request: Request): string {
  const authorization = request.headers.get("authorization") ?? "";
  return authorization.startsWith("Bearer ")
    ? authorization.slice("Bearer ".length).trim()
    : "";
}

async function consumeInvite(request: Request, env: Env): Promise<boolean> {
  const code = bearer(request);
  if (!code.startsWith("CSINV-") || code.length < 32 || code.length > 160) {
    return false;
  }
  const hash = await sha256(code);
  const now = new Date().toISOString();
  const invite = await env.DB.prepare(
    `SELECT id FROM registration_invites
     WHERE code_hash = ? AND used_at IS NULL AND revoked_at IS NULL
       AND (expires_at IS NULL OR expires_at > ?)`,
  ).bind(hash, now).first<{ id: string }>();
  if (!invite) return false;
  const consumed = await env.DB.prepare(
    `UPDATE registration_invites SET used_at = ?
     WHERE id = ? AND used_at IS NULL AND revoked_at IS NULL
       AND (expires_at IS NULL OR expires_at > ?)`,
  ).bind(now, invite.id, now).run();
  return (consumed.meta.changes ?? 0) === 1;
}

async function authorizeRegistration(request: Request, env: Env): Promise<boolean> {
  switch (registrationMode(env)) {
    case "open":
      return true;
    case "invite":
      return consumeInvite(request, env);
    case "token":
      return isDeviceAuthorized(
        request,
        env.ACCOUNT_REGISTRATION_TOKEN?.trim() || env.DEVICE_API_TOKEN,
      );
  }
}

async function createAccount(request: Request, env: Env): Promise<Response> {
  if (!(await authorizeRegistration(request, env))) {
    return json({ error: "registration_unauthorized" }, 401);
  }
  const id = crypto.randomUUID();
  const authSecret = randomSecret(48);
  await env.DB.prepare(
    `INSERT INTO sync_accounts (id, auth_hash, created_at, revoked_at)
     VALUES (?, ?, ?, NULL)`,
  ).bind(id, await sha256(authSecret), new Date().toISOString()).run();
  return json({ accountId: id, authSecret, protocolVersion: 3 }, 201);
}

async function createInvite(request: Request, env: Env): Promise<Response> {
  const adminToken = env.RELAY_ADMIN_TOKEN?.trim() || env.DEVICE_API_TOKEN;
  if (!isDeviceAuthorized(request, adminToken)) {
    return json({ error: "unauthorized" }, 401);
  }

  const declaredLength = Number.parseInt(request.headers.get("content-length") ?? "0", 10);
  if (declaredLength > 4096) return json({ error: "payload_too_large" }, 413);
  let hours = 24;
  if (request.body) {
    const raw = await request.text();
    if (new TextEncoder().encode(raw).byteLength > 4096) {
      return json({ error: "payload_too_large" }, 413);
    }
    if (raw.trim().length > 0) {
      try {
        const value = JSON.parse(raw) as Record<string, unknown>;
        if (value.expiresInHours !== undefined) {
          if (typeof value.expiresInHours !== "number" || !Number.isFinite(value.expiresInHours)) {
            return json({ error: "invalid_payload" }, 400);
          }
          hours = Math.min(Math.max(Math.round(value.expiresInHours), 1), 168);
        }
      } catch {
        return json({ error: "invalid_json" }, 400);
      }
    }
  }

  const id = crypto.randomUUID();
  const code = `CSINV-${randomSecret(24)}`;
  const createdAt = new Date();
  const expiresAt = new Date(createdAt.getTime() + hours * 60 * 60 * 1000);
  await env.DB.prepare(
    `INSERT INTO registration_invites
       (id, code_hash, created_at, expires_at, used_at, revoked_at)
     VALUES (?, ?, ?, ?, NULL, NULL)`,
  ).bind(
    id,
    await sha256(code),
    createdAt.toISOString(),
    expiresAt.toISOString(),
  ).run();
  return json({ id, code, expiresAt: expiresAt.toISOString() }, 201);
}

export default {
  async fetch(
    request: Request,
    env: Env,
    context?: ExecutionContext,
  ): Promise<Response> {
    const url = new URL(request.url);
    if (url.pathname === "/registration") {
      return request.method === "GET"
        ? json({ mode: registrationMode(env), protocolVersion: 3 })
        : methodNotAllowed();
    }
    if (url.pathname === "/accounts") {
      return request.method === "POST"
        ? createAccount(request, env)
        : methodNotAllowed();
    }
    if (url.pathname === "/admin/invites") {
      return request.method === "POST"
        ? createInvite(request, env)
        : methodNotAllowed();
    }
    return legacyHandler.fetch(request, env, context);
  },
  async scheduled(controller: ScheduledController, env: Env): Promise<void> {
    await legacyHandler.scheduled(controller, env);
  },
} satisfies ExportedHandler<Env>;
