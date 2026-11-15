# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> visual direction

**Current direction — published [0.7.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.7.0-alpha.1), November 14, 2026.** The owner's latest pivot starts the player **inside the dome, close to a clear panoramic window**, looking out at warm dunes and the stranded astronaut. The initial forward view contains no exterior dome, array, kiosks, path lamps, scanner or console clutter. This is the active brief. The ornate 0.6 images and [three supplied specifications](design-specs/README.md) remain historical design inputs; their exact ring, tablet, screen and decoration counts are no longer current acceptance criteria.

The product name comes from `game/data/brand.json` through `branding.gd`. The player remains a first-person junior astronaut, ages 7–12. The [core brief](CORE-BRIEF.md) still governs separate habitat/suit energy, visor cleaning, the independent particle event and passive refuge shielding. A simpler screen does not simplify away those model distinctions.

## The experience to build

Give the player one clear next step and room to look around. The title presents **Start mission**, **Explore · no timer**, and **Learn & more**. Learning, the suit lab, habitat notes, updates and sound remain reachable through the secondary menu. During the default operator mission, the three primary controls are **Clean panels**, **Save power**, and **Guide Mira**; keyboard shortcuts are **1/2/3**. **Tab** pauses for pointer controls. Guide Mira starts her visible journey to the side airlock. Both doors close during its timed cycle, the inner door then opens, and protection begins only after Mira enters the room. The button does not teleport or immediately shield her.

Two labelled battery gauges distinguish base energy from **Mira’s suit energy**; the exposure reading also belongs to Mira and retains the model unit mSv. The player stays indoors in a bounded walking area. The same numerical mission equations now use Mira as their exposed subject in this mode. Details and the optional **P** planner expose further readings without crowding the opening view. Warnings prioritize bringing Mira home before the particle event. No outdoor array inspection is performed in this operator scenario; the retained outdoor-EVA mode has its own movement and inspection flow. See the [player-experience review](PLAYER-EXPERIENCE-0.7.md) for what was tested and what still needs user/device review.

## Shape, material and light

| Layer             | Active direction                                                                                                      | Review criterion                                                                                                       |
| ----------------- | --------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| Landscape         | Broad warm dunes, a quiet distant horizon and sparse rocks outside the working area                                   | Mission equipment and routes remain easy to find; no noisy foreground field or jagged ring of cliffs                   |
| Habitat           | Smooth pearl shell, navy recesses, a readable entrance and restrained cyan trim                                       | Shape reads without all-over engraving, high emission or clipped-white highlights                                      |
| Default room      | Dedicated inner enclosure and nearly invisible panoramic glazing; no console or furniture in the initial forward view | At the near-window camera, only dunes and Mira appear outside; turning reveals the indoor room and separate side entry |
| Retained EVA room | Two separated navy workstations and a small side teaching plinth                                                      | Available through the older presentation/profile contract; hidden with its colliders during the default window mission |
| Materials         | Rough, calm surfaces and controlled contrast                                                                          | Pearl has no emission; essential readings do not depend on reflective glass or bloom                                   |
| Cultural detail   | Selective seigaiha inset and compact knot/garment references                                                          | A motif marks an intentional detail; it does not fill every surface or sit behind text                                 |
| Light             | Soft warm daylight, restrained ambient fill and distant haze                                                          | Keep floor, shell, hands and signs legible without yellow/white clipping; review storm states separately               |

The [landscape pivot record](DESIGN-PIVOT-0.7.md) describes the procedural dunes and their measured geometry inventory. Distant slopes are presentation geometry outside the playable perimeter, not a new traversable terrain system. The direction takes broad inspiration from quiet exploration games; no Journey artwork, meshes or textures are copied.

Colors and material values remain editable through the art profile, shared tokens and scene exports. Not every scene-local adjustment has been centralized. Shared motifs remain specific: Japanese wave/lattice/textile references and separately identified Chinese knot inspiration. Neither the product name nor a pattern is presented as a verified translation, scientific mechanism or universal representation of Asian design.

## First-person interface

Use generous spacing, controlled navy backings and a quiet sans-serif face. Keep the immediate objective separate from optional details. One active prompt should say whether to hold or press; inspection and panel cleaning are different actions. A cleaner state or warning must be understandable from its label, not cyan/red color alone.

Portrait and short landscape layouts must use scrolling or reflow rather than unreadable shrinking. Preserve keyboard focus, return/cancel, pointer input and touch targets. Simulated viewport tests at 1280×720, 960×540, 390×844 and 844×390 help find layout errors; they are not physical-phone or child comprehension tests. Native screen-reader support remains unverified.

## Character and science boundaries

Mira remains an original fictional companion, not a third-person player camera. Her return follows an explicit route to the side airlock; it never crosses the panoramic pane. The current source implements travel, timed cycling and indoor entry, with pause/abort handling. This is a deterministic teaching sequence, not pathfinding, collision-driven locomotion or pressure physics. The suit viewer, cosmetic themes and separate teaching exercises remain available under optional learning. A production character rig, expressive authored face and cloth/hair motion remain future work.

Do not import the old concept's “Age 12+,” “12+h life,” attenuation percentages or temperature labels as product ratings. The mission does not independently simulate oxygen inventory, water recycling, pressure or thermal regulation. Panel readings use actual mission state. Planner comparisons use the same deterministic game model, not live NASA predictions or a trained AI system.

Decorative glow does not provide shielding; dust cleaning does not remove energetic particles; atmospheric pressure does not create Earth gravity. The [science ledger](SCIENCE.md), [readable science guide](SCIENCE-GUIDE.md) and [16-page illustrated PDF](media/KOMAKU-Science-Guide.pdf) explain equations, sources and omissions.

## Review and acceptance

1. Review the title and default indoor mission at eye `(0, 1.78, -12.6)`, looking toward +Z with 52° vertical FOV. The dedicated `WindowOperatorView` marker records the local counterpart. The player’s bounded feet area is x `[-3,3]`, world z `[-16,-11.2]`. Record the actual camera, viewport, source and mission state for every capture.
2. Confirm base energy, Mira’s suit/dose and rescue state come from actual state. Check waiting, travel, both-doors-closed cycling, inner-door entry and protected states. The planner freezes current protection and does not predict the journey.
3. Check the three primary menu choices and three gameplay actions, readable subject labels, warning priority and return from every optional interface. Untimed exploration freezes resources and does not start a rescue.
4. Test the real window barrier, bounded indoor movement, separate side-airlock receiver, and reversible presentation flags. Restore outdoor-EVA geometry/collisions when that retained mode is selected. The glazing and timed doors are not a pressure or radiation-transport solver.
5. Measure the finished source on target devices before claiming frame rates. Review screenshots for clipping, text contrast and scene composition separately from headless tests.

0.7 is published from exact source `8968859e8ffdcda7b8c0c216ff0262df633400e6`; the [release evidence](evidence/release-0.7.0-alpha.1.json) records its accepted files and publication. No pixel-perfect, photoreal, physical-device-wide performance or educational-efficacy claim follows from this visual pass. Historical 0.5/0.6 captures remain versioned in the [media gallery](MEDIA.md).
