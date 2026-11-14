# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand -->

**Become the astronaut. Protect your crew.**

A first-person Mars survival adventure for ages 7–12. Explore an outpost, inspect its equipment, protect your suit, and make the energy decisions that bring your crew home.

[![Validation](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/workflows/validate.yml/badge.svg)](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/workflows/validate.yml)

**Status: early playable visual-development alpha.** The 0.6.1 hotfix repairs Mac bundle signing and adds native desktop launch gates and an update check on every fresh launch. Version 0.6 adds a live explorer suit lab, five adjustable science experiments, habitat field notes and more detailed mission control, architecture and suit artwork. Branding and presentation styles are centrally configured. Pixel-perfect likeness, photoreal character work and physical-device performance validation remain unfinished.

![Actual KŌMAKU habitat](docs/media/komaku-0.6.0-alpha.1-exterior.png)

[Versioned screenshots and capture provenance](docs/MEDIA.md).

## Play on your laptop

Get the game from [GitHub Releases](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases). Release notes identify available downloads, exact source commit, and what was tested. Game installers belong in Releases; an empty GitHub Packages tab does not mean downloads are missing.

The build pipeline creates macOS universal, Windows x64, Linux x64, and Web archives, with licenses and SHA-256 checksums. The Mac universal binary includes arm64 for Apple Silicon, including M5, and x86_64 for Intel. The 0.6.1 Mac app is ad-hoc signed for bundle integrity, without Apple Developer ID or notarization. Windows remains unsigned. This release passed native macOS and Windows CI launch checks; physical-device performance, audio and complete playthroughs remain separate tests. Native Android and iOS installers are not yet provided.

**Current download: [v0.6.1-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.6.1-alpha.1).** The older 0.6.0 Mac archive has an invalid bundle signature; download this corrected hotfix once if your existing app cannot open.

| Platform                               | Download                                                                                                                                                                           |
| -------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MacBook M5 / Apple Silicon / Intel Mac | [macOS universal ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.6.1-alpha.1/KOMAKU-Shield-Protocol-0.6.1-alpha.1-macOS-universal.zip) |
| Windows x64                            | [Windows ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.6.1-alpha.1/KOMAKU-Shield-Protocol-0.6.1-alpha.1-Windows-x64.zip)             |
| Linux x64                              | [Linux ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.6.1-alpha.1/KOMAKU-Shield-Protocol-0.6.1-alpha.1-Linux-x64.zip)                 |
| WebGL2 browser                         | [Web ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.6.1-alpha.1/KOMAKU-Shield-Protocol-0.6.1-alpha.1-Web.zip)                         |

See [download instructions](docs/DOWNLOADS.md). No development tools are required to play the native app. If macOS blocks the trusted download, the ZIP includes a one-time installer helper that asks for consent, verifies the app, preserves an existing copy, and removes quarantine only from the installed copy. It does not establish publisher identity or disable system-wide Gatekeeper. [Mac repair evidence](docs/MACOS-LAUNCH-REPAIR.md).

## In-game updates

The **0.6.1 desktop app checks for updates on every fresh launch**, once per process; a manual check is also available. Compatible signed content follows **Update available → Install → Restart**, with verification and recovery. Notices wait for safe menu/debrief points. There are no background notifications while the game is closed. An older Mac app that cannot start needs the corrected installer once; content cannot repair its native bundle. Installers from before 0.4 also need a manual upgrade. Engine/runtime changes require a full installer. [Behavior, evidence and limits](docs/UPDATES.md).

Browser offline/update packaging and the GitHub Pages deployment workflow are available in the repository. Public hosting is deferred by owner choice after verification found an inherited custom-domain redirect to another site; use downloadable builds for now. An internal Android build route is documented; no production Android/iOS native download or mobile self-updater is published.

## Your first mission

Mira, your crewmate, needs you at the solar array. A dust storm will dim the sky. A separate particle event will make the refuge important. You have four minutes, two batteries, and decisions that matter.

- Walk to the array and hold the interaction to inspect it.
- Clear the visor when visibility slows your work. It uses **suit** energy.
- Clean solar panels when sunlight makes it worthwhile. They use **habitat** energy.
- Conserve nonessential power while preserving life support.
- Walk into the pre-shielded refuge before the particle event.
- Finish with enough reserve to recover, then discover what your choices changed.

Keyboard: **WASD** move, **mouse** look, **E** use/hold to inspect, **Q** visor, **Space** hop, **Escape** pause, **F1** guide. Controller and landscape touch controls are included; further device testing is required.

## Learn with Mira

Mira's Field Academy adds five short science lessons, ten questions, hints and explanations, and a local review plan. It is accessible from the title menu and mission debrief. These lessons have been included since alpha 0.3.0-alpha.1. The tutor uses provisional Bayesian estimates, not a trained AI model; [learning design](docs/LEARNING-DESIGN.md) documents the research and limits. The [request tracker](docs/REQUEST-TRACKER.md) distinguishes delivered features from open requirements.

## New design-specification work

The current source adds **Explorer Suit Lab** (five live views, four cosmetic themes, five adjustable experiments) and **Habitat Field Notes** (four architecture lessons). Access both from the title menu; the suit lab is also in the pause menu, and **I** opens habitat notes during untimed exploration. The activities pause the mission and do not change its physical model.

The control room now has four live data panels, nine tabletop screens and a geodesic globe. The habitat and suit add shared pearl/crimson/rose-gold finishes and specific Japanese craft references, with a Chinese knot-inspired airlock emblem. These remain procedural interpretations. Read the [adapted design specifications](docs/design-specs/README.md) and [implementation ledger](docs/SPEC-IMPLEMENTATION.md) for each completed, partial and deferred target. These additions are included in the 0.6 release.

## Design direction

Sci-fi wonder, unusual forms, tactile discovery, and a world young explorers want to revisit. Scientific behavior stays explicit while the art evolves. Normally invisible phenomena may appear through labeled instrument visualizations; spectacular presentation must not imply false physics.

The game provides replaceable scene slots, palette/font profiles, a custom HUD contract, and detached visual-state snapshots. Your design team can replace the habitat, refuge, array, companion, scanner, landscape, and HUD without rewriting the mission equations. Changed collision shapes or shelter volumes still require gameplay validation.

Read the [visual direction](docs/VISUAL-DIRECTION.md), [design-team handoff](docs/DESIGN-HANDOFF.md), and [shared branding guide](docs/BRANDING.md).

## Build and develop

The primary game uses **Godot 4.6.3**, typed GDScript, and the compatibility renderer. Open `game/project.godot` in the editor, or:

```sh
godot --path game
```

Run the native checks:

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/mission_test.gd
godot --headless --path game --script res://tests/gameplay_test.gd
godot --headless --path game --script res://tests/art_contract_test.gd
godot --headless --path game --script res://tests/learning_test.gd
python3 scripts/test_updater.py
```

With the official export templates installed:

```sh
python3 scripts/test_game.py  # Full suite on Linux; native package gates run separately
python3 scripts/build_game.py --version 0.7.0-alpha.1
```

The Linux CI installer verifies the official SHA-512 manifest. The manual **Build downloadable game** workflow creates archives and a source-commit manifest. Publication is explicit and separate from building.

The earlier web dashboard remains a reference model in `src/`. For that prototype only: install Node 22.12+ and run `npm ci`, `npm run dev`, `npm test`, or `npm run test:e2e`. It is not the chosen final game interface.

## Evidence and documentation

Start with the [team progress briefing](docs/TEAM-STATUS.md) and [versioned changelog](CHANGELOG.md).

| Topic                                        | Document                                                        |
| -------------------------------------------- | --------------------------------------------------------------- |
| Product scope and original brief             | [Core brief](docs/CORE-BRIEF.md)                                |
| Framework choice and open-source foundations | [Engine decision](docs/ENGINE-DECISION.md)                      |
| Mission planner and model limits             | [Mission planner](docs/MISSION-PLANNER.md)                      |
| Rendering work and measured comparisons      | [Performance](docs/PERFORMANCE.md)                              |
| Core proposal and demonstration              | [Evidence](docs/CORE-PROPOSAL.md) · [Demo](docs/DEMO-SCRIPT.md) |
| Components and data flow                     | [Architecture](docs/ARCHITECTURE.md)                            |
| Art replacement contracts                    | [Design handoff](docs/DESIGN-HANDOFF.md)                        |
| Equations, source data, and limitations      | [Science](docs/SCIENCE.md)                                      |
| Completed checks and release gates           | [Validation](docs/VALIDATION.md)                                |
| Download and device instructions             | [Downloads](docs/DOWNLOADS.md)                                  |
| Demo narrative and judging evidence          | [Submission workspace](docs/SUBMISSION.md)                      |
| Learner and device testing                   | [Playtest protocol](docs/PLAYTEST.md)                           |
| Asset and engine attribution                 | [Credits](CREDITS.md)                                           |

## Privacy and scientific limits

No accounts, ads, analytics, or remote gameplay APIs. The 0.6.1 updater checks public GitHub releases on each fresh launch, or when requested; it sends no learner profile or mission record. A mission summary and academy practice profile are stored locally. Academy progress can be reset in the game. Source observations are bundled for offline use; publication summaries are not raw time-series datasets. Hardware loads, shielding factors, mission limits, and the compressed emergency timeline are illustrative. The companion uses transparent rules, not a trained ML model. NASA does not endorse the project.

For feedback, include the release version, device, OS, and steps to reproduce. Do not include personal information in public issues.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
