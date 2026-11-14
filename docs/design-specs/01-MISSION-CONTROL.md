# Mission Control — implementation brief

Part of **<!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->**. Derived from the [preserved control-room specification](source/01_Mission_Control_Room_Game_Spec.md); [decisions and status](../SPEC-IMPLEMENTATION.md) override conflicting source requirements.

## Composition to build

The room's focal point is a suspended coral Mars hologram within a transparent cylinder, beneath a sign drum. Frame it with concentric pearl/crimson ceiling rings, a curved console desk, four large cyan instrument panels, nine smaller tilted displays and two pearl chairs. The front view should make the globe, sign and desk immediately readable. The left oval window frames Mars; the right side carries warm lattice panels, planted alcoves, a corridor and blossom tree.

Use the source dimensions as a reference: roughly 22 m room diameter; 5.2 m cylinder diameter; 2.6 m globe; 6 m sign drum; 7.3 m outer console radius. The existing habitat scale and walkable routes must be checked before adopting them literally. A camera near eye level with a centered globe is a review preset, not a mandatory replacement for the player's first-person camera.

## Modular scene responsibilities

- **Projection module:** globe, visible triangular/geodesic network, pale nodes, slow rotation, subtle float and glass-cylinder lines. The network visualizes data; radiation is not visible light.
- **Canopy module:** sign from shared branding, three rows of wave inlay, concentric illuminated rings, blossom motifs on crimson bands.
- **Console module:** four legible hero panels, nine tilted instrument surfaces, pearl desk, lantern/lattice supports. Decorative charts must not pretend to be live measurements.
- **Furniture and planting:** two sculpted chair shells with red wave backs; amber lattices; potted greenery, bonsai and blossom forms; clear routes between all interaction points.
- **Material module:** pearl, crimson lacquer, rose-gold, pink projection and dark teal glass. Preserve text contrast and limit repeated transparent surfaces.

The accepted current backend is `game/art/red_veil/interior.gd`, its shader/helpers and the `interior_scene` art-profile slot. The stable internal directory name is not a public product title.

## Instruments and interaction

Use “MISSION CONTROL”, “ENVIRONMENT CONTROL”, “RADIATION FORECAST” and “LIFE SUPPORT” as readable panel headings where appropriate. The room receives detached state through `apply_mission_visuals(snapshot)`; numerical rules remain in the mission model. Show measured mission quantities in their units, including power, stored energy, dust and dose. Explain unsupported source values rather than silently rendering fixed “96% / 88% / 93%” gauges as real telemetry.

The supplied “0.32 mSv/day”, “18% risk”, six-sol trend and exact Sol 042 composition are not current mission calibration. The game uses a sourced historical 0.67 mSv/day background plus an explicitly fictional event schedule. A forecast chart must identify a tutorial scenario instead of suggesting live space weather.

Optional future extensions are a seated inspection camera, accessible close-up panel view, map-node dispatch, a six-step guided room tutorial and independently simulated resources. These require interaction and model work; geometry alone does not implement them.

## Science and accessibility

A pressurized room on Mars still has Mars gravity; pressure does not produce Earth gravity. Keep 3.71 m/s² movement unless a separately explained fictional mechanism is intentionally introduced. Leave simulated oxygen, water, thermal and pressure systems outside the current core until their models and learning objectives are defined.

Provide native legible labels, keyboard/touch access, scrollable explanations and reduced-motion choices for new overlays. Avoid deliberate high-frequency flicker or compulsory chromatic aberration. Do not infer native screen-reader support from visual accessibility or browser tests.

## Acceptance evidence

Capture a centered room review frame and normal first-person gameplay. Check sign visibility, four-panel and nine-console counts, chair/console routes, scene labels against model state, and the detached visual-state boundary. Check portrait and landscape overlays separately. Record render statistics and device frame times before claiming the source's 60 fps desktop/30 fps mobile budgets. Reflections, volumetric light, cloth and exact bloom depend on renderer support and require explicit fallback review.
