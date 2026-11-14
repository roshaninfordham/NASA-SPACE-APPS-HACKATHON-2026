# Red Veil — team progress briefing

**Latest published release: 0.3.0-alpha.1, November 14, 2026.**

## Explain it in thirty seconds

We have a downloadable first-person mechanics prototype of Red Veil. A young player becomes an astronaut, explores a Mars outpost, handles equipment, manages separate habitat and suit energy, and reaches a shielded refuge during an emergency. The mission ends with an explanation of the player's decisions. The game uses Godot and has modular art/scene contracts so the design team can replace the current placeholder presentation. It is not yet the finished visual experience, a product-grade release, or validated astronaut training.

Alpha 0.3.0-alpha.1 adds local science practice and review guidance to the mission. The release manifest records source `1187c3d0faa314c18cbebbd1f73330656d11dac6`.

## New in 0.3.0-alpha.1

This build adds Mira's Field Academy: five short science lessons and ten authored questions, optional hints, explanations, a local practice profile, and scheduled review suggestions. Mission outcomes recommend relevant support. A hand-parameterized Bayesian estimate guides practice; it is not trained AI or validated mastery. This is still one 3D mission, not five new 3D levels.

The latest published alpha has only the update-verification foundation. Newer work on main adds discovery, staged installation, explicit restart and startup recovery, plus additional isolated tests. A production trust root and acceptance build remain required before signed updating is enabled. Read the [learning design](LEARNING-DESIGN.md) and [request tracker](REQUEST-TRACKER.md) for evidence and open work. GitHub validation and the release workflow passed. Four public archives and their hashes were verified, along with downloaded Linux startup.

## Core mission inherited from alpha.2

| Area              | Current state                                                                                                   |
| ----------------- | --------------------------------------------------------------------------------------------------------------- |
| Player experience | First-person movement, scanner, companion, and radio guidance                                                   |
| Mission           | One four-minute exploration and survival loop                                                                   |
| Decisions         | Inspect array, clean panels, clean visor, conserve power, enter refuge                                          |
| Model             | Separate energy stores, cumulative exposure, two dust mechanisms, passive shelter                               |
| Learning feedback | Radio explanations and end-of-mission comparison                                                                |
| Downloads         | Mac universal, Windows x64, Linux x64, and Web archives                                                         |
| Art pipeline      | Replaceable world/equipment/companion/scanner slots, palettes/fonts, and HUD contract                           |
| Sources           | Bundled NASA publication observations with units and explicit assumptions                                       |
| Validation        | Numerical checks, headless full-mission interactions, art contract, Linux startup, archive/hash checks          |
| Documentation     | Architecture, design handoff, science, credits, downloads, changelog, submission outline, and playtest protocol |
| Distribution      | Versioned GitHub pre-releases with source manifests and checksums                                               |

## What is not finished

- The heavenly, unconventional sci-fi visual identity, animation, and sound direction are still being developed with the design team.
- Mac/Windows physical launch testing, M5 profiling, broader controller/mobile validation, and native accessibility remain open.
- Apple/Windows signing, notarization, and native Android/iOS distributions are not complete.
- There is no shipped in-game updater yet. Existing alpha downloads will need one manual upgrade to reach an updater-enabled build.
- Scientist/engineer review and age-appropriate learner playtesting have not happened. No educational efficacy or professional-training claim is justified yet.
- The native first mission does not simulate the entire colony or ingest a live NASA time-series feed.

## Why GitHub's sidebar looks incomplete

- **Releases:** three downloadable pre-releases exist. GitHub's stable-release summary can look sparse while every published version is an alpha. We will not label an alpha stable to change the sidebar.
- **Packages:** game ZIPs/apps are Release assets. A container or library registry package is unnecessary for downloading the game.
- **Contributors:** GitHub now lists `roshaninfordham` for recent commits using the owner's linked noreply identity. Earlier history is preserved.
- **Languages:** GitHub now detects GDScript, JavaScript, CSS, Python and HTML. Godot's C++ engine is an external binary dependency, so it is not counted as this repository's source.
- **About:** the owner completed the description, website and topics through the browser gear. All were verified through the API. The managed integration still lacks administration access; details are in [repository setup](REPOSITORY-SETUP.md).
- **Stars/watchers/forks:** these reflect real GitHub user activity, not implementation completeness.

## Immediate team responsibilities

1. Play the Mac alpha and report version, device, OS, and reproducible problems.
2. Design team: supply the next visual iteration through the documented scene/HUD contracts, with asset licenses and constraints.
3. Engineering: harden input/layout/performance and implement signed update infrastructure before enabling self-updates.
4. Science/education: review the model's limits and run the proposed supervised playtest protocol.
5. Repository owner: About is complete. Provision release-signing access when the update workflow is ready; no additional owner action is needed for this unsigned alpha.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
