# Live NASA solar imagery

KŌMAKU connects directly to NASA's Solar Dynamics Observatory (SDO) for its latest available 512 × 512 AIA 193 Å browse image. The solar viewer is an educational window onto a real NASA mission. It does not estimate a storm, predict radiation at Mars, or change the historical dose reference or authored battery, dust and timing settings.

- Fixed image endpoint: <https://sdo.gsfc.nasa.gov/assets/img/latest/latest_512_0193.jpg>
- NASA data and instrument context: <https://sdo.gsfc.nasa.gov/data/>
- NASA's data-use rules: <https://sdo.gsfc.nasa.gov/data/rules.php>
- Required credit: **Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.**

NASA describes these JPEGs as browse products. Displaying them for learning does not turn them into calibrated measurements suitable for quantitative scientific analysis. In particular, image color and brightness are not a child's absorbed dose, a Mars dose measurement or a medical risk assessment.

## What “latest” means

The client requests the latest file NASA makes available. A successful connection does not guarantee a new exposure was taken at that instant. The viewer keeps these times separate:

| Field                                 | Meaning                                                                                                                                         |
| ------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `last_checked_utc`                    | When this process last attempted a request, even if it failed.                                                                                  |
| `last_success_utc` / `fetched_at_utc` | When this process or its validated cache last received a usable NASA image. A failed refresh does not replace this time.                        |
| `file_updated_utc`                    | Validated HTTP `Last-Modified` publication metadata from NASA, displayed as publication time. This is **not a verified observation timestamp**. |
| `cache_age_seconds`                   | Time since the successful retrieval; `-1` for the bundled reference.                                                                            |
| `image_age_seconds`                   | Time since the file's publication metadata; `-1` if unavailable or invalid. This is not exposure age.                                           |

An embedded timestamp in the image is not parsed or independently validated. The client never relabels file metadata as acquisition time. A publication age greater than 24 hours receives a **stale** label. That threshold is our display freshness policy, not a NASA hazard threshold.

## Connected, cached and offline behavior

[`solar_feed.gd`](../game/live/solar_feed.gd) is a Node with a `changed` signal, `refresh(force = false)` and `snapshot()`. Creating the Node loads the last validated cache or bundled reference; it does not start a network request. The host explicitly requests an automatic refresh at an appropriate entry point. Further automatic calls are limited to once per 15 minutes; manual refresh is limited to once per minute. Concurrent requests are ignored.

| Status     | What the player should understand                                                                                |
| ---------- | ---------------------------------------------------------------------------------------------------------------- |
| `loading`  | A request is in progress; the existing image stays visible.                                                      |
| `live`     | “NASA connected · latest available.” This process received and validated a NASA response.                        |
| `stale`    | NASA responded, but its latest available file was published over 24 hours ago.                                   |
| `cached`   | The last validated image is available locally; this is not a successful current connection.                      |
| `fallback` | A bundled NASA reference is displayed because no valid downloaded image is available. It is explicitly not live. |

`is_live` is true only following a successful response in the current process (`live` or `stale`). Loading and failed requests clear it. `source_kind` records whether the displayed image came from this process's network response, a disk cache, or the bundle; it must be read together with status. For example, an image first downloaded during this session remains a network-origin image after a later failed refresh, but its status is cached and `is_live` is false.

Snapshots also provide the `Texture2D`, fixed source URLs, credit, message, SHA-256, dimensions, publication freshness, request status and received byte count. UI components own presentation; this client never changes the mission engine.

## Validation, cache and privacy

Every request uses the single fixed NASA HTTPS image endpoint. It has a 12-second timeout, a 2 MiB body limit and zero redirects. The response must be HTTP 200 with an `image/jpeg` content type. JPEG headers are checked for exactly 512 × 512 dimensions **before** decoding, and the decoder must then confirm those dimensions. A failed or invalid response leaves the previous valid image intact.

The cache lives in the application's `user://nasa-sdo/` directory. It publishes a content-addressed JPEG first and then atomically replaces a small `latest.json` pointer. Readers verify schema, fixed source URL, digest, bounded file size, valid retrieval time and decoded dimensions. Corrupt, partial, future-dated or traversal-shaped metadata falls back to the bundle. Cache paths reject symlinks. Old content-addressed JPEGs are removed after a successful pointer update; unknown user files are not removed. Cache-write failure still permits viewing the valid downloaded image for the current session.

There are no API keys, accounts, health permissions or learner-data payloads. The request contains no progress, names, quiz answers or device health data. NASA and network intermediaries still receive ordinary connection information such as an IP address. TLS certificate verification is never disabled.

The bundled fallback and its source, retrieval timestamp, publication metadata, byte count, SHA-256 and credit are recorded in [`sdo-aia-193-provenance.json`](../game/assets/nasa/sdo-aia-193-provenance.json). It remains a dated reference, even when the device is offline.

## Verification and platform limits

The deterministic [`live_solar_feed_test.gd`](../game/tests/live_solar_feed_test.gd) suite covers image bounds, corrupt/truncated data, metadata validation, publication age, offline fallback, cache integrity, path confinement and refresh throttling. It does not contact NASA.

```sh
XDG_DATA_HOME="$(mktemp -d)" godot --headless --path game --script res://tests/live_solar_feed_test.gd
```

The opt-in [`probe_live_solar_feed.gd`](../game/tests/probe_live_solar_feed.gd) performs the real request using Godot's `HTTPRequest`. It requires a fresh isolated `XDG_DATA_HOME` and `KOMAKU_SOLAR_LIVE_PROBE=1`. Environments that need an HTTPS CONNECT proxy can pass the host/port through `KOMAKU_SOLAR_PROXY_HOST` and `KOMAKU_SOLAR_PROXY_PORT`, plus a trusted CA bundle through `KOMAKU_SOLAR_CA_BUNDLE`. These settings configure only the probe's request factory; the production client does not read them. The probe keeps certificate verification enabled and emits only sanitized source, status, dimensions, digest and timestamps.

A Linux Godot 4.6.3 probe on **2026-11-15 at 05:09:57 UTC** received HTTP 200 and a validated **512 × 512, 46,582-byte** JPEG. NASA's `Last-Modified` was `Sun, 15 Nov 2026 05:03:06 GMT`; the SHA-256 was `9c737aa19d4122ec0651bdc8b55fcf09b6f92a7a6214428b076e540d863843e4`. See the sanitized [result](evidence/live-nasa-sdo-0.8.json) and [Godot log](evidence/live-nasa-sdo-0.8.log). This validates the real native-client request, not merely a Python download or bundled fixture.

Browser builds remain subject to NASA's CORS headers and the browser's networking rules. Native success does not prove browser or mobile fetching. If a browser blocks the request, show the explicitly cached/bundled image and offer **Open NASA source** in the device browser. Availability also depends on the device network and NASA's service. This integration does not establish compliance with any hackathon eligibility rule that has not been independently verified.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
