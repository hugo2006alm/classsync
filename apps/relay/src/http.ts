export function json(value: unknown, status = 200): Response {
  return Response.json(value, {
    status,
    headers: {
      "cache-control": "no-store",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
    },
  });
}

export function methodNotAllowed(): Response {
  return json({ error: "method_not_allowed" }, 405);
}

export function notFound(): Response {
  return json({ error: "not_found" }, 404);
}
