/* Full-build offline cache. The release inventory is embedded by the packager. */
const RELEASE = /* RED_VEIL_RELEASE */ null;
const ROOT = new URL(self.registration.scope);
const PREFIX = `red-veil-web:${ROOT.pathname}:`;
const CACHE = PREFIX + RELEASE.build_id;
const COMPLETE = new URL(".red-veil-complete", ROOT).href;
const ACTIVATION = new URL(".red-veil-activation", ROOT).href;
const BUILD_PREFIX = new URL("red-veil-builds/", ROOT).pathname;
const BUILD_ID = /^[a-f0-9]{24}$/;
const assetURLs = new Set(
  RELEASE.assets.map((asset) => new URL(asset.path, ROOT).href),
);

function scoped(client) {
  const url = new URL(client.url);
  return url.origin === ROOT.origin && url.pathname.startsWith(ROOT.pathname);
}

async function windows() {
  return (
    await self.clients.matchAll({ type: "window", includeUncontrolled: true })
  ).filter(scoped);
}

async function announce(message) {
  for (const client of await windows()) client.postMessage(message);
}

async function complete(cache = null) {
  const selected = cache || (await caches.open(CACHE));
  if (!(await selected.match(COMPLETE))) return false;
  for (const asset of RELEASE.assets) {
    if (!(await selected.match(new URL(asset.path, ROOT).href))) return false;
  }
  return true;
}

async function checkedResponse(asset) {
  const url = new URL(asset.path, ROOT);
  if (url.origin !== ROOT.origin || !url.pathname.startsWith(ROOT.pathname))
    throw new Error("Invalid asset location");
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), 300000);
  try {
    const response = await fetch(url.href, {
      cache: "no-store",
      credentials: "omit",
      redirect: "error",
      signal: controller.signal,
    });
    if (!response.ok || response.status !== 200 || !response.body)
      throw new Error("Asset unavailable");
    const bytes = new Uint8Array(asset.bytes);
    const reader = response.body.getReader();
    let length = 0;
    while (true) {
      const part = await reader.read();
      if (part.done) break;
      length += part.value.byteLength;
      if (length > asset.bytes) {
        await reader.cancel();
        throw new Error("Asset too large");
      }
      bytes.set(part.value, length - part.value.byteLength);
    }
    if (length !== asset.bytes) throw new Error("Asset incomplete");
    const hash = Array.from(
      new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
      (value) => value.toString(16).padStart(2, "0"),
    ).join("");
    if (hash !== asset.sha256) throw new Error("Asset hash mismatch");
    const headers = new Headers(response.headers);
    headers.delete("content-encoding");
    headers.set("content-length", String(asset.bytes));
    return new Response(bytes, { status: 200, headers });
  } finally {
    clearTimeout(timer);
  }
}

function cacheLease(name, operation) {
  // A pruning worker must not delete a cache that an installing worker has open.
  // Where Web Locks are unavailable, pruning is disabled instead.
  if (!self.navigator.locks) return operation();
  return self.navigator.locks.request(
    `red-veil-cache:${name}`,
    { mode: "exclusive" },
    operation,
  );
}

async function markPrepared(cache) {
  await cache.put(
    COMPLETE,
    new Response(
      JSON.stringify({
        build_id: RELEASE.build_id,
        version: RELEASE.version,
        prepared_at: Date.now(),
        activated_at: 0,
      }),
      { headers: { "content-type": "application/json" } },
    ),
  );
}

self.addEventListener("install", (event) => {
  event.waitUntil(
    cacheLease(CACHE, async () => {
      const cache = await caches.open(CACHE);
      if (await complete(cache)) {
        // A previously activated build can be offered again after a site rollback.
        // It is now a candidate, so pruning must not treat it as obsolete.
        await markPrepared(cache);
        return;
      }
      await caches.delete(CACHE);
      const pending = await caches.open(CACHE);
      let saved = 0;
      try {
        for (const asset of RELEASE.assets) {
          await pending.put(
            new URL(asset.path, ROOT).href,
            await checkedResponse(asset),
          );
          saved += asset.bytes;
          await announce({
            type: "RV_PREPARING",
            build_id: RELEASE.build_id,
            version: RELEASE.version,
            saved,
            total: RELEASE.total_bytes,
          });
        }
        await markPrepared(pending);
        // Reopen by name: a legacy worker may have deleted the Cache Storage entry
        // while this worker still held its detached Cache object.
        if (!(await complete())) throw new Error("Prepared cache was removed");
        await announce({
          type: "RV_PREPARED",
          build_id: RELEASE.build_id,
          version: RELEASE.version,
        });
        // Never skipWaiting here: an existing mission keeps its current worker.
      } catch (error) {
        await caches.delete(CACHE);
        await announce({
          type: "RV_PREPARE_FAILED",
          build_id: RELEASE.build_id,
        });
        throw error;
      }
    }),
  );
});

async function activatedMetadata(name) {
  try {
    const marker = await (await caches.open(name)).match(COMPLETE);
    if (!marker) return null;
    const metadata = await marker.json();
    if (
      !metadata ||
      !BUILD_ID.test(metadata.build_id) ||
      name !== PREFIX + metadata.build_id ||
      !Number.isFinite(metadata.activated_at) ||
      metadata.activated_at <= 0
    )
      return null;
    return metadata;
  } catch {
    // Partial, unactivated, malformed or unknown caches are never prune targets.
    return null;
  }
}

async function pruneUnusedCaches() {
  // Keep both current and previous activated build. With multiple windows or an
  // uncertain client set, retain extra caches rather than break a live mission.
  if (!self.navigator.locks || (await windows()).length > 1) return;
  const current = await caches.open(CACHE);
  const activation = await current.match(ACTIVATION);
  let previous = "";
  try {
    previous = activation ? (await activation.json()).previous : "";
  } catch {
    /* Preserve an alternative activated build below. */
  }
  let latestActivation = 0;
  const names = (await caches.keys()).filter(
    (name) => name.startsWith(PREFIX) && name !== CACHE,
  );
  if (!BUILD_ID.test(previous) || !names.includes(PREFIX + previous)) {
    previous = "";
    for (const name of names) {
      const metadata = await activatedMetadata(name);
      if (!metadata) continue;
      if (
        metadata.activated_at > latestActivation &&
        BUILD_ID.test(metadata.build_id)
      ) {
        latestActivation = metadata.activated_at;
        previous = metadata.build_id;
      }
    }
  }
  for (const name of names) {
    if (name === PREFIX + previous) continue;
    await self.navigator.locks.request(
      `red-veil-cache:${name}`,
      { mode: "exclusive", ifAvailable: true },
      async (lock) => {
        if (!lock) return;
        // Recheck under the lease; an installing worker may be reusing this build.
        if (await activatedMetadata(name)) await caches.delete(name);
      },
    );
  }
}

self.addEventListener("activate", (event) => {
  event.waitUntil(
    (async () => {
      if (!(await complete()))
        throw new Error("Complete game cache unavailable");
      const cache = await caches.open(CACHE);
      const marker = await (await cache.match(COMPLETE)).json();
      marker.activated_at = Date.now();
      await cache.put(
        COMPLETE,
        new Response(JSON.stringify(marker), {
          headers: { "content-type": "application/json" },
        }),
      );
      await pruneUnusedCaches();
      await self.clients.claim();
      await announce({
        type: "RV_ACTIVE",
        build_id: RELEASE.build_id,
        version: RELEASE.version,
      });
      // No client.navigate(), and no message requesting other windows to reload.
    })(),
  );
});

self.addEventListener("fetch", (event) => {
  if (event.request.method !== "GET") return;
  const url = new URL(event.request.url);
  if (url.origin !== ROOT.origin || !url.pathname.startsWith(ROOT.pathname))
    return;
  url.search = "";
  url.hash = "";
  const rootNavigation =
    event.request.mode === "navigate" &&
    (url.pathname === ROOT.pathname ||
      url.pathname === new URL("index.html", ROOT).pathname);
  if (rootNavigation || assetURLs.has(url.href)) {
    event.respondWith(
      (async () => {
        const response = await (
          await caches.open(CACHE)
        ).match(rootNavigation ? new URL("index.html", ROOT).href : url.href);
        return (
          response ||
          new Response(
            "This saved game is incomplete. Reconnect and reload Red Veil.",
            { status: 503, headers: { "content-type": "text/plain" } },
          )
        );
      })(),
    );
    return;
  }
  // A window opened just before activation may still be playing the prior build.
  // Immutable asset paths keep its engine, scripts and PCK together.
  if (url.pathname.startsWith(BUILD_PREFIX)) {
    const build = url.pathname.slice(BUILD_PREFIX.length).split("/")[0];
    if (!BUILD_ID.test(build)) return;
    event.respondWith(
      (async () => {
        const response = await (
          await caches.open(PREFIX + build)
        ).match(url.href);
        return (
          response ||
          new Response(
            "That game version is not saved on this device. Reconnect and reload.",
            { status: 503, headers: { "content-type": "text/plain" } },
          )
        );
      })(),
    );
  }
});

self.addEventListener("message", (event) => {
  event.waitUntil(
    (async () => {
      const source = event.source && (await self.clients.get(event.source.id));
      const port = event.ports[0];
      if (
        !source ||
        !scoped(source) ||
        !port ||
        !event.data ||
        typeof event.data.type !== "string"
      )
        return;
      if (event.data.type === "RV_STATUS") {
        port.postMessage({
          ok: true,
          build_id: RELEASE.build_id,
          version: RELEASE.version,
          complete: await complete(),
        });
        return;
      }
      if (event.data.type !== "RV_APPLY") return;
      const open = await windows();
      if (open.length !== 1 || open[0].id !== source.id) {
        port.postMessage({ ok: false, error: "other_windows" });
        return;
      }
      if (!(await complete())) {
        port.postMessage({ ok: false, error: "incomplete" });
        return;
      }
      const previous = BUILD_ID.test(event.data.previous)
        ? event.data.previous
        : "";
      await (
        await caches.open(CACHE)
      ).put(
        ACTIVATION,
        new Response(JSON.stringify({ previous }), {
          headers: { "content-type": "application/json" },
        }),
      );
      port.postMessage({ ok: true });
      await self.skipWaiting();
    })(),
  );
});
