# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> design-team handoff

**Reviewed November 14, 2026 for the 0.7 source candidate.** The latest user direction is an indoor, first-person operator looking through a clear panoramic window at dunes and Mira outside. The earlier ornate 0.6 specifications and the intermediate two-console redesign are historical/alternate presentation inputs. They do not override the new uncluttered forward view. [Team status](TEAM-STATUS.md) records publication evidence; [visual direction](VISUAL-DIRECTION.md) and the [implementation ledger](SPEC-IMPLEMENTATION.md) describe current source behavior and limits.

## Creative direction and first minute

The child is the first-person hero, intended for ages 7–12. Mira is the astronaut to help. Start with a clear purpose: guide her home while preserving the base’s energy. The primary title choices are **Start mission**, **Explore · no timer**, and **Learn & more**. Optional lessons, suit viewer, habitat notes, updates and sound remain reachable without competing with the first choice.

During the default mission, **Clean panels**, **Save power**, and **Guide Mira** are the three primary actions. Base energy and Mira’s suit energy are different stores; exposure belongs to Mira. Her visible journey goes to the side airlock, through a timed both-doors-closed cycle, and through the inner door before protection starts. The player stays inside a bounded part of the room. This is a deterministic teaching sequence, not a certified pressure/airlock simulation.

Keep wonder in the landscape, character and understandable consequences rather than visual density. Use warm dunes, matte pearl/navy surfaces and restrained cyan controls. Selected cultural details remain specific and optional: Japanese wave/lattice/textile references and separately identified Chinese knot inspiration. Do not claim the name is a verified translation or a motif has a scientific benefit. Avoid coercive rewards, advertising, purchases and streak pressure.

## Scientific and artistic boundaries

Physical claims must trace to measurements, equations, explicit assumptions or labelled speculation. The numerical mission still separates dust, sunlight, stored energy, visor condition and radiation. Dust cleaning is not radiation shielding; passive shielding does not consume continuous power; pressure does not create Earth gravity. Operator mode maps the existing exposed-subject model to Mira rather than silently treating the indoor player as exposed.

The planner compares fixed settings using the same game equations. In operator mode it holds Mira’s current protection fixed; it does not simulate her route or predict the time she reaches safety. The current timed rescue route and airlock cycle are additional scenario assumptions, not human-motion or gas-dynamics validation.

The [science ledger](SCIENCE.md), [readable science guide](SCIENCE-GUIDE.md) and [16-page illustrated PDF](media/KOMAKU-Science-Guide.pdf) explain the models, units, sources and omissions. Their source fingerprints must be refreshed when code behavior changes. No artwork, test suite or PDF establishes NASA endorsement, certified hardware performance or demonstrated educational efficacy.

## Replaceable contracts

Open `game/art/default_art.tres` in Godot’s Inspector. Duplicate the profile for a new direction and assign it to the main game node. Change presentation through slots/tokens; do not duplicate mission equations to change artwork.

| Slot               | Origin / convention                                  | Stable responsibility                                                                              |
| ------------------ | ---------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Landscape          | World origin, meters, Y up                           | Cosmetic dunes; existing playable floor and boundaries remain authoritative                        |
| Habitat / interior | Configurable `habitat_origin`, currently `(0,0,-16)` | Exterior/retained EVA geometry and dedicated indoor enclosure use separate reversible presentation |
| Refuge             | `(-14,0,-7)`, entrance +Z                            | Retained outdoor-EVA shelter contract; hidden in default window mode                               |
| Solar array        | `(16,0,-8)`, approach +Z                             | Retained outdoor-EVA inspection/cleaning contract; hidden in default window mode                   |
| Companion          | Operator scenario starts `(0,0,7)`                   | Rescue orchestration supplies position/orientation; character artwork does not decide safety       |
| Scanner            | Camera-local, looks -Z                               | Hidden for indoor operator view; restored for retained EVA presentation                            |

Scene replacements are `PackedScene` resources. Imported GLB assets can use a `.tscn` wrapper. `apply_mission_visuals(snapshot: Dictionary)` consumes a detached presentation snapshot: time, weather/event, solar generation, both batteries, dose, dust, inspection, shelter, cleaning, conservation and terminal state. Never mutate the simulation through this adapter.

Geometry footprints, doorway sizes, camera clearance, receiver positions and collision volumes affect behavior. Changing them requires related route/collision checks, not only a screenshot. A decorative swap must not silently change protection or make a previously valid route impassable.

## Default window presentation

`art_profile.gd` exposes `start_in_window_presentation` and `window_hidden_categories`. The default profile hides `habitat`, `refuge`, `solar_array`, `power_control`, `route`, `rocks` and `wayfinding`. `world.set_window_presentation(enabled)` controls those categories and calls compatible presentation adapters. Hiding an object must also disable its collision/picking state; switching back must restore the original state, including deliberately hidden fallback geometry. Repeated or rapid toggles must remain safe.

The old exterior habitat also supplied inner shell faces, so hiding it alone would leave an open platform. `interior.gd` now supplies a dedicated `OperatorWindowRoom`: floor, rear/side walls, ceiling, a real transparent window barrier and a separate side vestibule. The older room’s geometry/colliders are hidden while this enclosure is active and restored when it is disabled. The earlier two large telemetry workstations remain in that retained room; they do not occupy the default forward view.

The approved review camera is `(0,1.78,-12.6)`, looking toward +Z, with 52° vertical FOV. `WindowOperatorView` records the corresponding local position `(0,1.78,3.4)` under the habitat origin. The operator’s bounded feet area is x `[-3,3]`, world z `[-16,-11.2]`; ordinary walking is constrained inside it. Turning may reveal room surfaces and the side entry. The initial forward image should show only clear glazing, dunes and Mira outside.

### Crew entry geometry

The panoramic pane lies at world z `-9.8`. Mira’s separate route goes through `(-7.15,0,-5.5)`, `(-7.15,0,-9.23)`, and the vestibule receiver `(-7.15,0,-11.4)`. The inner door is at z `-12.3`; the final receiver is `(-7.15,0,-13.0)`. Preserve the actual opening and floor under this route. Never move the character through the main pane just to match a camera composition.

`interior.set_airlock_phase(phase)` accepts `idle`, `approach`, `cycling` and `complete`. Approach opens only the outer door; cycling closes both; complete opens only the inner door. `companion_rescue.gd` and `game.gd` own travel, time, pause, abort and protection. The visual callback cannot grant shielding. The cycle and containment geometry do not implement atmospheric pressure, gas exchange, radiation transport or equipment certification.

The old outdoor-EVA flow remains behind its own mode/profile path and retains on-foot inspection and refuge behavior. It is not the default start. Restore its scene categories/colliders before testing its routes. Untimed exploration uses the indoor presentation but freezes resources and does not start the timed rescue.

## Interface contracts

A custom `hud_scene` uses a `Control` root and preserves the orchestrator’s unique-name bindings:

- `HUD`, `Menu`: control containers.
- `Objective`, `Metrics`, `Radio`, `Prompt`, `Clock`: labels.
- `Visor`: overlay; indoor operator presentation does not show it as the player’s visor condition.
- `Begin`, `Guide`, `Sound`: primary bindings; optional `Explore`, `Academy`, `Updates`, `SuitLab` and `HabitatNotes` remain reachable.
- `PanelCleaning`, `SavePower`, `FindShelter`: action bindings. The stable `FindShelter` name presents **Guide Mira** in operator mode and the original refuge guidance in EVA mode.

The controller owns actions, pause/resume and rescue state; the interface owns layout and labels. Keep one immediate objective, accurately labelled batteries/dose and reachable controls. **Tab** enables paused pointer controls; **1/2/3** invoke primary actions. Optional Details and the **P** planner should not crowd the first screen or leave an invisible input blocker after closing.

Use reflow/scrolling on portrait or short landscape viewports. Preserve keyboard focus, cancellation, touch target size and mode-specific hints. Simulated viewport checks are useful but do not establish physical-mobile ergonomics or child comprehension. Native screen-reader support remains unverified.

## Shared appearance and asset delivery

The art profile owns scene slots, broad colors, optional fonts, frame cap, shadow and particle settings. `game/data/visual_style.json` provides validated palette, surface and motif tokens through `visual_style.gd`; brand identity remains exclusively in `game/data/brand.json`. Some local presentation adjustments and cameras remain per-scene; do not create another naming source to make a new screen.

Prefer meters, Y up, explicit pivots, named materials, reusable meshes and GLB wrappers. Keep compatibility-renderer fallbacks for effects. Avoid expensive stacked transparency, needless unique materials and per-frame allocation. Cultural ornament remains removable; it must not obscure text or narrow a route. Do not restore dense historical decoration simply because its old specification remains in the repository.

Every asset needs origin, creator, exact license, attribution requirements and modification status. Do not bundle unlicensed inspiration images. Store source/export pairs deliberately; large artist source files need a storage strategy rather than accidental Git growth.

## Learning and update interfaces

`academy.gd` presents authored content from `data/lessons.json`; `learning.gd` owns estimates and persistence. Preserve hints, explanations, local reset confirmation, save-error feedback and return focus. Animation or cosmetic success must not update knowledge estimates.

`suit_lab.gd` owns a live 3D stage with selectable views, cosmetic themes and a scrollable experiment card. `suit_experiments.gd` contains isolated teaching models, not validated suit capability tests. `habitat_inspector.gd` explains architecture without creating construction or pressure physics. A temporary overview may reveal the retained exterior while paused; close must restore the active window presentation.

The update client lives under the persistent `Updates` autoload. `updater/panel.gd` is presentation. Keep verification errors, cancellation, explicit restart consent, interrupted-storage repair and installer fallback accessible through the secondary menu. Autoload/global-class/runtime changes need compatibility review and may require a new full installer; see [updates](UPDATES.md).

## Verification and media handoff

Run the numerical, gameplay, art-contract, enclosure/door, rescue, mode-restoration and input/layout checks appropriate to the change. Check the final native/browser render separately. Confirm that pause stops both the resource clock and Mira’s movement, an aborted sequence cannot later finish, and protection does not begin on recall or before inner entry.

Capture the actual running game and record source commit/build target, viewport, camera, input sequence and special test state. The [media gallery](MEDIA.md) distinguishes old 0.5/0.6 imagery and the superseded exterior-start 0.7 candidate from the newest operator flow. Do not cite an earlier passing audit or screenshot as validation of a later pivot. Software rendering and fixed capture rates do not establish target-device FPS.

Do not composite missing controls, characters or outcomes into product screenshots. A useful review includes the default forward view, a turn toward the side entry, route/cycle/entry states and optional interfaces. The [player-experience review](PLAYER-EXPERIENCE-0.7.md) must distinguish engineering checks from actual supervised learner studies.

The next gates remain final-source visual/input review, scientific review, physical-device profiling/accessibility and supervised comprehension testing. The current procedural character and environment are not final photoreal assets; one implemented return sequence is not the full rescue curriculum.
