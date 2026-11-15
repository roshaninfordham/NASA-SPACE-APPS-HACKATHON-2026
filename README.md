# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

**Explore the science. Make a plan. Bring your crewmate home.**

A Mars learning game for ages 7–12, built with Godot. You are inside mission control, looking through a quiet window at the dunes and an astronaut outside. The design combines a clear, accessible interface with restrained Asian-inspired craft details.

[![Validation](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/workflows/validate.yml/badge.svg)](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/workflows/validate.yml)

**Release source snapshot: 0.8.0-alpha.1.** Prepared November 15, 2026, America/New_York. Publication was pending when this source snapshot was prepared; check the [release index](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases) for available files and the final acceptance record. A versioned source document alone is not proof of publication.

![Journey prototype captures; final pace-workflow media pending](docs/media/journey/contact-sheet.png)

[Gameplay screenshots](docs/media/journey/README.md) · [Live NASA observation](docs/media/journey/LIVE-SUN.md) · [30-second pitch](docs/VIDEO-PITCH.md)

## The 0.8 journey

1. **A short cosmic opening:** Year 2059, Planet Mars, with optional sound and reduced motion.
2. **Control-room preflight:** inspect the science bubbles and choose Ren's starting pace. Nothing advances until **START MISSION**. The science constellation is optional; reading all eight cards is not required.
3. **A five-minute default mission:** slower/faster controls and a stepped slider adjust requested cleaning pace. Fictional fatigue affects effective work. At 30 simulated minutes Ren automatically enters the nearby shelter. Reading and Pause freeze the whole model.
4. **Result and equations:** see actual cleaned fraction, battery energy and model dose, then try another plan. WIN means at least 80% cleaned, PASS at least 40%, and LOSE less than 40%.

| Relationship                                      | What it teaches                                                          |
| ------------------------------------------------- | ------------------------------------------------------------------------ |
| Requested pace and fictional fatigue → work       | A higher setting can yield less cleaning after fatigue builds.           |
| Cleanliness → solar generation                    | Partial dust removal changes output immediately.                         |
| Integrated generation minus load → battery energy | kW and kWh are different quantities; the result is actual stored energy. |
| Integrated authored radiation rate → model dose   | Exposure depends on time and rate, not on the cleaning slider itself.    |

Pace ranges from 0.25 to 1.75 in steps of 0.25. Effective work is `0.125 × pace × (1 − fatigue)` sections per simulated minute. The historical 210 µGy/day reference is multiplied by an authored rising curve; every completed default round has the same **10.9375 µGy** dose. There is no dose bonus, Sv conversion or medical risk score. The final workflow has no recall, walking route or future-energy reserve target.

**Controls:** 1 = slower, 3 = faster, Enter = Start in preflight, Escape = contextual Back/Pause, F11 = fullscreen. Shared theme, science content, audio, navigation and model components keep visual changes separate from the rules. The older operator/EVA/lab activities remain under **Advanced lab · earlier mission**, with distinct rules.

The [independent pace-model audit](docs/evidence/pace-model-0.8-audit.json) is recorded; final captures, controller and release acceptance remain pending until their evidence is updated. [Model](docs/TRAINING-MODEL.md) · [Journey contract](docs/design-specs/JOURNEY-0.8.md) · [Team status](docs/TEAM-STATUS.md) · [Roadmap](docs/ROADMAP.md).

## Download this version

Release assets contain the runnable game; the GitHub Packages tab is not needed. The links below target **0.8.0-alpha.1** and become available only after publication. Check the [release index](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases) if a link is not yet live; do not infer availability from a filename.

| Platform or document                    | Versioned asset — available once published                                                                                                                                         |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Apple Silicon, including M5 / Intel Mac | [macOS universal ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-macOS-universal.zip) |
| Windows x64                             | [Windows ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Windows-x64.zip)             |
| Linux x64                               | [Linux ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Linux-x64.zip)                 |
| WebGL2 browser                          | [Web export ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Web.zip)                  |
| Guide accompanying 0.8                  | [Versioned science PDF](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.8.0-alpha.1/KOMAKU-Shield-Protocol-0.8.0-alpha.1-Science-Guide.pdf) |

Extract the whole ZIP and read `START-HERE.txt`; native players need no editor or developer tools. **Mac is ad-hoc signed without Apple Developer ID or notarization; Windows is unsigned.** The Mac archive includes a consent-based installer helper for a trusted download. It verifies integrity and changes quarantine only on the installed copy. The native hosted launch gates for 0.7.1 passed; that does not establish performance on every physical M5, PC, or graphics driver. [Installation instructions](docs/DOWNLOADS.md) · [Mac repair](docs/MACOS-LAUNCH-REPAIR.md) · [0.7.1 evidence](docs/evidence/release-0.7.1-alpha.1.json).

No production Android or iOS native installer is published. Web exports require HTTP(S) hosting and WebGL2. Public hosting remains deferred by owner choice; a cross-platform engine does not remove iOS distribution requirements.

Historical mission screenshots and performance evidence remain in the [media gallery](docs/MEDIA.md) and [0.7.1 measurements](docs/WINDOW-STARTUP-PERFORMANCE.md); they are distinct from the current journey.

## Updates from inside the desktop game

Compatible desktop content follows **Update available → Install → Restart**. The app checks public GitHub releases at each fresh launch and on request, verifies a signed manifest plus exact size/hash, and retains recovery content. Notifications wait for safe menu/debrief points. There are no background notifications while the app is closed and no forced restart.

Published older installers passed local signed-content activation and recovery checks for **0.7.1**. Those historical results alone do not verify a different content pack. Each 0.8 candidate needs exact-artifact baseline acceptance; consult its final release record for those results. Native engine or bootstrap-contract changes require a full installer; a Mac app that cannot launch needs one corrected installation. [Update behavior, evidence, and limits](docs/UPDATES.md).

## Understand the science

For video editing, the separate [equation-card PDF](docs/media/KOMAKU-Video-Equations.pdf) and [plain-language equation notes](docs/VIDEO-EQUATIONS.md) explain the final pace/fatigue model. They accompany the game documentation; the standalone release science-guide asset remains the main guide.

The [illustrated guide](docs/media/KOMAKU-Science-Guide.pdf) and [readable Markdown](docs/SCIENCE-GUIDE.md) are being refreshed for the final pace/fatigue model, diagrams, units and worked examples. Final PDF/fingerprint acceptance remains pending until regeneration. Historical 0.7.1 archives retain their earlier guide.

The mission uses the historical **210 ± 40 µGy/day** Curiosity RAD tissue-like detector result as the baseline for an explicitly authored increasing rate curve. It does not measure the child or infer injury. Fatigue, deadline, cleaning rate, panel transmission, load and battery parameters are scenario choices. The battery uses a dimensioned generation-minus-load energy balance. The original Pathfinder dust result measured a relative current decrease; it is not silently relabelled as a universal power or dust rate. [Verified sources and corrections](docs/SCIENCE-JOURNEY-SOURCES.md) · [Complete science and learning source index](docs/SOURCE-INDEX.md).

An optional **NASA solar view** fetches the latest available SDO AIA 193 Å image, with explicit online/cached/offline status. This is real observational imagery for exploration; it does not change the authored Mars dose curve, mission deadline, or energy calculation. Retrieval time and server file modification time are labelled separately from an unverified image-exposure time. [Live data and fallback behavior](docs/LIVE-DATA.md).

No accounts, ads, analytics, wearable health collection, or remote gameplay API are required. Local settings and learning records stay on the device. GitHub provides public update discovery/download; opening the solar view contacts NASA for its public image, and external source links open only when selected. The mission remains playable offline. The local explanations and planner are transparent rules, not a trained AI tutor. NASA does not endorse the project.

## Build and develop

The game uses **Godot 4.6.3**, typed GDScript, and the compatibility renderer. Godot supplies the C++ engine; Python handles build, validation, and document generation. Additional languages are added for a measured need, not a checklist. [Engine decision](docs/ENGINE-DECISION.md).

```sh
godot --path game
python3 scripts/test_game.py
python3 scripts/test_updater.py
python3 scripts/build_science_guide.py --check
```

Open `game/project.godot` to develop the source. A build requires the official export templates and a deliberate project version matching the requested artifact; publication is a separate explicit workflow. The **Build downloadable game** Actions workflow binds artifacts to a source commit and requires native package gates before publication.

The earlier JavaScript dashboard in `src/` is a tested reference model, not the new primary interface. For that prototype only, use Node 22.12+, `npm ci`, `npm run dev`, and `npm test`.

## Team documentation

[Changelog](CHANGELOG.md) · [Team briefing](docs/TEAM-STATUS.md) · [Request tracker](docs/REQUEST-TRACKER.md) · [Roadmap](docs/ROADMAP.md) · [Architecture](docs/ARCHITECTURE.md) · [Design handoff](docs/DESIGN-HANDOFF.md) · [Validation](docs/VALIDATION.md) · [Playtest protocol](docs/PLAYTEST.md) · [Credits](CREDITS.md) · [Audio credits](docs/AUDIO-CREDITS.md) · [30-second video pitch](docs/VIDEO-PITCH.md).

When reporting a problem, include the release version, device, OS, steps, and exact error. Do not include personal information in public issues.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
