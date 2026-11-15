/** Public educational context only. No simulation, learner state or user URLs. */
export const SOURCE_URL =
  "https://sdo.gsfc.nasa.gov/assets/img/latest/latest_512_0193.jpg";
export const SOURCE_PAGE_URL = "https://sdo.gsfc.nasa.gov/data/";
export const POLICY_URL = "https://sdo.gsfc.nasa.gov/data/rules.php";
export const CREDIT =
  "Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.";
export const MAX_BYTES = 2 * 1024 * 1024;
export const REFRESH_MS = 15 * 60 * 1000;
export const RETAIN_MS = 7 * 24 * 60 * 60 * 1000;
export const RETRY_MS = 60 * 1000;
export const PUBLICATION_STALE_MS = 24 * 60 * 60 * 1000;
const TIMEOUT_MS = 8000;
const STATE_HEADER = "X-Komaku-Cache-State";
const META_PATH = "/v1/solar/latest.json";
const IMAGE_PATH = "/v1/solar/latest.jpg";
const CACHE_PATH = "/__komaku_cache/nasa-sdo-v1";
const HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Expose-Headers":
    "ETag, X-Komaku-Status, X-Komaku-Retrieved-At, X-Komaku-File-Updated",
  "X-Content-Type-Options": "nosniff",
  "Cache-Control": "no-store",
};

export function publicationTime(value, now) {
  if (
    typeof value !== "string" ||
    !/^(Mon|Tue|Wed|Thu|Fri|Sat|Sun), \d{2} (Jan|Feb|Mar|Apr|May|Jun|Jul|Aug|Sep|Oct|Nov|Dec) \d{4} \d{2}:\d{2}:\d{2} GMT$/.test(
      value,
    )
  )
    return null;
  const parsed = Date.parse(value);
  if (
    !Number.isFinite(parsed) ||
    new Date(parsed).toUTCString() !== value ||
    parsed < Date.UTC(2000, 0, 1) ||
    parsed > now + 300000
  )
    return null;
  return parsed;
}

export function jpegDimensions(bytes) {
  if (
    !(bytes instanceof Uint8Array) ||
    bytes.length < 4 ||
    bytes.length > MAX_BYTES ||
    bytes[0] !== 255 ||
    bytes[1] !== 216 ||
    bytes.at(-2) !== 255 ||
    bytes.at(-1) !== 217
  )
    return null;
  let offset = 2;
  while (offset + 3 < bytes.length) {
    if (bytes[offset] !== 255) return null;
    while (bytes[offset] === 255) offset++;
    const marker = bytes[offset++];
    if ([0, 216, 217, 218].includes(marker)) return null;
    if (marker === 1 || (marker >= 208 && marker <= 215)) continue;
    const length = bytes[offset] * 256 + bytes[offset + 1];
    if (length < 2 || offset + length > bytes.length) return null;
    if ([192, 194].includes(marker)) {
      if (length < 8 || bytes[offset + 2] !== 8) return null;
      return {
        width: bytes[offset + 5] * 256 + bytes[offset + 6],
        height: bytes[offset + 3] * 256 + bytes[offset + 4],
      };
    }
    offset += length;
  }
  return null;
}

export async function readBounded(response) {
  const declared = response.headers.get("Content-Length");
  if (
    declared !== null &&
    (!/^\d+$/.test(declared) || Number(declared) > MAX_BYTES)
  )
    throw new Error("body_limit");
  if (!response.body) throw new Error("empty_body");
  const reader = response.body.getReader();
  const chunks = [];
  let length = 0;
  try {
    while (true) {
      const next = await reader.read();
      if (next.done) break;
      length += next.value.byteLength;
      if (length > MAX_BYTES) throw new Error("body_limit");
      chunks.push(next.value);
    }
  } catch (error) {
    await reader.cancel().catch(() => {});
    throw error;
  } finally {
    reader.releaseLock();
  }
  const bytes = new Uint8Array(length);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return bytes;
}

export async function sha256(bytes) {
  return Array.from(
    new Uint8Array(await crypto.subtle.digest("SHA-256", bytes)),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}

function json(value, status = 200, extra = {}) {
  return new Response(JSON.stringify(value), {
    status,
    headers: {
      ...HEADERS,
      "Content-Type": "application/json; charset=utf-8",
      ...extra,
    },
  });
}

function imageIsValid(bytes) {
  const dimensions = jpegDimensions(bytes);
  return dimensions?.width === 512 && dimensions?.height === 512;
}

function validState(state, now) {
  if (
    !state ||
    state.schema !== 1 ||
    !["image", "unavailable"].includes(state.kind) ||
    typeof state.failed !== "boolean"
  )
    return false;
  for (const field of ["checked_at", "next_check_at"])
    if (!Number.isSafeInteger(state[field]) || state[field] <= 0) return false;
  if (
    state.checked_at > now + 300000 ||
    state.next_check_at < state.checked_at ||
    state.next_check_at > state.checked_at + REFRESH_MS
  )
    return false;
  if (state.kind === "unavailable")
    return (
      state.failed &&
      state.fetched_at === null &&
      state.sha256 === null &&
      state.last_modified === null
    );
  return (
    Number.isSafeInteger(state.fetched_at) &&
    state.fetched_at > 0 &&
    state.fetched_at <= state.checked_at &&
    now - state.fetched_at < RETAIN_MS &&
    /^[0-9a-f]{64}$/.test(state.sha256) &&
    (state.last_modified === null ||
      publicationTime(state.last_modified, state.fetched_at) !== null)
  );
}

/** Injectable only for local tests; the deployed handler supplies fixed dependencies. */
export function createService({
  cache,
  fetcher = fetch,
  now = () => Date.now(),
}) {
  const inFlight = new Map();

  async function readCache(key, time) {
    try {
      const response = await cache.match(key);
      if (!response) return null;
      const raw = response.headers.get(STATE_HEADER);
      if (!raw || raw.length > 2048) return null;
      const state = JSON.parse(raw);
      if (!validState(state, time)) return null;
      if (state.kind === "unavailable") return { state, bytes: null };
      const bytes = await readBounded(response);
      if (!imageIsValid(bytes) || (await sha256(bytes)) !== state.sha256)
        return null;
      return { state, bytes };
    } catch {
      return null;
    }
  }

  async function writeCache(key, record, time) {
    const lifetime = record.bytes
      ? RETAIN_MS - (time - record.state.fetched_at)
      : RETRY_MS;
    if (lifetime <= 0) return false;
    try {
      await cache.put(
        key,
        new Response(record.bytes, {
          headers: {
            "Content-Type": "application/octet-stream",
            "Cache-Control": `public, max-age=${Math.max(1, Math.floor(lifetime / 1000))}`,
            [STATE_HEADER]: JSON.stringify(record.state),
          },
        }),
      );
      return true;
    } catch {
      return false;
    }
  }

  async function latest(key) {
    const start = now();
    const cached = await readCache(key, start);
    if (cached && start < cached.state.next_check_at)
      return { ...cached, checked: false, cacheStored: true };
    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), TIMEOUT_MS);
    try {
      // Never forward client cookies, authorization, address or caller headers.
      const upstream = await fetcher(SOURCE_URL, {
        method: "GET",
        redirect: "manual",
        credentials: "omit",
        signal: controller.signal,
        headers: { Accept: "image/jpeg" },
      });
      if (
        upstream.status !== 200 ||
        upstream.redirected ||
        (upstream.url && upstream.url !== SOURCE_URL)
      )
        throw new Error("source_status");
      if (
        upstream.headers
          .get("Content-Type")
          ?.split(";")[0]
          .trim()
          .toLowerCase() !== "image/jpeg"
      )
        throw new Error("source_type");
      const bytes = await readBounded(upstream);
      if (!imageIsValid(bytes)) throw new Error("source_image");
      const time = now();
      const modified = upstream.headers.get("Last-Modified");
      const state = {
        schema: 1,
        kind: "image",
        failed: false,
        fetched_at: time,
        checked_at: time,
        next_check_at: time + REFRESH_MS,
        last_modified:
          publicationTime(modified, time) === null ? null : modified,
        sha256: await sha256(bytes),
      };
      const record = { state, bytes };
      return {
        ...record,
        checked: true,
        cacheStored: await writeCache(key, record, time),
      };
    } catch {
      const time = now();
      const stillUsable =
        cached?.bytes && time - cached.state.fetched_at < RETAIN_MS;
      const state = stillUsable
        ? {
            ...cached.state,
            failed: true,
            checked_at: time,
            next_check_at: time + RETRY_MS,
          }
        : {
            schema: 1,
            kind: "unavailable",
            failed: true,
            fetched_at: null,
            checked_at: time,
            next_check_at: time + RETRY_MS,
            last_modified: null,
            sha256: null,
          };
      const record = { state, bytes: stillUsable ? cached.bytes : null };
      return {
        ...record,
        checked: true,
        cacheStored: await writeCache(key, record, time),
      };
    } finally {
      clearTimeout(timer);
    }
  }

  function provenance(record, time) {
    const state = record.state;
    const publication = publicationTime(state.last_modified, time);
    const retrievalAge =
      state.fetched_at === null
        ? null
        : Math.max(0, (time - state.fetched_at) / 1000);
    const publicationAge =
      publication === null ? null : Math.max(0, (time - publication) / 1000);
    const status = !record.bytes
      ? "unavailable"
      : state.failed ||
          retrievalAge > REFRESH_MS / 1000 ||
          publicationAge > PUBLICATION_STALE_MS / 1000
        ? "stale"
        : "available";
    return {
      schema_version: 1,
      status,
      delivery: !record.bytes
        ? "none"
        : state.failed
          ? "stale-cache"
          : record.checked
            ? "upstream"
            : "edge-cache",
      upstream_check: record.checked
        ? state.failed
          ? "failed"
          : "validated"
        : "not-attempted",
      cache_stored: record.cacheStored,
      source_url: SOURCE_URL,
      source_page_url: SOURCE_PAGE_URL,
      policy_url: POLICY_URL,
      credit: CREDIT,
      image_path: record.bytes ? IMAGE_PATH : null,
      sha256: state.sha256,
      width: record.bytes ? 512 : null,
      height: record.bytes ? 512 : null,
      bytes: record.bytes?.byteLength ?? 0,
      fetched_at_utc:
        state.fetched_at === null
          ? null
          : new Date(state.fetched_at).toISOString(),
      last_checked_utc: new Date(state.checked_at).toISOString(),
      file_updated_utc:
        publication === null ? null : new Date(publication).toISOString(),
      http_last_modified: state.last_modified,
      observed_at_utc: null,
      cache_age_seconds: retrievalAge,
      publication_age_seconds: publicationAge,
      message: !record.bytes
        ? "NASA is unavailable. Use the game's labelled offline reference or open the NASA source."
        : state.failed
          ? "NASA could not be checked. This is the last validated cached image."
          : status === "stale"
            ? "NASA's latest available file is old. Check its publication date."
            : record.checked
              ? "NASA image validated. File publication time is not observation time."
              : "Cached NASA image. This request did not contact NASA.",
      scientific_scope:
        "Educational AIA 193 Å browse imagery only. No Mars dose, storm prediction, solar-panel output or game scoring is derived from this image.",
    };
  }

  return {
    async fetch(request) {
      const url = new URL(request.url);
      if (![META_PATH, IMAGE_PATH].includes(url.pathname))
        return json({ error: "not_found" }, 404);
      if (url.search)
        return json({ error: "query_parameters_not_supported" }, 400);
      if (request.method === "OPTIONS")
        return new Response(null, {
          status: 204,
          headers: {
            ...HEADERS,
            "Access-Control-Allow-Methods": "GET, OPTIONS",
            "Access-Control-Max-Age": "600",
          },
        });
      if (request.method !== "GET")
        return json({ error: "method_not_allowed" }, 405, {
          Allow: "GET, OPTIONS",
        });
      const key = new Request(`${url.origin}${CACHE_PATH}`);
      if (!inFlight.has(key.url))
        inFlight.set(
          key.url,
          latest(key).finally(() => inFlight.delete(key.url)),
        );
      const record = await inFlight.get(key.url);
      const metadata = provenance(record, now());
      if (!record.bytes || url.pathname === META_PATH)
        return json(
          metadata,
          record.bytes ? 200 : 503,
          record.bytes ? {} : { "Retry-After": "60" },
        );
      const headers = {
        ...HEADERS,
        "Content-Type": "image/jpeg",
        "Content-Length": String(record.bytes.length),
        ETag: `"${record.state.sha256}"`,
        "X-Komaku-Status": metadata.status,
        "X-Komaku-Retrieved-At": metadata.fetched_at_utc,
        "Cache-Control":
          metadata.status === "available" ? "public, max-age=60" : "no-store",
      };
      if (metadata.file_updated_utc)
        headers["X-Komaku-File-Updated"] = metadata.file_updated_utc;
      return new Response(record.bytes, { headers });
    },
  };
}

let deployedService;
export default {
  fetch(request) {
    deployedService ??= createService({ cache: caches.default });
    return deployedService.fetch(request);
  },
};
