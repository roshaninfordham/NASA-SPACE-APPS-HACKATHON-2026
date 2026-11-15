import test from "node:test";
import assert from "node:assert/strict";
import { createCoach } from "../src/coach.js";
const request = (topic = "dust", options = {}) =>
  new Request("https://lab.example/api/coach?topic=" + topic, {
    method: "POST",
    headers: { Origin: "https://lab.example" },
    ...options,
  });
const env = {
  GEMINI_API_KEY: "test-only",
  COACH_LIMITER: { limit: async () => ({ success: true }) },
};
const response = () =>
  new Response(
    JSON.stringify({
      candidates: [
        {
          finishReason: "STOP",
          content: {
            parts: [
              {
                text: JSON.stringify({
                  explanation: "Dust blocks sunlight.",
                  question: "What changes when the panel is cleaned?",
                }),
              },
            ],
          },
        },
      ],
    }),
  );
class Cache {
  map = new Map();
  async match(r) {
    return this.map.get(r.url)?.clone();
  }
  async put(r, v) {
    this.map.set(r.url, v.clone());
  }
}
test("rejects arbitrary topics, bodies and origins without calling Gemini", async () => {
  let calls = 0;
  const c = createCoach({
    fetcher: async () => {
      calls++;
      return response();
    },
  });
  for (const r of [
    request("prompt"),
    request("dust", { body: "child data" }),
    request("dust", { headers: { Origin: "https://other.example" } }),
    request("dust", { method: "GET" }),
  ])
    assert.ok((await c(r, env)).status >= 400);
  assert.equal(calls, 0);
});
test("missing key and limiter fail closed", async () => {
  const c = createCoach();
  assert.equal((await (await c(request(), {})).json()).provider, "built-in");
  assert.equal(
    (await (await c(request(), { GEMINI_API_KEY: "test" })).json()).reason,
    "protection_not_configured",
  );
});
test("quota rejection is explicit and never stored as generated output", async () => {
  let calls = 0;
  const c = createCoach({
    cache: new Cache(),
    fetcher: async () => {
      calls++;
      return new Response("{}", { status: 403 });
    },
  });
  for (let i = 0; i < 2; i++) {
    const r = await c(request(), env);
    assert.equal(r.status, 200);
    const body = await r.json();
    assert.equal(body.reason, "upstream_403");
    assert.equal(body.provider, "built-in");
  }
  assert.equal(calls, 2);
});
test("reuses generated explanation and expires cache after one day", async () => {
  let calls = 0,
    time = Date.now();
  const c = createCoach({
    cache: new Cache(),
    now: () => time,
    fetcher: async (url, options) => {
      calls++;
      const payload = JSON.parse(options.body);
      assert.match(payload.contents[0].parts[0].text, /Pathfinder/);
      assert.equal(options.headers["x-goog-api-key"], "test-only");
      return response();
    },
  });
  assert.equal((await (await c(request(), env)).json()).delivery, "generated");
  assert.equal((await (await c(request(), env)).json()).delivery, "cached");
  assert.equal(calls, 1);
  time += 86400001;
  await c(request(), env);
  assert.equal(calls, 2);
});
test("rate limit blocks generation", async () => {
  let calls = 0;
  const c = createCoach({
    fetcher: async () => {
      calls++;
      return response();
    },
  });
  assert.equal(
    (
      await await c(request(), {
        ...env,
        COACH_LIMITER: { limit: async () => ({ success: false }) },
      })
    ).status,
    200,
  );
  assert.equal(calls, 0);
});
test("malformed AI output cannot become a successful explanation", async () => {
  const c = createCoach({
    fetcher: async () =>
      new Response(
        JSON.stringify({
          candidates: [
            {
              finishReason: "STOP",
              content: { parts: [{ text: "not JSON" }] },
            },
          ],
        }),
      ),
  });
  assert.equal(
    (await (await c(request(), env)).json()).reason,
    "invalid_response",
  );
});
test("concurrent requests share a generation and share failure status", async () => {
  let calls = 0;
  const c = createCoach({
    fetcher: async () => {
      calls++;
      await new Promise((r) => setTimeout(r, 10));
      return new Response("{}", { status: 429 });
    },
  });
  const results = await Promise.all([c(request(), env), c(request(), env)]);
  assert.equal(calls, 1);
  assert.deepEqual(
    results.map((r) => r.status),
    [200, 200],
  );
  for (const r of results)
    assert.equal((await r.json()).reason, "upstream_429");
});
test("network errors return a useful fallback", async () => {
  const c = createCoach({
    fetcher: async () => {
      throw Error("network");
    },
  });
  const r = await c(request(), env);
  assert.equal(r.status, 200);
  assert.equal((await r.json()).reason, "upstream_unavailable");
});

test("empty browser POST stream is accepted, with an honestly labelled fallback", async () => {
  const c = createCoach();
  const r = await c(request("dust", { body: "" }), {});
  assert.equal(r.status, 200);
  const b = await r.json();
  assert.equal(b.provider, "built-in");
  assert.match(b.label, /Not generated by Gemini/);
  assert.ok(b.explanation.length > 20);
});
