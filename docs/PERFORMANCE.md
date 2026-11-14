# Geometry performance work

This is a geometry-cost audit, not a claim of frame rate on Mac, Windows, phones, or tablets. No physical Apple M5 device was available for this measurement.

## Measured reduction

Godot 4.6.3 Compatibility, main scene with the same default artwork, headless inventory on the cloud runner:

| Metric | Before | After | Reduction |
| --- | ---: | ---: | ---: |
| Retained triangles, including every MultiMesh instance | 786,438 | 521,542 | 33.7% |
| Visible geometry eligible to cast shadows | 686,276 | 242,476 | 64.7% |
| Unique mesh channel bytes | 23,124,632 | 15,944,904 | 31.0% |
| Retained mesh instances | 280 | 293 | — |

Mesh channel bytes estimate uncompressed vertices, normals, indices and other mesh arrays. They do **not** represent application RAM, GPU allocation, textures, or download size. Retained triangle counts include hidden equipment; shadow eligibility does not count repeated light passes. Splitting small rocks from boulders and separating shadow modes increases mesh batches slightly while reducing triangle and shadow work substantially.

Changes preserve the habitat layout, collision bodies, boulder topology, material palette, motif placement, and random stone positions:

- Tiny decorative pebbles use 24 triangles instead of the 154-triangle boulder mesh and do not cast shadows. Boulders retain their existing geometry and shadows.
- Millimetre-scale ornamental tubes use four sides; wave and blossom curves use fewer samples while retaining their patterns. Decorative strokes default to no shadow casting.
- Exterior and interior material batches preserve each source's shadow mode. Previously, merging geometry could turn shadows back on for intentionally excluded ornaments.
- Distant ridge vertices are indexed before generating normals, preserving sampled terrain positions and triangles with smaller mesh arrays and shared, smooth normals.

## Reproduce

From the repository root:

```sh
godot --headless --path game --script res://tests/profile_scene.gd -- --output /tmp/komaku-scene-profile.json
godot --headless --path game --script res://tests/render_budget_test.gd
```

The profiler loads the real main scene, inventories each retained mesh/material and MultiMesh population, then reports conservative AABB/frustum candidates for fixed title, interior, and player-start cameras. Candidate counts do not model occlusion or actual shadow passes. Run without `--headless` on a real graphical display to also record Godot's rendered primitive/draw-call monitors; software-rendered cloud timings must not be advertised as player-device performance.

The regression test checks that both batching implementations preserve all four shadow modes and all input faces, and that pebble/boulder populations keep their intended shadow behavior. Existing interior/exterior/world tests cover inspection anchors and collision geometry.

## Remaining verification

Measure actual frame times, peak memory, thermal behavior and interaction latency on physical target devices at a fixed resolution before publishing device performance claims. Use the same camera, renderer, viewport size, scene state and build for before/after comparisons. Remaining large costs include the habitat/interior shells, transparent surfaces, shadow passes and procedural scene construction. Do not remove collision or learning cues to meet a rendering budget.
