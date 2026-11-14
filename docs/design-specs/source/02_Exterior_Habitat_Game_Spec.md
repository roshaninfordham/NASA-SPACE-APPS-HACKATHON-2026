# RED VEIL — GAME 2: "HABITAT: FIRST LIGHT" (Exterior Explore \+ Base-Build 3D Game)

**Source visual:** Red\_Veil\_Mars\_Survival\_Lab\_exterio\_final\_2.png **Genre:** Third-person open-area exploration \+ light base-building/maintenance survival, with a walk-in transition to Game 1's interior **Goal:** The opening scene must match the image's silhouette, lighting (rose-gold Martian dusk), materials and callout hotspots exactly.

---

## 0\. HOW TO USE THIS DOC

- Part A \= engineer spec. Part B \= AI generation prompts. Part C \= acceptance checklist.  
- **\[ASSUMED\]** \= not visible in the image; confirm with Joy.  
- Stack: Unity 6 URP (or Unreal 5.4+). Web alt: Three.js/R3F. Units in metres.

---

## PART A — ENGINEER SPEC

### A1. Concept

The player (a youth explorer in the Red Veil suit, see Game 3\) arrives at the **Red Veil Mars Survival Lab** at golden dusk. They walk the glowing path to the **AIRLOCK**, learn how each part of the habitat protects people (the four callouts in the image become interactive "Inspect" hotspots), repair and upgrade the shell against dust, thermal swings and radiation, and survive a rolling set of Martian weather events (dust gusts, solar particle alerts, night freeze). Entering the airlock loads Game 1's Mission Control interior.

### A2. Hero shot (must match)

- **Hero camera**: low, 3/4 view from the front-left. Position ≈ **(−16, 1.7, −22)** relative to dome centre (0,0,0), looking at the dome centre; FOV **38°** (telephoto-ish compression), pitch **\+3°** (slightly up).  
- **Composition:** Airlock tunnel in left-foreground; main dome mass occupies centre/right; two moons upper-left; satellite dish upper-right; glowing curved path sweeps from bottom-left toward the airlock; foreground red rocks bottom edge slightly out of focus (DoF f/2.8).  
- **Logo "RED VEIL – MARS SURVIVAL LAB"** top-left, white, thin, spaced (UI overlay in title screen; with a small **arc of light** over the "RED VEIL" word — a thin glowing rose-gold orbit curve, like a sunrise rim).  
- 3 leader-line callouts at right (see A8).

### A3. Terrain & sky

1. **Terrain:** Heightmap 2 × 2 km, playable radius **350 m** around the habitat; the rest is vista. Surface colour **rust-coral (\#B4573F) → rose (\#C9806E)** with darker iron-oxide pockets (\#7B3A2E). Rocky outcrops (1–6 m) scattered, denser at bottom foreground and on the far right. Soft rolling hills in the background, **layered atmospheric perspective** (three bands: near coral, mid dusty-rose, far mauve-lilac \#8A5C70).  
2. **Habitat pad:** flat 60 × 45 m platform; **regolith berm** (a mounded embankment) hugging the right/rear half of the dome up to \~**2.2 m** height at the foot of the observation windows, sloping out over \~6 m.  
3. **Sky:** Gradient dusk: horizon peach-gold (\#F6A877) → rose (\#E58A8E) → mauve (\#B66E86) → dusty plum (\#8A5A78) at top. Thin cirrus-like dust streaks left side. **Two moons** (Phobos & Deimos-style) upper-left: large moon **angular diameter \~3.5°** (crescent-lit, partial phase, pale cream-pink, mottled craters), small moon \~1.2° lower-right of it, lit crescent too. Sun is **low, behind-left of camera**, casting long raking shadows toward the right/forward.  
4. **Atmosphere:** exponential height fog density 0.004, colour \#E9A08C, scattering stronger toward sun. Dust motes particles (low density) drifting left→right at 0.6 m/s; occasional gust events spike wind.

### A4. The Habitat (precise geometry)

The habitat is a **cluster of smooth organic domes** — a large main dome, a stepped second shell, a smaller third shell, a top cupola — fused with a **cylindrical airlock tunnel** on the left. Everything is clad in **pearl-white composite plates with crimson lacquer ribbon panels and rose-gold line ornament**.

| Element | Dimensions | Notes |
| :---- | :---- | :---- |
| **Main dome mass** | 36 m long × 24 m wide × 11 m high | Asymmetric blob form, not a hemisphere. Flowing "silk-ribbon" shell layers wrap diagonally. |
| **Layer stack** | 3 stacked shell tiers, each stepping back \~2 m | Each tier edge has a **glowing orange-white neon seam** (emissive \~4.0) tracing the curve. |
| **Top cupola** | Ø 7 m, 2.2 m tall, centre-top, slightly offset left | Ringed vents, with **2 thin antenna masts (11 m and 8 m)** \+ 3 small whip antennas; a **parabolic satellite dish** Ø 3.6 m on a 5 m pylon, right of the cupola, tilted 35° skyward, rotating slowly toward the moons (yaw 1.5°/s, idle sway). |
| **Observation window \#1 (large)** | 11 m × 4.8 m oval, at lower-front | Shows interior: the **glowing pink Mars hologram globe** in the central cylinder, wall-screens with cyan graphs, desks and chairs (it IS the room from Game 1, rendered as a cheap interior proxy: baked cubemap \+ a few emissive cards). Frame: red lacquer ring with a **kumiko lattice** pattern on both short ends of the oval. |
| **Observation window \#2 (medium)** | 6 m × 3.2 m oval, right of \#1 | Interior: a **lounge with sofa**, a **red cherry blossom tree**, pendant lamp globe (warm). Kumiko lattice sides. |
| **Observation window \#3 (small, upper)** | 5 m × 1.8 m oval, upper tier | Shows lattice-screened interior, warm amber. |
| **Lower service vent** | 7 m long slot at the base right | A slim glowing **horizontal orange slit** under the berm edge (thermal vent) — emissive 3.0. |
| **Airlock tunnel** | Ø 6.2 m, length 9 m (3 ring segments) \+ 2nd stub segment behind at left (Ø 5 m), semi-hidden | Cylinder shell in **brushed rose-gold/champagne metal (\#C9A58E, metallic 0.9, roughness 0.35)** with **riveted panel seams** and a **carved lattice/key-fret motif** around the door arch. |
| **Airlock door** | Round-arched double door, 3.6 m wide × 4.2 m tall | Dark bronze-rose recessed door with text **"RED VEIL / MARS SURVIVAL LAB"** (small, upper), **"AIRLOCK"** (centre), and below it a **round endless-knot (mystic-knot/Chinese-knot) emblem** in rose-gold. Two **square lanterns** (0.5 m) mounted on each side of the arch, warm amber glow, with an extra pair on the ground (railing posts). |
| **Entry ramp/path** | 3.6 m wide, 40 m long | Smooth **pearl-grey/pink glossy tiles** (reflective, roughness 0.15) with **continuous glowing rose-gold edge strip** (emissive 3.5) running the entire left edge and the curved right edge; path curves from bottom-left foreground (camera) up toward the airlock. Reflects sky \+ lantern glow. |
| **Path lanterns** | 0.45 m lantern cubes at 6 m spacing | Kumiko cube, **amber glow (2400 K)**, light range 5 m, alternating sides; plus 2 chunkier stair-rail lanterns near the door. |
| **Safety railings** | thin steel, 1 m high, at the airlock approach | Left of door. |

**Shell surface design (make from shader \+ decals):**

- **Pearl white panels**: slightly iridescent (thin-film shift pink↔cream), roughness 0.25, subtle panel seams every 1.4 m following curvature.  
- **Crimson lacquer bands** (\#A8102A, clearcoat 1.0, roughness 0.08): sweeping ribbons 1.6–2.4 m wide, with **glowing edge trim** (rose-gold \+ orange) on both edges.  
- **Ornament decals (rose-gold/white, hand-drawn line style):**  
  - **Sakura (cherry blossom) branches** on the upper crimson bands: 5-petal flowers 0.3–0.5 m wide, curved branch lines, spaced irregularly. Flowers have a faint inner glow (emissive 0.6).  
  - **Seigaiha (wave arcs)** on the white zones near the windows and right-side lower band: concentric arcs in rose-gold.  
  - All ornaments in **metallic gold-pink (\#E9B8A0)**; engrave with normal-map depth 0.4 mm equivalent.  
- **Window glass:** multi-layer look \= outer glass with reflection (sunset tint) \+ inner warm light; **closable radiation shutters** (see A6) slide from top.

### A5. Lighting recipe

- **Sun (directional):** colour **\#FFB38A**, intensity **3.2**, elevation **8°**, azimuth behind-left of hero camera. Soft shadows (long, \~14 m shadow length per 1 m height), penumbra 1.2°.  
- **Sky ambient:** gradient ambient: top \#8A5A78, equator \#D98B88, ground \#6B3B3B; intensity 1.1.  
- **Habitat self-light:** emissive neon seams (orange-white \#FFC892, HDR 4.0); lanterns (amber \#FFAA5C, point, range 5 m, intensity 2.5); interior windows glow (area emissive 1.5, colours: pink for globe room, amber for lounge).  
- **Reflection probe** at path centre; SSR on path tiles and window glass; shell reflects sky/moons.  
- **Post:** Bloom threshold 0.95, intensity **1.1**, scatter 0.75, tint \#FFC7A8 (strong glow on neon seams and lanterns); **Colour grading**: lift shadows toward magenta-brown (\#4A1F2C), warm highlights, saturation \+10, contrast \+10; **filmic tonemapper (ACES-like)**; **vignette 0.2**; slight **film grain 0.05**; **DoF** active in cinematics only.  
- **God-rays:** sun shafts through dust haze on left; subtle.

### A6. Gameplay systems

1. **Movement:** third-person; walk 1.5 m/s, sprint 3.0 m/s (suit-limited), **Mars gravity 3.71 m/s²** → jump height ≈ 1.1 m, long arcs; footprint decals in regolith (fade 40 s).  
2. **Habitat Integrity (the core loop):** habitat has 4 integrity meters mapped to the image's callouts:  
   - **Shell** (Habitat Dome): *Pressurized Habitat / Radiation-Shielded Shell / Thermal Insulation / Dust Protection* → 4 sub-bars.  
   - **Glazing** (Observation Windows): *Multi-Layer Shielded Glazing with Closable Radiation Shutters* → integrity \+ shutter state (OPEN/CLOSED).  
   - **Berm** (Regolith Shielding, Partial Berm): *Adds Radiation Protection and Thermal Stability* → player **shovels/robot-bulldozes regolith** (mini-game: drag regolith with a rover blade to build up berm height, target 2.2 m; each \+0.3 m \= \+8 % radiation protection, \+6 % thermal stability).  
   - **Airlock**: seals wear down with dust; player cleans with air-jet tool; entering costs 20 s cycle (pressurize animation: lanterns pulse, door cycles).  
3. **Weather director:** random events every 3–6 min: **dust gust** (visibility ↓, solar power ↓, dust accumulation on panels → player must clean), **solar particle alert** (siren; close radiation shutters; get indoors in 90 s), **night freeze** (temp drops to −90 °C; lanterns auto-brighten; suit heater drain), **meteorite sparkle** (cosmetic).  
4. **Day/night:** 1 sol \= 30 min real time; golden-dusk start (hero look at 17:40 local). Night: stars \+ two moons brighter; neon seams get brighter (post exposure −1).  
5. **Hotspots (interactive Inspect callouts):** when the player looks at a part for 1 s, a **thin leader line \+ title \+ 3–4 lines of text** animates in (same style as image). Press E to open a 3D cutaway (see A8). Learning data unlocks upgrade points.  
6. **Upgrades (tech tree):** Thicker regolith berm · Aerogel insulation · Electrostatic dust shield · Photochromic shutters · Extra lantern lights (cosmetic) · Larger dish.  
7. **Entry:** at the airlock, E to enter → pressure-cycle cinematic (8 s) → loads **Game 1 interior**.  
8. **Win:** keep Habitat Integrity \> 60 % through 7 sols and complete the 4 callout lessons.

### A7. Camera modes

- **Explore** (third-person, 5 m behind), **Inspect** (orbit around a part, FOV 35°), **Photo mode** (free cam, DoF, filters: "Red Veil Dusk", "Night Lanterns", "Clean Blueprint"), **Title cinematic** (dolly from hero shot, 12 s, slow 1.2 m/s move).

### A8. UI & callout typography (match the image exactly)

Callout lines: **thin 1.5 px white line**, with a small dot at the part end (Ø 6 px) and an angled elbow, ending at a text block on the right edge.

- **Callout 1 — "HABITAT DOME"** (title, all caps, white, medium weight, \~22 px @1080p): text lines (small, regular, 16 px, white 90 %): *Pressurized Habitat / Radiation-Shielded Shell / Thermal Insulation / Dust Protection* → leader line points to the upper right of the dome (shell panel).  
- **Callout 2 — "OBSERVATION WINDOWS"**: *Multi-Layer Shielded Glazing with Closable Radiation Shutters* → leader to the right-end of window \#2.  
- **Callout 3 — "REGOLITH SHIELDING"** \+ sub "(Partial Berm)": *Adds Radiation Protection and Thermal Stability* → leader to the mounded soil at lower right.  
- **Logo** top-left: **RED VEIL** (wide tracking \+220, thin, white, \~46 px) with rose-gold orbit arc over the word; **MARS SURVIVAL LAB** below (tiny, tracking \+300, 11 px).  
- Typeface: **Jost / Montserrat Light** \+ **Inter** for body. Text shadow: 0 0 6 px rgba(60,10,20,0.6) for legibility on sky.

### A9. Audio

- Wind bed (low, hollow), high-frequency dust hiss at gusts.  
- Footsteps on **crunchy regolith** vs **glossy tile "tick"** on the path.  
- Habitat hum \+ gentle pad; shakuhachi/koto motif every \~60 s; lantern light "tinkle" when approaching.  
- Airlock: hiss, thunk, rotating bolts, bell chime.  
- Alerts: soft two-tone siren (not harsh) for solar particle alert.

### A10. Performance budget

- PC 60 fps@1080p; mobile 30 fps. Tris on screen ≤ **1.5 M** PC / **400 k** mobile.  
- Habitat meshes: 280 k tris (LOD0), LOD1 90 k @ 40 m, LOD2 25 k @ 120 m.  
- Terrain: CDLOD/GPU tessellation; rocks instanced (3 variants × 3 LODs, 2,500 instances).  
- Interior through windows: use **interior mapping / baked cubemap proxy** (cost \~0), swap to real interior only inside the airlock.  
- Emissive lanterns use **fake light cookies** beyond 20 m (no real-time light).  
- Texture sets: Habitat shell 4K (trim sheet), airlock 2K, path 2K, rocks 2K atlas.

### A11. Deliverables

1. `Habitat_Main.fbx` (3 shell tiers \+ cupola \+ windows \+ berm geometry) \+ trim sheet  
2. `Airlock_Tunnel.fbx` \+ door \+ emblem  
3. `Path_Tiles` modular kit \+ edge-light strip  
4. `Lantern_Kumiko.fbx` ×2 sizes  
5. `Dish_And_Antennas.fbx`  
6. Terrain \+ rock kit \+ regolith shader (with deformation mask for berm mini-game)  
7. Sky shader with 2 moons (phase-lit crescents, **Phobos/Deimos-like**; NOT Earth's Moon look)  
8. Decal sets: sakura, seigaiha, knot emblem, panel seams  
9. Window interior proxy cubemaps (×3)  
10. UI: logo lockup, callout system, hotspot prefab  
11. Weather director \+ integrity systems  
12. Audio kit

### A12. Build order (6 weeks)

1. Wk1: Terrain, hero-camera blockout, sun/sky match.  
2. Wk2: Habitat main mesh \+ airlock \+ path; first lighting pass.  
3. Wk3: Materials (pearl, lacquer, rose-gold), decals, neon seams, lanterns.  
4. Wk4: Windows with interiors, dish/antennas, moons, atmosphere, post stack.  
5. Wk5: Gameplay: movement, hotspots, integrity, weather, berm mini-game.  
6. Wk6: Airlock transition to Game 1, audio, optimisation, side-by-side matching.

---

## PART B — AI PROMPTS

**STYLE LOCK (append to every prompt):** `Red Veil visual identity: futuristic Mars lab fused with East-Asian (Japanese/Chinese) craft; palette crimson #A8102A, pearl white, rose-gold, blush pink, rust-coral Mars terrain, warm amber lantern glow, cyan holographic UI; glossy lacquer + pearl composite materials; golden dusk rose-peach sky, long soft shadows; cinematic, hyper-detailed, 8k, Unreal Engine 5 render, no text artifacts`

**B1 — Hero exterior plate** `Futuristic Mars habitat at golden dusk, smooth organic multi-tier dome clad in pearl-white panels with sweeping crimson lacquer ribbons edged by glowing orange neon seams, rose-gold sakura cherry blossom branches and seigaiha wave ornament engraved on the shell, large oval observation windows with kumiko lattice ends showing a glowing pink hologram globe room and a lounge with a red cherry blossom tree inside, cylindrical rose-gold airlock tunnel on the left with round arched door reading "AIRLOCK" and "RED VEIL MARS SURVIVAL LAB" and a mystic-knot emblem, square amber kumiko lanterns, glossy tiled path with glowing rose-gold edge strip curving to the door, partial regolith berm at lower right, satellite dish and thin antenna masts on top, rust-coral rocky terrain, two crescent-lit Martian moons in a peach-to-mauve sky, low sun raking light, telephoto 38mm, shallow depth of field foreground rocks` \+ STYLE LOCK

**B2 — Airlock close-up (model ref)** `Round arched Mars airlock door in a champagne rose-gold metal cylinder tunnel, carved lattice key-fret border, riveted panel seams, amber square lanterns either side, recessed bronze-rose double doors with a mystic-knot emblem, front orthographic + 3/4` \+ STYLE LOCK

**B3 — Shell trim sheet (texture)** `Game trim sheet 4096px: pearl-white composite plates with thin-film iridescence, crimson lacquer clearcoat bands, rose-gold embossed sakura branches, seigaiha arcs, glowing orange neon seam strips, panel seam lines, rivets; PBR albedo/normal/roughness/metallic/emissive`

**B4 — Dusk sky \+ moons (HDRI/skybox)** `Mars dusk sky panorama, gradient from peach-gold horizon through rose and mauve to dusty plum, wispy dust streaks, two small irregular potato-shaped moons Phobos and Deimos as lit crescents, soft haze, 16k equirectangular, no clouds like Earth`

**B5 — Terrain/regolith textures** `Seamless Mars regolith ground, rust-coral fine dust with darker iron-oxide gravel and small rocks, PBR set 2048px, plus rock cliff set, tileable`

**B6 — Lantern** `Square Japanese kumiko lattice lantern, dark red lacquer frame, warm amber inner glow, 0.4m cube, game-ready with emissive map`

---

## PART C — ACCEPTANCE CHECKLIST

- [ ] Hero camera frame matches (airlock left-foreground, dome centre/right, dish upper-right, moons upper-left).  
- [ ] Three callouts show exact text from §A8 with leader lines.  
- [ ] Shell: pearl \+ crimson ribbon \+ glowing orange seams \+ sakura \+ seigaiha ornaments visible at hero distance.  
- [ ] 3 oval windows with proxy interiors (hologram globe room; lounge \+ red tree; lattice upper).  
- [ ] Airlock door text "RED VEIL / MARS SURVIVAL LAB / AIRLOCK" \+ knot emblem.  
- [ ] Path: glossy tiles with glowing rose-gold edge and amber lanterns.  
- [ ] Regolith berm at lower right, 2.2 m peak.  
- [ ] Sky gradient \+ two crescent moons; long raking shadows.  
- [ ] Weather director, integrity, berm mini-game, airlock → Game 1 loading all work.  
- [ ] 60 fps PC / 30 fps mobile.