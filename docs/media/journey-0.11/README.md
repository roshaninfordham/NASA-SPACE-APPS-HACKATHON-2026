# Native journey screenshots

These are actual Godot screenshots of the stationary-cleaning journey in `game/main.tscn`. The first scene preparation has a real cancellable loading state. Ren starts cleaning only after START MISSION. Three main readings show cleaned fraction, stored energy and remaining play time; the default Science window restores the outpost frame and all eight live scientific bubbles. View & accessibility offers a larger Focused window while retaining Science access. Reading a concept pauses the mission. The operator chooses a pace with slower/faster buttons or the stepped slider; faster work builds an authored game-fatigue indicator. The default round lasts 90 active-play seconds, compressing 30 simulated minutes; at the countdown's end Ren steps directly inside. The visible panel clears dust continuously from the mission model.

![Native game contact sheet](contact-sheet.png)

| Screen                                                         | Resolution |
| -------------------------------------------------------------- | ---------- |
| [Story](story-desktop.png)                                     | 1280 × 720 |
| [Control room · before Start](preflight-desktop.png)           | 1280 × 720 |
| [Microgray science card](concept-desktop.png)                  | 1280 × 720 |
| [Window frame, eight live ideas and pace](mission-desktop.png) | 1280 × 720 |
| [Immediate mission result](debrief-desktop.png)                | 1280 × 720 |
| [Portrait mission](mission-portrait.png)                       | 390 × 844  |
| [Optional science library](preparation-desktop.png)            | 1280 × 720 |
| [Story · meet the crew](story-crew-desktop.png)                | 1280 × 720 |
| [Story · your control room](story-control-desktop.png)         | 1280 × 720 |
| [Eight ideas combine](bubble-merge-desktop.png)                | 1280 × 720 |
| [Four visual science connections](science-desktop.png)         | 1280 × 720 |
| [Cancellable scene preparation](loading-desktop.png)           | 1280 × 720 |
| [Optional discovery library](discovery-desktop.png)            | 1280 × 720 |
| [Home](home-desktop.png)                                       | 1280 × 720 |
| [Optional destinations](more-desktop.png)                      | 1280 × 720 |
| [NASA context · offline fixture](nasa-context-desktop.png)     | 1280 × 720 |
| [View and accessibility](view-menu-desktop.png)                | 1280 × 720 |
| [Focused window](focused-window-desktop.png)                   | 1280 × 720 |
| [Settings returns to View](settings-view-return-desktop.png)   | 1280 × 720 |
| [Settings returns to Pause](settings-pause-return-desktop.png) | 1280 × 720 |
| [Settings returns to Home](settings-home-return-desktop.png)   | 1280 × 720 |
| [Small phone science window](mission-small-phone.png)          | 320 × 568  |
| [Short landscape science window](mission-landscape.png)        | 844 × 390  |
| [Portrait focused window](focused-window-portrait.png)         | 390 × 844  |

The capture fixture uses normal screen intents, then advances the actual model to repeatable points. The mission image follows explicit Start, 18 active-play seconds at steady cleaning plus 24 at 1.25×: 1.9 cleared sections and 16% game fatigue. The debrief follows 48 further active seconds at normal pace and automatic shelter entry: 3.58 cleared sections (WIN), with 10.9375 µGy accumulated model dose. There is no recall or walking mission; pace commands produce scripted radio captions. Results appear immediately. Selecting “See how science connects” animates the eight ideas together before revealing four clickable visual science connections; the transition screenshot holds the real shell animation at 0.35 seconds. Optional details reveal the full word equations, exact numerical equations, history graphs and transfer question. The NASA viewer capture uses its explicitly labeled bundled image with online requests disabled; it is not evidence of a fresh observation. All values come from the model; no result summary is fabricated. The scene is illustrative and does not establish physical panel dimensions or human work-rate measurements. Battery energy stored now uses kWh; power generation and habitat load use kW. The rising radiation profile and game fatigue are authored teaching assumptions, not live NASA radiation data or personal health readings.

Captured with Godot's Linux compatibility renderer under authenticated Xvfb/Mesa. This checks native composition at desktop, portrait and short-landscape sizes. It does not establish Mac/Windows installation, mobile-device performance, audio quality, live update acceptance or real-time player usability. Audio output is muted only in the capture fixture, and user data is isolated.

`capture-provenance.json` records the source SHA-256 hashes, image hashes, actual model snapshots and fixture actions. The contact sheet contains only scaled native screenshots with external labels. The full QA run also captures all three story beats, cancellable loading, preflight, steady/faster cleaning, live concepts, pause, settings, storm countdown, automatic entry, the immediate result, the eight-bubble transition, four visual science connections, optional graphs, the learning-transfer question the return to results, the discovery library, offline NASA context and expanded connection details, View & accessibility, Focused window, Settings return routes to View/Pause/Home, Home and More at 1280×720, 960×540, 390×844, 320×568 and 844×390.

Reproduce from the repository root (Godot, Xvfb and Pillow required):

```sh
python3 scripts/capture_journey.py --output /tmp/komaku-journey-capture --publish-to docs/media/journey-0.11
```

Use `--xvfb /path/to/Xvfb` if Xvfb is not on `PATH`. Publishing rejects any run with geometry findings or source changes during capture.
