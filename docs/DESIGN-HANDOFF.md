# Red Veil design-team handoff

**Reviewed November 14, 2026.** [Team status](TEAM-STATUS.md) records the exact released build. [The roadmap](ROADMAP.md) separates presentation, media, platform and validation work.

## Creative direction

The player is the astronaut, in first person. Mira is a companion character, not a camera mode. Aim for sci-fi wonder: futuristic, unconventional, warm, playful, and compelling to revisit. Young explorers should want to discover another system and try another idea. Do not use coercive rewards, advertising, purchases, or streak pressure.

The current outpost is a mechanics blockout. No silhouette, palette, material, character, icon, typography, or HUD layout is final. The design team can iterate throughout development.

## Scientific honesty and artistic freedom

Physical behavior must remain traceable to measurements, equations, explicit assumptions, or labeled speculation. Art may be extraordinary without implying false physical mechanisms. Radiation is invisible to human eyes; a dramatic radiation display belongs to a labeled sensor visualization. Visor cleaning does not create shielding. Passive shelter material does not require continuous electrical power. Martian dust does not behave like a dense terrestrial hurricane merely to make a dramatic scene.

Habitat shells, motion, lighting, audio, materials, and companion expression are creative territory. A shell whose shape claims engineering feasibility requires engineering review. A sensor overlay is not a direct view of an invisible phenomenon. Artistic originality is a design objective, not an assertion of unprecedented invention.

## Replaceable contracts

Open `game/art/default_art.tres` in Godot's Inspector. Duplicate the profile for a new art direction and assign it to the main game node. Do not copy or modify the numerical mission model to change art.

| Slot        | Local origin / convention            | Stable responsibility                                     |
| ----------- | ------------------------------------ | --------------------------------------------------------- |
| Landscape   | World origin, meters, Y up           | Existing playable floor and boundaries remain             |
| Habitat     | (0, 2.4, -16)                        | Cosmetic pressure-vessel/lab presentation                 |
| Refuge      | (-14, 0, -7), entrance toward +Z     | Existing shelter bounds and collisions remain             |
| Solar array | (16, 0, -8), approach from +Z        | Existing inspection and cleaning interaction remains      |
| Companion   | (-4, 0, 7), faces +Z                 | Cosmetic character; radio behavior lives in orchestration |
| Scanner     | Camera-local origin, camera looks -Z | Place visible hands/tool roughly 0.5–0.8 m forward        |

World replacements are `PackedScene` resources. GLB models can be imported into a `.tscn` wrapper. The wrapper may implement `apply_mission_visuals(snapshot: Dictionary)` to animate from a **detached** visual snapshot. Keys include time, storm, event state, solar output, both batteries, dose, dust fractions, inspection, shelter, cleaning, conservation, and terminal status. Do not mutate the simulation through the art adapter.

Default procedural meshes are hidden when a replacement is assigned; their collision geometry remains. Changing footprints, walkways, doorway size, equipment locations, shelter volume, or camera clearance is a gameplay change. Update the collision/interaction contract and rerun the gameplay tests; cosmetic swaps must not silently change safety outcomes.

### HUD

A `hud_scene` on the main game node replaces the generated fallback interface. Use a `Control` root and mark these nodes as unique in owner:

- `HUD`, `Menu`: Control containers
- `Objective`, `Metrics`, `Radio`, `Prompt`, `Clock`: Label nodes
- `Visor`: ColorRect overlay
- `Begin`, `Guide`, `Sound`: Button nodes
- Optional `Academy`: Button node opening the practice interface
- Optional `Updates`: Button node opening the update interface between missions

The orchestrator binds those names to existing state and actions. Keep instructions legible on a 720p landscape viewport. Controller focus, touch targets, safe areas, pause, and readable failure feedback must survive a redesign. Screen-reader support for the native canvas interface is not yet validated; do not infer it from the earlier web dashboard's accessibility checks.

### Shared appearance

The art profile provides terrain, hull, structure, instrument, route, interface text and button colors, optional interface/title fonts, scene slots, frame cap, shadows, and particle budget. An optional Godot Theme can supply additional shared control styling. The fallback HUD still contains layout constants; full layout pivots should use a custom HUD scene rather than editing mission rules.

## Asset delivery

Use meters, Y up, and explicit pivots. Prefer GLB with separate named materials, compressed textures, and reusable meshes. Start with one 1K atlas per small asset set; treat this as a budget to measure, not a permanent limit. Avoid per-frame allocation, unnecessarily unique materials, and expensive transparency layers. Keep a low-cost compatibility-renderer variant for each effect.

Every contribution must include origin, creator, exact license, attribution requirements, and whether modifications were made. Do not embed unlicensed inspiration images in the build. Blender source files can be stored separately from runtime GLB exports when size warrants it. Keep large source art out of normal Git history until a storage strategy is agreed.

## Validation for a visual pivot

Run `npm run game:test`, the gameplay integration script, and the art-contract test. Check the new asset in native and browser builds. Walk through every doorway and interaction, test the shelter boundary, and repeat a complete mission. Measure draw calls, frame times, and memory on the target Mac and a representative mobile device before calling a visual change performance-neutral.

### Academy

`academy.gd` is a separate presentation module using the same art profile and optional interface theme. Its scroll layout keeps long explanations reachable. Lesson content lives in `data/lessons.json`; learning estimates and persistence live in `learning.gd`. A visual redesign must preserve hints, explanation, keyboard focus, return to mission, save-error feedback, and confirmed local reset. Do not update knowledge estimates from animation or success effects.

### Update interface

The update client lives under the persistent `Updates` autoload so a mission reload cannot lose an in-progress download or restart prompt. `updater/panel.gd` is presentation; it accepts the shared art profile/theme. The title/debrief notification is deferred during active play. Keep verification errors, cancellation, restart consent, manual-installer fallback, and explicit interrupted-storage repair accessible when redesigning. Changes to autoloads, global script registries, or runtime layout need compatibility review and may require a new full installer. See [updates](UPDATES.md).

## Captures and review material

The inspected 0.4.0-alpha.1 [mission still](media/red-veil-0.4.0-alpha.1-mission.png), [20-second gameplay GIF](media/red-veil-0.4.0-alpha.1-gameplay.gif), [title](media/red-veil-0.4.0-alpha.1-title.png), [academy](media/red-veil-0.4.0-alpha.1-academy.png) and [question](media/red-veil-0.4.0-alpha.1-question.png) captures provide current review material. [Media provenance and reproduction](MEDIA.md) identifies the exact build and scope.

Screenshots and GIFs must come from the running software. Record the source commit or release, build target, viewport, input sequence, and any special test state. Caption the current scene as provisional where appropriate. A browser capture of an update-information screen is not evidence of native installation or restart, and a staged test notification must be labeled as such.

Use actual gameplay to show scale, navigation, equipment interaction, readability and pacing. Keep an unmodified capture or repeatable capture procedure so the team can reproduce the view. Compression, trimming and a carefully chosen viewport can make review material clearer; do not composite nonexistent controls, characters, effects or outcomes into a product screenshot. Licensed concept art belongs in a separately labeled concept section.

## Next design review

Prioritize a coherent first-person arrival, readable short instructions for ages 7–12, meaningful equipment feedback, and a clear distinction between dust, sunlight, stored energy and invisible radiation shown through instruments. Review sound with volume/mute control, captions or equivalent visual cues, and an explicit asset license. The current mission and academy are functional prototypes; new artwork does not establish expert scientific approval or learner comprehension.

Deliver changes through the existing art/theme/scene contracts first. If a design needs a new interaction, collision boundary, global class, autoload or runtime layout, agree that behavior with engineering and update its acceptance checks. A signed content pack must remain compatible with the baseline installer; otherwise use a planned full-installer transition.
