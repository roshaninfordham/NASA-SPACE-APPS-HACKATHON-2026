# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> design specifications

These briefs translate the design team's three November 14, 2026 specifications into one first-person game for ages **7–12**. The original documents describe visual targets and several proposed game modes. They do not establish that those modes are shipped, that the structures are feasible, or that the stated performance has been measured.

| Working brief                                     | Preserved input                                                                    |
| ------------------------------------------------- | ---------------------------------------------------------------------------------- |
| [Mission Control](01-MISSION-CONTROL.md)          | [Original control-room specification](source/01_Mission_Control_Room_Game_Spec.md) |
| [Habitat and refuge](02-HABITAT.md)               | [Original exterior specification](source/02_Exterior_Habitat_Game_Spec.md)         |
| [Explorer suit and Suit Lab](03-EXPLORER-SUIT.md) | [Original suit specification](source/03_Explorer_Suit_Game_Spec.md)                |

[Implementation status and decisions](../SPEC-IMPLEMENTATION.md) connect the targets to code, checks and remaining work. [Design handoff](../DESIGN-HANDOFF.md) defines replaceable scene contracts. The original files remain byte-for-byte copies; [provenance.json](source/provenance.json) records their SHA-256 hashes. Their old product name is historical source material, not current game branding. The accompanying concept images are visual references supplied in chat; this folder does not contain or claim runtime-ready versions of those images.

## Shared creative direction

**KŌMAKU: Shield Protocol** is the exact product name. `game/data/brand.json` remains its canonical source. Runtime titles use `branding.gd`; scripts and generated package names use the existing branding tools. Do not paint the old name into new textures, models or generated artwork. The ASCII download stem is a technical filename, not an alternate display name. Historical release filenames, update identifiers and save locations are compatibility boundaries.

The visual language combines pearl composite, deep crimson lacquer, rose-gold inlay, amber lanterns and restrained cyan instruments. Use specific craft references consistently:

- **Seigaiha:** Japanese overlapping wave arcs, used on chair backs, shells and suit fabric.
- **Kumiko-inspired lattice:** geometric Japanese joinery translated into fictional lacquer or metal panels and lantern cages; do not claim procedural grids are authentic handcrafted joinery.
- **Sakura and bonsai:** blossom branches and cultivated miniature trees, used as interior art and planting references.
- **Kimono wrap, hakama and obi:** references for suit silhouette, trouser volume and harness construction; they do not confer physical protection or character abilities.
- **Crane embroidery:** a decorative suit motif, with no stamina or intelligence bonus.
- **Chinese endless-knot reference:** a separate ornamental source for the airlock emblem. Label its inspiration specifically instead of calling every motif Japanese.

The name is user-selected. No Japanese etymology or cultural meaning has been verified; do not invent a translation. Cultural and readability review by the design team remains useful before final artwork approval.

## Implementation rules

1. Preserve one connected game and the existing mission model. The three documents inform scene modules and optional practice interfaces; they do not automatically replace the mission with three unrelated games.
2. Keep live data, explanatory text and decorative graphics distinct. Native text replaces illegible generated lettering. An unsimulated oxygen, water or thermal value must be labeled illustrative, or omitted.
3. Keep art and simulation separate. A new shader, motif, color preset or camera cannot silently change dose, power, movement or learning evidence.
4. Keep the Godot Compatibility renderer working for existing desktop/Web exports. Unity, Unreal, FBX, shader-graph and HDR suggestions describe intent, not mandatory engine migration or deliverable formats.
5. Treat dimensions, camera positions and performance numbers as targets requiring checks against playable collision routes, screen composition and actual hardware. Scaling a room is an engineering change, not merely a color change.
6. Review real screenshots and gameplay against the concepts. Until measured and reviewed, use “procedural visual-development alpha”; do not claim pixel identity, photorealism, production character rigging or device frame rates.

## Shared style configuration

`game/data/visual_style.json` supplies versioned palette colors, material roughness/metallic values and motif descriptions. `game/scripts/visual_style.gd` validates the schema and exposes `color(key)`, `number(key)` and `motif(key)` to presentation modules. Its schema excludes gameplay statistics and product names. Review cameras, quality/LOD policies and every legacy color have not yet been centralized. Product names continue to come from the brand resource; science constants remain in the mission model.
