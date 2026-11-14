# Geometry performance work

> Historical pre-0.7 design-pivot measurements. These screenshots and counts describe the earlier dense landscape; see [the 0.7 landscape pivot](DESIGN-PIVOT-0.7.md) for the new dune direction. They are not current whole-game benchmarks. The new default window mode also hides optional EVA assets that remain in retained inventories; prior captures cannot establish its final GPU cost or application RAM usage.

This is a geometry-cost audit, not a claim of frame rate on Mac, Windows, phones, or tablets. No physical Apple M5 device was available for this measurement.

## Measured reduction

Godot 4.6.3 Compatibility, main scene with the same default artwork, headless inventory on the cloud runner:

| Metric                                                 |     Before |      After | Reduction |
| ------------------------------------------------------ | ---------: | ---------: | --------: |
| Retained triangles, including every MultiMesh instance |    786,438 |    521,542 |     33.7% |
| Visible geometry eligible to cast shadows              |    686,276 |    242,476 |     64.7% |
| Unique mesh channel bytes                              | 23,124,632 | 15,944,904 |     31.0% |
| Retained mesh instances                                |        280 |        293 |         — |

Mesh channel bytes estimate uncompressed vertices, normals, indices and other mesh arrays. They do **not** represent application RAM, GPU allocation, textures, or download size. Retained triangle counts include hidden equipment; shadow eligibility does not count repeated light passes. Splitting small rocks from boulders and separating shadow modes increases mesh batches slightly while reducing triangle and shadow work substantially.

The pre-pivot changes retained the habitat layout, collision bodies, boulder topology, material palette and motif placement. Exact stone placement was not established by the invalid headless digest discussed below:

- Tiny decorative pebbles use 24 triangles instead of the 154-triangle boulder mesh and do not cast shadows. Boulders retain their existing geometry and shadows.
- Millimetre-scale ornamental tubes use four sides; wave and blossom curves use fewer samples while retaining their patterns. Decorative strokes default to no shadow casting.
- Exterior and interior material batches preserve each source's shadow mode. Previously, merging geometry could turn shadows back on for intentionally excluded ornaments.
- Distant ridge vertices are indexed before generating normals, preserving sampled terrain positions and triangles with smaller mesh arrays and shared, smooth normals.

## Actual rendered comparison

The repaired 0.6.1-alpha.1 world and optimized world were rendered on the same Godot 4.6.3 / Mesa llvmpipe software renderer at **960 × 540**, with identical camera positions, field of view, lighting and default mission state. These captures use the real standalone world; menus, player equipment and updater UI are excluded, and node animation/dust are frozen for comparison. They are not concept images.

| Fixed view               | Rendered primitives before → after | Reduction | Draw calls before → after |
| ------------------------ | ---------------------------------: | --------: | ------------------------: |
| Title overview           |              3,266,658 → 1,255,270 |     61.6% |                 624 → 582 |
| Mission-control interior |              3,271,112 → 1,264,484 |     61.3% |                 358 → 327 |

Rendered primitives include repeated shadow-pass work, so they exceed the retained mesh inventory above. In the overview, shadow primitives fell from 2,530,854 to 783,162. This is evidence of reduced rendering work, **not** evidence of a particular frame rate or proportional speedup. The Compatibility backend reports zero in its separate shadow draw-call counter despite rendering shadow primitives; the table uses the total draw-call monitor.

| Actual view       | Before                                                          | After                                                           |
| ----------------- | --------------------------------------------------------------- | --------------------------------------------------------------- |
| Exterior overview | [Baseline screenshot](evidence/performance/before/title.png)    | [Optimized screenshot](evidence/performance/after/title.png)    |
| Interior          | [Baseline screenshot](evidence/performance/before/interior.png) | [Optimized screenshot](evidence/performance/after/interior.png) |

Both image pairs were inspected: the dome outline, entry, lantern positions, consoles, hologram, chairs and major shadows remain. Fine pebble silhouettes and ornamental shadows change intentionally. This is a check of two representative views, not proof of identical pixels or full visual acceptance on every device.

The earlier stone-placement digest is **invalid as position-verification evidence**: the headless dummy renderer returned identity transforms for MultiMesh readback. Both versions retained 1,500 stones, but that digest cannot establish identical placement. Rendered image/counter evidence and CPU mesh-array inventories do not rely on that readback and remain valid. The [comparison record](evidence/performance/comparison.json) includes camera settings, source-file/image hashes, scope, and renderer limitations. Per-version `profile.json` files contain rendered-world inventories; `main-profile.json` files reproduce the full-scene table above. Logs and the stone-placement verification script are preserved alongside them.

## Reproduce

From the repository root:

```sh
godot --headless --path game --script res://tests/profile_scene.gd -- --output /tmp/komaku-scene-profile.json
godot --headless --path game --script res://tests/render_budget_test.gd
# Requires a graphical display; writes actual rendered images and JSON.
godot --path game --script res://tests/profile_scene.gd --fixed-fps 60 -- --world-only --views title,interior --width 960 --height 540 --capture-dir /tmp/komaku-render --output /tmp/komaku-render-profile.json
# Inspect current stone transforms on a graphical display (headless readback is unsupported).
godot --path game --script ../docs/evidence/performance/stone-placement.gd -- /tmp/komaku-stone-placement.json
```

`--fixed-fps 60` fixes simulation stepping for repeatability; it does not measure or assert 60 FPS. For baseline comparisons, run the same profiler script against the baseline checkout using an absolute `--script` path and identical options.

The default profiler loads the real main scene, inventories each retained mesh/material and MultiMesh population, and, on a graphical renderer, reports conservative AABB/frustum candidates for fixed title, interior, and player-start cameras. Headless runs omit these candidates because dummy-renderer MultiMesh bounds are unsupported. Candidate counts do not model occlusion or actual shadow passes. Run without `--headless` on a real graphical display to also record Godot's rendered primitive/draw-call monitors; software-rendered cloud timings must not be advertised as player-device performance.

At capture time, the regression test checked that both batching implementations preserved all four shadow modes and all input faces, and that the then-default populated stone field stayed below 70,000 triangles (59,140). The current test instead checks the dune and sparse-rock budgets documented in DESIGN-PIVOT-0.7.md. The historical render-budget, interior-spec, exterior-spec and design-world runs passed, including continuous capsule routes through the habitat and to mission equipment; their archived logs are in the evidence directory.

## Remaining verification

Measure actual frame times, peak memory, thermal behavior and interaction latency on physical target devices at a fixed resolution before publishing device performance claims. Use the same camera, renderer, viewport size, scene state and build for before/after comparisons. Remaining large costs include the habitat/interior shells, transparent surfaces, shadow passes and procedural scene construction. Do not remove collision or learning cues to meet a rendering budget.
