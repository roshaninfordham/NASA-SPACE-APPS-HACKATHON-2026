# Changelog

All published game versions and notable unreleased work are recorded here. The version and source commit in each release manifest identify the exact downloadable build. Documentation on `main` can be newer than an installer.

## Unreleased

### Documentation and repository

- Added a team-facing progress report and clearer distinctions between implemented, tested, provisional, and outstanding work.
- Added this changelog and the requested Team Roshan Xingbo credit.
- Linked future commits to the repository owner's public GitHub noreply identity; earlier history is preserved.
- Confirmed that About metadata updates require additional integration permissions or an owner-side edit.

### Update security foundation (not an enabled updater)

- Added a pinned-key RSA/SHA-256 manifest verifier, exact content hash/size checks, version ordering, and fixed release asset paths.
- Added owner-run signing setup and a release manifest signer; private keys stay outside Git. No production trust root is configured yet.
- Added 24 runtime security checks using disposable keys; CI exercises tampering, downgrade, incompatible engine, path, size, and hash rejection.

### Planned, not shipped

- Signed in-game update discovery, staging, activation, and startup rollback. Alpha.1 and alpha.2 do not include an updater.
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

[0.2.0-alpha.2]: https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.2.0-alpha.2
[0.2.0-alpha.1]: https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.2.0-alpha.1

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
