# Engine decision

## Chosen: Godot 4.6.3 with typed GDScript

The owner clarified that Red Veil is a first-person astronaut adventure, not an outpost dashboard. Godot supplies a coherent game runtime: character movement, collision, cameras, scene composition, input, UI, audio, and native exports. The compatibility renderer is the baseline to reach modest devices. Typed GDScript keeps iteration quick; native C++ extensions are reserved for a measured bottleneck, not introduced speculatively.

| Candidate           | Relevant strength                                               | Decision for this game                                                  |
| ------------------- | --------------------------------------------------------------- | ----------------------------------------------------------------------- |
| Godot               | Open-source MIT engine; editable scenes; native and Web exports | Primary game runtime                                                    |
| Tauri               | Small system-webview desktop shell; Rust integration            | Not the primary runtime for the requested immersive game                |
| Three.js            | Lightweight, flexible web 3D renderer                           | Retained in the earlier web simulation prototype                        |
| Unity               | Mature tooling and asset ecosystem                              | Additional licensing/runtime complexity; not needed for this scope      |
| Unreal Engine       | Advanced high-end rendering and production tools                | Heavier baseline than this small cross-device learning game needs       |
| Custom C/C++ engine | Maximum low-level control                                       | Would require building systems that an existing engine already provides |

This is a scoped engineering choice, not a claim that Godot is universally fastest or smallest. The exported engine increases download size versus the web dashboard. Physical-device memory, battery use, frame pacing, and thermal behavior still need measurement. Architecture supports replacing art; replacing the engine remains a substantial engineering task.

## Open-source foundations inspected

- [Godot engine](https://github.com/godotengine/godot), official 4.6.3 binaries and SHA-512-verified export templates.
- [Godot demo projects](https://github.com/godotengine/godot-demo-projects), maintained reference collection for engine patterns.
- [Kenney 3D Platformer Starter Kit](https://github.com/KenneyNL/Starter-Kit-3D-Platformer), inspected at commit `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0`. Camera-relative movement informed the controller; selected CC0 sound effects and the separately OFL-licensed font are bundled.

No unrelated project source or user brief was sent to these repositories. Public source and assets were downloaded for local inspection. See `CREDITS.md` for redistribution notices.

## Language responsibilities and the Tauri question

More languages do not by themselves make a game robust. Cross-language boundaries add packaging, ABI, memory ownership, debugging, and platform testing work. Each addition needs a measured benefit.

| Technology     | Current use or decision                                                                                                                                 | Evidence needed to expand it                                                                                                  |
| -------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------- |
| C++            | Godot's native engine provides rendering, physics, scene management, audio and platform exports. This repository does not maintain a custom C++ engine. | Profile a specific bottleneck before writing a GDExtension.                                                                   |
| Typed GDScript | Mission simulation, input routing, presentation adapters and the local tutor.                                                                           | Replace a hot path only after profiling, preserving the tested contract.                                                      |
| Python         | Verified engine installation, cross-platform build orchestration, release signing and security test fixtures.                                           | Future offline learner-model fitting can use evaluated research tools; do not ship a Python runtime just for a few equations. |
| Rust           | No production Rust module yet. A possible native service or GDExtension for a demonstrated workload.                                                    | Benchmarks, binding/ABI support, licenses, all target exports and maintenance cost.                                           |
| C#             | Not currently needed. Adding the .NET runtime would change distribution and platform support.                                                           | A concrete library or team tooling requirement.                                                                               |
| C              | No custom C module. Engine dependencies already use native code where appropriate.                                                                      | A necessary native API/library with reviewed ownership and platform support.                                                  |
| JavaScript     | Earlier Vite/Three.js model prototype and its browser tests.                                                                                            | Remains a reference testbed, not an additional required runtime for native play.                                              |

[Tauri's documented architecture](https://v2.tauri.app/concept/architecture/) combines a Rust core with operating-system webviews. It can be an excellent desktop application shell. It does not supply a 3D game engine, character physics, spatial audio, scene editing, or asset pipelines. A Tauri/Three.js alternative would need those systems built or integrated separately; embedding the native Godot game as a sidecar adds a second lifecycle and distribution boundary. Neither is automatically more efficient on the target hardware. Keep Godot as the primary runtime until a measured requirement justifies that cost. A separate Tauri companion/launcher is an option, not an implemented feature or a requirement for safe updates.

The offline tutor currently uses transparent Bayesian equations and scheduling rules. It runs without a GPU, LLM, cloud service, or trained model. See [learning design](LEARNING-DESIGN.md) for research, assumptions, privacy, and planned evaluation. Realistic equations and a real engine do not establish that every futuristic design is engineering-validated.
