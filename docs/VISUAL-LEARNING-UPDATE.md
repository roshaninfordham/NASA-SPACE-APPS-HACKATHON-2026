# Current visual and learning update

**Unreleased source; integrated source checks passed, including the final navigation-label recheck.** The available published game remains [0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1). Earlier 0.11 C1 acceptance belongs to source `20e361a2099f7bc67aacb0e7eedb65c7eab9d0a0`; it does not establish acceptance of these newer changes.

## The submission video is ready

[Download the 29.5-second MP4](media/submission-demo/KOMAKU-30-second-demo.mp4). It is 1920×1080 at 24 fps, with burned-in captions and AI-generated Indian English male narration. It uses actual engine footage and computed-result fixtures, edited for the short presentation. Source footage was captured at lower resolution and scaled; the gameplay segment uses Godot MovieWriter timing. This is not a physical-device benchmark, an uninterrupted full run, or a recording of a child playing. [Credits, edit and provenance](media/submission-demo/README.md).

The video is publicly committed at `2c6fdd1`. Its delivery does not publish a new game version, and its captured source may precede later edits described here.

## Visual changes in source

Ren has a more visible face and revised brush movement. The exterior adds layered Mars terrain, light and reflections; the panel gains beveled geometry with smoother continuous dust presentation. The window glass, frame and control rail share a more cohesive treatment. The story gains a gradient treatment and the result screen gains illustration.

These are implementation changes. The team still needs to assess composition, character appeal, clarity and performance in the integrated game. The [earlier 41-screen C1 review gallery](https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/review/0.11.0-alpha.1/) remains useful historical evidence but does not show all this new work. No claim of photorealism, pixel-identical reference reproduction or final visual acceptance follows from the source changes.

## Coaching during a mission

A few short radio exchanges respond to the actual run: trying the pace slider, removing enough dust to discuss power, rising fictional fatigue, and the approaching deadline. Each cue appears at most once in a run; an active player-command exchange takes priority. Reading and pause do not advance the mission or consume coaching out of view.

This is deterministic local teaching support. It does not assess emotion, diagnose fatigue, use a neural network, or turn the fictional radiation curve into a health prediction. The existing 90-second standard mission and numerical rules remain the same.

## Your training: a local journal

**Home / Menu → Your training** shows completed missions, ideas explored, recent results, and a suggested next activity. Opening it during a mission pauses play. It is a summary of local records, not an online account or a measure of real astronaut readiness.

Profile schema 3 retains up to **30 detailed recent runs** plus cumulative counters. Earlier profiles retained at most ten detailed runs; migration can count only the history still present. The journal labels incomplete history as a lower bound rather than inventing missing attempts. Existing settings and available records are preserved through supported migration.

“Ideas explored” means a science card was visited and acknowledged. It is **not mastery**. “First-try practice” reports the first unassisted answer to the **existing pace/fatigue question**; retries do not rewrite that first answer. The journal does not imply that all eight science concepts have been tested. Suggested activities use transparent local rules; personalized or validated AI tutoring is not claimed.

## Optional NASA context service

The [standalone Cloudflare Worker](../services/nasa-context-worker/README.md) caches NASA’s public SDO AIA 193 Å browse image and serves its provenance. It has **17 isolated tests**, a successful **Wrangler dry run**, and an **actual NASA-source access probe**. These are service checks, not game-client integration or deployed-edge evidence.

The Worker is **not deployed and not wired into the Godot client**. No NASA API key is needed. Deployment would require a Cloudflare account and permission to publish the Worker, followed by endpoint/integration verification. The current client still requests NASA directly; offline play is independent of either service. Solar-image pixels do not drive Mars radiation, storm timing, power or scoring.

## Acceptance still required

The shared native game suite passed after integration, including the 401-assertion training-journal suite, 377 progress assertions, and existing model/PDF/updater/Python checks. A supplemental actual-main training flow passed 53 assertions; it has been added to the authoritative runner, and its final navigation-label recheck also passed. These results do not establish visual acceptance. Review updated scenes and journal navigation, and retain the recorded migration scope. New exports and supported update baselines must then be tested on the actual candidate bytes. Preserve the earlier C1 records as historical evidence rather than relabelling them. Visual approval, physical-device testing, publication and public-download verification remain distinct outcomes.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
