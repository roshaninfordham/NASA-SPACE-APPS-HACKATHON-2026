# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> visual direction

**Working art brief — November 14, 2026.** The current product name is **<!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->**, provided at runtime by `game/data/brand.json` and `game/scripts/branding.gd`. Earlier release captures retain their historical Red Veil names and provenance. Translate the supplied direction into original, replaceable game assets: an ivory organic habitat with ruby recesses and coral rims, curved cyan glass interfaces, a helmet-visible hologram, and cinematic warm Mars light. The values below are proposed production targets, not measurements or a pixel-match claim for the reference images.

The player remains the first-person junior astronaut, ages 7–12. The [core brief](CORE-BRIEF.md) still governs habitat/suit/visor trade-offs, a separate particle event, passive refuge shielding and the compressed teaching mission. A visual pivot must not silently change these rules.

## Shape, material and light

| Layer                          | Direction                                                                                                                     | Proposed starting treatment                                                                                                         |
| ------------------------------ | ----------------------------------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Habitat silhouette             | Broad, smooth, asymmetrical ivory shell; layered lips and a readable entrance; supported mass rather than floating primitives | Warm ivory `#F1E6D2`, broad curved highlights, restrained panel seams; retain visible curvature without large clipped-white patches |
| Recesses and structure         | Deep ruby cavities create depth beneath the pale shell; interior framing remains legible                                      | Ruby `#4B1C2A`, dark warm shadow `#261C24`; rougher than glass, with selective metallic details                                     |
| Edge and route light           | Coral traces the shell lip and useful approaches; light guides attention                                                      | Coral `#FF785F`; thin emissive geometry plus a small number of actual lights, not dependence on unsupported bloom                   |
| Interface and instrument glass | Cyan outlines and a subtle tint; clear central world view; readable labels on controlled dark backing                         | Cyan `#91E7E7`, restrained transparency; avoid stacks of overlapping full-screen transparent surfaces                               |
| Terrain and distance           | Warm ochre near the player, softer rust silhouettes and atmospheric separation farther away                                   | Ground `#A9573C`, distant rust `#855047`; authored large forms, sparse fine detail and a clear walkable route                       |
| Lighting                       | Low warm key light, cooler restrained fill, contact shadows beneath the shell and equipment                                   | Start near the existing low-angle sun; keep faces, doorways and essential readings visible during both clear and dusty states       |

These colors are editable swatches, not fixed brand rules. Review the palette at normal exposure and with emission reduced. The silhouette must still read in grayscale; coral and cyan cannot be the only way to distinguish safety, interaction or warning states.

## Latest ornament layer

The newest reference adds gold overlapping wave arcs (seigaiha), gold blossom-branch inlays, amber lanterns inside crimson geometric lattices, bonsai/sakura accents, wave-pattern chair upholstery and a luminous lattice desk pedestal. This is the current leading ornament direction. Keep those surfaces as separate interchangeable ornament/material resources on the existing shell, furniture and lighting slots. Use original or appropriately licensed patterns, and record attribution.

Apply detail in tiers: a readable wave/inlay texture or a few instanced curves at distance; selective close-range geometric lattice at the focal console; restrained emissive lantern cores with a small bounded light count. Document triangle counts, draw calls and transparency before increasing density. Optional bonsai/blossoms should be removable by a quality preset and must not narrow playable routes. UI may echo a small gold wave ornament in unused corner space; no pattern behind text, telemetry or button labels. Cultural ornament is an art layer, not evidence for scientific capability.

## First-person interface

Use a quiet system sans-serif family and generous spacing. The title sits at the upper left over the world. A small lower-left translucent mission card offers **Begin mission**, **Explore the habitat**, guide, academy, updates and sound controls. The center remains open for the habitat and hologram. Exploration is a distinct untimed review mode only when its gameplay implementation exists; its button alone does not establish that mode.

During play, use thin corner panels for one objective and the separate habitat/suit/dose readings, a restrained reticle, a short interaction prompt and Mira's radio. Keep real units and labels. At 1280×720, aim to leave the central 40% of width by 45% of height unobstructed by persistent opaque UI. At a 390×844 portrait review size, use stacking/scrolling rather than shrinking essential controls beyond readability. Essential text should remain at least 16 actual capture pixels and primary targets at least 44×44; verify the engine's canvas scaling, not only editor font numbers.

A curved glass impression can come from shaped borders, shallow geometry and restrained highlights. Keep text on a readable plane. Provide a simple compatibility-renderer fallback before adding refraction or expensive screen effects. Motion, shimmer and glow should explain a state, and a reduced-motion/low-effect route must remain possible.

## Rescue crewmate

The third reference establishes the **astronaut to be rescued**, not a third-person player camera: a young girl with dark braided curls, freckles, a clear bubble helmet with pink/cyan reflections, and an ivory textile suit. Use a crimson segmented collar/harness, a round chest unit, slim pale backpack with red rails, articulated knees/elbows, gloves and substantial boots. Cherry blossom, crane and gold-wave motifs are a Japanese-inspired art direction; create or license original patterns and credit them.

Treat this as a character-art target. The existing companion slot is replaceable; a procedural figure is still a placeholder, and a photoreal face needs a suitable authored model/material/rig. Keep face visibility, an understandable silhouette and non-frightening distress cues for the audience. The rescue role requires its own implemented interaction and success/failure checks before it can be described as playable.

Do not import the concept's “Age 12+”, attenuation, self-cleaning, −80 to 20 temperature, or “12+h life” annotations as established product specifications. They neither change the 7–12 audience nor prove suit performance. Suit telemetry must come from implemented state and explicit assumptions.

## Scientific boundary

| Reference-like visual                           | Grounded interpretation in playable Mars                                                                                                                           |
| ----------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Transparent protective dome or glowing field    | An optional labeled visor/engineering visualization. It does not provide shielding, spend power to sustain protection, or replace the preinstalled passive refuge. |
| Floating hologram                               | A helmet-rendered AEGIS overlay or clearly identified display, with a noninteractive presentation contract. Do not imply unsupported free-air projection physics.  |
| Huge moon or neighboring planet filling the sky | Keep it out of a literal Mars sky unless its scale/orbit is sourced. Such imagery may belong in a clearly labeled concept or training projection.                  |
| Dense decorative readings and charts            | Use non-numeric patterns for decoration. Energy, dose, time and progress numbers bind to real mission state; no invented scientific telemetry for visual density.  |
| Radiant dust and suit glow                      | Light and presentation cues. Dust cleaning changes surface dust/visibility; it does not remove energetic particles or make radiation visible to the eye.           |

## Modular implementation contract

- **Geometry:** use existing `habitat_scene`, `refuge_scene`, `solar_array_scene`, `companion_scene`, `scanner_scene` and `landscape_scene` slots. Deliver local origins, meters/Y-up, named material slots and licensed source files. Preserve current collision/interaction volumes unless a deliberate gameplay change is reviewed.
- **Materials:** separate shell, recess, rim, glass and terrain resources. Reuse surfaces and textures. The art profile owns appearance; no energy, shielding, age or mission threshold belongs in a material or mesh generator.
- **HUD:** a `Control` scene preserves the unique nodes in [design handoff](DESIGN-HANDOFF.md). Presentation may expose an optional `Explore` button; the controller owns its behavior. No new global script class is needed for a HUD swap.
- **Light and atmosphere:** keep key/fill/fog/emission choices grouped and adjustable. Weather presentation reads detached mission state. A brighter screenshot cannot alter solar-generation equations.
- **Animation and hologram:** consume `apply_mission_visuals(snapshot)` or a similarly explicit presentation input. Decorative geometry has no collision or mission authority. New runtime/global-class assumptions require updater compatibility review.

## Current-stage acceptance

1. Capture an exterior title view at the agreed camera `(15, 5, 5)` looking toward `(0, 3, -16)`, and a first-person interior exploration view from the agreed spawn near `(-3, 0.2, -11)`. Record actual camera/FOV, version, viewport and mission state; these are proposed repeatable review views, not reference-image measurements.
2. In both views, the ivory silhouette, ruby depth, coral rim and cyan glass read as distinct layers. The title/menu leaves the central habitat/hologram visible. Capture a 1280×720 landscape and a 390×844 portrait layout with all controls reachable.
3. The new HUD resolves every required unique node, remains readable, exposes the separate energy stores, and preserves guide, academy, sound and update actions. Explore and rescue behavior are accepted separately from their visual affordances.
4. Walk through the doorway and all existing interactions; rerun numerical/gameplay/art-contract checks. No decorative shell or glass panel may block a valid route or change the refuge boundary silently.
5. Record frame time, draw calls, transparency and memory on an agreed device before increasing effects. Compatibility rendering and provisional cloud captures are not proof of final Mac/mobile performance or photoreal quality.

This pass can establish a coherent playable visual slice. It does not complete final character production, reference-image fidelity, scientific engineering validation, accessibility, or the whole game. Keep authentic before/after captures and list remaining differences for the next design review.
