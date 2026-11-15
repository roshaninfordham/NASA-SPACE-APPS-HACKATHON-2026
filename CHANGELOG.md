# Changelog

All published game versions and notable unreleased work are recorded here. The version and source commit in each release manifest identify the exact downloadable build. Documentation on `main` can be newer than an installer.

## [0.11.0-alpha.1] — Unreleased candidate

Restore the outpost-window presentation and eight visible, updating science bubbles while preserving the published 0.10 wording, fonts, short explanations and mission rules. This entry describes candidate work, not a published package or completed release acceptance. [Design contract](docs/design-specs/JOURNEY-0.11.md).

- Add **View → Science window / Focused window** for the same mission. The default Science window exposes the eight concepts during play; a bubble opens a paused explanation, while Focused window reduces surrounding information.
- Add direct **Home** actions to **Menu** and **Settings**, retaining contextual Back/Resume destinations and safe pause behavior.
- Add brief player/Ren radio captions for Start and pace changes. These are scripted feedback, not microphone input, voice recognition or AI conversation.
- Migrate recognized local schema 1 progress to schema 2, adding the saved view preference without resetting existing settings or run history. Keep application/save identity and content-update trust stable.
- Preserve the 90-second standard clock, 30 simulated minutes, pace/fatigue model, actual energy, automatic entry, cleaned-fraction outcomes and equal final dose. The optional NASA SDO image remains separate from the model.
- Prepare copy-ready submission answers and replace the obsolete EVA submission outline with the current window-mission scope. Record source wording for the Pathfinder citation and distinguish concept footage from gameplay.

The published 0.10 downloads and historical galleries remain available. New source/layout, native startup, compatible-content updates, packaged-document checks and public-file verification are required before claiming a 0.11 release. Physical-device and learner acceptance retain their separate scope.

## Team screen review website — 2026-11-15

Add a separate versioned review gallery for the published 0.10 game screens: drawing tools, numbered notes, local drafts, annotated links, PNG/JSON export and explicit prefilled GitHub feedback. Screen identity is bound to the version, source commit and image hash. Deployment preserves the existing Pages game and older review versions. The published game packages and science model are unchanged. [Review guide](docs/SCREEN-REVIEW.md).

## [0.10.0-alpha.1] — 2026-11-15

Published at **13:53:05 UTC** from `26f19540baf330b00b0ac4a1b470d0e1439f7382`. [Source validation](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43720618321), [signed build/native startup](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43720633663), [twelve native update jobs](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43721023112) and [publication](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43721296427) passed. The documented Linux 0.4 update baseline also passed. [Public-file verification](docs/evidence/release-0.10.0-alpha.1.json) matched all ten downloads to the accepted build, passed all four ZIP integrity checks and confirmed the exact three reviewed PDFs plus current filenames/download links in each package.

Correct the installation handoff bundled with 0.9.0: current download URLs, package version and Mac/Windows/Linux executable names now describe the actual 0.10.0 files. Put older-version instructions in an explicit historical section. Update the release documentation and native export version metadata; extend required update checks to the public 0.9.0 installers, for twelve Mac/Windows jobs across six baselines plus Linux 0.4. [Release notes](docs/releases/0.10.0-alpha.1.md).

- Reduce the mission view to three primary readings—cleaned panel, stored energy and real play time—and one seven-step pace control. Keep Ren's work visible and move the eight concepts into an optional paused **Science** library.
- Begin concept cards with a brief explanation, diagram and everyday analogy. **Learn more** reveals the full model; **Data & sources** keeps the original evidence accessible separately. Opening concepts is exploration, not a mastery score or required reading gate.
- Shorten story and result copy. Show four simple science relationships after the bubble merge, with exact equations, actual-run numbers and graphs behind **Explore my numbers and graphs**. Keep result, retry and Home navigation explicit.
- Show an actual first-scene loading state with **Back to Home** cancellation. Clarify pause, settings, source-viewer and return paths without advancing a hidden mission clock.
- Add softer original pace, discovery and card sounds with cooldowns, reduced-motion adjustments and alert priority; retain mute, focus-loss and pause behavior. No unavailable Drive recording is claimed.
- Retain the 90-second standard round, all mission equations and update trust. Regenerate all three science/equation PDFs for the current teaching flow and include them in every platform package.

The published 0.9.0 artifacts are preserved. This is a new version with separate source, package, updater and public-file acceptance. No learning-effectiveness or physical-device claim follows from interface tests alone.

## [0.9.0-alpha.1] — 2026-11-15

Published **KŌMAKU: Dust & Radiation** at 13:12:47 UTC on November 15, 2026 from `40dbea61cc1690b3f45bce397e75aa1e582cfebd`. Its packaged installation document still foregrounded older 0.8 filenames and links; the separate 0.10.0 patch corrects that handoff without replacing published assets. [0.9 notes](docs/releases/0.9.0-alpha.1.md) · [Design contract](docs/design-specs/JOURNEY-0.9.md).

- Rename the current display title and new package stem from shared brand metadata. Preserve app IDs, saved progress, signing trust, runtime contract and historical release filenames. Existing apps updated through content keep their original OS filename.
- Shorten the standard round from five active real minutes to **90 active real seconds**, retaining 30 simulated minutes and the same work, fatigue, energy and dose equations. Make real play time the primary countdown and simulated time the secondary explanation.
- Bring Ren and the panel closer in the window, make brushing cadence changes easier to see, and enlarge science bubbles, labels and controls. Add a red, stepped pace slider with visible increments; clearing still follows modeled work.
- Use three unlettered story illustrations—exterior, astronaut, interior—with larger separately rendered titles. These are generated adaptations of the team's references, not recovered originals or gameplay captures.
- Show the result immediately at the deadline. Add **See how science connects**, an eight-bubble merge into four equation groups, **Back to results**, **Try another plan** and **Home**. Use actual readings and average effective rates; correct the reference artwork's dust/power equation.
- Add original synthesized countdown, warning and urgent beeps, with a shared rate limit, pause/focus/mute behavior and visual warning support. The inaccessible Drive recording is not claimed as bundled.
- Refresh all three science/equation PDFs from the canonical brand and current clock settings; include the simple one-page sheet in the next package alongside the guide and technical sheet. Add submission-writing and recording drafts for team review.
- Extend the required native content-update matrix to public 0.8 Mac/Windows installers, alongside 0.6.0, 0.6.1, 0.7.0 and 0.7.1. Ten native jobs and the Linux 0.4 baseline must pass on the exact signed candidate bytes before compatibility is claimed.

Source checks and media retain their recorded source scope; exact release/update records identify their accepted artifacts. Historical release evidence below remains unchanged. Mac notarization, Windows publisher signing, public hosting, production native mobile packages and physical-device acceptance remain separate work.

## [0.8.0-alpha.1] — 2026-11-15

Published [v0.8.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.8.0-alpha.1) from `8b13e027ce5e0fa941a6bbeb1e09c5873b11baee`. Validation **43683254365**, signed build/native launch **43683280236**, eight Mac/Windows update jobs **43683700390**, and publication **43683976252** passed. The unchanged public Linux 0.4 installer also passed activation/recovery. [Release evidence](docs/evidence/release-0.8.0-alpha.1.json) records all ten public files redownloaded and matched to the accepted build, all four ZIP integrity checks and exact inclusion of both reviewed PDFs. Publication did not rebuild artifacts.

- Introduce a short Mars opening followed by control-room preflight. Set a starting pace and explicitly press START MISSION; all model quantities remain frozen beforehand. Science bubbles and the constellation are optional learning routes.
- Replace radio/recall controls with SLOWER, FASTER and a seven-step pace slider from 0.25 to 1.75. Fictional fatigue grows above pace 1 and recovers below 1 while cleaning remains; effective work is 0.125 × pace × (1 − fatigue) sections/minute.
- Run a fixed 30 simulated minutes at a standard sixfold clock. Ren enters automatically at the deadline. There is no walking route, recall, manual work hold or early-entry command.
- Integrate continuous work into solar generation and actual battery kWh. Remove the prior warning-time energy forecast and reserve target. Classify final cleaned fraction as WIN ≥80%, PASS ≥40%, otherwise LOSE.
- Use 210 µGy/day as a historical Curiosity reference inside an explicitly authored increasing rate curve. All completed default rounds accumulate 10.9375 µGy; remove lower-dose stars. Keep gray distinct from sievert and omit health/wearable inference.
- Retain shared navigation, focus/fullscreen recovery, paused science readings, accessible audio/motion settings, the optional advanced lab and local progress boundaries. Preserve earlier quiz identities instead of relabeling past learning records.
- Add NASA SDO's latest available solar browse image with verified HTTPS, bounded decoding, cache/fallback, publication-age labels and required attribution. The imagery does not change mission equations or score.
- Update the model guide, science PDF, pitch and captures for the final workflow. Final-workflow numerical, controller, responsive capture and native-navigation evidence is recorded separately from earlier radio/recall checks.
- Preserve stable branding/save/update identities, credited audio and original design references. Retain signed desktop content updates; the exact released pack passed the supported historical-installer activation and recovery matrix.

Post-release documentation adds a [word-only equation sheet](docs/media/KOMAKU-Video-Equations-Simple.pdf) and [result-screen copy](docs/RESULT-SCREEN-COPY.md) for the design team; these do not alter the published packages.

Mac remains ad-hoc signed without Developer ID/notarization; Windows remains unsigned. Native Android/iOS installers are not provided.

## [0.7.1-alpha.1] — 2026-11-15

A startup-performance patch for the indoor operator view. Published from `c86ad73da7810176e437e33e192a8d8475ae72a8`. [Validation 43657982759](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43657982759), [signed build/native launch 43657993286](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43657993286), [six native updater jobs 43658356504](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43658356504), and [publication 43658558570](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43658558570) all passed. [Public-file evidence](docs/evidence/release-0.7.1-alpha.1.json) records all ten accepted assets redownloaded and verified, including the 16-page PDF and every ZIP’s versioned `START-HERE.txt`. [Startup measurements and scope](docs/WINDOW-STARTUP-PERFORMANCE.md).

- Defer construction of the hidden exterior habitat, refuge, solar-array equipment, route props and legacy control-room artwork until an optional activity needs them. Keep the default clear-window view of dunes and Mira, bounded operator room and rescue behavior.
- Load the exterior on demand when opening **Habitat Field Notes**, then restore the prior world presentation when the lesson closes. Keep constructed optional assets cached afterward; the first optional visit pays the deferred build cost. Optional outdoor EVA can still construct and use the original outpost.
- Restore the exact previous active camera, transform, projection settings and field of view after the architecture overview, together with the prior menu/pause state and keyboard focus. Closing the lesson must return to the same indoor framing instead of leaving the borrowed camera outside.
- Extend the native signed-content update gate to the actual public **0.7.0-alpha.1** Mac and Windows baselines, alongside 0.6.0 and 0.6.1. All six native Mac/Windows jobs passed original-executable activation, repeated healthy startup and tamper recovery; the public 0.4 Linux executable passed the same checks. These use local signed artifacts and headless launches, not a new network/notification/relaunch acceptance test.
- Measure initial-window RSS at 348.43 → 306.64 MiB and synchronous construction at 843 → 436 ms in three fresh Linux llvmpipe processes per version, after warmup. This shifts work to the first optional exterior visit; both versions retain about 429 MiB afterward. These are hosted startup measurements, not physical-device FPS or memory guarantees.
- Keep mission equations, Mira's suit/dose ownership, the 12-hour survival requirement, existing save identity and signing trust unchanged. Refresh the 16-page science guide's source fingerprint; its scientific content is unchanged.

## [0.7.0-alpha.1] — 2026-11-14

Published from `8968859e8ffdcda7b8c0c216ff0262df633400e6` with ten assets. [Validation 43654885534](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43654885534), [signed build 43654898929](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43654898929) and [publication 43655466167](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43655466167) passed. The release adds an indoor operator guiding Mira home, simpler controls and an illustrated science guide. [Release evidence](docs/evidence/release-0.7.0-alpha.1.json).

- Make **Start mission** the indoor operator experience. Keep **Explore · no timer** indoors and retain the original exterior/equipment mode under **Learn & more → Outdoor EVA mission**. Primary controls become panel cleaning, power saving and **Guide Mira**, using buttons or **1/2/3**; **Tab** pauses for cursor controls.
- Frame the primary window with dunes and stranded Mira. Hide exterior dome, equipment, approach and refuge props reversibly for this mode; bound the operator to the room and hide the handheld scanner. Keep the default forward frame free of room consoles; the larger workstations and outpost are retained for optional EVA. Use restrained pearl/navy/cyan presentation.
- Add a companion rescue sequence: **Guide Mira** starts continuous movement through a side-airlock route, abstract cycle and final indoor entry. Shelter applies only at the receiver after all three phases. Mira’s suit/dose state controls her exposure; operator position does not shield her. Require base power survival through 12 simulated hours after mission start, including time after rescue.
- Add a 16-page illustrated science PDF with equations, units, actual parameters, worked examples, sources and explicit teaching assumptions. Package it alongside `START-HERE.txt` in every platform ZIP and publish a standalone versioned PDF, making ten release assets; CI rejects stale source fingerprints.
- Replace abrupt edge teleports with a labelled training-area boundary; distant dune scenery is outside the playable area. Ordinary movement/gravity and reachable mission routes remain intact.
- Add AEGIS mission planning: press **P** during a mission or choose **Compare mission plans** from Pause. Compare four cleaner/conservation policies over the same one-hour scenario, inspect the maths and apply only the chosen switches. Opening the planner pauses mission time and resources.
- Use the actual fixed-step mission model for each private projection, holding present protection fixed. The planner does not predict Mira’s travel or airlock timing. Show abort duration and separate suit/habitat stores; no trained-AI, live-forecast or safety guarantee is implied.
- Simplify the landscape from 109,710 to 21,388 retained triangles while retaining tested walking routes and equipment cues. This is landscape-only geometry work, not whole-game FPS or RAM. [Final landscape scope](docs/DESIGN-PIVOT-0.7.md). Earlier 33.7%/approximately 61% reductions describe historical pre-pivot work; the headless stone-placement digest was invalid and does not prove unchanged positions. [Corrected historical evidence](docs/PERFORMANCE.md).
- Centralize native game validation so local Linux checks, CI and release exports run the same model, UI, performance and updater suites. Pass the complete source suite, 87 operator/291 integration assertions, 36 independent semantic assertions and 65 native input/capture assertions. Pass the exact archive’s native Mac/Windows launch gates and local signed-content activation/repeat-start/tamper-recovery checks from historical 0.6.0/0.6.1 Mac/Windows and 0.4 Linux baselines. These are hosted/native checks, not physical-device FPS or notarization claims.
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
