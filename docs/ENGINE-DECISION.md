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
