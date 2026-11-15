# Offline polish and optional local-model roadmap

Reviewed November 15, 2026. This is an implementation roadmap and source review, **not a claim that a new engine, neural model, art pack, or release has shipped**. The current game is Godot 4.6.3 / GDScript with GL Compatibility rendering; the native mission model already runs locally. The user selected automatic device-dependent presentation with a manual override, a complete minimal base download and optional model/art packs, and cloud-based development to avoid filling the user's Mac. Exact package sizes and device-specific performance budgets remain provisional until measured.

## Recommendation

Keep Godot for the next playable milestone, improve the actual assets and interaction, and make the source-grounded built-in coach the dependable offline path. Evaluate a separate optional local language-model pack after the game is enjoyable and performant. Do not make a cloud key, online service, database, or model download a prerequisite for the mission.

“GTA VI-level” is an art-production and engineering aspiration, not a measurable promise for this prototype. An engine switch cannot produce a rigged character, authored animation, production materials, cinematography, audio mixing, and device testing by itself. This game has a much smaller scene and a deliberately fixed window viewpoint: concentrating detail around Ren, her hands, the brush, the panel and the window will deliver more value than constructing an open world.

## Selected modular direction

**One complete base game, progressively enhanced by explicitly selected packs.** The smallest installation must include the mission, local science explanations, necessary art/sound, readable controls, pause/navigation, results, replay and saved progress. It must not be a broken preview that requires an AI or high-resolution pack to teach the lesson. Sources needed to understand the simulation remain bundled; opening a source website is optional.

| Component                                                                 | Base or optional                     | Behavior without it                                                      |
| ------------------------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------ |
| Deterministic mission, UI, built-in coach and journal                     | Required base                        | No installation may omit these and still claim a complete game           |
| Baseline character/environment/textures and essential sound cues          | Required base                        | The window mission remains visually understandable                       |
| Higher-resolution textures, extra mesh detail and richer cosmetic effects | Optional art pack                    | Continue using baseline assets; identical mission/science outcomes       |
| Local language-model weights and compatible inference runtime             | Optional AI pack                     | Immediate source-based built-in guide; no API key or network requirement |
| Additional voice/language or mission content                              | Future optional packs                | Captions and the complete introductory mission remain available          |
| Cloudflare/NASA live imagery, Gemini companion and TimescaleDB demo       | Optional online/authoring facilities | Use explicitly labelled bundled source references; no mission dependence |

“Full” means all **supported and selected** components, not blindly enabling every expensive effect or simultaneously loading every model. Download choices must show package size, additional free space needed for staging/unpacking, target OS/architecture, license, current version and a clear remove option. Removing optional content must preserve progress and keep the base playable. Exact sizes are published from release artifacts, not estimated marketing totals.

### Automatic quality with a manual override

- Keep **Auto**, **Low**, **Balanced** and **High** choices understandable to players. Auto chooses from installed compatible resources only; it must never trigger a multi-gigabyte download or switch to a new engine renderer without consent.
- Start conservatively when capability detection is incomplete. OS/platform, memory availability, supported renderer/backend and actual measured frame behavior are stronger signals than a GPU name alone. Detectability differs across native/web/mobile environments, so “unknown” must be a supported state.
- Separate **capability** (what the device can run), **availability** (which packs are installed) and **preference** (what the player selected). “High” cannot load missing textures or an unsupported inference backend; explain the limitation and retain the working base profile.
- Auto may reduce render scale, shadow detail, particle count or cosmetic effects when sustained measurements justify it. Use a warm-up and stable thresholds rather than changing quality every frame. Never change simulation rates, science values, control sensitivity or outcome thresholds to reach an FPS target.
- A manual selection stays selected until the player changes it; hardware warnings can suggest a lower tier without silently undoing the choice. Reduced motion, text scaling, contrast, audio controls and control accessibility remain independent of visual quality.
- The first preset selector is a foundation, not evidence of dynamic benchmarking, asset-pack management, mobile coverage or installed neural inference. Each of those gets its own implementation and acceptance record.

### Preset selector now implemented in source

`game/scripts/graphics_preferences.gd` supplies persisted **Auto / Battery saver / Balanced / High** modes. Auto selects Battery saver for mobile/web, reported physical RAM at or below 8 GiB, unknown/empty graphics adapters, and recognized software renderers; otherwise it selects Balanced. It does not automatically select High or download assets.

| Current source preset | Frame cap | 3D MSAA  | Sun shadows                            | Decorative dust budget |
| --------------------- | --------: | -------- | -------------------------------------- | ---------------------: |
| Battery saver         |    30 FPS | Disabled | Off                                    |                     0% |
| Balanced              |    60 FPS | 2×       | Existing art-profile shadow permission |                    50% |
| High                  |    60 FPS | 4×       | Existing art-profile shadow permission |                   100% |

Reduced motion suppresses decorative dust. These are configured presentation budgets, **not measured device FPS**. The initial Auto decision is a conservative static capability heuristic, not adaptive frame-time benchmarking, texture streaming, or a model-pack manager. It does not alter mission equations. See the [implemented milestone](OFFLINE-POLISH-MILESTONE.md) for source checks and remaining target-device acceptance.

### Cloud development versus offline storage

Heavy source assets, Blender work, model conversion, builds and CI can stay in the cloud workspace; the user's low-storage Mac does not need the repository, build tools, art sources or every candidate model. Share a cloud preview or small exported build for feedback and keep versioned source/assets in appropriate repository or artifact storage.

A **fully offline installed game still needs its chosen runtime assets on that device**. Cloud development cannot make a 1.83 GB model available offline without storing it locally first. The Mac can use the complete base game and built-in coach, while a larger desktop explicitly installs additional packs. Cloud-hosted inference is an optional online mode with different privacy, latency and cost properties; it is not an offline substitute.

## Per-child adaptation: learner state, not a newly trained model

Training a separate neural model for each child is not required for useful personalization and is a poor default for low-storage, offline devices. It adds compute, storage, deletion/versioning complexity and overfitting risk without evidence that it improves this small mission. No on-device fine-tuning or per-child neural model is claimed or required.

Use a small local profile to remember actual attempts, chosen settings, explanations explored, responses to explicit practice questions and the next suggested activity. A shared reviewed policy can choose the next hint or practice task from those records. An optional common language model can rephrase a selected explanation using a bounded summary; its weights stay the same for all players. This separates three things that must not be conflated:

1. **Activity history:** what was opened or played; not mastery.
2. **Assessed understanding:** evidence from deliberately designed questions and explanations; requires evaluation before claiming accuracy.
3. **Model training:** changing neural weights; not part of this milestone.

Keep profiles local and removable, make “start fresh” predictable, and avoid carrying one player's recommendations into another player's session. Multiple local profiles need explicit implementation/testing before being advertised. Do not infer intelligence, disability, emotion or readiness for real astronaut work. Future learning research can evaluate whether adaptive recommendations improve understanding and delayed recall; the current journal alone does not establish that benefit.

## What the repository already supports

- `game/project.godot`: Godot 4.6, Compatibility renderer, 1280 × 720 design viewport, 60 Hz physics, Mars-like gravity setting, local entry scene and updater.
- `game/scripts/art_profile.gd`: replaceable scene slots for the companion, array, environment and interior; a shared palette; FPS, shadow and particle controls.
- `game/scripts/window_work_view.gd`: aspect-aware camera framing that keeps the astronaut and panel in the unobstructed window region.
- `game/scripts/journey_game.gd`: model, presentation, local progress, navigation, audio, optional solar viewer and updater orchestration. The current source now has persisted connection preferences, a `--offline` override and request gates for the solar feed/updater; consult [the implemented milestone](OFFLINE-POLISH-MILESTONE.md) for exact verification scope. A locally running model alone still does not prove zero network requests.
- `game/scripts/pace_mission.gd` and `docs/TRAINING-MODEL.md`: deterministic cleaning/fatigue/work/solar/battery/dose rules. Completed rounds currently share outside duration and dose. Visual polish or an AI explanation must not silently change those rules.
- Existing release/update logic verifies compatible content packs; engine changes require the full-installer path. Local scene slots are a safer route for early art improvements than a rewrite.

## Engine decision

| Candidate                               | Useful strengths                                                                                                          | Cost for this game                                                                                                                                  | Decision                                                                                                              |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| Godot 4, current Compatibility renderer | Existing tested model, navigation, save migration, exports and update path; broad hardware/web reach; open-source tooling | Asset and animation quality still need production work; some rendering features differ from Forward+/Mobile                                         | Retain as the baseline; use quality profiles and measured assets                                                      |
| Godot 4, optional Forward+ profile      | More advanced rendering path on supported hardware                                                                        | Shader/material differences, device checks, larger GPU budget; switching renderers does not fix composition or a low-detail hero asset              | Prototype a separate high-quality profile after baseline art acceptance; never require it for offline play            |
| Unreal Engine                           | Strong high-end scene and cinematic tooling                                                                               | Rebuild game logic/UI, import and animation pipeline, packaging and tests; proprietary licensing terms and higher-content ambition to manage        | Reconsider only if the team commits to a staffed cinematic production and measures a Godot limitation; no rewrite now |
| Unity                                   | Established production/editor ecosystem and asset tooling                                                                 | Similar porting and revalidation cost; commercial license/plan requirements; existing Godot investment discarded                                    | No clear benefit justifying a port for the current stationary mission                                                 |
| Bevy / Rust                             | Open-source Rust engine and explicit systems architecture                                                                 | Rebuild editor/content/UI/gameflow pipeline; official introduction warns of API-breaking development and recommends Godot for more complete tooling | Use only for a specific measured subsystem need, not a general “Rust makes it robust” rewrite                         |

Sources: [Godot renderer guidance](https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html), [official renderer documentation source](https://github.com/godotengine/godot-docs/blob/master/tutorials/rendering/renderers.rst), [Unity Personal](https://unity.com/products/unity-personal), [Unreal licensing](https://www.unrealengine.com/en-US/license), [Bevy introduction/stability warning](https://bevy.org/learn/quick-start/introduction/). The Unreal licensing page blocked this environment's request, so no current price/royalty threshold was verified or used in this decision. Renderer documentation was read from the official GitHub source because the rendered documentation site returned 403; verify feature availability against the pinned game-engine version before adopting it.

## First production-quality scene milestone

1. **Hero asset:** create a licensed Blender source asset for Ren with an actual skeleton, deliberate silhouette and facial readability; define shoulder/elbow/wrist joints and a hand/brush contact target. Author a short set of idle, steady-cleaning, fast-cleaning, tired and completion animations. Blend pace changes; do not merely spin an entire limb faster. Preserve a small procedural fallback while the asset is unfinished.
2. **Panel feedback:** distinguish dust, glass, cell grid and metal frame with consistent material roughness and normal detail. Map the actual cleaned fraction to a continuous dust mask. Brush movement and cleaned-area revelation should be visually related, without pretending the cosmetic mask is a validated dust-transport model.
3. **Window composition:** keep the player visibly inside the outpost, enlarge the meaningful action, and leave enough clean background for science bubbles. Give the hand/panel interaction priority over terrain decoration. Avoid depth of field or glare that hides the learning task.
4. **Light and materials:** one deliberate key light, coherent ambient fill, restrained reflections/emission and a controlled warm/cool palette. Investigate authored lightmaps where supported by the chosen renderer; baked lightmaps are cheaper at runtime but require a real asset/UV workflow. Do not add dynamic lights or transparent surfaces without profiling.
5. **Interaction and sound:** clear hover/focus/press states, a distinct response to a pace change, short captioned radio feedback, and layered brush/air/confirmation sounds with independent mute controls. Motion reduction must disable cosmetic shake without hiding information.
6. **Asset handoff:** keep `.blend` sources and license/provenance records; export reviewed `.glb` with stable pivots, units, material names and animation names. Godot recommends glTF 2.0. Each scene slot must have an anchor/scale contract and a low-detail fallback.

Sources: [Godot's glTF pipeline](https://github.com/godotengine/godot-docs/blob/master/tutorials/assets_pipeline/importing_3d_scenes/available_formats.rst), [lightmap workflow and limitations](https://github.com/godotengine/godot-docs/blob/master/tutorials/3d/global_illumination/using_lightmap_gi.rst). These are workflows, not generated production assets already present in the repository.

## Provisional performance budgets — targets, not measurements

| Area                  | Baseline target to test                                                                                                                               | Quality option                                                                                              |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------- |
| Hardware              | Ordinary integrated-GPU laptop reference (initially 8 GB RAM); OS/CPU recorded; a separate low-memory mobile tier requires physical-device validation | 16+ GB Apple Silicon or a discrete-GPU desktop                                                              |
| Rendering             | 30 FPS minimum at a chosen 720p/900p render scale; 60 FPS goal on a measured reference machine                                                        | 1080p with better shadows/materials if the frame budget permits                                             |
| Frame time            | 95th percentile under 33.3 ms at the minimum tier; report CPU and GPU separately                                                                      | 95th percentile under 16.7 ms on the selected higher tier                                                   |
| Scene starting budget | Approximately 200k visible triangles, 200 draw calls and 128–256 MiB texture residency; adjust from profiling                                         | Add detail only after a measured benefit and acceptable memory use                                          |
| Game memory           | Start with a target below 1.5 GiB resident memory, excluding optional inference                                                                       | Model pack gets a separate budget; do not count disk size as total RAM                                      |
| Download              | Complete minimal base; publish its measured compressed/installed/staging sizes independently of model weights                                         | Manually selected model/texture packs or a full bundle; automatic quality never implies automatic downloads |
| Responsiveness        | Pace control changes the next rendered animation state; pauses freeze model and audio consistently                                                    | Extra visual effects may not delay input or explanations                                                    |

Measure startup, a complete mission, result transition, replay and return home with the network unavailable. Record p50/p95 frame time, peak process memory, GPU memory where observable, loading time and audio glitches. The current cloud container is not a substitute for the user's Apple Silicon Mac or the minimum Windows laptop. No hardware benchmark in this document establishes those targets as achieved.

## Optional local language model: candidate, not a SOTA claim

**Evaluated candidate, not approved for shipment: Qwen3-1.7B, non-thinking mode, via llama.cpp.** The task is short rephrasing of supplied science facts and one investigation question, not general autonomous reasoning. A small model can be more suitable than the largest leaderboard model because the game must remain responsive and usable without a GPU server. The first task-specific evaluation now records factual failures, so this candidate is not selected for the production coach; no comparison establishes it as the “best” available model. See [the preserved baseline and stricter-prompt results](LOCAL-MODEL-EVALUATION.md).

Verified from the publisher's resources on November 15, 2026:

- [Official model card](https://huggingface.co/Qwen/Qwen3-1.7B): 1.7 billion parameters; Apache-2.0 license; supports explicitly disabling thinking. Keep its full context capacity separate from the much smaller context we would allocate.
- [Model license](https://huggingface.co/Qwen/Qwen3-1.7B/blob/main/LICENSE): Apache License 2.0, requiring the appropriate notices when redistributing weights/derivatives.
- [Official GGUF repository](https://huggingface.co/Qwen/Qwen3-1.7B-GGUF/tree/90862c4b9d2787eaed51d12237eafdfe7c5f6077): at the inspected revision, the listed weight file is **Qwen3-1.7B-Q8_0.gguf**, **1,834,426,016 bytes** (about 1.83 GB decimal / 1.71 GiB), SHA-256 **061b54daade076b5d3362dac252678d17da8c68f07560be70818cace6590cb1a**. This is metadata verification, not a completed download or runtime checksum check.
- A **Q4_K_M** derivative is a possible smaller-pack experiment, estimated around **1.0–1.3 GB** depending on the quantization recipe; that size is not verified. The inspected official GGUF repository did not list a Q4 file. Build or obtain a reviewed quantization with its own immutable revision, hash and notices rather than copying an arbitrary model URL.
- [llama.cpp](https://github.com/ggml-org/llama.cpp): MIT-licensed runtime with CPU execution, Apple Metal acceleration and Vulkan support; [server documentation](https://github.com/ggml-org/llama.cpp/blob/master/tools/server/README.md) exposes a local API, authentication and bounded inference options.

**Memory estimate:** budget roughly **3–4 GiB additional process/unified memory** for the Q8 baseline with a deliberately short 2,048-token context; investigate **2–3 GiB** for a smaller reviewed quantization. These are planning estimates, not measured requirements. KV cache, backend allocations, thread count and the running game change actual usage. An 8 GB machine may be better served entirely by the built-in guide; do not silently load a model and create swap pressure.

**A cloud-only experiment has now downloaded and hash-verified the official Q8 model and llama.cpp CPU runtime, and run real local inference.** [Actual evaluation](LOCAL-MODEL-EVALUATION.md) records 11 baseline cases plus six strict repeats, 2.26–2.36 GiB sampled peak server RSS, and factual failures despite valid JSON. The model is **not integrated into the native game or approved for shipment**; the ordinary-laptop release remains complete without it.

## Local inference contract

- The built-in guide returns immediately and always works offline. A user can explicitly enable an optional model pack; downloads happen only on request, with size, license and checksum visible. No Gemini API key or cloud inference is needed.
- Pin and package a tested llama.cpp build for each supported OS/architecture. Start the process only when needed, bind exclusively to loopback, and use a per-session authorization token. Do not expose a public LAN endpoint or enable filesystem/shell/MCP tools.
- Use CPU by default on ordinary Windows/Linux hardware, tested Metal on supported Apple Silicon, and tested Vulkan as an optional acceleration path. Keep a CPU fallback. Do not guess that enabling GPU offload improves the game: graphics and inference compete for GPU/unified memory.
- Inference belongs on a paused explanation/result screen, not the simulation thread. Cancel on navigation. Unload after idle where appropriate. A 12-second full-response deadline is an acceptance target, not measured speed; retain the built-in explanation while work is pending and after any failure.
- Send only fixed concept IDs, a bounded selection of local source facts and numerical values computed by the deterministic model. Use 2,048-token maximum context and about 160 generated tokens initially. Configure the model's non-thinking template explicitly; verify actual generated output rather than assuming a `/no_think` string alone is enough.
- Accept only a bounded explanation/question structure. Source identifiers come from the application, never arbitrary model-generated URLs. Reject extra numbers/units that were not supplied, fabricated NASA claims, medical predictions, insults and irrelevant instructions. Schema validation is not scientific validation: use a reviewed evaluation set and a fallback, not a claim of zero hallucinations.
- The model cannot change equations, elapsed time, score, mission settings, stored progress or medical interpretations. It does not infer mastery, emotion or intelligence from a child. No personal details, microphone or unrestricted chat are required.
- Label output as an optional locally generated explanation. If the model is missing, too slow or wrong-format, show “Built-in guide”; never disguise authored text as neural generation.

Evaluation before recommending a pack: held-out prompts across all eight concepts, unit-confusion cases, same-final-dose scenarios, contradictory input, adversarial requests, reading-level review, latency/memory with the game active, and offline cold-start on each claimed platform. Have educators/science reviewers assess factual faithfulness and age-appropriate explanations. A neural model's benchmark score does not establish learning benefit for this game.

## Delivery gates

| Milestone                               | Concrete acceptance                                                                                                                              | Not implied                                                                   |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------- |
| A. Offline foundation and visual polish | Start, learn, complete, replay and review progress with network unavailable; screenshot comparisons at desktop/portrait; unchanged model outputs | A new native release or target-device performance                             |
| B. Hero asset and motion                | Reviewed GLB character/panel, contact animation, visible dust changes and art-profile fallback; licenses recorded                                | Photorealism or pixel-identical image reconstruction                          |
| C. Measured quality tiers               | Auto plus persistent manual override; repeatable frame/memory measurements on named devices; missing-pack and unsupported-backend fallback       | “Runs on every device,” automatic model download, or certified mobile support |
| D. Optional local model                 | Verified package, bounded loopback runtime, passing factual/latency tests, complete fallback                                                     | Proven adaptive tutoring or no hallucinations                                 |
| E. Release                              | Exact installer bytes tested; saves/update/rollback checked; signed manifests and required platform checks                                       | Guaranteed macOS/Windows trust without platform signing                       |

Existing Gemini and Cloudflare companion features can remain optional demonstrations. NASA's bundled reference and sources must stay usable offline, while any cached image clearly retains its retrieval age. OpenSpace reference files can be bundled with their license. The local TimescaleDB demonstration is not a dependency for a child's game; the bounded local journal is sufficient for this mission.

## Packaging and unavoidable platform boundaries

Desktop, browser, Android and iOS need separate export and physical-device acceptance. A desktop CPU/Metal/Vulkan model backend is not automatically usable in a browser or mobile sandbox. Begin mobile with the complete baseline scene and built-in coach; evaluate native inference separately with memory, battery, thermal and suspension/resume checks. Do not ship desktop executables inside a purported mobile model pack. Browser caches and mobile storage can be evicted, so an installed/offline claim must be tested in that platform's actual storage model.

The current repository has Android build scaffolding and earlier browser export work; this roadmap does not establish a production Android/iOS release or a universally working PWA. A quality flag adapts presentation within a supported build—it cannot remove operating-system distribution rules or add a missing export pipeline.

A change to Godot/runtime/native inference binaries is a new installer, not merely a compatible content-pack update. Art and model packs should have separate signed manifests, verified file hashes, minimum compatible game/runtime versions and OS/architecture constraints; check free disk before staging, resume bounded downloads where supported, and activate only after verification. Interrupted or corrupt optional downloads must not prevent game startup; optional packs must be removable without touching saves. Preserve user saves, retain a working previous build, and keep release notes consistent with shipped bytes.

Godot's [macOS export documentation](https://github.com/godotengine/godot-docs/blob/master/tutorials/export/exporting_for_macos.rst) explicitly notes Gatekeeper restrictions for unsigned/unnotarized downloads. Open-source engines and local models do not remove those restrictions. For a smooth general-public macOS installation, plan appropriate signing/notarization and any embedded executable signing; do not call a quarantine-removal command a seamless distribution solution. Windows signing/reputation and Android package-signing/update rules need their own acceptance checks. Native iOS distribution remains subject to Apple's platform rules; an offline desktop game does not establish an App-Store-free universal native mobile path.

## What this review establishes

The architecture and candidate resources were inspected, the Qwen license/file metadata were verified from publisher sources, and the runtime/backend documentation was reviewed. The separate [local-model evaluation](LOCAL-MODEL-EVALUATION.md) now verifies a downloaded CPU runtime and real cloud-local inference; it also records teaching failures that block shipping the model. The current milestone adds source-level graphics/connection controls and an offline coach. These facts do not validate neural teaching, benchmark the user’s devices, replace the current renderer, install optional player packs, or publish a new release. Remaining implementation and acceptance milestones stay explicit above.
