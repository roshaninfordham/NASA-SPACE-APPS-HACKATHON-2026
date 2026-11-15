# KŌMAKU Mission Science Lab

A small **companion demonstration**, separate from the native game: NASA SDO imagery served through Cloudflare; three source-linked science lessons; an optional Gemini explanation button. It does not change the game's simulation, learning journal, or release downloads.

## Verified status — November 15, 2026

- Cloudflare accepted the `komaku-mission-lab` Worker upload, including its rate-limit binding. The account's workers.dev subdomain lookup returns 404; public reachability is **not yet verified**. Initial subdomain registration via the API token returned 405, so dashboard setup is required.
- Gemini model discovery succeeded. Actual generation with `gemini-2.5-flash-lite` returned **403 PERMISSION_DENIED: “The Gemini API free tier is not available for this project.”** No successful generation is claimed. Billing was not enabled.
- 25 tests passed (8 coach tests plus 17 existing NASA-cache tests).
- Chromium checks passed at 1280 px and 390 px: topic selection, missing-key fallback, no horizontal overflow and no JavaScript errors. A real NASA image was retrieved and its bytes checked against the metadata SHA-256 before display. [Desktop capture](evidence/desktop.png) · [Mobile capture](evidence/mobile.png). These are **local browser checks**, not proof of a public endpoint.

## Where the free tiers help

| Service | Specific contribution | Limit and design response |
|---|---|---|
| Cloudflare Workers Free | Serve the companion page and cache one fixed NASA source near viewers; retain provenance and visibly label stale imagery. | Official limits list 100,000 requests/day per account and 10 ms CPU/request. Our HTML, JS, CSS and API requests run through the Worker and count. Network wait differs from CPU time. No paid plan was enabled; actual account billing must be checked in its dashboard. |
| Gemini 2.5 Flash-Lite | Rephrase fixed NASA-derived facts into two short sentences and one investigation question. | Published pricing lists free input/output for eligible free-tier projects, but this project's generation was rejected. Actual model quotas vary by project/tier; inspect AI Studio. No promise of unlimited free calls. |

Sources checked: [Cloudflare limits](https://developers.cloudflare.com/workers/platform/limits/) ([official docs source](https://github.com/cloudflare/cloudflare-docs/blob/production/src/content/docs/workers/platform/limits.mdx)); [Gemini pricing](https://ai.google.dev/gemini-api/docs/pricing#gemini-2.5-flash-lite); [Gemini rate limits](https://ai.google.dev/gemini-api/docs/rate-limits).

Cloudflare caches NASA for 15 minutes, with explicitly labelled fallback on refresh failure. Gemini responses are cached for 24 hours per topic, with up to 10 requests/minute per client IP using the Worker rate-limit binding. Cache/rate-limit behavior is distributed and best effort: this is **not a global spending cap** or a guarantee of three generations per day. A cache miss in another location may generate again. Provider quotas still apply. API failures produce an honest unavailable message; the authored lesson always remains usable.

Google's free-tier pricing marks content as used to improve its products. This demo sends only one of three fixed public-science prompts: no learner names, answers, progress, arbitrary text or health information. Cloudflare receives ordinary connection information and uses the IP for request limiting; this is not a claim of zero infrastructure data processing. Application logs/observability are disabled.

## Required account-owner steps

1. In Cloudflare **Workers & Pages**, complete initial workers.dev onboarding and choose the account's subdomain. The Worker `komaku-mission-lab` has already been uploaded.
2. In Google AI Studio, use a project that actually permits free-tier generation or the appropriate MLH-provided project. The current key cannot generate on the free tier. No paid billing is authorized by this setup.
3. In Cloudflare, open **komaku-mission-lab → Settings → Variables and Secrets → Add**, choose **Secret**, set the name to `GEMINI_API_KEY`, and enter the eligible key privately. Save/deploy the binding. Environment proxy credentials cannot be extracted and copied to a Worker. Never put this key in GitHub or the game client.
4. Supply the eligible key through this environment's secure settings too if direct verification here is wanted. No NASA key is needed for this SDO service.
5. Verify the public `/api/status`, `/v1/solar/latest.json`, image display and **Explain with Gemini** button. Credential presence in `/api/status` is not evidence of a successful generation. A successful response explicitly says `generated` or `cached` and carries model/time/source metadata.

The `CLOUDFLARE_ACCOUNT_ID` environment setting was an email, not an ID. A read-only account lookup resolved the sole accessible account for this deployment. Correct that setting to your account's 32-character ID for future deploys; the ID is not a secret.

## Reproduce

From the repository root:

```sh
node --test services/mission-lab/test/*.test.js services/nasa-context-worker/test/*.test.js
python services/mission-lab/scripts/deploy.py
```

Deployment requires the scoped Cloudflare token and valid account ID in the environment. The deployment script preserves existing secret bindings, uploads only code, and never transfers Gemini/NASA secrets. It creates or updates only `komaku-mission-lab` and enables that Worker's workers.dev route.

`src/ui.js` contains the page, styles and browser logic; `src/coach.js` owns fixed topics and AI calls. `src/index.js` routes them and imports the existing NASA cache. The browser renders AI content as text, not HTML, checks NASA image checksums/dimensions, and applies a restrictive content security policy. AI output is schema/length checked, **not scientifically validated**. Sources and the AI warning remain visible.

## Demo script once unblocked

1. Open the public Worker URL. Show the actual NASA image, retrieval time and cache status.
2. Select **Dust**, **Energy**, then **Radiation**. Explain that solar imagery does not forecast the fictional Mars storm.
3. Press **Explain with Gemini**. Show the returned explanation, investigation question, model and generation time.
4. Repeat the same topic: demonstrate an explicitly labelled cached AI response rather than implying another model call.
5. Open the NASA source. Explain that the AI changes wording, not game physics.

SI disclosure: code, interface copy and tests were developed with AI assistance. Runtime Gemini explanations are visibly labelled AI-generated. NASA image bytes are unmodified and credited; no synthetic NASA branding is generated.
