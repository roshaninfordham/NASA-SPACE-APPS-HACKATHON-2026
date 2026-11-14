# Red Veil

**Become the astronaut. Find a way through the veil.**

A first-person Mars survival adventure for ages 7–12. Explore an outpost, inspect its equipment, protect your suit, and make the energy decisions that bring your crew home.

[![Validation](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/workflows/validate.yml/badge.svg)](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/workflows/validate.yml)

**Status: early playable alpha.** The public download below contains the mechanics-era visuals. A new design-team direction—flowing ivory/crimson architecture and holographic mission control—is being implemented on main. It is not yet a released or production-certified game.

![Actual v0.4 gameplay before the visual pivot](docs/media/red-veil-0.4.0-alpha.1-gameplay.gif)

[Versioned screenshots and capture provenance](docs/MEDIA.md).

## Play on your laptop

Get the game from [GitHub Releases](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases). Release notes identify available downloads, exact source commit, and what was tested. Game installers belong in Releases; an empty GitHub Packages tab does not mean downloads are missing.

The build pipeline creates macOS universal, Windows x64, Linux x64, and Web archives, with licenses and SHA-256 checksums. The Mac universal binary includes arm64 for Apple Silicon, including M5, and x86_64 for Intel. Early Mac and Windows builds are unsigned; the Mac build is not notarized. Physical Mac/Windows launches and device-specific performance remain to be verified. Native Android and iOS installers are not yet provided.

**Current download: [v0.4.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.4.0-alpha.1).**

| Platform                               | Download                                                                                                                                                             |
| -------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| MacBook M5 / Apple Silicon / Intel Mac | [macOS universal ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.4.0-alpha.1/Red-Veil-0.4.0-alpha.1-macOS-universal.zip) |
| Windows x64                            | [Windows ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.4.0-alpha.1/Red-Veil-0.4.0-alpha.1-Windows-x64.zip)             |
| Linux x64                              | [Linux ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.4.0-alpha.1/Red-Veil-0.4.0-alpha.1-Linux-x64.zip)                 |
| WebGL2 browser                         | [Web ZIP](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.4.0-alpha.1/Red-Veil-0.4.0-alpha.1-Web.zip)                         |

See [download instructions](docs/DOWNLOADS.md). No development tools are required to play the native app.

## In-game updates

The **v0.4.0-alpha.1 desktop downloads include signed content updates**: notice → download → explicit restart, with verification and recovery. Older releases need one manual upgrade. The Linux acceptance run fetched the actual public GitHub release, installed it, automatically relaunched, and recovered from a tampered pack. Mac/Windows physical acceptance and upgrades from previously shipped baselines remain separate gates. Engine/runtime changes require a full installer. [Behavior, evidence and limits](docs/UPDATES.md).

Browser offline/update packaging and the GitHub Pages deployment workflow are now available in the repository. An internal Android build route is documented; no production Android/iOS native download or mobile self-updater is published.

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

Mira's Field Academy adds five short science lessons, ten questions, hints and explanations, and a local review plan. It is accessible from the title menu and mission debrief. These lessons are included in alpha 0.4.0-alpha.1. The tutor uses provisional Bayesian estimates, not a trained AI model; [learning design](docs/LEARNING-DESIGN.md) documents the research and limits. The [request tracker](docs/REQUEST-TRACKER.md) distinguishes delivered features from open requirements.

## Design direction

Sci-fi wonder, unusual forms, tactile discovery, and a world young explorers want to revisit. Scientific behavior stays explicit while the art evolves. Normally invisible phenomena may appear through labeled instrument visualizations; spectacular presentation must not imply false physics.

The game provides replaceable scene slots, palette/font profiles, a custom HUD contract, and detached visual-state snapshots. Your design team can replace the habitat, refuge, array, companion, scanner, landscape, and HUD without rewriting the mission equations. Changed collision shapes or shelter volumes still require gameplay validation.

Read the [design-team handoff](docs/DESIGN-HANDOFF.md).

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
python3 scripts/build_game.py --version 0.4.0-alpha.1
```

The Linux CI installer verifies the official SHA-512 manifest. The manual **Build downloadable game** workflow creates archives and a source-commit manifest. Publication is explicit and separate from building.

The earlier web dashboard remains a reference model in `src/`. For that prototype only: install Node 22.12+ and run `npm ci`, `npm run dev`, `npm test`, or `npm run test:e2e`. It is not the chosen final game interface.

## Evidence and documentation

Start with the [team progress briefing](docs/TEAM-STATUS.md) and [versioned changelog](CHANGELOG.md).

| Topic                                        | Document                                   |
| -------------------------------------------- | ------------------------------------------ |
| Product scope and original brief             | [Core brief](docs/CORE-BRIEF.md)           |
| Framework choice and open-source foundations | [Engine decision](docs/ENGINE-DECISION.md) |
| Components and data flow                     | [Architecture](docs/ARCHITECTURE.md)       |
| Art replacement contracts                    | [Design handoff](docs/DESIGN-HANDOFF.md)   |
| Equations, source data, and limitations      | [Science](docs/SCIENCE.md)                 |
| Completed checks and release gates           | [Validation](docs/VALIDATION.md)           |
| Download and device instructions             | [Downloads](docs/DOWNLOADS.md)             |
| Demo narrative and judging evidence          | [Submission workspace](docs/SUBMISSION.md) |
| Learner and device testing                   | [Playtest protocol](docs/PLAYTEST.md)      |
| Asset and engine attribution                 | [Credits](CREDITS.md)                      |

## Privacy and scientific limits

No accounts, ads, analytics, or remote gameplay APIs. The upcoming updater checks public GitHub releases at most daily automatically, or when requested; it sends no learner profile or mission record. A mission summary and academy practice profile are stored locally. Academy progress can be reset in the game. Source observations are bundled for offline use; publication summaries are not raw time-series datasets. Hardware loads, shielding factors, mission limits, and the compressed emergency timeline are illustrative. The companion uses transparent rules, not a trained ML model. NASA does not endorse the project.

For feedback, include the release version, device, OS, and steps to reproduce. Do not include personal information in public issues.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
