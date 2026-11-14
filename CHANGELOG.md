# Changelog

All published game versions and notable unreleased work are recorded here. The version and source commit in each release manifest identify the exact downloadable build. Documentation on `main` can be newer than an installer.

## Unreleased

- Signed in-game update discovery, staging, activation, and startup rollback remain in development. No published alpha includes an updater.
- Further missions, final art/audio, mobile input/accessibility, physical-device profiling, and learner evaluation remain open.

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
