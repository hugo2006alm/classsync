import { readFileSync, readdirSync } from "node:fs";
import { Miniflare, convertV4MiniflareOptions } from "miniflare";
import { afterAll, beforeAll, describe, expect, it, vi } from "vitest";
import { notifyDevices, notifyAccountDevices, retryPendingDeliveries } from "../src/firebase";
import worker from "../src/index";
import type { Env } from "../src/types";

describe("real Worker and D1", () => {
  let runtime: Miniflare;
  let db: Awaited<ReturnType<Miniflare["getD1Database"]>>;
  const bootstrap = "local-test-bootstrap-credential-0000000000";
  const headers = (device: string) => ({
    authorization: `Bearer credential-for-${device}-0000000000000000`,
    "x-classsync-device-id": device,
    "content-type": "application/json",
  });
  const request = (path: string, init?: Parameters<Miniflare["dispatchFetch"]>[1]) =>
    runtime.dispatchFetch(`https://relay.test${path}`, init);

  beforeAll(async () => {
    runtime = new Miniflare(convertV4MiniflareOptions({
      workers: [{
      name: "relay",
      modules: true,
      scriptPath: "dist/index.js",
      compatibilityDate: "2026-09-01",
      d1Databases: ["DB"],
      bindings: { DEVICE_API_TOKEN: bootstrap, FIREFLIES_WEBHOOK_SECRET: "local-test-only" },
      }],
    }));
    db = await runtime.getD1Database("DB");
    for (const name of readdirSync("migrations").filter((name) => name.endsWith(".sql")).sort()) {
      for (const sql of readFileSync(`migrations/${name}`, "utf8").split(";").filter((sql) => sql.trim())) {
        await db.prepare(sql).run();
      }
    }
    for (const device of ["device-one", "device-two"]) {
      expect((await request("/devices/enroll", {
        method: "POST", headers: { authorization: `Bearer ${bootstrap}` },
        body: JSON.stringify({ deviceId: device, credential: `credential-for-${device}-0000000000000000` }),
      })).status).toBe(200);
    }
  }, 30000);
  afterAll(async () => { await runtime?.dispose(); });

  it("rejects malformed route escapes without a runtime exception", async () => {
    expect((await request("/claims/%ZZ", { method: "POST", headers: headers("device-one") })).status).toBe(400);
  });

  it("isolates account snapshots and rejects simultaneous first writers", async () => {
    const create = async () => {
      const response = await request("/accounts", { method: "POST", headers: { authorization: `Bearer ${bootstrap}` } });
      expect(response.status).toBe(201);
      const account = await response.json() as { accountId: string; authSecret: string };
      return { authorization: `Bearer ${account.authSecret}`, "x-classsync-account-id": account.accountId,
        "x-classsync-device-id": "account-device-one", "content-type": "application/json" };
    };
    const first = await create();
    const second = await create();
    const writes = await Promise.all(["one", "two"].map((ciphertext) => request("/account/sync/config", {
      method: "PUT", headers: first, body: JSON.stringify({ baseRevision: 0, ciphertext, nonce: "test", schemaVersion: 2 }),
    })));
    expect(writes.map((response) => response.status).sort()).toEqual([200, 409]);
    const isolated = await request("/account/sync/config", { headers: second });
    expect(await isolated.json()).toEqual({ revision: 0 });
    expect((await request("/account/sync/config", { headers: { ...second, "x-classsync-account-id": first["x-classsync-account-id"] } })).status).toBe(401);
    const body = JSON.stringify({ pushToken: "account-owned-push-token-00000000000000", platform: "android" });
    expect((await request("/account/devices/register", { method: "POST", headers: first, body })).status).toBe(200);
    expect((await request("/account/devices/register", { method: "POST", headers: second, body })).status).toBe(409);
    await request("/account/devices/register", { method: "DELETE", headers: second, body });
    expect(await db.prepare("SELECT account_id FROM relay_devices WHERE push_token = ?").bind("account-owned-push-token-00000000000000").first("account_id")).toBe(first["x-classsync-account-id"]);
  });

  it("does not let a different legacy device delete a push registration", async () => {
    const body = JSON.stringify({ pushToken: "push-token-owned-by-device-one-0000000000", platform: "android" });
    expect((await request("/devices/register", { method: "POST", headers: headers("device-one"), body })).status).toBe(200);
    await request("/devices/register", { method: "DELETE", headers: headers("device-two"), body });
    expect(await db.prepare("SELECT id FROM relay_devices WHERE device_id = 'device-one'").first()).not.toBeNull();
  });

  it("does not let a different legacy device take over a push registration", async () => {
    const body = JSON.stringify({ pushToken: "another-push-token-owned-by-one-00000000", platform: "android" });
    await request("/devices/register", { method: "POST", headers: headers("device-one"), body });
    expect((await request("/devices/register", { method: "POST", headers: headers("device-two"), body })).status).toBe(409);
  });

  it("only one device acquires a transcript; another cannot complete it", async () => {
    const results = await Promise.all(["device-one", "device-two"].map(async (device) => {
      const response = await request("/claims/lecture-concurrent", { method: "POST", headers: headers(device) });
      return { device, claim: await response.json() as { acquired: boolean } };
    }));
    expect(results.filter((result) => result.claim.acquired)).toHaveLength(1);
    const loser = results.find((result) => !result.claim.acquired)!.device;
    expect((await request("/claims/lecture-concurrent/complete", {
      method: "POST", headers: headers(loser), body: JSON.stringify({ notionPageId: "page-one" }),
    })).status).toBe(409);
  });

  it("rejects empty completion page IDs", async () => {
    await request("/claims/lecture-empty", { method: "POST", headers: headers("device-one") });
    expect((await request("/claims/lecture-empty/complete", {
      method: "POST", headers: headers("device-one"), body: JSON.stringify({ notionPageId: "" }),
    })).status).toBe(400);
  });

  it("reopens a completed claim only for its existing page and keeps one owner", async () => {
    await request("/claims/reprocess", { method: "POST", headers: headers("device-one") });
    await request("/claims/reprocess/complete", { method: "POST", headers: headers("device-one"), body: JSON.stringify({ notionPageId: "existing-page" }) });
    const wrong = await request("/claims/reprocess", { method: "POST", headers: { ...headers("device-two"), "x-classsync-reprocess-page-id": "wrong-page" } });
    expect((await wrong.json() as { acquired: boolean }).acquired).toBe(false);
    const reopened = await request("/claims/reprocess", { method: "POST", headers: { ...headers("device-two"), "x-classsync-reprocess-page-id": "existing-page" } });
    expect((await reopened.json() as { acquired: boolean }).acquired).toBe(true);
    const busy = await request("/claims/reprocess", { method: "POST", headers: { ...headers("device-one"), "x-classsync-reprocess-page-id": "existing-page" } });
    expect((await busy.json() as { acquired: boolean }).acquired).toBe(false);
  });

  it("bounds streamed webhook bodies before buffering", async () => {
    expect((await request("/webhooks/fireflies", { method: "POST", body: "x".repeat(65537) })).status).toBe(413);
  });

  it("cleanup retains a revoked identity while its claim still references it", async () => {
    await db.prepare("INSERT INTO relay_device_auth (id, credential_hash, created_at, updated_at, revoked_at) VALUES ('old-device', 'hash', '2020-01-01', '2020-01-01', '2020-01-01')").run();
    await db.prepare("INSERT INTO processing_claims (fireflies_transcript_id, device_id, lease_expires_at, status, updated_at) VALUES ('old-claim', 'old-device', '2020-01-01', 'processing', '2020-01-01')").run();
    await worker.scheduled({} as ScheduledController, { DB: db } as unknown as Env);
    expect(await db.prepare("SELECT id FROM relay_device_auth WHERE id = 'old-device'").first()).not.toBeNull();
  });

  it("isolates legacy pushes and persists account push failures for retry", async () => {
    const pair = await crypto.subtle.generateKey({ name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" }, true, ["sign", "verify"]);
    const key = Buffer.from(await crypto.subtle.exportKey("pkcs8", pair.privateKey)).toString("base64");
    const env = { DB: db, FIREBASE_SERVICE_ACCOUNT_JSON: JSON.stringify({ project_id: "local-test", client_email: "local@test.invalid", private_key: `-----BEGIN PRIVATE KEY-----\n${key}\n-----END PRIVATE KEY-----` }) } as unknown as Env;
    const now = new Date().toISOString();
    await db.prepare("INSERT INTO sync_accounts (id, auth_hash, created_at) VALUES ('account-push-test', 'test', ?)").bind(now).run();
    await db.prepare("INSERT INTO relay_devices (id, push_token, platform, created_at, updated_at, device_id, account_id) VALUES ('account-push-device', 'private-account-push-token', 'android', ?, ?, 'device-account', 'account-push-test')").bind(now, now).run();
    await db.prepare("INSERT INTO relay_events (id, fireflies_transcript_id, event_type, received_at) VALUES ('push-event', 'push-meeting', 'meeting.transcribed', ?)").bind(now).run();
    await db.prepare("INSERT INTO account_relay_events (id, account_id, fireflies_transcript_id, event_type, received_at) VALUES ('account-push-event', 'account-push-test', 'account-meeting', 'meeting.transcribed', ?)").bind(now).run();
    const tokens: string[] = [];
    vi.stubGlobal("fetch", async (url: string, init?: RequestInit) => {
      if (url.includes("oauth2")) return Response.json({ access_token: "local-access-token", expires_in: 3600 });
      tokens.push(JSON.parse(String(init?.body)).message.token);
      return Response.json({ error: { status: "UNAVAILABLE" } }, { status: 503 });
    });
    try {
      await notifyDevices(env, { id: "push-event", transcriptId: "push-meeting", eventType: "meeting.transcribed" });
      expect(tokens).not.toContain("private-account-push-token");
      await notifyAccountDevices(env, "account-push-test", { id: "account-push-event", transcriptId: "account-meeting", eventType: "meeting.transcribed" });
      expect(await db.prepare("SELECT status FROM account_push_deliveries WHERE event_id = 'account-push-event'").first("status")).toBe("retry");
      // Simulate process death after persisting sending, then retry through the scheduler boundary.
      await db.prepare("UPDATE account_push_deliveries SET status = 'sending', updated_at = '2020-01-01' WHERE event_id = 'account-push-event'").run();
      vi.stubGlobal("fetch", async () => Response.json({ name: "delivered" }));
      await retryPendingDeliveries(env);
      expect(await db.prepare("SELECT status FROM account_push_deliveries WHERE event_id = 'account-push-event'").first("status")).toBe("delivered");
    } finally { vi.unstubAllGlobals(); }
  });
});
