/** Opt-in read-only NASA check; no Cloudflare deployment or user data. */
import { createService } from "../src/index.js";
const entries = new Map();
const service = createService({
  cache: {
    async match(request) {
      return entries.get(request.url)?.clone();
    },
    async put(request, response) {
      entries.set(request.url, response.clone());
    },
  },
});
const response = await service.fetch(
  new Request("https://local-probe.invalid/v1/solar/latest.json"),
);
const result = await response.json();
console.log(
  JSON.stringify(
    {
      probe_ran_at_utc: new Date().toISOString(),
      scope:
        "Local Node execution of the Worker handler against NASA HTTPS, using an in-memory cache. Not a Cloudflare deployment or a Godot-client acceptance test.",
      http_status: response.status,
      result,
    },
    null,
    2,
  ),
);
if (response.status !== 200) process.exitCode = 1;
