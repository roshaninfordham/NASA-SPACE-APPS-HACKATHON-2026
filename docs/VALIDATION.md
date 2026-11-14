# Validation record

**Reviewed November 14, 2026.** Evidence is tied to a source/build and a test scope. Passing code checks, publishing an installer, launching it on a physical device, and demonstrating learning benefit are separate outcomes. [Team status](TEAM-STATUS.md) and [the roadmap](ROADMAP.md) record the current release boundary.

## Current 0.6 release

Source `c0beba698c32741fb17f6c8e9ec44fd6bb875852` passed validation `43645084085` and signed build `43645098947`. Publication uses the accepted artifact bytes without rebuilding. [Public-file and platform archive checks](evidence/release-0.6.0-alpha.1.json) record final hashes.

The [0.4 → 0.6 compatibility gate](evidence/update-0.4-to-0.6.json) runs the unchanged, independently pinned historical Linux executable against the new signed content. Healthy activation, repeat startup and same-size corruption recovery pass. This is local-artifact/headless evidence; physical Mac/Windows remain unverified.

New checks cover live control-room telemetry, transformed architecture anchors and a physical berm slope, shared visual-token validation, five suit experiments, and actual keyboard/menu flows. Initial lesson-card bounds, focus scrolling, title/menu separation, 44-pixel targets, mission-resource freezing and pause restoration are checked at 1280×720, 960×540, 390×844 and 844×390. Six rendered UI views were inspected separately. [Media provenance](MEDIA.md) distinguishes screenshot sources from release source. Software rendering cannot establish physical-device frame rates.

## Historical 0.5 release

Source `1b4d1b8e0907f76a055a8aca85e1073c4eff34eb` passed validation run `43641676500` and signed build `43641694667`. Publication run `43642409838` published the accepted nine files without rebuilding. The release manifest SHA-256 is `6dcd7330517e41698cf10f707c74e6e8b5c90c74d934ae01cc9b760faacd16bd`.

The [actual 0.4 → 0.5 installer gate](evidence/update-0.4-to-0.5.json) pins the published Linux ZIP and original executable, stages through its original verifier/store/key, and verifies new startup, repeat startup and tamper fallback. Staging uses matching Godot tooling because release templates do not expose script execution; all boot checks use the unchanged shipped executable. This is Linux/headless/local-artifact evidence, not a new network/GUI/other-OS test.

New checks include continuous capsule routes to the control room/refuge/array, real untimed Explore behavior, and keyboard-operated guide/pause/debrief flows at desktop, portrait and landscape sizes. The downloaded Web archive launched in Chromium with the exact new title and no captured browser errors. Source-project visuals and their scope are recorded in [media provenance](MEDIA.md). Physical Mac/Windows/mobile behavior, educational efficacy and final art quality remain separate gates.

## Historical 0.4 signed desktop content release

[Build 43634324156](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43634324156) completed successfully for source **`48901d0bce68e72974b36377c3a060f90403ebe9`**, public release **0.4.0-alpha.1**, with nine assets and Godot 4.6.3 and runtime contract `red-veil-desktop-v1`. The public trust root was committed by the owner in `2d2aa7c`; the build signed the content manifest with its matching private key.

The exact artifacts passed [native acceptance](../scripts/verify_native_update_acceptance.py):

- ZIP integrity, declared file lengths and SHA-256 hashes matched.
- The content manifest's real signature matched the installer public key and exact source.
- A disposable exported Linux fixture at version `0.4.0-alpha.0` displayed an update notice, verified and staged the actual released content, and prepared activation.
- The production PCK replaced the fixture main scene, reached the startup checkpoint, and persisted across a second launch.
- Same-size tampering with the installed PCK restored the bundled baseline.
- An additional GUI pass exercised real `OS.create_instance` relaunch under authenticated Xvfb/Mesa. The new production process stayed alive with a healthy activation journal for three seconds, without headless/test arguments in that new process.

The accepted pack hash is `e9cf215745acabeb7644ea64f9cc372997432b7a14de4c2c4da5ad82632af157`. The [sanitized acceptance report](evidence/update-0.4.0-alpha.1.json) preserves the machine-readable evidence. The harness can retain logs/fixture exports with `--keep-workspace`.

```sh
python3 scripts/verify_native_update_acceptance.py --artifacts /path/to/exact/downloaded/assets --expected-commit 48901d0bce68e72974b36377c3a060f90403ebe9 --keep-workspace /path/to/new/acceptance-directory
```

**Scope:** Linux x64, headless plus X11 on authenticated Xvfb; a synthetic older fixture, not a previously shipped installer. The final acceptance run used production HTTPRequest against public GitHub URLs with fixture-only proxy/verified-CA configuration. All four HTTP transfers succeeded and exact artifacts matched. Automatic relaunch, healthy repeat boot and tamper recovery passed under Mesa software rendering. Physical Mac/Windows, an earlier public installer transition, physical GPU performance and audio-device behavior remain separate gates.

## Runtime and release suites

The signed release's build/validation paths run these checks. Test files and CI logs are the authoritative current inventory; this document does not preserve a brittle total count as features change.

| Suite                                                                  | Meaningful behavior covered                                                                                                                                                                  | Evidence boundary                                                                                        |
| ---------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `game/tests/mission_test.gd`                                           | Habitat energy accounting, separate suit/visor load, inspection/visibility trade-off, shelter/conservation policy, exposure abort and terminal invariance                                    | Numerical teaching model; not expert validation of hardware or safety limits                             |
| `game/tests/gameplay_test.gd`                                          | Scene launch, HUD anchoring, proximity/held inspection, equipment controls, physical shelter entry, pause, successful mission, debrief, academy integration and nonduplicated input bindings | Headless authored interaction sequence; not physical controller/touch usability                          |
| `game/tests/art_contract_test.gd`                                      | Scene substitution and detached visual snapshots preserve mission rules                                                                                                                      | The tested replacement contract; not every possible new asset/collision layout                           |
| `game/tests/learning_test.gd`                                          | Bayesian arithmetic, alternate prompts, review scheduling, hints/repetition evidence limits, bounded profile recovery/reset and mission-specific support                                     | Provisional tutor correctness; not measured educational efficacy                                         |
| `scripts/test_updater.py`                                              | Real disposable-key signatures, changed manifests/packs, schema/engine/runtime/version/path/size/hash rejection                                                                              | Cryptographic boundary with test keys; no production secret                                              |
| `game/tests/update_client_test.gd`                                     | Release/channel selection, manual fallback, verified install orchestration, network/error states, cancellation/retry, stale callbacks, throttle and explicit repair                          | Deterministic injected transport/store; actual trust and boot behavior tested separately                 |
| `game/tests/update_ui_test.gd`                                         | Small notification, viewport fit, deferral during play, persistent client/restart state across scene reloads and explicit confirmation                                                       | Headless UI state; physical-device interaction remains open                                              |
| `scripts/test_update_bootstrap.py` / `game/tests/update_store_test.gd` | Real temporary PCKs, pinned-key capture before mounting, new script via explicit preload, staged activation, trial/healthy journal, recovery, tampering and storage locking                  | Disposable isolated projects; Linux behavior does not prove every platform's filesystem/restart behavior |
| `tests/test_release_tools.py`                                          | Signing-key match/strength, signature tampering, exact versions/source/tags, temporary-key cleanup, asset allowlist, stale-file exclusion and immutable published-release checks             | Isolated keys/files and mocked GitHub reads                                                              |
| `tests/test_publish_workflow.py`                                       | Accepted build/source binding, rerun/artifact safety, tampering and unchanged publication bytes                                                                                              | Publisher workflow tests; actual publication is a separate operation                                     |

Use `npm run game:test` for the native/release suites wired into that command, and the following publisher check when changing accepted-artifact delivery:

```sh
python3 -m unittest discover -s tests -p test_publish_workflow.py -v
```

The native build smoke test uses isolated user data. Editor/script tests must not activate a developer's real cached update or overwrite a player's practice profile. Published release verification must identify the exact manifest/source; later documentation or tests on main do not retroactively alter an older installer.

## Browser evidence

The exported first-person Godot game has been opened and played in Chromium, with no reported browser errors in the recorded checks. Earlier screenshot inspection exposed a HUD anchoring defect that was fixed and covered by a regression check. Inspected release title, academy and question screenshots now document the actual Web artifact at 1280×720; [media provenance](MEDIA.md) records source and reproduction. The inspected mission still and 20-second gameplay GIF use genuine input and are recorded in the capture manifest with zero browser errors. Their software-rendered capture and encoded frame rate are not physical-device performance evidence.

A separate browser/PWA delivery implementation is in progress. GitHub Pages Actions has been enabled by the owner; this does not itself establish a deployed or verified browser application. Its complete-cache, update, offline and multi-tab behavior requires its own tests and an actual hosting/deployment check. Do not infer PWA installation, Safari/iOS compatibility, Android performance or native RSA-update support from a Chromium launch of a Web ZIP.

## Internal Android export

An isolated internal arm64 APK export passed actual APK signature schemes v2/v3 verification, package identity, version-code and ABI checks. It is 27,857,179 bytes, SHA-256 `bfc3b2cc3f0b05871d859d49b031735e8b60f7b4891a85f392176753a85f64f2`, with package `io.github.roshaninfordham.redveil.internal` and version code 40001. The manifest records committed game source `11aefc47c05ec2e1ef2f5448961d72c0ddc8412b` and `build_tools_working_tree_dirty: true` for the newly developed tooling at that test. This is not an exact committed production release of the new Android build system.

The internal signing key is disposable, not the permanent app identity. Eight isolated Android-tool tests passed. No emulator or physical launch, app upgrade preserving data, native in-app installation, production keystore, public APK or mobile PCK updating has been verified. [Mobile distribution](MOBILE-DISTRIBUTION.md) records the build commands, official platform references and remaining gates.

## Retained reference-model tests

The repository-root Vite/Three.js simulation is still an intentional reference testbed. Its Node model tests cover scenarios and trade-offs, including the sourced Opportunity opacity example. Playwright checks cover desktop/mobile viewport interactions, a complete mission/export flow, WebGL loss/restoration and automated accessibility checks. A production offline reload was checked without third-party runtime requests in that reference flow.

These results belong to the reference application. They do not certify the Godot canvas interface's native screen-reader support, mobile controls or newly added browser delivery layer. Preserve useful model/source regressions when removing obsolete wiring.

## Release and product gates still open

- Continue public download/source verification and expand physical-platform coverage. Actual shipped-installer transitions to 0.5 and 0.6 passed the documented Linux gate.
- Complete live network update checks and physical MacBook M5, Windows and broader Linux graphics validation. Automatic Linux relaunch under Xvfb has passed; physical Mac/Windows relaunch has not.
- Frame pacing, memory, battery and thermal behavior on agreed physical devices; software-rendered cloud Chromium is not Apple Silicon GPU evidence.
- Apple signing/notarization, Windows signing, native Android packaging/signing, and the applicable mobile distribution rules. No native iOS package is currently provided.
- Safari/WebKit, iPhone/iPad and Android browser behavior, touch/safe areas, home-screen installation, persistent storage and update behavior.
- Native screen-reader accessibility, controller navigation, localization and appropriate reading burden across ages 7–12.
- Scientist/engineer review of shielding, energy, atmosphere and compressed-time assumptions; broader colony systems are not independently simulated.
- Supervised learner playtesting for comprehension, engagement, delayed recall and transfer. No child participants or educational-outcome results are claimed.
- Final design-team art, animation, audio direction and optimized replacement assets.

## Proposed evaluation targets

After a guided mission, aim for at least 80% of pilot participants to explain why clean panels can still generate little power under a dusty sky and distinguish suit energy from habitat energy. These are proposed criteria, not observed results. Survival alone is not evidence of understanding.

Measure cached launch time, 30/60 fps presets and memory across ten restarts on agreed physical devices, then establish budgets from those observations. Follow the [playtest protocol](PLAYTEST.md) and keep research/learner data handling explicit.
