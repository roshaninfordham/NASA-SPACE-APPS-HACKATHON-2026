# 0.7 landscape direction: quiet Martian dunes

The exterior now frames the control-room window with broad sand curves and a muted distant horizon. The aim is clear space around the outpost and readable mission landmarks, with the warmth of the new visual references. This is original procedural geometry; no artwork, meshes or textures were copied from Journey or another game.

## Landscape and light

- Three continuous, smooth dune/mountain belts replace the jagged, noisy ridge silhouettes. Indexed vertex buffers share vertices across each belt; the belts contain 11,520 triangles altogether.
- The default foreground pebble field is removed. Five sparse rocks remain authored outside the 48 m clear core for optional EVA exploration. They are hidden in the default window presentation, so the outside view contains terrain and the stranded astronaut. Future art variants can still configure rock populations through the landscape exports.
- Sand uses closely related mineral tones, subtle grain and gentle normal variation. `grain_strength` in the shared regolith shader controls detail without adding another material implementation.
- A neutral warm ambient fill and restrained direct light replace the stronger pink/yellow contrast. Warm haze separates distant landforms. The weather adapter still dims the sun and increases haze during the simulated storm.
- The service approach, lanterns and mission equipment remain authored for optional EVA, with their coordinates and the authoritative flat floor preserved. The default window mode hides this infrastructure and disables its collision and processing; an explicit EVA switch restores its authored state. Background dunes begin at 72 m radius; the gameplay perimeter prevents walking into these presentation-only slopes. They are not a newly implemented traversable terrain system.

The palette and atmosphere are art direction, not calibrated Mars colorimetry or a weather/irradiance model. The landscape remains a dry mineral environment; it does not add Earth vegetation, oceans or a breathable atmosphere. Gameplay radiation, pressure, power and suit models do not read these visual colors.

## Shared, reversible window presentation

The default art resource sets `start_in_window_presentation = true`. `window_hidden_categories` centralizes the categories hidden in this view: `habitat`, `refuge`, `solar_array`, `power_control`, `route`, `rocks`, and `wayfinding`. Terrain, the dedicated interior and the stranded astronaut remain available. The interior receives the same mode change to select its enclosed operator room.

`world.set_window_presentation(true)` hides the selected category subtrees, including lights, pauses their processing and disables their physical layers, masks, pickability and shapes. `world.set_window_presentation(false)` restores the original state, including meshes that were intentionally hidden before the switch and shapes that were already disabled. Changing the category list and calling the same method applies a future visual pivot without deleting the optional EVA assets. Repeated calls and rapid toggles are covered by `window_presentation_test.gd`.

The visibility API does not move the astronaut or modify radiation, power, shelter or rescue equations. The game controller separately handles indoor/EVA player movement and the continuous companion rescue sequence.

## Geometry evidence and limits

The landscape subtree alone changes from **109,710 to 21,388 retained triangles** compared with the earlier optimized, pre-pivot artwork. The [landscape-only inventory](evidence/performance-dunes-0.7.json) preserves the source counts. This retained inventory includes optional route/lantern/rock assets even when window mode hides them: 11,520 dune triangles and 770 distant-rock triangles remain. Summed mesh-channel arrays change from 1,999,200 to 1,001,616 bytes; those numbers are not process RAM, GPU memory, download size, or FPS measurements.

Other agents are changing the room and habitat simultaneously, so these landscape counts must not be presented as the whole game's current rendering cost. The earlier captures and primitive counts in [PERFORMANCE.md](PERFORMANCE.md) and `docs/evidence/performance/` are explicitly **historical pre-pivot evidence**. Fresh whole-game screenshots and measurements are required for the final 0.7 layout and default window mode. Hiding retained optional assets does not establish a final GPU cost or reduce these retained CPU-array counts to an application-RAM measurement.

The former headless stone-transform digest was invalid: Godot's dummy renderer returned identity transforms for MultiMesh readback. That historical claim has been corrected. Current placement tests inspect the actual CPU transforms supplied to instancing, rather than relying on unsupported headless GPU readback.

## Verification

`game/tests/render_budget_test.gd` checks indexed dune meshes, the clear core, the clear forward-window rock corridor, shadow behavior, a 12,000-triangle dune budget and a 2,000-triangle sparse-rock budget. Batching regression fixtures continue to check that every shadow mode and input face survives merging. Existing design-world tests verify continuous capsule routes through the outpost and to mission equipment.
