import { describe, expect, it } from "vitest";
import worker from "../src/index";
import type { Env, ProcessingClaimRow, RelayEventRow } from "../src/types";

const secret = "test-webhook-secret";
const deviceToken = "0123456789abcdef0123456789abcdef";

class MemoryD1 {
  readonly rows = new Map<string, RelayEventRow>();
  readonly devices = new Map<string, string>();
  readonly auth = new Map<string, { hash: string; revoked: string | null }>();
  readonly acks = new Set<string>();
  readonly claims = new Map<string, ProcessingClaimRow>();

  prepare(query: string): D1PreparedStatement {
    let values: unknown[] = [];
    const statement = {
      bind: (...bound: unknown[]) => {
        values = bound;
        return statement;
      },
      run: async () => {
        if (query.includes("INSERT INTO relay_events")) {
          const [id, transcriptId, eventType, receivedAt] = values as string[];
          const duplicate = [...this.rows.values()].some(
            (row) =>
              row.fireflies_transcript_id === transcriptId &&
              row.event_type === eventType,
          );
          if (!duplicate) {
            this.rows.set(id!, {
              id: id!,
              fireflies_transcript_id: transcriptId!,
              event_type: eventType!,
              received_at: receivedAt!,
              acknowledged_at: null,
            });
          }
          return { success: true, meta: { changes: duplicate ? 0 : 1 } };
        }
        if (query.includes("UPDATE relay_events")) {
          const [acknowledgedAt, id] = values as string[];
          const row = this.rows.get(id!);
          if (row) {
            this.rows.set(id!, { ...row, acknowledged_at: acknowledgedAt! });
          }
          return { success: true, meta: { changes: row ? 1 : 0 } };
        }
        if (query.includes("INSERT INTO relay_device_auth")) {
          const [id, hash] = values as string[];
          this.auth.set(id!, { hash: hash!, revoked: null });
          return { success: true, meta: { changes: 1 } };
        }
        if (query.includes("INSERT INTO relay_event_acks")) {
          const [eventId, deviceId] = values as string[];
          this.acks.add(`${eventId}:${deviceId}`);
          return { success: true, meta: { changes: 1 } };
        }
        if (query.includes("INSERT INTO processing_claims")) {
          const [transcriptId, deviceId, expires, updated] = values as string[];
          if (!this.claims.has(transcriptId!)) {
            this.claims.set(transcriptId!, {
              fireflies_transcript_id: transcriptId!,
              device_id: deviceId!,
              lease_expires_at: expires!,
              status: "processing",
              notion_page_id: null,
              updated_at: updated!,
            });
          }
          return { success: true, meta: { changes: 1 } };
        }
        if (query.includes("UPDATE processing_claims") && query.includes("status !=")) {
          const [deviceId, expires, updated, transcriptId, sameDevice, now] =
            values as string[];
          const current = this.claims.get(transcriptId!);
          if (
            current &&
            current.status !== "completed" &&
            (current.device_id === sameDevice || current.lease_expires_at <= now!)
          ) {
            this.claims.set(transcriptId!, {
              ...current,
              device_id: deviceId!,
              lease_expires_at: expires!,
              updated_at: updated!,
              status: "processing",
            });
            return { success: true, meta: { changes: 1 } };
          }
          return { success: true, meta: { changes: 0 } };
        }
        if (query.includes("UPDATE processing_claims") && query.includes("notion_page_id")) {
          const [pageId, updated, transcriptId, deviceId] = values as string[];
          const current = this.claims.get(transcriptId!);
          if (!current || current.device_id !== deviceId) {
            return { success: true, meta: { changes: 0 } };
          }
          this.claims.set(transcriptId!, {
            ...current,
            status: "completed",
            notion_page_id: pageId!,
            updated_at: updated!,
          });
          return { success: true, meta: { changes: 1 } };
        }
        if (query.includes("INSERT INTO relay_devices")) {
          const [id, pushToken] = values as string[];
          this.devices.set(id!, pushToken!);
          return { success: true, meta: { changes: 1 } };
        }
        if (query.includes("DELETE FROM relay_devices")) {
          const target = values[0] as string;
          const entry = [...this.devices.entries()].find(
            ([id, token]) => id === target || token === target,
          );
          if (entry) this.devices.delete(entry[0]);
          return { success: true, meta: { changes: entry ? 1 : 0 } };
        }
        throw new Error(`Unexpected test query: ${query}`);
      },
      all: async <T>() => {
        const deviceId = values[0] as string;
        const limit = values[1] as number;
        const results = [...this.rows.values()]
          .filter((row) => !this.acks.has(`${row.id}:${deviceId}`))
          .sort((a, b) => a.received_at.localeCompare(b.received_at))
          .slice(0, limit) as T[];
        return { success: true, results, meta: {} };
      },
      first: async <T>() => {
        if (query.includes("FROM relay_device_auth")) {
          const row = this.auth.get(values[0] as string);
          return (row
            ? {
                id: values[0],
                credential_hash: row.hash,
                revoked_at: row.revoked,
              }
            : null) as T | null;
        }
        if (query.includes("SELECT id FROM relay_events")) {
          const row = this.rows.get(values[0] as string);
          return (row ? { id: row.id } : null) as T | null;
        }
        if (query.includes("FROM processing_claims")) {
          return (this.claims.get(values[0] as string) ?? null) as T | null;
        }
        throw new Error(`Unexpected test query: ${query}`);
      },
    };
    return statement as unknown as D1PreparedStatement;
  }
}

function testEnv(database = new MemoryD1()): Env {
  return {
    DB: database as unknown as D1Database,
    FIREFLIES_WEBHOOK_SECRET: secret,
    DEVICE_API_TOKEN: deviceToken,
  };
}

async function fetch(request: Request, env: Env): Promise<Response> {
  return worker.fetch(request, env);
}

async function signature(body: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const result = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(body));
  const hex = Array.from(new Uint8Array(result))
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
  return `sha256=${hex}`;
}

async function enroll(env: Env, deviceId: string): Promise<Record<string, string>> {
  const credential = `credential-${deviceId}-0123456789abcdef0123456789abcdef`;
  const response = await fetch(
    new Request("https://relay.test/devices/enroll", {
      method: "POST",
      headers: {
        authorization: `Bearer ${deviceToken}`,
        "content-type": "application/json",
      },
      body: JSON.stringify({ deviceId, credential }),
    }),
    env,
  );
  expect(response.status).toBe(200);
  return {
    authorization: `Bearer ${credential}`,
    "x-classsync-device-id": deviceId,
  };
}

describe("ClassSync Relay", () => {
  it("reports health without exposing data", async () => {
    const response = await fetch(new Request("https://relay.test/health"), testEnv());
    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toMatchObject({ status: "ok" });
  });

  it("rejects invalid signatures", async () => {
    const response = await fetch(
      new Request("https://relay.test/webhooks/fireflies", {
        method: "POST",
        headers: { "x-hub-signature": "sha256=bad" },
        body: "{}",
      }),
      testEnv(),
    );
    expect(response.status).toBe(401);
  });

  it("deduplicates delivery and supports authenticated acknowledgement", async () => {
    const database = new MemoryD1();
    const env = testEnv(database);
    const deviceHeaders = await enroll(env, "device-one");
    const body = JSON.stringify({
      event: "meeting.transcribed",
      timestamp: Date.now(),
      meeting_id: "meeting-42",
    });
    const headers = {
      "content-type": "application/json",
      "x-hub-signature": await signature(body),
    };
    for (let attempt = 0; attempt < 2; attempt += 1) {
      const response = await fetch(
        new Request("https://relay.test/webhooks/fireflies", {
          method: "POST",
          headers,
          body,
        }),
        env,
      );
      expect(response.status).toBe(202);
    }
    expect(database.rows).toHaveLength(1);

    expect(await fetch(new Request("https://relay.test/events"), env)).toMatchObject({
      status: 401,
    });
    const pending = await fetch(
      new Request("https://relay.test/events", {
        headers: deviceHeaders,
      }),
      env,
    );
    const payload = (await pending.json()) as { events: Array<{ id: string }> };
    const id = payload.events[0]!.id;
    const acknowledged = await fetch(
      new Request(`https://relay.test/events/${encodeURIComponent(id)}/ack`, {
        method: "POST",
        headers: deviceHeaders,
      }),
      env,
    );
    expect(acknowledged.status).toBe(200);
  });

  it("rejects a malformed signed payload", async () => {
    const body = JSON.stringify({ event: "meeting.transcribed" });
    const response = await fetch(
      new Request("https://relay.test/webhooks/fireflies", {
        method: "POST",
        headers: { "x-hub-signature": await signature(body) },
        body,
      }),
      testEnv(),
    );
    expect(response.status).toBe(400);
  });

  it("registers and unregisters an authenticated Android push token", async () => {
    const database = new MemoryD1();
    const env = testEnv(database);
    const deviceHeaders = await enroll(env, "device-one");
    const pushToken = "fcm-token-that-is-long-enough-for-validation-12345";
    const request = (method: "POST" | "DELETE", authorized = true) =>
      new Request("https://relay.test/devices/register", {
        method,
        headers: {
          "content-type": "application/json",
          ...(authorized ? deviceHeaders : {}),
        },
        body: JSON.stringify({ pushToken, platform: "android" }),
      });

    expect(await fetch(request("POST", false), env)).toMatchObject({
      status: 401,
    });
    expect(await fetch(request("POST"), env)).toMatchObject({ status: 200 });
    expect(database.devices).toHaveLength(1);
    expect(await fetch(request("DELETE"), env)).toMatchObject({ status: 200 });
    expect(database.devices).toHaveLength(0);
  });

  it("allows only one device claim and records completion", async () => {
    const database = new MemoryD1();
    const env = testEnv(database);
    const firstHeaders = await enroll(env, "device-one");
    const secondHeaders = await enroll(env, "device-two");
    const claim = (headers: Record<string, string>) =>
      fetch(
        new Request("https://relay.test/claims/meeting-99", {
          method: "POST",
          headers,
        }),
        env,
      );
    await expect((await claim(firstHeaders)).json()).resolves.toMatchObject({
      acquired: true,
    });
    await expect((await claim(secondHeaders)).json()).resolves.toMatchObject({
      acquired: false,
    });
    const completed = await fetch(
      new Request("https://relay.test/claims/meeting-99/complete", {
        method: "POST",
        headers: { ...firstHeaders, "content-type": "application/json" },
        body: JSON.stringify({ notionPageId: "notion-page" }),
      }),
      env,
    );
    expect(completed.status).toBe(200);
    await expect((await claim(secondHeaders)).json()).resolves.toMatchObject({
      completed: true,
      notionPageId: "notion-page",
    });
  });
});
