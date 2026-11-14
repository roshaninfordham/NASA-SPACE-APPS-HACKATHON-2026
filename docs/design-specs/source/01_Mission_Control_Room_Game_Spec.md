# RED VEIL — GAME 1: "MISSION CONTROL" (Interior 3D Sim)

**Source visual:** Oriental\_Mars\_Control\_Room\_with\_Cherry\_Blossoms\_final\_2.png **Genre:** First-person / third-person-orbit 3D operations sim \+ survival strategy **Goal:** The shipped game's opening room must be visually indistinguishable in composition, palette, lighting and UI text from the reference image.

---

## 0\. HOW TO USE THIS DOC

- Part A \= engineer spec (what to build, exact numbers).  
- Part B \= AI generation prompts (to create concept plates, textures, 3D models, UI art that match the image).  
- Part C \= acceptance checklist (compare in-engine screenshot to source image side-by-side).  
- Items marked **\[ASSUMED\]** are not readable/visible in the image; engineer should confirm with the art director (Joy).  
- Items marked **\[IMAGE GLITCH\]** are inconsistencies in the source image text; see §A9.

**Recommended stack:** Unity 6 (URP, HDRP optional for desktop-only) — or Unreal 5.4+ (Lumen). Web build alt: Three.js / React-Three-Fiber \+ postprocessing. Spec below is engine-agnostic; Unity terms used.

---

## PART A — ENGINEER SPEC

### A1. Game concept (one paragraph)

The player is the Mission Control operator of the Red Veil Mars Survival Lab on **Sol 042**. They stand/sit in a circular control atrium around a glowing holographic Mars globe and manage three live systems — **Environment (Mission Control)**, **Radiation Forecast**, **Life Support** — while crew out on the surface send requests. Wrong decisions drain O₂/H₂O/Power; right decisions keep the crew alive across sols. Educational layer: all values are plausible Mars science (-63 °C surface temp, \~0.32 mSv/day radiation, dust opacity, solar particle events).

### A2. Camera & player rig

| Mode | Spec |
| :---- | :---- |
| Default "Hero" camera | Fixed-start camera exactly matching the image: eye height **1.55 m**, position \~**9 m** back from room centre on the room's main axis, FOV **62°** (vertical), slight wide-angle feel, pitch ≈ **\-3°** (looking marginally down). The central globe cylinder sits at screen centre; "RED VEIL / MARS SURVIVAL LAB" sign at top centre, \~12% from top edge. |
| Gameplay camera | First-person walk (WASD \+ mouse / left-stick \+ right-stick), eye height 1.55 m, walk 1.4 m/s, run 2.6 m/s. Mars-gravity feel is NOT applied indoors (it's a pressurized, gravity-normalized interior — keep 1 g for comfort). |
| Seated mode | Click either white chair → camera glides (0.8 s ease-in-out) to seated eye height 1.15 m facing the globe; console touchscreens become reachable. |
| Orbit/inspect | Hold RMB on any hologram panel to enter "zoom to panel" (camera dollies to 0.9 m from panel, FOV 45°). |

### A3. Room layout (build in metres; origin \= centre of globe pedestal)

Build as a **circular atrium, \~22 m diameter, \~7 m ceiling at rim, \~9 m under the central drum**.

1. **Central hologram pedestal (the hero object)**  
   - Floor-standing glass cylinder: **diameter 5.2 m, height 5.5 m**, clear glass with faint grid lines (tiny pale-pink horizontal \+ vertical lines, 0.25 m spacing) and soft Fresnel edge glow (pink-white).  
   - Inside: a floating **Mars hologram sphere, diameter 2.6 m**, center at 2.4 m above pedestal floor. Surface \= translucent coral-red planet texture overlaid with a **geodesic wireframe network** (triangle mesh, nodes glowing hot white-pink at vertices, lines pale pink). Core glows brighter. Slow rotation **2°/s** around Y. Subtle vertical float ±0.05 m at 0.2 Hz.  
   - Base of the cylinder: a stepped round plinth, 2 concentric glowing rings (white-hot inner ring, red outer ring) on the floor, radii 3.2 m and 4.4 m. A soft pink bloom light-cone rises from base to the globe.  
   - Top of cylinder: connects into a **drum sign-ring**: a brushed-steel/white band, **diameter 6 m, height 1.1 m**, hanging from the ceiling. Text on band: **"RED VEIL"** (large) and **"MARS SURVIVAL LAB"** (small, below). White, thin geometric sans (see §A8), letter-spaced \+180. Flanked left and right by **seigaiha (wave) fan-scale patterns** embossed in steel with glowing rose-gold edge lines, 3 rows.  
2. **Ceiling**  
   - Concentric ring layers around the drum: (a) inner white emissive neon ring, Ø 8 m; (b) second white emissive ring Ø 11 m; (c) **crimson ring band with white/rose-gold sakura (cherry-blossom) branch motifs**, outer Ø 14 m, band width 1.6 m; (d) outer thin red neon ring Ø 17 m. All rings are curved panels (convex), glossy.  
   - Rings emit light: **white-pink emissive intensity \~6.0 (HDR)**, red rings **\~3.5**.  
3. **Walls (curved, organic "sweep")**  
   - Left: big **white-to-crimson ribbon wall** that swoops from floor to ceiling like a flowing silk band. Glossy lacquer: crimson (\#B0122A-ish) with white pearl strip along the edge, sharp specular highlights.  
   - Left wall has a **large oval porthole window** (**2.6 m wide × 1.5 m tall**, centre at 2.2 m height) looking out on a **real-time Mars landscape**: coral/rose desert, rocky hills mid-ground (silhouette of buttes), peach-pink hazy sky. Frame \= white pearl ring with a red inner lip. Window glass: slight reflection \+ dust-haze gradient (pink at horizon → pale peach).  
   - Right: tall **kumiko-lattice panels** (Japanese wooden-grid pattern but in dark red lacquer \+ glowing amber backlight) in a **balcony/mezzanine railing** that arcs along the top-right (rail height 1.1 m, at 3.5 m above floor). Below it, an **arched corridor doorway** (arch width 3.2 m, height 3.4 m) outlined in glowing orange-white neon, leading into a warmly lit hallway.  
   - Back wall (behind pedestal, right-of-centre): **kumiko-style arched alcoves** (2 tiers) displaying small potted plants / a **bonsai tree**, small ornaments, back-lit amber. Shelf lighting warm 2700 K.  
4. **Cherry blossom tree** — far right, in a white ceramic vase on the floor near the corridor arch: height 2.4 m, **pink-red blossoms** (instance \~1,800 flower cards with soft emissive 0.4), dark twisty branches. Gentle sway (wind noise 0.15 Hz). A few petals drift (GPU particles, 12 live max).  
5. **Lanterns** — Small **square kumiko lanterns** (0.35 m cube) with warm amber glow, placed on the floor around the right corridor and as **pillar bases under the console desk** (see below).  
6. **Floor** — Highly **polished reflective floor**, pearl-pink/silver (\#CFC2C3 base), roughness 0.12, with **three-to-four concentric glowing circle inlays** (thin white-hot lines, radii 5.5 / 7.5 / 9.5 / 11.5 m) and strong planar/SSR reflections of ceiling rings and consoles. Subtle large square tile seams (1.2 m).  
7. **Console desk (the "horseshoe")**  
   - A **curved horseshoe-shaped desk** wrapping 200° around the front of the pedestal, tabletop **white pearl/ceramic**, thickness 0.12 m, tabletop height 0.95 m, depth 1.3 m, outer radius 7.3 m.  
   - On the desktop: **9 tilted touch-screens** (each \~0.9 × 0.55 m, tilt 18° toward the seat), glass with rounded corners. They show cyan/teal UI: globes/wireframes, circular dials, waveform graphs, schematics (see §A7).  
   - Under the desk: the apron is hung with **backlit kumiko lattice panels** (amber glow, 0.8 m wide each) separated by dark red uprights. **Warm lantern-lit lattice towers** under the desk at 4 places.  
   - **Two white lounge chairs** at the front (player-side) — see §A6.

### A4. Large floating hologram screens (4 "hero panels")

Curved, glass-edged, translucent, **pink/white bevel**, dark teal-black interior with cyan UI. Each panel hovers \~0.3 m above the desk behind it, panels fan out in an arc around the pedestal.

| \# | Position (clock face around pedestal, facing camera \= 6 o'clock) | Size | Title / key text |
| :---- | :---- | :---- | :---- |
| P1 | far left (8–9 o'clock), tilted 25° inward | 3.0 × 2.0 m | **"MISSION CONTROL"** / **"SOL 042"** / 🌡 **TEMP −63 °C** / ☢ **RAD 0.32 mSv/day** / 〰 **DUST Low**; below: glowing cyan **terrain wireframe mountain range** graph |
| P2 | left-mid (10 o'clock) | 3.0 × 2.0 m | Dense dashboard: top title (small caps, mostly illegible at this scale — treat as **"ENVIRONMENT CONTROL"**) **\[ASSUMED\]**; centre: orange-red **Mars planet render** with HUD ring; left column of 8 red/white status dots \+ bars; bottom: **cyan bar chart (7 bars, rising then dipping)** |
| P3 | right-mid (2 o'clock) | 3.0 × 2.0 m | **"RADIATION FORECAST"**; red warning triangle ⚠; **"Next 72h: ELEVATED"**; small text **"(Solar Particle Risk 18%)"**; red/pink **rising line graph** with filled area underneath (trend rising toward right); footer **"SOL 042 – SOL 048"** |
| P4 | far right (3–4 o'clock), tilted 25° inward | 2.6 × 2.0 m | **"LIFE SUPPORT"**; three circular gauges (left column) with text: **O₂ 96%**, **H₂O 88%**, **⚡ 93%** (see glitch note); on the right a **cyan holographic astronaut wireframe** (full-body suit outline, standing pose) with glow |

### A5. Lighting recipe (critical to match the look)

- **Global mood:** Rose-champagne dawn palette. Everything bathed in **pink-white (\#FFD9D9 → \#FF8A8A)** with **crimson accents**; deep shadows are **wine-red/maroon (\#3B0A14)**, never pure black.  
- **Ambient / skybox:** Interior-only; no skybox except through the oval window (Mars exterior HDRI: dusty rose, sun low-left behind hills).  
- **Key emitters:** all ceiling rings (area lights, **colour 4500 K pink-white**), hologram sphere (point light, **\#FF7C8C**, range 12 m, intensity pulse 1.8–2.4 at 0.4 Hz), console screens (cyan **\#6FE6F2** area lights, low).  
- **Warm accents:** lanterns & lattice lights **2400–2800 K amber (\#FFB067)**.  
- **Reflections:** reflection probes at pedestal centre \+ 4 around desk; SSR enabled on floor. Floor reflection strength 0.75.  
- **Bloom:** threshold 1.0, intensity **0.9**, scatter 0.7, tint pale pink. **Anamorphic streaks** off.  
- **Colour grade:** Lift shadows toward maroon; contrast \+12; saturation \+8; split-tone highlights \= warm pink, shadows \= deep wine. Add **very subtle chromatic aberration (0.08)** at frame edges and light **vignette (0.18)**.  
- **Atmosphere:** volumetric haze, density very low (0.012), pinkish; light shafts from ceiling rings downward around pedestal.  
- **Hologram shading:** additive blend; **Fresnel rim power 3**; scanlines (1 px every 3 px, 4% opacity) on panels; slight flicker 0.5% at 8 Hz.

### A6. Chair spec (2 hero chairs)

- Sculpted **white lacquer shell**, organic curved back with a **red seigaiha (wave) fan pattern** inset on the upper back (3 concentric arcs repeated like overlapping scales, deep red on pearl-white). Seat: white leather-like, soft sheen. Base: a **single sweeping pedestal leg** in brushed steel/silver curving out, splayed 3-point foot.  
- Dimensions: seat height 0.46 m, back height 1.05 m, width 0.62 m.  
- Position: both chairs face the globe, **1.6 m apart**, placed on the inner side of the horseshoe desk. Left chair rotated 12° toward centre; right chair 8° toward centre.

### A7. Gameplay systems the engineer must implement

1. **Live Sol Clock**: 1 Sol \= 24 min of real time (accelerated; adjustable). Starts at **SOL 042, 06:00 local**.  
2. **Environment (P1/P2):**  
   - `Temp` starts **−63 °C**; diurnal swing ±35 °C (night min ≈ −95, day max ≈ −20). Updates every 5 s.  
   - `Radiation` starts **0.32 mSv/day**; spikes to **0.6–1.4** on solar events.  
   - `Dust` states: **Low / Medium / High / Storm**; affects solar power and visibility through porthole.  
3. **Radiation Forecast (P3):** 72-hour outlook with states **LOW / MODERATE / ELEVATED / SEVERE**, plus **Solar Particle Risk %**. Starts **ELEVATED, 18%**. Player must trigger "Close Radiation Shutters" and "Recall Crew" before risk window. Graph is a live line, area fill red→pink gradient.  
4. **Life Support (P4):** three resources start **O₂ 96 %, H₂O 88 %, Power 93 %**. Drain rates scale with crew count; recover via actions (ISRU electrolysis, ice-mining run, solar array tilt).  
5. **Crew Requests (event system):** every 90–180 s a crew radio request appears (text \+ voice): e.g., "EVA-2 requests dust-cover clearance" — player routes resources or approves/denies.  
6. **Hologram Globe (central):** click → opens "Site Map". Globe shows glowing nodes for the habitat, mining sites, landing zone; player drags to rotate and taps node to dispatch.  
7. **Fail/Win:** Fail if any resource \< 10 % for 120 s, or crew radiation dose cumulative \> threshold. Win by surviving to **SOL 048** (matches panel footer "SOL 042 – SOL 048") in the tutorial scenario.  
8. **Tutorial path:** 6 steps guided by a soft pink waypoint glow on each panel.

### A8. Typography & UI style

- **Wordmark "RED VEIL":** thin geometric sans (**Montserrat Light / Jost Light** equivalent), all caps, tracking **\+180**, white. Subline **"MARS SURVIVAL LAB"** in the same font, **Regular**, 35 % of wordmark size, tracking \+120.  
- **Panel headings** (MISSION CONTROL, RADIATION FORECAST, LIFE SUPPORT): **Rajdhani / Orbitron-light** style, white-cyan, small caps. Data numbers: bold, slightly larger, **tabular numerals**.  
- **UI palette:** cyan \#67E8F0 (primary data), teal-dark panel BG \#0B2A33 at 82 % opacity, white \#F5FBFF text, warning red \#FF3B4E, amber \#FFC15A, panel bevel pale pink \#FFD6DC.  
- Panel corner radius 14 px at 1080-tall reference; 2 px glass border with inner glow.  
- Icons are thin 2 px line style (thermometer, radiation trefoil, dust waves, warning triangle, oxygen ring gauge).

### A9. Known inconsistencies in the source image (decide, then lock)

1. Life Support gauges read **O₂ 96%**, **H₂O 88%** (shown as "H₂O" with garbled glyph), and a third labelled **O₂ 93%** next to a lightning icon. **Recommendation:** treat third gauge as **POWER 93 %** (lightning icon \= power). **\[IMAGE GLITCH\]**  
2. Radiation Forecast says **"Next 72h"** but footer range **SOL 042 – SOL 048** (≈ 6 sols ≈ 6 days). **Recommendation:** keep the label "Next 72h" for the alert and show "SOL 042 – SOL 048" as the chart X-axis span (the chart shows the 6-sol trend; the alert is the near-term headline).  
3. P2 title text is garbled in the image. Use **"ENVIRONMENT CONTROL"** **\[ASSUMED\]**.  
4. Image text on the panels' small print is AI-generated gibberish — replace with real data labels in-engine; keep same glyph density.

### A10. Audio

- **Ambience bed:** low HVAC hum 60 Hz bed \+ soft airy pad (bamboo flute / shakuhachi note every \~40 s, reverb 4 s). Subtle gong-like tone on alerts.  
- **UI sounds:** glassy "tink" on tap; rising chime on resource restored; two-note descending on warning.  
- **Globe:** low resonant drone with shimmer, pitch tied to rotation.  
- **Voice:** crew radio with light vocoder \+ static.

### A11. Performance budget (PC / high-end mobile)

- Target **60 fps @ 1080p desktop / 30 fps mobile**.  
- Triangles on screen ≤ **1.2 M** desktop / **350 k** mobile. Draw calls ≤ 800 / 250 (use GPU instancing for blossoms, lattice tiles, lanterns, ceiling tiles).  
- Textures: 2K for hero (pedestal, desk, chairs), 1K for props, 512 for UI atlases. ASTC/BC7.  
- Baked GI (lightmaps) for static architecture \+ real-time lights only for globe \+ screens. Reflection probes baked; SSR optional on mobile (fallback: planar reflection at half-res).  
- Hologram UI: render each panel to a **RenderTexture 1024×683** at 30 Hz.

### A12. Deliverables / asset list

1. `Atrium_Architecture.fbx` (ceiling rings, walls, arches, floor)  
2. `Hologram_Pedestal.fbx` \+ globe shader graph  
3. `Console_Horseshoe.fbx`, 9 tilted screens, lattice apron  
4. `Chair_White_Seigaiha.fbx` ×2 (one mesh, two instances)  
5. `Cherry_Blossom_Tree.fbx` \+ blossom atlas  
6. `Kumiko_Lantern.fbx` \+ lattice tileable texture (+emissive)  
7. `Mars_Window_Landscape` (terrain \+ sky dome, 4 km visible)  
8. UI: 4 hero panel prefabs \+ 9 console prefabs (UGUI/UI Toolkit)  
9. VFX: globe wire network, light shafts, petal particles, scanline overlay  
10. Audio kit as above  
11. Build: Windows/macOS \+ WebGL fallback (low spec)

### A13. Build order (suggested 6-week plan)

1. Wk1 — Blockout (scale-accurate), camera matching to hero shot.  
2. Wk2 — Architecture \+ floor \+ ceiling rings \+ lighting pass \#1 (compare to image).  
3. Wk3 — Pedestal, globe, desk, chairs, lanterns, tree.  
4. Wk4 — UI panels \+ systems (Sol clock, resources, forecast).  
5. Wk5 — Events, tutorial, audio, VFX polish, colour grade.  
6. Wk6 — Optimisation, QA, side-by-side match review.

---

## PART B — AI PROMPTS (for concept plates, textures, models)

> Use these in Midjourney / Flux / Imagen / Meshy / Tripo / Rodin etc. Always append the **STYLE LOCK** below.

**STYLE LOCK (append to every prompt):** `Red Veil visual identity: futuristic Mars lab fused with East-Asian (Japanese/Chinese) craft; palette crimson #B0122A, pearl white, rose gold, blush pink, warm amber lantern glow, cyan holographic UI; glossy lacquer + pearl-ceramic materials; soft pink bloom lighting, wine-red shadows; cinematic, hyper-detailed, 8k, Octane/Unreal render look, no text artifacts`

**B1 — Hero room concept plate (reference matching)** `Wide interior of a futuristic Mars survival lab mission control atrium, circular room, central floor-to-ceiling glass cylinder containing a floating holographic Mars globe with a glowing geodesic wireframe network, hanging white steel sign-drum above reading "RED VEIL – MARS SURVIVAL LAB" with seigaiha wave patterns, concentric glowing white and crimson ceiling rings with rose-gold cherry blossom engraving, curved crimson lacquer wall ribbon with an oval porthole showing a rose-pink Mars desert, kumiko lattice balconies and arched corridor with glowing orange neon outline, bonsai alcoves, blooming cherry blossom tree in white vase on the right, polished pearl-pink reflective floor with glowing concentric circle inlays, horseshoe white ceramic console desk with nine tilted cyan touchscreens, four large floating curved hologram screens (MISSION CONTROL SOL 042 TEMP -63°C RAD 0.32 mSv/day DUST Low; radiation forecast graph; life support gauges with holographic astronaut), two white lacquer lounge chairs with red seigaiha wave back pattern and single curved steel leg, warm paper lanterns under desk, 24mm lens, eye-level, symmetrical composition` \+ STYLE LOCK

**B2 — Seigaiha chair (image→3D / turntable)** `Single sculpted futuristic lounge chair, white pearl lacquer shell with organic curved back, upper back inlaid with red seigaiha wave fan pattern, soft white leather seat, one sweeping brushed-steel pedestal leg with three splayed feet, studio turntable on pearl-pink floor, front/side/back/3-quarter views, neutral soft lighting` \+ STYLE LOCK

**B3 — Central hologram pedestal** `Floor-standing transparent glass cylinder 5m wide, inside it a floating translucent coral-red Mars sphere covered in glowing geodesic triangular wireframe with white-hot nodes, pink volumetric light cone from base, stepped circular plinth with two concentric emissive rings (white and red), top joined to steel band with seigaiha patterns` \+ STYLE LOCK

**B4 — Kumiko lattice tileable (texture)** `Seamless tileable Japanese kumiko lattice panel, dark red lacquer wood geometric grid, amber backlit glow through the gaps, albedo + emissive + normal + roughness maps, 2048px` (no STYLE LOCK text rules; keep palette only)

**B5 — Seigaiha pattern (texture)** `Seamless tileable seigaiha wave pattern, crimson on pearl white, plus rose-gold embossed version, flat top-down, albedo + normal + height maps, 2048px`

**B6 — Cherry blossom bonsai/tree** `Stylised blooming cherry blossom tree in a white ceramic vase, dark twisted branches, pink-red blossoms with soft emissive glow, game-ready asset, orthographic turntable`

**B7 — Holographic UI sheet (for UI team)** `Futuristic holographic dashboard panels, dark teal glass with pale pink bevel edge, cyan line UI: terrain wireframe graph, circular gauge dials, red rising line chart with warning triangle, astronaut wireframe, bar charts; clean legible text 'MISSION CONTROL', 'SOL 042', 'RADIATION FORECAST', 'LIFE SUPPORT'` (generate once, then **rebuild text natively in-engine**)

**B8 — Mars window vista** `Panoramic Mars desert at dusk, rose-coral sand, mid-distance rocky buttes, hazy peach-pink sky, soft sun low on horizon, seen through an oval window, matte painting, 16k HDRI, no sky features other than dust haze`

---

## PART C — ACCEPTANCE CHECKLIST (side-by-side with source)

- [ ] Hero camera frame matches: sign top-centre, globe centred, desk horseshoe spans lower third.  
- [ ] All 4 hero panels present with exact text from §A4.  
- [ ] Palette sampling: dominant crimson/pearl/rose-gold; no neutral greys; cyan only on screens.  
- [ ] Ceiling has 4 concentric ring layers with sakura band.  
- [ ] Floor shows reflections and concentric circle inlays.  
- [ ] Kumiko lattice backlit amber on desk apron, right balcony, alcoves.  
- [ ] Chairs show seigaiha red back pattern \+ single steel leg.  
- [ ] Cherry blossom tree \+ bonsai present.  
- [ ] Mars window landscape visible on left in oval.  
- [ ] Game systems run: Sol clock, 3 resources, forecast alert, crew requests.  
- [ ] 60 fps at target spec.