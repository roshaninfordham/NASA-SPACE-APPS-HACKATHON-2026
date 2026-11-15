# Optional NASA context cache on Cloudflare Workers

This service gives KŌMAKU a useful optional Cloudflare integration: cache NASA's public SDO image near players, serve provenance with it, and reduce repeated requests to NASA. Public CORS responses also provide a possible browser-compatible route when NASA's own CORS policy blocks the game. **It is implemented and locally tested, but not deployed or connected to the Godot client.** The current client remains [game/live/solar_feed.gd](../../game/live/solar_feed.gd).

The service uses Cloudflare Workers and its Cache API. It needs no database, queue, NASA key, learner account, paid AI service or client secret. Plain JavaScript and Node's built-in test runner keep the implementation small. No third-party implementation is copied into this service; Wrangler is Cloudflare's open-source deployment tool.

## Source and scientific boundary

- Image: <https://sdo.gsfc.nasa.gov/assets/img/latest/latest_512_0193.jpg>
- Instrument context: <https://sdo.gsfc.nasa.gov/data/>
- Source-use rules: <https://sdo.gsfc.nasa.gov/data/rules.php>
- Credit: **Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.**

This is a colorized AIA 193 Å extreme-ultraviolet **browse image**. It is educational context, not a live Mars dose measurement, particle-event prediction, solar-panel input or score. NASA's browse-image restrictions and the existing [live-data policy](../../docs/LIVE-DATA.md) still apply. No image pixels enter the game equations.

`file_updated_utc` comes only from valid NASA HTTP `Last-Modified` metadata. It is publication time, **not verified acquisition time**. `observed_at_utc` is always `null`. Retrieval/check timestamps come from the server clock at the actual request, and a failed refresh never replaces the last successful retrieval time. Missing, impossible, future or malformed publication dates stay unknown.

## HTTP contract

| Request                     | Response                                                                                                          |
| --------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `GET /v1/solar/latest.json` | Versioned JSON provenance and availability; HTTP 200 with a usable image, or 503 with no image.                   |
| `GET /v1/solar/latest.jpg`  | Unmodified validated NASA JPEG bytes and status/digest headers; 503 **JSON**, not a fake image, when unavailable. |
| `OPTIONS` on either route   | Public read-only CORS response; no NASA request.                                                                  |

Other paths, query parameters, and methods are rejected. There is no URL override, upload, learner profile endpoint, analytics beacon or credential forwarding. The Worker never follows upstream redirects. The application does not copy `Authorization`, cookies, device data or caller headers into the NASA request.

Metadata schema version 1 provides fixed `source_url`, `source_page_url`, `policy_url`, `credit`, `scientific_scope`, `image_path`, `sha256`, dimensions, byte length and these status fields:

| Field                                           | Meaning                                                                                                                           |
| ----------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------- |
| `status`                                        | `available`, `stale`, or `unavailable`. “Available” means a validated retrievable browse image, not a guaranteed recent exposure. |
| `delivery`                                      | `upstream`, `edge-cache`, `stale-cache`, or `none`.                                                                               |
| `upstream_check`                                | `validated` or `failed` if this request checked NASA; `not-attempted` for a cache hit.                                            |
| `fetched_at_utc`                                | Last successful retrieval, preserved through later failures; null when no image exists.                                           |
| `last_checked_utc`                              | Most recent actual attempt represented by this edge cache.                                                                        |
| `file_updated_utc` / `http_last_modified`       | Validated publication metadata, or null.                                                                                          |
| `observed_at_utc`                               | Always null: this service does not independently determine exposure time.                                                         |
| `cache_age_seconds` / `publication_age_seconds` | Ages calculated at response time; null when unknown.                                                                              |
| `cache_stored`                                  | Whether this edge successfully retained the record; cache-write failure does not discard a valid NASA response.                   |

Metadata uses `Cache-Control: no-store` so age and status can be evaluated on each request. Available image responses permit 60 seconds of browser caching; stale images use `no-store`. The image `ETag` is its SHA-256 in quotes. `X-Komaku-Status`, `X-Komaku-Retrieved-At` and optional `X-Komaku-File-Updated` make image provenance visible without inventing a `Last-Modified` date.

The `latest` image can change between separate requests or edge locations. A future client must compare downloaded bytes against metadata `sha256`, confirm a decoded 512 × 512 JPEG and retry metadata on a mismatch; it must not attach stale metadata to different bytes. It must also retain the current labelled bundled/local fallback. This Worker checks JPEG signatures, bounded segment structure, 8-bit SOF dimensions and ending marker; it is **not a full JPEG decoder**. The existing Godot client already performs the full decode check.

## Cache and failure behavior

- A usable edge entry avoids another NASA request for 15 minutes. Same-isolate concurrent requests share one upstream fetch.
- Every fetch has an 8-second abort timer and a streaming 2 MiB body limit, including responses without `Content-Length`. HTTP status, MIME type and 512 × 512 JPEG structure must pass before replacing a good cache entry.
- A failed refresh serves the prior validated image as `stale-cache`, preserving its digest and successful retrieval timestamp. Failures back off for one minute; a cold-cache failure also receives a one-minute negative-cache entry.
- Images published over 24 hours ago are labelled stale even after a successful new fetch. This is a display freshness policy, not a radiation-warning threshold.
- Images can be retained for up to seven days. Failed retries never extend that age limit. Afterwards an unreachable source produces 503 so the game can show its explicitly labelled local/bundled reference.
- Cloudflare's Cache API is best-effort and local to a data center. Entries may be evicted, and request coalescing is per isolate, **not a globally guaranteed request rate or durable offline storage**. No KV/Durable Object is required for this one optional feed.

No application request logs or analytics are emitted, and Wrangler observability is disabled by default. Cloudflare still receives ordinary connection information such as the requesting IP, and NASA receives ordinary connection information from the upstream request. Provider-managed headers and infrastructure handling are outside this application’s privacy guarantee. This is not a promise that infrastructure providers collect nothing. Keep children’s names, progress, answers and identifiers out of requests.

## Local verification

Node 22 or newer is required; Node 24.22.1 was used for the recorded checks. Tests need no npm dependencies or credentials:

```sh
cd services/nasa-context-worker
npm test
```

[Verification summary](evidence/verification.json) records the tested source hashes and packaging scope.

The 17 tests cover cache reuse and refresh, concurrent calls, stale/empty failure, retry backoff, retention, timestamps, URL/method restrictions, CORS, non-forwarded headers, malformed upstream data, oversized streams, corrupt cache state, cache-write failure and abort timeout. Test JPEG fixtures exercise structure and bounds rather than claiming full image decoding.

The opt-in read-only probe executes the same handler against real NASA HTTPS using a local in-memory cache:

```sh
npm run probe
```

On Node versions supporting environment proxy configuration, an environment that requires its approved HTTPS proxy can instead run:

```sh
node --use-env-proxy scripts/probe-upstream.js
```

TLS verification remains enabled. [Recorded access evidence](evidence/upstream-probe.json) received a 46,400-byte 512 × 512 JPEG on **2026-11-15 at 15:56:44 UTC**, with NASA `Last-Modified` **15:53:06 UTC**. This is one actual source-access check, not a Cloudflare deployment, native-client test or uptime guarantee.

## Deploy when an account owner chooses to enable it

A Cloudflare account and permission to create a Worker are required. **No deployment has been performed.** No NASA API key is needed, and no secret belongs in the game or this repository. Workers quotas and account settings still apply; review the selected plan in your account.

From this directory:

```sh
npx --yes wrangler@4.162.0 deploy --dry-run --outdir /tmp/komaku-nasa-worker
npx --yes wrangler@4.162.0 login
npx --yes wrangler@4.162.0 deploy
```

Wrangler 4.162.0 successfully bundled the module with `deploy --dry-run` (no bindings or account authentication). This is a packaging check, not proof of deployed edge-cache behavior.

`login` authorizes Wrangler in your browser; `deploy` is the publishing step. With multiple accounts, choose the intended account through Wrangler's account configuration. No `account_id`, custom domain or existing GitHub Pages domain is assumed in the supplied configuration. The generated `workers.dev` hostname is separate from the game's existing hosting decision. To avoid optional CLI metrics during these commands, set `WRANGLER_SEND_METRICS=false`.

After deployment, verify both fixed routes and an offline/stale scenario before adding a fixed, reviewed endpoint to the game. Keep the source credit, timestamps, fallback and model separation visible. The deployment must not silently replace the production client's trusted fixed source until its metadata, cache and decoding integration have been tested. The only present deployment configuration is [wrangler.jsonc](wrangler.jsonc); no account credentials or automated publishing workflow are included.

## Other sponsor integrations considered

| Integration                  | Decision and useful next boundary                                                                                                                                                                                       |
| ---------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **Cloudflare Workers**       | Implemented here for public-source caching and provenance. Optional; offline play stays independent.                                                                                                                    |
| **Gemini**                   | Deferred. A bounded, adult-reviewed coach grounded in authored explanations could help later, but must not invent science, request child data, or replace deterministic mission rules. No API call or key is added now. |
| **Twilio**                   | Not added. SMS/phone messaging is unrelated to the current child-facing offline learning flow and would introduce contact data and costs.                                                                               |
| **Sentry**                   | Deferred. Explicit opt-in error reports could help diagnose release failures later, with identifier/message scrubbing and no learner responses or profiles. No telemetry SDK is installed.                              |
| **Tiger Data / TimescaleDB** | Not added. One public JPEG feed and local learner progress do not need a hosted time-series database. Reconsider only for a real, consented research-data requirement.                                                  |

These are functional fit decisions, not sponsorship or endorsement claims.
