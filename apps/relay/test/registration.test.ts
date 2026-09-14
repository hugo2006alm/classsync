import { describe, expect, it } from "vitest";
import worker from "../src/entrypoint";
import type { Env } from "../src/types";

const deviceToken = "0123456789abcdef0123456789abcdef";
const registrationToken = "abcdef0123456789abcdef0123456789";

class RegistrationD1 {
  accounts = 0;

  prepare(query: string): D1PreparedStatement {
    let values: unknown[] = [];
    const statement = {
      bind: (...bound: unknown[]) => {
        values = bound;
        return statement;
      },
      run: async () => {
        if (query.includes("INSERT INTO sync_accounts")) {
          expect(values[0]).toBeTypeOf("string");
          expect(values[1]).toBeTypeOf("string");
          this.accounts += 1;
          return { success: true, meta: { changes: 1 } };
        }
        throw new Error(`Unexpected registration test query: ${query}`);
      },
      first: async <T>() => null as T | null,
      all: async <T>() => ({ success: true, results: [] as T[], meta: {} }),
    };
    return statement as unknown as D1PreparedStatement;
  }
}

function env(
  database: RegistrationD1,
  mode?: "open" | "invite" | "token",
): Env {
  return {
    DB: database as unknown as D1Database,
    FIREFLIES_WEBHOOK_SECRET: "test-fireflies-secret",
    DEVICE_API_TOKEN: deviceToken,
    ACCOUNT_REGISTRATION_MODE: mode,
    ACCOUNT_REGISTRATION_TOKEN: registrationToken,
  };
}

describe("account registration policy", () => {
  it("reports the configured public mode", async () => {
    const database = new RegistrationD1();
    const response = await worker.fetch(
      new Request("https://relay.test/registration"),
      env(database, "open"),
    );

    expect(response.status).toBe(200);
    await expect(response.json()).resolves.toEqual({
      mode: "open",
      protocolVersion: 3,
    });
  });

  it("creates an account without a credential in open mode", async () => {
    const database = new RegistrationD1();
    const response = await worker.fetch(
      new Request("https://relay.test/accounts", { method: "POST" }),
      env(database, "open"),
    );

    expect(response.status).toBe(201);
    expect(database.accounts).toBe(1);
    await expect(response.json()).resolves.toMatchObject({ protocolVersion: 3 });
  });

  it("requires the registration token in token mode", async () => {
    const database = new RegistrationD1();
    const protectedEnv = env(database, "token");

    const denied = await worker.fetch(
      new Request("https://relay.test/accounts", { method: "POST" }),
      protectedEnv,
    );
    expect(denied.status).toBe(401);
    expect(database.accounts).toBe(0);

    const allowed = await worker.fetch(
      new Request("https://relay.test/accounts", {
        method: "POST",
        headers: { authorization: `Bearer ${registrationToken}` },
      }),
      protectedEnv,
    );
    expect(allowed.status).toBe(201);
    expect(database.accounts).toBe(1);
  });

  it("defaults an unconfigured relay to fail-closed token mode", async () => {
    const database = new RegistrationD1();
    const response = await worker.fetch(
      new Request("https://relay.test/registration"),
      env(database),
    );

    await expect(response.json()).resolves.toMatchObject({ mode: "token" });
  });
});
