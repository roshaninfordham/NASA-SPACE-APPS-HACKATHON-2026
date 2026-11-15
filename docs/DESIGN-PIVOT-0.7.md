# 0.7 landscape direction: quiet Martian dunes

The exterior now frames the control-room window with broad sand curves and a muted distant horizon. The aim is clear space around the outpost and readable mission landmarks, with the warmth of the new visual references. This is original procedural geometry; no artwork, meshes or textures were copied from Journey or another game.

## Landscape and light

- Three continuous, smooth dune/mountain belts replace the jagged, noisy ridge silhouettes. Indexed vertex buffers share vertices across each belt; the belts contain 11,520 triangles altogether.
- The default foreground pebble field is removed. Five sparse rocks remain authored outside the 48 m clear core for optional EVA exploration. Released 0.7 constructs and hides them; the 0.7.1 candidate defers their construction while the default window presentation excludes them, so the outside view contains terrain and the stranded astronaut. Future art variants can still configure rock populations through the landscape exports.
- Sand uses closely related mineral tones, subtle grain and gentle normal variation. `grain_strength` in the shared regolith shader controls detail without adding another material implementation.
- A neutral warm ambient fill and restrained direct light replace the stronger pink/yellow contrast. Warm haze separates distant landforms. The weather adapter still dims the sun and increases haze during the simulated storm.
- The service approach, lanterns and mission equipment remain authored for optional EVA, with their coordinates and the authoritative flat floor preserved. In released 0.7, default window mode hides this infrastructure and disables its collision and processing. The 0.7.1 candidate defers excluded infrastructure until requested; an explicit EVA switch constructs any missing assets and restores their authored state. Background dunes begin at 72 m radius; the gameplay perimeter prevents walking into these presentation-only slopes. They are not a newly implemented traversable terrain system.

The palette and atmosphere are art direction, not calibrated Mars colorimetry or a weather/irradiance model. The landscape remains a dry mineral environment; it does not add Earth vegetation, oceans or a breathable atmosphere. Gameplay radiation, pressure, power and suit models do not read these visual colors.

## Shared, reversible window presentation

The default art resource sets `start_in_window_presentation = true`. `window_hidden_categories` centralizes the categories hidden in this view: `habitat`, `refuge`, `solar_array`, `power_control`, `route`, `rocks`, and `wayfinding`. Terrain, the dedicated interior and the stranded astronaut remain available. The interior receives the same mode change to select its enclosed operator room.

`world.set_window_presentation(true)` hides already-constructed selected category subtrees, including lights, pauses their processing and disables their physical layers, masks, pickability and shapes. In the 0.7.1 candidate, excluded categories can remain unconstructed at startup. `world.set_window_presentation(false)` constructs missing optional content and restores the original state of existing content, including meshes that were intentionally hidden before the switch and shapes that were already disabled. Changing the category list and calling the same method applies a future visual pivot without deleting the optional EVA assets. Repeated calls and rapid toggles are covered by `window_presentation_test.gd`.

The visibility API does not move the astronaut or modify radiation, power, shelter or rescue equations. The game controller separately handles indoor/EVA player movement and the continuous companion rescue sequence.

## 0.7.1 candidate: defer hidden construction

The current patch candidate preserves the released window composition and the shared category flags. It changes when optional geometry is constructed: the exterior habitat, refuge, solar equipment, route and rocks wait until a caller requests the full presentation. The interior similarly builds the operator enclosure first and defers its legacy EVA room. Categories excluded by the configuration can be left unconstructed; visible terrain and Mira remain available from startup.

Opening **Habitat Field Notes** requests the exterior before resolving its inspection anchors, so the optional architecture lesson remains usable. Closing it restores the previous window presentation and exact camera/projection state. Entering outdoor EVA requests the full outpost. Once constructed, optional content is retained and reused; returning to window mode hides it rather than claiming to unload or reclaim all of its memory. First use of an optional activity can therefore incur construction work that startup no longer performs.

[Window-startup performance methodology](WINDOW-STARTUP-PERFORMANCE.md) will record final candidate measurements. No startup-time or process-memory improvement is quantified here before that measurement completes. Deferred construction, reduced retained mesh arrays and lower RSS are different claims and require different evidence.

## Historical released-0.7 geometry evidence and limits

For released **0.7.0-alpha.1**, the fully constructed landscape subtree changed from **109,710 to 21,388 retained triangles** compared with the earlier optimized, pre-pivot artwork. The [landscape-only inventory](evidence/performance-dunes-0.7.json) preserves the source counts. That historical retained inventory includes optional route/lantern/rock assets even when released-0.7 window mode hides them: 11,520 dune triangles and 770 distant-rock triangles remain. Summed mesh-channel arrays change from 1,999,200 to 1,001,616 bytes; those numbers are not process RAM, GPU memory, download size, or FPS measurements.

These landscape-only counts describe released 0.7 construction, not the 0.7.1 candidate’s deferred default startup or the whole game’s rendering cost. The earlier captures and primitive counts in [PERFORMANCE.md](PERFORMANCE.md) and `docs/evidence/performance/` remain **historical pre-pivot evidence**. The [0.7 gallery](MEDIA.md) records the released window view; screenshots alone do not establish GPU cost. Neither hiding retained assets nor counting CPU mesh arrays is an application-RAM or frame-rate measurement.

The former headless stone-transform digest was invalid: Godot's dummy renderer returned identity transforms for MultiMesh readback. That historical claim has been corrected. Current placement tests inspect the actual CPU transforms supplied to instancing, rather than relying on unsupported headless GPU readback.

## Verification

`game/tests/render_budget_test.gd` checks indexed dune meshes, the clear core, the clear forward-window rock corridor, shadow behavior, a 12,000-triangle dune budget and a 2,000-triangle sparse-rock budget. Batching regression fixtures continue to check that every shadow mode and input face survives merging. Existing design-world tests verify continuous capsule routes through the outpost and to mission equipment. The patch adds checks for deferred category construction, repeated optional-mode access and Field Notes restoration; measured startup results belong to the separate performance record.
