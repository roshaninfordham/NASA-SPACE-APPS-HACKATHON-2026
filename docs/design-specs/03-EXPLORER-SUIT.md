# Explorer suit and Suit Lab — implementation brief

Part of **<!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->**. Derived from the [preserved explorer-suit specification](source/03_Explorer_Suit_Game_Spec.md); [decisions and status](../SPEC-IMPLEMENTATION.md) override conflicting source requirements.

## Character and visual direction

Mira is an original fictional rescue crewmate. The player remains the first-person hero. The design sheet's teenage-looking character does not change the game's audience from ages **7–12**, and the pictured “Age 12+” is not an established software age rating.

Keep the recognizable silhouette: clear bubble helmet and cyan visor instruments; crimson layered collar; pearl kimono-wrap jacket; rose-gold blossoms; circular chest module; crimson obi-inspired harness; lavender sash with wave/crane ornament; wide hakama-inspired trousers; bulky boots with three crimson straps and pale luminous sole; rounded life-support backpack. Favor readable proportions and craftsmanship over multiplying tiny geometry.

Use an original stylized face, dark braids and warm skin tones without claiming the procedural mesh is a production likeness, facial rig or character customization system. The reference's loose fabrics are artistic costume direction; their presence does not establish suitability for a pressure garment.

## Suit Lab presentation

The desktop target is a live design sheet: close-up, front/back views, detail views and a legible spec card. Small screens should switch views or tabs rather than shrink six cameras and long text into illegibility. Reuse one character scene and shared materials where practical; avoid rendering many full worlds merely to produce thumbnails.

Each card opens an educational interaction for **radiation**, **dust**, **thermal control**, **life support** or **pressure fit**. Keep learning outcomes concrete: choose a protection response, compare energy costs, explain why a change helps, then retry. Label simplified models as teaching examples, with units and assumptions where numerical values are shown. The lab must pause active gameplay safely and restore navigation/focus on exit.

Cosmetic presets may change colors and patterns. A crane does not improve stamina; waves do not intrinsically repel dust; an obi motif does not create carrying capacity. If equipment configuration changes physics later, separate that equipment definition from its ornamental appearance.

## Scientific interpretation of the reference card

| Reference claim                                         | Accepted treatment                                                                                                                                                            |
| ------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Radiation attenuation up to 60% from pearl/lacquer/film | Unsupported. Teach shelter and dose reduction with labeled illustrative assumptions; no fabricated certified suit attenuation.                                                |
| Dust-repellent wave pulse                               | Explain electrodynamic dust removal as an engineering mechanism. Decorative wave embroidery alone does not produce an electric field. Mars suit effectiveness is unvalidated. |
| Thermal regulation −80 °C to 20 °C                      | A proposed environment range, not certification or an acceptable human body-temperature range. Thermal exercises need heat-balance assumptions and energy costs.              |
| Life support 12+ hours                                  | Fictional design goal. Current mission models suit energy, not validated oxygen capacity, CO₂ removal or twelve-hour hardware endurance.                                      |
| Pressure fit sliders                                    | A simplified learning activity, not instructions for configuring a real suit or evidence that fit ensures airtightness.                                                       |
| Cosmetic module perks                                   | Decorative motifs remain cosmetic. Equipment performance requires explicit parameters and explanations.                                                                       |

## Implementation and asset boundary

The active procedural character lives in `game/art/red_veil/astronaut.gd/.tscn`. Material and viewer helpers should be explicit scene/script dependencies so the signed content-pack compatibility boundary remains inspectable. Shared branding supplies every new label; do not hard-code new titles into meshes or test cards.

Angle-dependent color shading can approximate an iridescent look in the Compatibility renderer. It is not automatically a physically calibrated thin-film model, nor a substitute for UVs, weave/embroidery textures, skin shading and artist-authored geometry. A breathing transform is not skeletal animation. Cloth, facial blendshapes, multiple hair/face presets, production LODs and three complete EVA missions require separate implementation and validation.

## Acceptance evidence

Capture the actual desktop and narrow-screen lab, every supported view and one completed learning interaction. Verify that exit restores the game, that camera controls work with keyboard/touch, that cosmetics do not alter mission/learning physics, and that displayed names use the shared brand. Measure character triangle count and renderer cost, then test physical devices before claiming 60/30 fps. Record which source-sheet details remain approximate.
