# Changelog

All published game versions and notable unreleased work are recorded here. The version and source commit in each release manifest identify the exact downloadable build. Documentation on `main` can be newer than an installer.

## [0.7.0-alpha.1] — unreleased

Source candidate only; the latest published installer remains 0.6.1-alpha.1. The candidate implements an indoor operator guiding Mira home. The full source suite, focused rescue checks and independent native Linux input/capture checks pass; science documentation has been regenerated. Final release-archive/native release-gate acceptance remains pending.

- Make **Start mission** the indoor operator experience. Keep **Explore · no timer** indoors and retain the original exterior/equipment mode under **Learn & more → Outdoor EVA mission**. Primary controls become panel cleaning, power saving and **Guide Mira**, using buttons or **1/2/3**; **Tab** pauses for cursor controls.
- Frame the primary window with dunes and stranded Mira. Hide exterior dome, equipment, approach and refuge props reversibly for this mode; bound the operator to the room and hide the handheld scanner. Keep the default forward frame free of room consoles; the larger workstations and outpost are retained for optional EVA. Use restrained pearl/navy/cyan presentation.
- Add a companion rescue sequence: **Guide Mira** starts continuous movement through a side-airlock route, abstract cycle and final indoor entry. Shelter applies only at the receiver after all three phases. Mira’s suit/dose state controls her exposure; operator position does not shield her. Require base power survival through 12 simulated hours after mission start, including time after rescue.
- Add a 16-page illustrated science PDF with equations, units, actual parameters, worked examples, sources and explicit teaching assumptions. Package it alongside `START-HERE.txt` in every platform ZIP and prepare a standalone versioned PDF, making ten release assets when published; CI rejects stale source fingerprints.
- Replace abrupt edge teleports with a labelled training-area boundary; distant dune scenery is outside the playable area. Ordinary movement/gravity and reachable mission routes remain intact.
- Add AEGIS mission planning: press **P** during a mission or choose **Compare mission plans** from Pause. Compare four cleaner/conservation policies over the same one-hour scenario, inspect the maths and apply only the chosen switches. Opening the planner pauses mission time and resources.
- Use the actual fixed-step mission model for each private projection, holding present protection fixed. The planner does not predict Mira’s travel or airlock timing. Show abort duration and separate suit/habitat stores; no trained-AI, live-forecast or safety guarantee is implied.
- Simplify the landscape from 109,710 to 21,388 retained triangles while retaining tested walking routes and equipment cues. This is landscape-only geometry work, not whole-game FPS or RAM. [Final landscape scope](docs/DESIGN-PIVOT-0.7.md). Earlier 33.7%/approximately 61% reductions describe historical pre-pivot work; the headless stone-placement digest was invalid and does not prove unchanged positions. [Corrected historical evidence](docs/PERFORMANCE.md).
- Centralize native game validation so local Linux checks, CI and release exports run the same model, UI, performance and updater suites. Pass the complete source suite, 87 operator/291 integration assertions, 36 independent semantic assertions and 65 native input/capture assertions. Keep native desktop archive gates from 0.6.1; candidate release artifacts still need those gates.
- Add a focused core proposal, demonstration script and research/source boundaries; preserve the current name and Mac Unicode-signing repair.

## [0.6.1-alpha.1] — 2026-11-14

Packaging and update-discovery repair. Gameplay and 0.6 artwork are unchanged. Built from `587d6c9fc7a5cd504b1c1ea68707628572bbbe4e`, signed build `43648641582`. Native Mac/Windows launch gates and actual historical-installer content activation/recovery passed; [release evidence](docs/evidence/release-0.6.1-alpha.1.json) records exact files and scope.

- Enable Godot's built-in ad-hoc Mac bundle signing, replacing the inherited engine-template signature that failed strict native verification in the public 0.6.0 download.
- Derive Mac filenames using Apple-compatible decomposed Unicode from the shared brand configuration, preserving the displayed KŌMAKU name. Native gates rejected the initially composed resource seal.
- Include a consent-based Mac installer that verifies integrity, installs into the user's Applications folder, preserves the previous app and changes quarantine only for that copied app. No Developer ID/notarization is claimed.
- Require native macOS signature, universal architecture, headless and graphical startup checks and native Windows startup checks on the exact exported ZIPs before publishing.
- Check Windows graphical startup using the default renderer and an explicit ANGLE fallback run. Native runner evidence confirms rendering when OpenGL 3.3 is unavailable.
- Check for content updates on every fresh launch; remove the persisted daily suppression that could hide releases after an offline launch. Keep manual checks, signature verification, explicit restart and rollback.
- Document the initial-installation trust boundary and why a broken Mac bundle needs one corrected full download. Existing saves, bundle identity and signed-content trust root remain unchanged.

[Mac root-cause report](docs/MACOS-LAUNCH-REPAIR.md). Native Windows remains unsigned; macOS remains unnotarized. Final release notes identify the accepted build and native test evidence.

## [0.6.0-alpha.1] — 2026-11-14

Published from `c0beba698c32741fb17f6c8e9ec44fd6bb875852`, signed build `43645098947`, with nine assets. [The actual 0.4 installer compatibility gate](docs/evidence/update-0.4-to-0.6.json) verifies signed activation, repeat startup and corruption recovery; [release evidence](docs/evidence/release-0.6.0-alpha.1.json) records public-file verification.

- Added Explorer Suit Lab with one live 3D stage, five inspection views, four cosmetic themes, and five adjustable teaching experiments covering dose/time, dust removal, heat balance, supply duration and pressure-fit tradeoffs. Cosmetics do not alter mission physics.
- Added Habitat Field Notes with four scene-anchored callouts, questions and explanations. Open from the title menu or press **I** during untimed exploration.
- Refined four mission-control panels and nine tabletop screens with live simulation data, a triangular hologram network, projection grid, layered ceiling rings, blossoms and lattice details.
- Added pearl/lacquer finish shaders, square lattice lanterns, airlock seams/rivets/knot ornament, lounge details, and a regolith berm with matching slope collision. The front aperture remains open; operational airlock/shutters and pressure simulation are not implemented.
- Added shared, validated palette/material/motif configuration in `game/data/visual_style.json`; product naming still comes only from `brand.json`.
- Preserved all three uploaded design specifications byte-for-byte with hashes; added adapted current-name briefs and a [requirement-by-requirement ledger](docs/SPEC-IMPLEMENTATION.md). Corrected the documented native mission acceleration to 180×.
- Added integrated learning-menu, pause/resume, resource-freeze, keyboard-focus and 44-pixel target checks at desktop/portrait/landscape sizes, plus scene and experiment checks in CI and release builds.

This is an iterative visual-development alpha. Pixel-identical art, production character rigging/cloth, six simultaneous character cameras, three new EVA missions, habitat construction and multi-sol campaigns remain open. Physical Mac/Windows/mobile performance is not established.

## [0.5.0-alpha.1] — 2026-11-14

Published from `1b4d1b8e0907f76a055a8aca85e1073c4eff34eb`, build `43641694667`, with nine assets. The actual published 0.4 Linux installer passed signed-pack activation, repeated healthy startup and tamper recovery. [Acceptance evidence](docs/evidence/update-0.4-to-0.5.json).

- Renamed current presentation to **KŌMAKU: Shield Protocol**, driven by one brand configuration and shared runtime/build accessors. Legacy save, signing, package identity and updater protocols remain stable.
- Added modular ivory/crimson habitat and refuge scenes, a walkable holographic control room, lanterns, gold wave/blossom inlays, lattice supports, terrain and a pearlescent crewmate/scanner. These are original procedural interpretations, not pixel-identical or photoreal reference reproductions.
- Added untimed habitat exploration and responsive menus, touch controls, scrollable dialogs and keyboard focus handling.
- Added collision-based route checks, real Explore-button checks, and static geometry batching. The mission equations and local learning model are unchanged.
- Added integrity-checked browser offline/update packaging, a Pages delivery workflow, and multi-window update controls.
- Added a reproducible internal Android build route; production signing, device testing and native mobile updating remain open.
- Added authentic versioned screenshots/GIFs and a ten-outcome roadmap with explicit evidence and limitations.

## [0.4.0-alpha.1] — 2026-11-14

Published from `48901d0bce68e72974b36377c3a060f90403ebe9`, with four platform archives and five signed-update/manifest/checksum assets. This release retains the mechanics-era visuals.

- Added title/debrief update notifications, bounded public GitHub discovery, verified desktop content downloads, explicit restart, and startup recovery.
- Pinned the RSA trust root and runtime contract; verifies signatures, exact sizes and hashes before installation and on boot. Incompatible runtime changes require a full installer.
- Added cancellation/retry, persisted client state, concurrent-install protection, staged activation, and recovery to previous or bundled content.
- Provisioned signing through the owner's machine and encrypted Actions secret. Releases publish the exact accepted build artifacts without rebuilding.
- Verified real GitHub transfers and automatic exported Linux GUI relaunch under Xvfb/Mesa, repeat startup, and tamper recovery. The older-version fixture was synthetic; physical Mac/Windows and a previously shipped baseline transition remain unverified. [Acceptance evidence](docs/evidence/update-0.4.0-alpha.1.json).
- Older releases require one manual upgrade. Native Android/iOS updating is not included.

## [0.3.0-alpha.1] — 2026-11-14

This release adds a small local practice academy to the existing first-person mechanics mission. It does not introduce five new 3D missions or a trained AI model. Built from `1187c3d0faa314c18cbebbd1f73330656d11dac6`. Validation and the four-target release workflow passed; public archives, SHA-256 hashes, and exported Linux startup were verified.

### Documentation and repository

- Added a team-facing progress report and clearer distinctions between implemented, tested, provisional, and outstanding work.
- Added this changelog and the requested Team Roshan Xingbo credit.
- Linked future commits to the repository owner's public GitHub noreply identity; earlier history is preserved.
- Confirmed that About metadata updates require additional integration permissions or an owner-side edit.

### Learning and reliability

- Added Mira's Field Academy: five science concepts, ten authored questions, optional hints, causal explanations, and links back to mission actions.
- Added local Bayesian practice estimates, alternate questions, scheduled review suggestions, and mission-outcome support recommendations. Parameters are provisional; this is not a trained or validated tutor.
- Prevented hints and same-day repeated questions from inflating learning evidence. Added local profile validation, recovery backup, and confirmed reset.
- Fixed repeated mission setup adding duplicate input bindings and preserved the current audio mute state when reopening the scene.
- Added learning-model and academy/gameplay integration checks, a research/design document, and a request-delivery tracker.

### Update security foundation (not an enabled updater)

- Added a pinned-key RSA/SHA-256 manifest verifier, exact content hash/size checks, version ordering, and fixed release asset paths.
- Added owner-run signing setup and a release manifest signer; private keys stay outside Git. No production trust root is configured yet.
- Added 24 runtime security checks using disposable keys; CI exercises tampering, downgrade, incompatible engine, path, size, and hash rejection.

### Planned, not shipped

- Signed in-game update discovery, staging, activation, and startup rollback. No published alpha includes an updater.
- Better mobile layout/input, performance characterization, and additional validation of design-owned replacement components.
- Final design-team visuals and real-device feedback remain separate from the mechanics alpha.

## [0.2.0-alpha.2] — 2026-11-14

**Type:** packaging correction. **Gameplay:** unchanged from alpha.1.

### Changed

- Pinned bundled Godot third-party notices to the exact `4.6.3-stable` engine tag.
- Rebuilt macOS universal, Windows x64, Linux x64, and Web archives through the repository's verified build workflow.
- Published new SHA-256 checksums and a manifest identifying source commit `84aec211dfe18090fe71a48637454d3ef96ffb3b`.

### Verified

- Numerical, gameplay integration, and art-contract checks in the release build.
- Exported Linux headless startup.
- Public downloads, archive integrity, exact engine notices, checksums, and both arm64/x86_64 slices in the Mac archive.

### Limitations

- Provisional geometry, characters, interface, and materials.
- Mac and Windows binaries are unsigned; Mac is not notarized or physically launch-tested here.
- M5 performance, native Android/iOS packages, final accessibility, learner studies, and expert scientific review remain outstanding.

## [0.2.0-alpha.1] — 2026-11-14

**Type:** first downloadable first-person mechanics alpha.

### Added

- Godot 4.6.3 first-person Mars outpost with movement, a handheld scanner, a companion character, and radio guidance.
- One four-minute mission: physical solar-array inspection, panel cleaning, visor cleaning, habitat conservation, a walk-in refuge, and mission recovery.
- Separate habitat and suit batteries; automatic suit life-support load; accumulated dose; atmospheric versus deposited dust; passive shelter protection.
- Debrief with a declared fixed-policy comparison and a local mission log.
- Keyboard/mouse, controller mappings, and provisional landscape touch controls.
- Replaceable scene slots, shared art profile, custom HUD contract, and detached visual snapshots.
- Bundled source observations, engine/asset notices, and offline play.
- Native export presets and downloadable archives for macOS universal, Windows x64, Linux x64, and Web.
- Numerical checks, a full headless gameplay sequence, an art-replacement contract check, and exported Linux startup verification.

### Source

Built from `a7f28042a4dfb510bcce9f419bea46731a23eb82`. The web dashboard remains a reference prototype, not the chosen final presentation.

### Upgrade note

Prefer alpha.2, which corrects the bundled engine notices. Neither alpha version contains automatic updating. Both are learning-game prototypes, not validated astronaut training.

## Before the first tagged release

The initial JavaScript/Three.js dashboard established the independent numerical model, three illustrative scenarios, source provenance, offline browser packaging, and browser tests. This was development work, not a separately published native game release.

[0.3.0-alpha.1]: https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.3.0-alpha.1
[0.2.0-alpha.2]: https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.2.0-alpha.2
[0.2.0-alpha.1]: https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.2.0-alpha.1

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
