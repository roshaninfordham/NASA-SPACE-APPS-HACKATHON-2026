# Red Veil — team progress briefing

**Reviewed November 14, 2026. Latest published release: [0.4.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.4.0-alpha.1), with nine public assets.** Exact source: `48901d0bce68e72974b36377c3a060f90403ebe9`; signed build `43634324156`, attempt 1.

## Explain it in thirty seconds

Red Veil is a downloadable first-person Mars learning-game prototype for ages 7–12. The player explores an outpost, handles equipment, manages separate habitat and suit energy, and reaches a shielded refuge. Mira provides guidance, and five short practice lessons explain the science. The published release adds GitHub-connected update notices and verified desktop content installation with startup recovery. Its real signed content passed Linux acceptance, including automatic process relaunch under Xvfb. The design team can replace the current provisional presentation through documented scene and interface contracts. Final visuals, more missions, device testing and educational validation remain open.

## What players can install today

Published **0.4.0-alpha.1** includes one four-minute mission, Mira's Field Academy, local practice progress, and the new desktop update interface. It provides macOS universal, Windows x64, Linux x64 and Web ZIPs, plus a signed content pack, its manifest/signature, a release manifest and checksums. Content signatures do not replace Apple/Windows app signing; those native apps remain unsigned, and Mac is not notarized.

Players on **0.3.0-alpha.1 or earlier must install 0.4 once manually**. Future compatible signed content releases can use the in-game install/restart flow. An already-current installation will not show a new-version popup. Automatic checks are limited to once per day; the Updates screen also offers a manual check. Engine or runtime-contract changes may require a new installer. Browser and mobile delivery have separate constraints.

Five practice concepts are not five new explorable 3D missions. The practice estimator remains a provisional Bayesian model, not trained AI or a measured mastery score.

## Signed release evidence

The owner completed signing setup: public key commit `2d2aa7c` is in Git, and the signing secret was exercised successfully by [build 43634324156](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43634324156). The released source is **`48901d0bce68e72974b36377c3a060f90403ebe9`**. The private key is not in the repository or game.

The [native acceptance harness](../scripts/verify_native_update_acceptance.py) checked the exact artifacts and actual signature, installed their production PCK through an exported Linux fixture, reached the production game, acknowledged startup, persisted across another launch, and confirmed that same-size pack tampering restored the bundled baseline. A GUI acceptance pass also exercised the real automatic `OS.create_instance` restart under authenticated Xvfb/Mesa; the new production process remained alive with a healthy activation journal. The content hash was `e9cf215745acabeb7644ea64f9cc372997432b7a14de4c2c4da5ad82632af157`.

The checks used **Linux headless plus authenticated Xvfb, local artifact transport, and a disposable older-version fixture**. Automatic Linux relaunch passed, but live HTTP pack transfer, physical Mac/Windows, an update from a previously shipped installer, physical GPU/visual quality and audio-device behavior remain unverified. [Acceptance evidence](evidence/update-0.4.0-alpha.1.json) records that scope. Live Godot GitHub metadata access returned HTTP 200 in a separate proxy-assisted check; that is narrower evidence than a live end-to-end installation.

The accepted bytes were published without rebuilding, with nine public assets and the exact source retained in the release notes. [Update behavior and limits](UPDATES.md) describes the contract and recovery boundaries.

## Current product scope

| Area                 | Implemented baseline                                                                                                           | Remaining scope                                                                                 |
| -------------------- | ------------------------------------------------------------------------------------------------------------------------------ | ----------------------------------------------------------------------------------------------- |
| Player and mission   | First-person movement, scanner, Mira, equipment interactions, one four-minute survival mission                                 | More missions, richer onboarding and tactile in-world experiments                               |
| Scientific model     | Separate energy stores, dust in the atmosphere versus on surfaces, cumulative exposure and passive refuge                      | Expert review and broader colony systems; operational limits remain illustrative                |
| Learning             | Five concepts, ten authored questions, hints, explanations and local review suggestions                                        | Larger curriculum, supervised age-appropriate testing and measured learning outcomes            |
| Presentation         | Replaceable world/equipment/companion/scanner scenes, palette/fonts and HUD contract                                           | Final heavenly sci-fi art, animation, sound direction and performance validation                |
| Desktop distribution | Mac universal, Windows x64 and Linux x64 downloads; signed content updates with scoped Linux install/restart/recovery evidence | Physical Mac/M5 and Windows launch/restart, OS signing and notarization                         |
| Browser/mobile       | Downloadable Godot Web build; tested internal Android arm64 export; browser delivery under active work                         | Verified hosted PWA, physical Safari/Android testing, native Android APK; no native iOS app yet |
| Repository           | About description/website/topics complete, linked contributor identity, documentation, validation/build workflows              | Keep public-release evidence and new platform checks current                                    |

The [ten-outcome roadmap](ROADMAP.md) tracks this delivery pass, with separate statuses for tested code, public releases, mobile routes, cleanup, media and documentation.

## Mobile delivery evidence

An internal Android arm64 APK has been exported and its signature/package/version/ABI checked. It uses a disposable `.internal` identity and is not a public production APK. Its manifest distinguishes committed game source `11aefc47c05ec2e1ef2f5448961d72c0ddc8412b` from the new build tools' uncommitted working state at that test. No emulator/physical launch, production Android signing identity, native installation flow or mobile content updater is claimed. [Mobile distribution](MOBILE-DISTRIBUTION.md) records the exact artifact and applicable Android/iOS routes.

## Review the actual interface

The release [title screen](media/red-veil-0.4.0-alpha.1-title.png), [academy](media/red-veil-0.4.0-alpha.1-academy.png) and [practice question](media/red-veil-0.4.0-alpha.1-question.png) were captured from the running Web artifact at 1280×720. They show real provisional software, not concept art or a native-update demonstration. [Media provenance](MEDIA.md) records the source and reproduction. The inspected [mission still](media/red-veil-0.4.0-alpha.1-mission.png) and [20-second gameplay GIF](media/red-veil-0.4.0-alpha.1-gameplay.gif) show real looking, walking and visor control. The GIF is 960×540 at 10 fps for presentation; it is not a performance benchmark or a completed-mission demonstration.

## GitHub sidebar

About now has the owner-provided description, website and topics. GitHub lists the owner as a contributor and detects GDScript, JavaScript, CSS, Python and HTML. Godot's C++ engine is an external dependency, so it does not appear as this repository's own C++ source. Game installers are Release assets; a separate Packages registry entry is not needed. Stars, watchers and forks represent real user activity. Alpha releases remain marked as prereleases.

## Immediate team responsibilities

1. Engineering: keep public release/source verification current, complete remaining live/device update checks, and integrate browser/mobile delivery with its own evidence. GitHub Pages Actions is enabled; browser deployment still awaits its packaging tests and a successful public deploy.
2. Design: supply licensed assets through the [replacement contracts](DESIGN-HANDOFF.md), and review authentic software captures without treating provisional art as final.
3. Science and education: review the assumptions and run the proposed supervised [playtest protocol](PLAYTEST.md). No child-study results or professional-training claim exist yet.
4. Device testers: report the exact version, OS, hardware, controls and reproducible steps. A successful cross-export does not replace a physical launch.
5. Repository owner: About, desktop update signing setup and GitHub Pages Actions enablement are complete. New platform credentials or hosting settings may need a separate, concrete owner action; no repeat desktop signing setup is required.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
