# Habitat and refuge — implementation brief

Part of **<!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->**. Derived from the [preserved exterior specification](source/02_Exterior_Habitat_Game_Spec.md); [decisions and status](../SPEC-IMPLEMENTATION.md) override conflicting source requirements.

## Composition to build

The exterior should read as a flowing, asymmetric cluster of pearl shells and crimson ribbons. A cylindrical champagne-metal airlock sits toward the left foreground; a glowing curved walkway leads to it. The main oval opening reveals the pink control-room globe, a smaller opening suggests an amber lounge, and an upper opening is screened by lattice. A cupola, antennas and dish break the silhouette. Regolith berms occupy the lower rear/right; warm lanterns guide the route.

The source's 36 × 24 × 11 m main mass, 6.2 m airlock diameter, 3.6 m path width and 2.2 m berm are dimensional references. Verify them against the current playable area before resizing the world. Three stepped shell bands should feel continuous and organic rather than a stack of simple hemispheres.

## Reusable kit

- Pearl shell sections with subtle seams; crimson ribbons with warm edge light.
- Rose-gold blossom strokes and wave arcs attached to surfaces rather than floating across openings.
- Oval frames, lattice end panels, readable native airlock text and a knot-inspired emblem.
- Lanterns at two sizes, path tiles, edge strips, rivets, railing and vent details.
- Dish/antenna module and a real enclosed refuge with a clear entrance.
- Material-batched geometry and instanced repeated details; distant views must not depend on dozens of dynamic lights.

Current scene entry points are `exterior.gd/.tscn`, `landscape.gd/.tscn`, `refuge.gd/.tscn` and shared geometry/ornament helpers. World coordinates, collision boundaries and equipment reachability are part of the gameplay contract.

## Inspect and learn

The three concept callouts become accessible learning entry points: **Habitat dome**, **Observation windows**, and **Regolith shielding**. An **Airlock** entry explains pressure isolation and dust control. Anchors should be scene-local metadata; a presentation interface projects them and shows readable explanations at different screen sizes. Interaction must work without requiring a precise one-second hover.

Teach that real habitats need pressure containment, insulation, dust control and shielding review. Windows and shutters involve engineering tradeoffs. Local regolith can provide shielding material and thermal mass; thickness is not a universal radiation-protection percentage. Do not implement the source's “+8% protection per 0.3 m” as a physical law. An inspect overlay is not a cutaway simulation or a validated habitat integrity model.

## Physical and gameplay boundaries

The current mission remains first-person with Mars gravity. The existing deterministic dust/particle-event schedule supports reproducible learning; it does not become a random multi-sol weather director merely because the art changes. Preserve the untimed review mode and short timed mission.

The source's giant crescent moons are cinematic exaggerations. Avoid presenting 3.5° and 1.2° moons as realistic Phobos/Deimos angular sizes. Dusk colors may be art-directed; label cinematic framing separately from astronomy where needed.

Do not claim a sealed pressure vessel when players can walk through an open facade. A functional airlock needs two controlled barriers, collision checks, transition state, cancellation behavior and a specified pressure model or clearly labeled simplified sequence. The source alternates between 20-second and eight-second cycles; neither is automatically accepted. Berm construction, integrity decay, a seven-sol campaign, footprint persistence and a base-upgrade tree are distinct future mechanics requiring tests and science review.

## Acceptance evidence

Capture a front-left hero frame and a normal approach along the path. Review the layered silhouette, airlock placement, window readability, lantern spacing, ornaments and berm profile. Walk every actual entrance and shelter route; check interaction reachability. Inspect overlays must remain readable in portrait and landscape. Measure native and exported Web behavior; target FPS, LOD counts, 2 km terrain and mobile frame budgets remain targets until implemented and benchmarked.
