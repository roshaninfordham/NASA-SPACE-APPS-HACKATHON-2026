import test from "node:test";
import assert from "node:assert/strict";
import {
  createService,
  SOURCE_URL,
  SOURCE_PAGE_URL,
  POLICY_URL,
  CREDIT,
  MAX_BYTES,
  REFRESH_MS,
  RETRY_MS,
  RETAIN_MS,
  publicationTime,
  jpegDimensions,
  sha256,
} from "../src/index.js";

// Structural SOF fixture; no claim that it is a fully decoded photograph.
const JPEG = Uint8Array.from([
  255, 216, 255, 192, 0, 17, 8, 2, 0, 2, 0, 3, 1, 17, 0, 2, 17, 1, 3, 17, 1,
  255, 217,
]);
const START = Date.UTC(2026, 10, 15, 12);
class MemoryCache {
  values = new Map();
  async match(request) {
    return this.values.get(request.url)?.clone();
  }
  async put(request, response) {
    this.values.set(request.url, response.clone());
  }
}
function nasa(body = JPEG, headers = {}) {
  return new Response(body, {
    headers: {
      "Content-Type": "image/jpeg",
      "Last-Modified": new Date(START - 60000).toUTCString(),
      ...headers,
    },
  });
}
function fixture(fetcher = async () => nasa(), cache = new MemoryCache()) {
  let time = START;
  const calls = [];
  const service = createService({
    cache,
    now: () => time,
    fetcher: (...args) => {
      calls.push(args);
      return fetcher(...args);
    },
  });
  return {
    service,
    calls,
    cache,
    tick: (milliseconds) => {
      time += milliseconds;
    },
    request: (path = "/v1/solar/latest.json", options = {}) =>
      service.fetch(new Request(`https://context.example${path}`, options)),
  };
}

test("fixed NASA source is cached once and provenance separates retrieval from publication", async () => {
  const f = fixture();
  const response = await f.request();
  const first = await response.json();
  assert.equal(response.status, 200);
  assert.equal(first.schema_version, 1);
  assert.equal(first.status, "available");
  assert.equal(first.delivery, "upstream");
  assert.equal(first.source_url, SOURCE_URL);
  assert.equal(first.source_page_url, SOURCE_PAGE_URL);
  assert.equal(first.policy_url, POLICY_URL);
  assert.equal(first.credit, CREDIT);
  assert.equal(first.observed_at_utc, null);
  assert.equal(first.fetched_at_utc, new Date(START).toISOString());
  assert.equal(first.file_updated_utc, new Date(START - 60000).toISOString());
  assert.equal(first.sha256, await sha256(JPEG));
  f.tick(30000);
  const second = await (await f.request()).json();
  assert.equal(second.delivery, "edge-cache");
  assert.equal(second.upstream_check, "not-attempted");
  assert.equal(second.cache_age_seconds, 30);
  assert.equal(second.fetched_at_utc, first.fetched_at_utc);
  assert.equal(f.calls.length, 1);
});

test("image and metadata share one cache; bytes and digest remain exact", async () => {
  const f = fixture();
  const meta = await (await f.request()).json();
  const image = await f.request(meta.image_path);
  assert.equal(image.headers.get("Content-Type"), "image/jpeg");
  assert.equal(image.headers.get("ETag"), `"${meta.sha256}"`);
  assert.equal(image.headers.get("X-Komaku-Status"), "available");
  assert.deepEqual(new Uint8Array(await image.arrayBuffer()), JPEG);
  assert.equal(f.calls.length, 1);
});

test("concurrent metadata and image requests coalesce within the isolate", async () => {
  let release;
  const waiting = new Promise((resolve) => {
    release = resolve;
  });
  const f = fixture(async () => {
    await waiting;
    return nasa();
  });
  const results = [f.request(), f.request("/v1/solar/latest.jpg"), f.request()];
  await new Promise((resolve) => setImmediate(resolve));
  assert.equal(f.calls.length, 1);
  release();
  assert.deepEqual(
    (await Promise.all(results)).map((r) => r.status),
    [200, 200, 200],
  );
});

test("refresh happens at15minutes and replaces the successful retrieval time", async () => {
  const f = fixture();
  await f.request();
  f.tick(REFRESH_MS);
  const next = await (await f.request()).json();
  assert.equal(f.calls.length, 2);
  assert.equal(next.delivery, "upstream");
  assert.equal(next.fetched_at_utc, new Date(START + REFRESH_MS).toISOString());
});

test("failure serves labelled stale bytes without rewriting successful provenance; retries back off", async () => {
  let failing = false;
  const f = fixture(async () => {
    if (failing) throw new Error("offline");
    return nasa();
  });
  const initial = await (await f.request()).json();
  failing = true;
  f.tick(REFRESH_MS);
  const stale = await (await f.request()).json();
  assert.equal(stale.status, "stale");
  assert.equal(stale.delivery, "stale-cache");
  assert.equal(stale.upstream_check, "failed");
  assert.equal(stale.sha256, initial.sha256);
  assert.equal(stale.fetched_at_utc, initial.fetched_at_utc);
  assert.equal(
    stale.last_checked_utc,
    new Date(START + REFRESH_MS).toISOString(),
  );
  const image = await f.request("/v1/solar/latest.jpg");
  assert.equal(image.headers.get("Cache-Control"), "no-store");
  assert.equal(f.calls.length, 2);
  f.tick(RETRY_MS);
  await f.request();
  assert.equal(f.calls.length, 3);
});

test("cold failure returns503 and a bounded negative cache, never a fabricated image", async () => {
  const f = fixture(async () => new Response("unavailable", { status: 503 }));
  const response = await f.request();
  const meta = await response.json();
  assert.equal(response.status, 503);
  assert.equal(response.headers.get("Retry-After"), "60");
  for (const field of [
    "image_path",
    "sha256",
    "fetched_at_utc",
    "file_updated_utc",
    "observed_at_utc",
    "width",
    "height",
  ])
    assert.equal(meta[field], null);
  assert.equal(meta.status, "unavailable");
  assert.equal(meta.bytes, 0);
  assert.equal((await f.request("/v1/solar/latest.jpg")).status, 503);
  assert.equal(f.calls.length, 1);
  f.tick(RETRY_MS);
  await f.request();
  assert.equal(f.calls.length, 2);
});

test("cache retention is seven days, failures cannot make old images immortal", async () => {
  let offline = false;
  const f = fixture(async () => {
    if (offline) throw new Error("offline");
    return nasa();
  });
  await f.request();
  offline = true;
  f.tick(RETAIN_MS - 1000);
  assert.equal((await (await f.request()).json()).status, "stale");
  const cached = [...f.cache.values.values()][0];
  assert.equal(cached.headers.get("Cache-Control"), "public, max-age=1");
  f.tick(1001);
  assert.equal((await f.request()).status, 503);
});

test("freshly fetched old publication remains labelled stale", async () => {
  const f = fixture(async () =>
    nasa(JPEG, {
      "Last-Modified": new Date(START - 25 * 60 * 60 * 1000).toUTCString(),
    }),
  );
  const meta = await (await f.request()).json();
  assert.equal(meta.status, "stale");
  assert.equal(meta.delivery, "upstream");
  assert.equal(meta.cache_age_seconds, 0);
  assert.equal(meta.publication_age_seconds, 25 * 60 * 60);
});

test("missing, malformed, impossible or future publication never becomes observation time", async () => {
  for (const value of [
    "",
    "yesterday",
    "Tue, 31 Feb 2026 00:00:00 GMT",
    new Date(START + 3600000).toUTCString(),
  ]) {
    const f = fixture(async () => nasa(JPEG, { "Last-Modified": value }));
    const meta = await (await f.request()).json();
    assert.equal(meta.file_updated_utc, null);
    assert.equal(meta.publication_age_seconds, null);
    assert.equal(meta.observed_at_utc, null);
  }
  assert.equal(publicationTime("Sun, 15 Nov 2026 12:00:00 GMT", START), START);
});

test("only fixed paths are accepted; caller URL/query/method never changes upstream", async () => {
  const f = fixture();
  for (const path of [
    "/",
    "/fetch",
    "/__komaku_cache/nasa-sdo-v1",
    "/v1/solar/../private",
    "/v1/solar/%6catest.jpg",
  ])
    assert.equal((await f.request(path)).status, 404);
  assert.equal(
    (await f.request("/v1/solar/latest.json?url=https://attacker.example"))
      .status,
    400,
  );
  assert.equal(
    (
      await f.request("/v1/solar/latest.json", {
        method: "POST",
        body: "child data",
      })
    ).status,
    405,
  );
  assert.equal(f.calls.length, 0);
  await f.request("/v1/solar/latest.json", {
    headers: {
      Authorization: "secret",
      Cookie: "id=private",
      "X-Forwarded-For": "192.0.2.4",
    },
  });
  const [url, options] = f.calls[0];
  assert.equal(url, SOURCE_URL);
  assert.equal(options.redirect, "manual");
  assert.equal(options.credentials, "omit");
  assert.deepEqual(options.headers, { Accept: "image/jpeg" });
});

test("public read-only CORS has no credentials and OPTIONS does not hit NASA", async () => {
  const f = fixture();
  const response = await f.request("/v1/solar/latest.json", {
    method: "OPTIONS",
  });
  assert.equal(response.status, 204);
  assert.equal(response.headers.get("Access-Control-Allow-Origin"), "*");
  assert.equal(response.headers.get("Access-Control-Allow-Credentials"), null);
  assert.equal(f.calls.length, 0);
});

test("redirects, HTML, bad JPEG, dimensions and oversized declarations are rejected", async () => {
  const wrongSize = JPEG.slice();
  wrongSize[8] = 1;
  for (const response of [
    new Response(null, {
      status: 302,
      headers: { Location: "https://attacker.example" },
    }),
    nasa(JPEG, { "Content-Type": "text/html" }),
    nasa(new TextEncoder().encode("<html>bad</html>")),
    nasa(wrongSize),
    nasa(JPEG.slice(0, -2)),
    nasa(JPEG, { "Content-Length": String(MAX_BYTES + 1) }),
  ]) {
    const f = fixture(async () => response);
    assert.equal((await f.request()).status, 503);
  }
  assert.deepEqual(jpegDimensions(JPEG), { width: 512, height: 512 });
});

test("body limit applies during streaming even without Content-Length", async () => {
  let cancelled = false;
  let index = 0;
  const stream = new ReadableStream({
    pull(controller) {
      if (index++ < 3) controller.enqueue(new Uint8Array(1024 * 1024));
    },
    cancel() {
      cancelled = true;
    },
  });
  const f = fixture(
    async () =>
      new Response(stream, { headers: { "Content-Type": "image/jpeg" } }),
  );
  assert.equal((await f.request()).status, 503);
  assert.equal(cancelled, true);
});

test("invalid cache schema, checksum and future times force clean source validation", async () => {
  for (const tamper of [
    (state) => {
      state.schema = 2;
    },
    (state) => {
      state.sha256 = "0".repeat(64);
    },
    (state) => {
      state.checked_at = START + 86400000;
    },
    (state) => {
      state.last_modified = "not a date";
    },
  ]) {
    const f = fixture();
    await f.request();
    const [key, value] = [...f.cache.values][0];
    const state = JSON.parse(value.headers.get("X-Komaku-Cache-State"));
    tamper(state);
    f.cache.values.set(
      key,
      new Response(JPEG, {
        headers: { "X-Komaku-Cache-State": JSON.stringify(state) },
      }),
    );
    const meta = await (await f.request()).json();
    assert.equal(f.calls.length, 2);
    assert.equal(meta.delivery, "upstream");
  }
});

test("cache API failure does not discard a usable NASA response", async () => {
  const cache = {
    async match() {
      throw new Error("cache unavailable");
    },
    async put() {
      throw new Error("quota");
    },
  };
  const f = fixture(async () => nasa(), cache);
  const meta = await (await f.request()).json();
  assert.equal(meta.status, "available");
  assert.equal(meta.cache_stored, false);
  assert.equal(meta.delivery, "upstream");
});

test("invalid refresh preserves previously validated bytes and digest", async () => {
  let malformed = false;
  const f = fixture(async () =>
    malformed ? nasa(new Uint8Array([1, 2, 3])) : nasa(),
  );
  const initial = await (await f.request()).json();
  malformed = true;
  f.tick(REFRESH_MS);
  const next = await (await f.request()).json();
  assert.equal(next.status, "stale");
  assert.equal(next.sha256, initial.sha256);
  assert.deepEqual(
    new Uint8Array(
      await (await f.request("/v1/solar/latest.jpg")).arrayBuffer(),
    ),
    JPEG,
  );
});

test("upstream timeout aborts the request and returns an honest unavailable state", async (t) => {
  t.mock.timers.enable({ apis: ["setTimeout"] });
  let aborted = false;
  const f = fixture(
    async (_url, options) =>
      new Promise((_resolve, reject) => {
        options.signal.addEventListener(
          "abort",
          () => {
            aborted = true;
            reject(new Error("aborted"));
          },
          { once: true },
        );
      }),
  );
  const request = f.request();
  await new Promise((resolve) => setImmediate(resolve));
  t.mock.timers.tick(8000);
  assert.equal((await request).status, 503);
  assert.equal(aborted, true);
});
