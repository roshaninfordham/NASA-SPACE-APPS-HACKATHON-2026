# RED VEIL — GAME 3: "EXPLORER SUIT: YOUTH EDITION" (Character Lab \+ EVA Survival 3D Game)

**Source visual:** Red\_Veil\_Youth\_Explorer\_Suit\_final.png **Genre:** 3D character customiser / suit-engineering lab \+ third-person EVA (spacewalk) survival missions **Audience:** Youth, age **12+** (matches the spec card in the image). Keep all content age-appropriate. **Goal:** The suit and character viewer must match the image's design sheet: hero close-up, front view, back view, three detail crops, and the right-hand spec card.

---

## 0\. HOW TO USE THIS DOC

- Part A \= engineer spec; Part B \= AI prompts; Part C \= acceptance checklist.  
- **\[ASSUMED\]** \= not visible; confirm with Joy.  
- Stack: Unity 6 URP (or UE5). Character rig: Humanoid, skinned, cloth sim on obi/sash. Web alt: Three.js \+ GLB.  
- **The character is a fictional youth explorer. Do not use a real person's likeness; create an original character.**

---

## PART A — ENGINEER SPEC

### A1. Concept

Players inspect, assemble and test the **Red Veil Explorer Suit (Youth Edition, Age 12+)**, then wear it for EVA missions on Mars. Each suit system (the 5 spec-card features) is a playable subsystem: Radiation Attenuation, Dust Repellent & Self-Cleaning, Thermal Regulation, Life Support, High Mobility & Pressure Fit. The suit's Japanese-inspired modular design (Seigaiha wave, Crane motif, Obi-style harness, lightweight layers) is both the cosmetic customisation system and the gameplay modules.

### A2. Game modes

1. **Suit Lab (design-sheet mode)** – turntable viewer replicating the image layout (see A3). Customise modules, colours, patterns; run tests (radiation chamber, dust tunnel, thermal chamber, pressure test).  
2. **EVA Missions (third-person)** – 12-minute missions: collect samples, repair solar panels, cross dust fields, return before O₂ runs out.  
3. **Photo Studio** – pose mode with the same backdrop (Mission Control hologram arc \+ pink hall).

### A3. The "Design Sheet" screen (Suit Lab home) — exact layout (16:9, 1920×1080 ref)

Reproduce the image as the **home screen** of the Suit Lab with live 3D (not a static picture):

- **Left 0–38%, full height — Panel A "Hero Close-Up"**: live 3D camera tightly framing the **character's head and shoulder, 3/4 view from lower-left, slight low angle**; helmet bubble large in frame; face turned slightly up and right. Focal length **85 mm equiv**, aperture f/1.8 DoF.  
- **Centre 38–68%, full height — Panel B "Front \+ Back full-body"**: two full-body characters side-by-side on a glossy reflective floor: **front view (left)**, **back view (right)**, both standing neutral relaxed pose (hands at sides, slight A-pose), camera **eye level, 50 mm equiv**, character height ≈ 62% of panel height. Background: blurred **Mission Control hall** — a big arched window showing Mars hills, cyan-teal monitors, red-pink swirling ceiling rings.  
- **Right 68–90% — Panel C "Detail stack"**: three stacked inset cameras with fixed crops:  
  1. **Top: side profile of helmet** (head in profile facing right, helmet HUD visible — cyan floating UI inside visor).  
  2. **Middle: back shoulder/obi detail** — the **crane motif** and **seigaiha** pattern embroidered on the sash, lavender-pink gradient fabric.  
  3. **Bottom: boot detail** — chunky white-chrome boots with red buckle straps, **glowing white-pink sole light**.  
- **Far right 90–100% — Spec Card (dark wine-brown panel \#3A2A2D)** with the text exactly as follows:

```
RED VEIL
EXPLORER SUIT
(Youth Edition · Age 12+)
───────────────
[shield icon]  Radiation
               Attenuation
[dust icon]    Dust Repellent
               & Self-Cleaning
[thermo icon]  Thermal
               Regulation
               (−80°C – 20°C)
[O2 icon]      Life Support
               (12+ hrs)
[runner icon]  High Mobility
               & Pressure Fit
[knot icon]    Japanese-Inspired
               Modular Design
               - Seigaiha (Wave)
               - Crane Motif
               - Obi-Style Harness
               - Lightweight Layers
───────────────
[4 colour swatches: crimson ● pearl-pink ● holo iridescent ● cyan]
[crescent moon emblem, bottom]
```

- Top-left overlay: **"RED VEIL"** (wide tracking, thin) \+ **"MARS SURVIVAL LAB"** (tiny).  
- Each spec line is a **clickable row** that opens the corresponding test (see A7).

### A4. Character spec (original youth explorer)

- **Age look:** early-to-mid teens. Height **1.52 m** (scales 1.40–1.70 m via slider). Slender proportions, Humanoid rig.  
- **Face:** warm medium-brown skin, soft freckles across nose/cheeks, dark brown eyes, brows soft; neutral calm, slightly tilted-up expression in hero shot.  
- **Hair:** dark brown, **loose curly braids** (two thin braids framing face \+ hair pulled up in a bun/top-knot at back visible in back view). Hair strands short physics (cloth/hair sim, 3 bones per braid).  
- **Earring:** a tiny pearl stud in visible ear.  
- **Customisation:** skin tone (12 swatches), hair style (6), hair colour, freckles toggle, face presets (6). Keep age-appropriate.  
- Facial animation: 52 ARKit blendshapes minimal subset (blink, brow, gaze, subtle smile).

### A5. The Suit — layer-by-layer build

Overall: **pearl-white holographic fabric** with **crimson (\#A8102A) lacquer straps/piping**, **rose-gold embroidery**, **iridescent film layer** (pink-lilac-cyan shift), and **glowing red-pink edge lines** tracing seams (emissive). Silhouette: **baggy, flowing Japanese-hakama-inspired trousers**, **kimono-wrap jacket**, spacesuit rigidity at shoulders/neck.

**1\) Helmet (bubble)**

- Clear **spherical polycarbonate bubble**, Ø **0.33 m** (head-fit, large), thin glossy **rim lighting** (pink-white refraction), subtle fingerprints/dust none.  
- **Interior HUD:** floating cyan UI elements inside the visor at the right eye: small translucent panels with mini graphs/data (see A6).  
- **Neck ring/collar:** layered **crimson lacquer \+ clear acrylic ring**, high collar flaring like a ruff, clear tubular rim with red glow trim; on the collar a **circular red-ringed port** (0.07 m).  
- **Neck seal:** thin glowing red ring around the base.  
- Anti-fog sheen: faint reflection of the room.

**2\) Torso (kimono-wrap jacket)**

- Left-over-right **kimono wrap (crossed collar V)**, shiny **iridescent holographic pearl panels** (diamond/hex "geometric crystal" texture pattern overlay at 6 cm cells, visible shimmer under light).  
- **Crimson diagonal harness straps** crossing chest, buckles (silver) at hips; a **chest life-support module** — **round hub 0.09 m Ø**, white shell with **red glowing ring** and a lens centre (breathing/telemetry port) on the left chest.  
- **Sakura embroidery** (rose-gold/pink) on the right chest/shoulder: 5–7 flowers \+ thin branch.  
- Sleeves: wide **kimono-style sleeves** gathered at wrists with **red lacquer cuffs** (0.06 m wide) \+ white gloves with red knuckle guards.  
- **Backpack (PLSS)**: boxy rounded white module 0.30 × 0.38 × 0.14 m, mounted by crimson straps, on the front face a **circular red-glow ring Ø 0.06 m** \+ **crescent-moon emblem** \+ **"RED VEIL"** printed small; handle loops; hoses.

**3\) Obi harness \+ sash**

- **Obi-style waist wrap**: crimson belt (0.11 m wide) with silver buckles, tied in a **flat bow-less knot** at back; a **long hanging sash tail** (hip to knee) of lavender-to-rose gradient fabric (\#B28BC9 → \#D9A6B8) with **seigaiha wave** embroidery in pearl-gold and a **crane motif** (white crane in flight with outstretched wings, embroidered, 0.18 m span) on the lower panel. Tail cloth sim, 5 bones, wind-reactive.  
- A red **tassel/cord** hangs from hip.

**4\) Trousers**

- **Hakama-style wide-leg jogger** shape: baggy thigh, tapered/gathered ankle with **red elastic cuff**. Holographic pearl panels, **glowing red-pink line seams** down the sides. Large **cargo pocket** with white strap on thigh.  
- **Seigaiha wave** embroidery near the lower leg (rose-gold arcs) as in the boot close-up.

**5\) Boots (platform sneaker-boots)**

- **Chunky platform soles 0.06 m**, white-chrome with iridescent finish; **three red buckle straps** across the instep and ankle (silver buckles); **glowing white-pink LED light strip** on the sole edge (emissive 3.0, pulses at footfall); high ankle cuff with red flap. Heel stud details. Reflective.

**6\) Colour swatches (customisation presets):** Crimson `#A8102A`, Pearl-pink `#E6C9C9`, Holographic iridescent (shader), Cyan `#3CE6F0` (accents). Provide 4 theme presets: *Original*, *Cyan Pulse*, *Midnight Wine*, *Gold Crane*.

### A6. Materials & shaders (reproduce the look)

- **Iridescent holo fabric (hero material):** Unity Shader Graph / UE Material: base pearl `#EFD9DA`, **thin-film iridescence** (thickness 380–620 nm, angle-driven hue shift pink→lilac→cyan→gold), **anisotropic specular** along weave, **geometric hex-crystal normal map** (cell 6 cm, depth 0.35), clear coat 0.4. Sparkle noise (very low).  
- **Crimson lacquer:** `#A8102A`, clearcoat 1, roughness 0.12, subtle orange-peel normal.  
- **Rose-gold embroidery:** metallic 1.0, roughness 0.3, thread-direction normal map; displacement 0.5 mm; sakura/crane/seigaiha atlases (2K).  
- **Glow lines:** emissive HDR 3.5, colour `#FF5A6E` (red-pink) with 6 % flicker; bloom picks up.  
- **Helmet glass:** refraction IOR 1.49, thin shell, reflectance 0.06, tint 3 % pink, add fresnel pink-white rim; interior HUD rendered in front with no refraction.  
- **Skin:** SSS (thickness map), freckles via albedo mask; peach-fuzz fine.  
- **Floor:** glossy pearl-pink with strong reflections; red-pink ring lights in background arcs.

### A7. Gameplay mapped to the spec card (5 testable systems \+ 1 cosmetic system)

1. **Radiation Attenuation (shield icon):** Mini-game "Radiation Chamber" — a solar-flare timeline; player stacks protection layers (Pearl layer, Crimson lacquer lining, Reflective film). **Dose meter** shows mSv; suit attenuation up to **60 %** with all layers. During EVA, storms trigger auto "storm shelter" alerts.  
2. **Dust Repellent & Self-Cleaning (dust icon):** "Dust Tunnel" — fabrics collect dust; player activates **electrostatic wave pulse** (Seigaiha lines glow, dust ripples off) every 20 s. Dust on suit reduces thermal efficiency/mobility.  
3. **Thermal Regulation (−80 °C to 20 °C):** Gauge in HUD; suit heats/cools. The chamber sweeps −80 → \+20; player manages layer toggling (Lightweight Layers on/off). Out of range → frost/overheat effects.  
4. **Life Support (12+ hrs):** **O₂ capacity \= 12 h baseline** (sim-scaled: 12 h → **12 min** of real mission time at 60× so a full mission fits a session). HUD ring gauge; refill at oxygen cache stations.  
5. **High Mobility & Pressure Fit (runner icon):** Mobility score; mini-game "Pressure Fit": adjust 6 sliders (neck, chest, waist, hip, knee, ankle) to keep pressure within window; too tight \= slow stamina, too loose \= leaks. Mars-gravity jumps (g \= 3.71 m/s²), stride animations.  
6. **Japanese-Inspired Modular Design (knot icon):** The **cosmetic \+ modular system** — swap **Seigaiha / Crane / Obi / Lightweight Layers** modules; each module gives a minor perk (see table).

| Module | Look | Perk |
| :---- | :---- | :---- |
| Seigaiha (Wave) | Wave arcs on fabric | Dust-repel pulse \+20 % |
| Crane Motif | White crane embroidery on sash | \+10 % stamina recovery (calm) |
| Obi-Style Harness | Crimson belt \+ sash | \+load capacity (sample bag 4 → 6 slots) |
| Lightweight Layers | Thin holo layer toggle | −15 % mass, \+mobility; −8 % radiation shield |

### A8. Helmet HUD (inside the visor, cyan)

Small floating translucent panels, right side of the visor: **mini oxygen ring**, **temperature**, **dose**, **compass**, **tiny waveform graph**, mission timer. Typeface: **Rajdhani / Orbitron-lite**, cyan `#7BE8F2`, 70 % opacity, 0.8 px glow. Parallax with head movement (3 cm).

### A9. EVA mission structure (3 missions)

1. **"Dust Run"** (tutorial): walk 400 m to a sample site, collect 3 rock samples, return. Teaches O₂/dust.  
2. **"Solar Storm Shelter"**: repair 2 solar panels; solar particle alert at T+6 min; run to shelter (Habitat from Game 2).  
3. **"Night Freeze"**: transit at low temp; manage heat and lantern waypoints. Each mission: 8–12 min, checkpoints, 3 stars (survive / fast / low dose).

### A10. Animation list

Idle (breathing, small weight shift), Walk, Run, Mars-low-g bounce-jog, Jump (large arcs), Land, Kneel+Scoop, Pick-up, Repair (tool), Look-up (hero pose), Salute, Wave, Photo poses (6). Hair/braids, sash, tassel, hoses \= secondary motion (cloth/spring bones). Helmet HUD micro-lag.

### A11. Camera/light for the Suit Lab (match the image)

- **Key light:** large soft area light **upper-left front**, colour `#FFE5E0` (warm pink-white), intensity 5; **rim lights** magenta-red `#FF4A6A` on both sides from behind (intensity 4\) producing the glowing red outlines on the suit edges and helmet; **fill** cyan `#4ED8E8` from behind-right (monitors) intensity 1.2.  
- Background: **bokeh**\-blurred hall: big arched window (Mars hills in rose-coral), cyan monitors, swirling red ring ceilings. DoF f/2.0, bokeh shape circular.  
- Floor reflection roughness 0.1; reflect characters.  
- Post: bloom 1.0, **chromatic aberration 0.06**, vignette 0.2, subtle film grain 0.04, colour grade pink-magenta highlight / wine shadows.

### A12. Performance

- Character: **Hero LOD0 ≤ 120 k tris** (suit 85 k, head 18 k incl. hair cards, helmet 6 k, boots 11 k); LOD1 45 k; LOD2 12 k. 2 characters in Suit Lab at once ≤ 260 k.  
- Textures: suit 4K atlas (holo \+ embroidery masks), face 2K, hair 1K, boots 2K.  
- Cloth sim: 120 particles on sash, GPU; hair 6 braids × 12 segments.  
- Target 60 fps desktop / 30 fps mobile; mobile fallback: remove iridescence thin-film to LUT (cheap), single cloth sash.

### A13. Deliverables

1. Character base mesh (female-presenting youth, **original**), rig, blendshapes.  
2. Suit modular meshes: helmet, collar, jacket, harness/obi, sash, trousers, gloves, boots, backpack.  
3. Texture sets \+ shader graphs.  
4. Embroidery atlases (sakura, seigaiha, crane).  
5. Suit Lab scene (design sheet layout), Photo Studio, EVA mission scenes.  
6. HUD (helmet) \+ Spec card UI.  
7. Animations (mocap-clean or hand-keyed).  
8. Audio: suit breathing loop (soft), servo/air hiss, footfall regolith crunch, boot-light "tick", UI chimes, shakuhachi stinger.  
9. Test mini-games (5).

### A14. Build order (6 weeks)

1. Wk1: Character base \+ rig \+ proportions; blockout suit; Suit Lab hero camera matched.  
2. Wk2: Suit modelling pass (helmet, jacket, harness, boots); UV \+ textures.  
3. Wk3: Shaders (holo, lacquer, embroidery, glow), cloth/hair sim; lighting match.  
4. Wk4: Spec card UI \+ test mini-games.  
5. Wk5: EVA movement, HUD, missions 1–3, audio.  
6. Wk6: Customisation polish, performance, side-by-side match review, QA, age-rating review (12+).

---

## PART B — AI PROMPTS

**STYLE LOCK (append to every prompt):** `Red Veil visual identity: futuristic Mars lab fused with East-Asian (Japanese) craft; palette crimson #A8102A, pearl white, rose-gold, blush pink, holographic iridescent film, cyan HUD accents; glossy lacquer, pearl composite, thin-film iridescence; soft pink bloom lighting with magenta-red rim lights; cinematic, hyper-detailed, 8k, Unreal Engine render, no text artifacts`

**B1 — Hero character plate** `Young teenage explorer girl (original character, not a real person), warm brown skin with light freckles, dark brown loose curly braids and a small bun, wearing a huge clear glass bubble helmet with cyan holographic HUD inside, Japanese-inspired space suit: pearl-white holographic iridescent fabric with crystalline hex pattern, kimono-wrap jacket, crimson lacquer harness straps with silver buckles, chest life-support hub with a red glowing ring, rose-gold sakura embroidery on shoulder, crimson high collar ring with clear acrylic flare, gloves with red knuckle guards, large boxy backpack with crescent-moon emblem and glowing red ring, hakama-style baggy trousers with glowing red-pink seam lines and cargo pocket, chunky platform white-chrome boots with red buckle straps and glowing sole lights, standing in a pink-red futuristic Mars mission control hall with cyan monitors and a big arched window showing Mars hills, shallow depth of field, 3/4 portrait from lower-left, looking slightly upward` \+ STYLE LOCK

**B2 — Character turnaround (for modelling)** `Character turnaround sheet: front, back, left, right, 3/4 views of the same youth explorer in the Red Veil suit; A-pose; neutral light-grey studio; consistent proportions; flat even lighting; clean silhouette` \+ STYLE LOCK

**B3 — Obi sash \+ crane embroidery (texture)** `Seamless-edge sash fabric texture, lavender-to-rose gradient silk, embroidered pearl-gold seigaiha wave pattern, a white crane in flight with outstretched wings embroidered in the lower panel, thread detail, albedo + normal + roughness, 2048px`

**B4 — Holographic hex-crystal fabric (texture)** `Seamless iridescent pearl holographic fabric, crystalline hexagonal geometric facets, thin-film pink-lilac-cyan shift, 4096px albedo + normal + roughness + height`

**B5 — Platform boot (image→3D)** `Chunky futuristic platform sneaker-boot, white chrome with iridescent finish, three crimson buckle straps with silver buckles, glowing white-pink LED sole strip, high ankle cuff, studio turntable, front/side/back`

**B6 — Helmet \+ collar** `Clear spherical glass helmet with a crimson lacquer high collar ring and clear acrylic flared rim, a red-ringed circular port, glowing red neck seal, cyan HUD interface projected inside visor, transparent studio render, orthographic`

**B7 — Spec-card UI icons** `Set of thin 2px line icons: shield, dust sparkle, thermometer, O2 ring, running figure, mystic knot; white on dark wine-brown #3A2A2D; consistent 64px grid; vector style`

---

## PART C — ACCEPTANCE CHECKLIST

- [ ] Suit Lab home matches image layout: hero close-up, front+back pair, 3 stacked details, spec card.  
- [ ] Spec card text exact (incl. "(Youth Edition · Age 12+)", "(−80°C – 20°C)", "(12+ hrs)", and the 4 bullet modules).  
- [ ] Suit has: bubble helmet w/ cyan HUD, crimson collar ring, kimono wrap jacket, hex-crystal iridescent fabric, chest red-ring hub, backpack with crescent emblem \+ red ring, obi \+ lavender sash with crane \+ seigaiha, hakama trousers with glowing seams, platform boots with red buckles and glowing soles.  
- [ ] Lighting: pink-white key, red-magenta rims, cyan back fill, reflective floor, blurred mission-control hall.  
- [ ] Character is an original youth explorer; no real-person likeness.  
- [ ] All 5 spec systems playable as tests \+ module perk system works.  
- [ ] 3 EVA missions complete end-to-end.  
- [ ] 60 fps PC / 30 fps mobile; age rating review for 12+.