# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> — team progress

**Source candidate: 0.7.0-alpha.1. Latest published release: [0.6.1-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.6.1-alpha.1).** The candidate implements an indoor operator mission: guide Mira home while managing base power. The [current gallery](MEDIA.md) contains fresh indoor-rescue captures replacing the superseded outdoor-start views. The published 0.6.1 download still has the older outdoor mission and presentation.

The candidate packaging prepares **ten release assets**: four platform ZIPs, a standalone versioned science PDF, signed content, its update manifest/signature, the release manifest and checksums. The same PDF and a short `START-HERE.txt` launch/mission guide are bundled in every ZIP. Publication and final artifact acceptance are separate from source implementation.

The published 0.6.1 repair enables Mac ad-hoc bundle signing and includes an explicit-consent installer, adds native Mac/Windows launch gates, checks Windows ANGLE fallback startup, and checks for updates at every fresh startup. [Root cause and limits](MACOS-LAUNCH-REPAIR.md). A blocked 0.6 Mac app needs one corrected full installation; it cannot repair its own bundle via content updates.

The primary candidate experience keeps the player inside a bounded control room. The default forward window view contains only dunes and Mira; room consoles do not crowd that frame. The scanner and exterior outpost props are hidden in this mode. A separate advanced outdoor EVA retains the original mission and equipment. Branding and presentation remain shared. The new rescue route is a scripted teaching sequence; photoreal art, production character animation and a broader rescue campaign remain separate work.

## New in 0.7

The candidate title has **Start mission**, **Explore · no timer**, and **Learn & more**. Start begins the indoor operator mission; Explore is an untimed room visit. **Learn & more → Outdoor EVA mission** exposes the earlier outdoor mode. The main actions are **1** panel cleaning, **2** power saving and **3 / Guide Mira**. **Tab** pauses for clickable controls and **Escape** returns to room movement.

The rescue state machine moves Mira continuously along a fixed side-airlock path, runs an abstract airlock cycle, and completes the final walk to the indoor receiver before granting shelter protection. Suit energy and dose belong to Mira, so walking the operator into a sheltered region cannot shield her. Base survival must continue through the full **12 simulated hours**. The implementation uses an illustrative **60 metres per simulated hour** route speed and **0.15 simulated hours (9 minutes)** for the cycle. These are game assumptions, not physiological or pressure-system validation. The route has a 20.30-metre approach and a 1.60-metre indoor entry. Source integration tests pass, including protection only after the complete entry and full-duration base survival.

AEGIS planning remains optional via **P** or Pause. It compares four fixed cleaner/power-saving policies over one simulated hour, holding the current protection state fixed; it does not predict Mira’s route or airlock transition. The mission stays paused and **Use this plan** changes only those switches. [Planner contract](MISSION-PLANNER.md).

The 16-page [science PDF](media/KOMAKU-Science-Guide.pdf) explains the model at everyday and technical reading levels. It has been regenerated against the final rescue model, including operator/EVA distinctions, the return/cycle/entry timing and planner limits. Stale source fingerprints are a packaging failure.

The final landscape subtree changes from **109,710 to 21,388 retained triangles**. That includes landscape geometry, route and lanterns; it does not measure the whole game, FPS or application RAM. [Landscape evidence](DESIGN-PIVOT-0.7.md). Earlier 33.7% retained-triangle and approximately 61% rendered-primitive reductions refer to historical pre-pivot work. The old headless stone-transform digest was invalid and cannot establish preserved placements; [the corrected performance record](PERFORMANCE.md) keeps those limits explicit. The shared game-test runner synchronizes development, CI and release checks.

## Preserved from 0.6

Suit Lab views and five educational experiments, four habitat callout lessons, the local academy and shared presentation configuration remain available. The dense four-panel/nine-screen room and extensive ornaments are historical 0.6 artwork, superseded by the quieter candidate direction. [The specification ledger](SPEC-IMPLEMENTATION.md) records exact source coverage and the larger unfinished art/campaign requirements.

## What the team can demonstrate

- Download and run the Mac universal, Windows x64 or Linux x64 build. Mac is ad-hoc signed but not notarized; Windows has no publisher certificate. Follow the one-time OS trust instructions. Native CI startup is a release gate; physical-device playtesting remains open.
- In the source candidate, demonstrate **Start mission → Guide Mira → return/cycle/entry → full-duration base survival**. **Explore · no timer** visits the bounded room without consuming mission resources; Pause can start a fresh rescue or return to the title.
- Use **Outdoor EVA mission** for the earlier array inspection, personal visor cleaning and walk-in refuge. These outdoor actions are not the primary indoor operator task.
- In the source candidate, use **Learn & more → Explorer suit lab** to rotate/inspect Mira and compare five teaching experiments; choose **Habitat field notes** for four architecture lessons. Both preserve paused mission resources.
- Open Mira's academy, use hints and explanations, and review locally stored progress. The tutor is a provisional Bayesian model, not a trained or validated AI educator.
- Review [authentic screenshots and gameplay](MEDIA.md), [visual handoff](VISUAL-DIRECTION.md), [changelog](../CHANGELOG.md), and [shared branding](BRANDING.md).

## Candidate validation

The complete shared `scripts/test_game.py` suite passed on the final operator source. Focused checks include 87 operator assertions and 291 specification-integration assertions. An independent review passed 36 semantic assertions, including a successful guide-and-save run through 12 simulated hours, the no-action abort, crew/observer independence, no instant shielding, pause and tour reset. These use accelerated controller steps and negative-state fixtures, not a wall-clock human playthrough.

Native Godot Linux input/capture checks passed 65 assertions across 1280×720 and 844×390. They use real engine keyboard/pointer events and verify default view, crew labels, cursor capture, Details bounds, control actions and completed entry. [Player-experience audit](PLAYER-EXPERIENCE-0.7.md) · [capture evidence](media/0.7-capture.json). Exact 0.7 release archives and native Mac/Windows release gates remain pending; the older release evidence below must not be presented as candidate artifact acceptance.

## Published 0.6.1 delivery evidence and update behavior

The build pipeline requires numerical/gameplay suites, Linux startup and native Mac/Windows launch gates. The evidence below belongs to published 0.6.1; it does not establish acceptance of the 0.7 candidate. Final release evidence records which exact artifacts passed. Runtime checks cover numerical invariants, a successful mission, capsule-based walking routes, untimed exploration, keyboard-operated dialogs, and desktop/portrait/landscape bounds. Browser fixtures cover offline updates and overlapping worker activation; physical phones are not validated by those fixtures.

The **actual published 0.6 Mac and Windows executables** and **0.4 Linux executable** verified and mounted the signed 0.6.1 pack, acknowledged healthy startup, repeated startup and recovered their original versions after same-size pack tampering. Their original package files stayed unchanged. [Mac evidence](evidence/update-0.6-to-0.6.1-macos.json), [Windows evidence](evidence/update-0.6-to-0.6.1-windows.json), [Linux evidence](evidence/update-0.4-to-0.6.1-linux.json). This gate used local verified bytes and headless launches. Separately, the earlier [0.4 synthetic-fixture acceptance](evidence/update-0.4.0-alpha.1.json) passed real GitHub transfers and automatic GUI relaunch under Xvfb. These are distinct scopes; none establishes physical M5 performance or complete end-user interaction coverage.

Final build `43648641582` also passed [native Mac launch checks](evidence/native-launch-0.6.1-macos.json) (strict signature, both universal architectures, graphics and LaunchServices opening) and [Windows graphics checks](evidence/native-launch-0.6.1-windows.json) (default and forced ANGLE). Hosted runners used silent audio.

Players on 0.4 can receive compatible content through **Updates → download → restart**. Earlier installers need one initial upgrade. The rename preserves save paths and signing identity; older installed application bundles can keep their historical filename. Engine/native dependency changes still require a full installer.

## Platform and repository limits

Public hosting is deferred by owner choice. Pages deployment succeeded, but verification found an inherited custom-domain redirect to another website. Automatic web deployment is disabled until a separate game address is chosen. The Web archive remains available for self-hosting.

Android tooling produced an earlier internal arm64 APK with a disposable test identity; no production Android/iOS native package, mobile self-updater or physical-device result is claimed. [Mobile routes](MOBILE-DISTRIBUTION.md).

The repository has releases, source commits, workflows, media and documentation. The About description still needs the owner to apply the new name because the integration returned HTTP 403. Downloads belong in Releases; the Packages registry is not required. Stars, watchers and forks reflect real users, not project tasks.

## Remaining work

Design review and authored high-fidelity assets; a production character rig, broader rescue interactions and a physically modeled sealed habitat/airlock; broader curriculum and missions; reduced-effect/device performance profiles; physical Mac/Windows/mobile input and update testing; accessibility/device-cutout review; science-expert and supervised learner evaluation. The [roadmap](ROADMAP.md) keeps these separate from delivered code.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
