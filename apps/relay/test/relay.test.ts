import { describe, expect, it } from "vitest";
import worker from "../src/index";
import type { Env, RelayEventRow } from "../src/types";

const secret = "test-webhook-secret";
const deviceToken = "0123456789abcdef0123456789abcdef";

class MemoryD1 {
  readonly rows = new Map<string, RelayEventRow>();
  readonly devices = new Map<string, string>();

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
        const limit = values[0] as number;
        const results = [...this.rows.values()]
          .filter((row) => row.acknowledged_at === null)
          .sort((a, b) => a.received_at.localeCompare(b.received_at))
          .slice(0, limit) as T[];
        return { success: true, results, meta: {} };
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
        headers: { authorization: `Bearer ${deviceToken}` },
      }),
      env,
    );
    const payload = (await pending.json()) as { events: Array<{ id: string }> };
    const id = payload.events[0]!.id;
    const acknowledged = await fetch(
      new Request(`https://relay.test/events/${encodeURIComponent(id)}/ack`, {
        method: "POST",
        headers: { authorization: `Bearer ${deviceToken}` },
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
    const pushToken = "fcm-token-that-is-long-enough-for-validation-12345";
    const request = (method: "POST" | "DELETE", authorized = true) =>
      new Request("https://relay.test/devices/register", {
        method,
        headers: {
          "content-type": "application/json",
          ...(authorized
            ? { authorization: `Bearer ${deviceToken}` }
            : {}),
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
});
