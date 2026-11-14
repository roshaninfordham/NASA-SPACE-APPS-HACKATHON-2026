# Red Veil — team progress briefing

**Latest published release: 0.2.0-alpha.2, November 14, 2026.**

## Explain it in thirty seconds

We have a downloadable first-person mechanics prototype of Red Veil. A young player becomes an astronaut, explores a Mars outpost, handles equipment, manages separate habitat and suit energy, and reaches a shielded refuge during an emergency. The mission ends with an explanation of the player's decisions. The game uses Godot and has modular art/scene contracts so the design team can replace the current placeholder presentation. It is not yet the finished visual experience, a product-grade release, or validated astronaut training.

Alpha.2 changed the bundled engine notices, not the gameplay. Its exact source is recorded in the release manifest.

## What exists today

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

- **Releases:** two downloadable pre-releases exist. GitHub's stable-release summary can look sparse while every published version is an alpha. We will not label an alpha stable to change the sidebar.
- **Packages:** game ZIPs/apps are Release assets. A container or library registry package is unnecessary for downloading the game.
- **Contributors:** earlier commits use an author address that GitHub has not linked to an account. Future commits use the owner's GitHub noreply identity. Existing history is preserved.
- **Languages:** GitHub computes and caches this breakdown. Its API was still reporting the initial JavaScript snapshot despite GDScript being present on main.
- **About:** the connected integration is denied repository-administration updates. Exact owner-side values are in [repository setup](REPOSITORY-SETUP.md).
- **Stars/watchers/forks:** these reflect real GitHub user activity, not implementation completeness.

## Immediate team responsibilities

1. Play the Mac alpha and report version, device, OS, and reproducible problems.
2. Design team: supply the next visual iteration through the documented scene/HUD contracts, with asset licenses and constraints.
3. Engineering: harden input/layout/performance and implement signed update infrastructure before enabling self-updates.
4. Science/education: review the model's limits and run the proposed supervised playtest protocol.
5. Repository owner: set the About fields and provision release-signing access when the update setup is ready.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
