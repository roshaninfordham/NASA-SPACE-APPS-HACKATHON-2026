# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> — team progress

**Latest published release: [0.7.1-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.7.1-alpha.1).** This startup-performance patch keeps the indoor operator mission and default dunes/Mira framing. The [0.7 gallery](MEDIA.md) remains historical source media; [the new measurement capture](evidence/window-startup/candidate/visual/window_initial.png) records the patch source with its [provenance](WINDOW-STARTUP-PERFORMANCE.md).

Published from `c86ad73da7810176e437e33e192a8d8475ae72a8`. [Validation 43657982759](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43657982759), [signed build/native launch 43657993286](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43657993286), [six native updater jobs 43658356504](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43658356504), and [publication 43658558570](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43658558570) all passed. [Release evidence](evidence/release-0.7.1-alpha.1.json) records all ten public assets redownloaded and matched to the accepted bytes, ZIP CRCs and the exact PDF/START-HERE contents.

The release has **ten assets**: four platform ZIPs, a [standalone 16-page science PDF](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/download/v0.7.1-alpha.1/KOMAKU-Shield-Protocol-0.7.1-alpha.1-Science-Guide.pdf), signed content, its update manifest/signature, the release manifest and checksums. Every ZIP includes the identical guide and versioned `START-HERE.txt`. [Platform downloads](DOWNLOADS.md).

The published 0.6.1 repair enables Mac ad-hoc bundle signing and includes an explicit-consent installer, adds native Mac/Windows launch gates, checks Windows ANGLE fallback startup, and checks for updates at every fresh startup. [Root cause and limits](MACOS-LAUNCH-REPAIR.md). A blocked 0.6 Mac app needs one corrected full installation; it cannot repair its own bundle via content updates.

The primary experience keeps the player inside a bounded control room. The default forward window view contains only dunes and Mira; room consoles do not crowd that frame. The scanner and exterior outpost props are hidden in this mode. A separate advanced outdoor EVA retains the original mission and equipment. Branding and presentation remain shared. The new rescue route is a scripted teaching sequence; photoreal art, production character animation and a broader rescue campaign remain separate work.

## New in 0.7.1

The patch defers hidden exterior equipment and legacy interior construction until outdoor EVA or Habitat Field Notes needs them. The default dunes/Mira view and rescue rules stay unchanged. On three fresh Linux llvmpipe processes per version after warmup, median initial RSS falls from **348.43 to 306.64 MiB (12.0%)** and synchronous scene construction from **843 to 436 ms (48.3%)**. The first optional full-world visit incurs the deferred construction cost (394 ms median), and its assets stay cached: both versions then retain about 429 MiB. These are scoped hosted startup measurements, not physical-device FPS or memory guarantees. [Measurement method, ranges and evidence](WINDOW-STARTUP-PERFORMANCE.md). Habitat Field Notes restores the exact active camera, pose/projection/FOV, prior menu/pause state and keyboard focus after its demand-loaded overview. Optional assets remain cached after closing it.

The unchanged public **0.6.0, 0.6.1 and 0.7.0 Mac/Windows executables**, plus **0.4 Linux**, passed signed 0.7.1 content activation, repeated healthy startup and same-size tamper recovery. These native headless checks use local signed artifacts; they do not independently test HTTP transport, notification clicks or automatic GUI relaunch. Directly launching the historical 0.6.0 Mac executable does not repair its invalid Finder bundle signature. [Mac 0.6.0](evidence/update-0.6.0-to-0.7.1-macos.json) · [Windows 0.6.0](evidence/update-0.6.0-to-0.7.1-windows.json) · [Mac 0.6.1](evidence/update-0.6.1-to-0.7.1-macos.json) · [Windows 0.6.1](evidence/update-0.6.1-to-0.7.1-windows.json) · [Mac 0.7.0](evidence/update-0.7.0-to-0.7.1-macos.json) · [Windows 0.7.0](evidence/update-0.7.0-to-0.7.1-windows.json) · [Linux 0.4](evidence/update-0.4-to-0.7.1-linux.json).

The exact 0.7.1 archives passed hosted native [Mac](evidence/native-launch-0.7.1-macos.json) and [Windows](evidence/native-launch-0.7.1-windows.json) launch gates. Mac is still ad-hoc signed without Developer ID/notarization; Windows remains unsigned. Source validation and these hosted gates do not establish physical M5 performance or learner outcomes.

## Mission features introduced in 0.7

The title has **Start mission**, **Explore · no timer**, and **Learn & more**. Start begins the indoor operator mission; Explore is an untimed room visit. **Learn & more → Outdoor EVA mission** exposes the earlier outdoor mode. The main actions are **1** panel cleaning, **2** power saving and **3 / Guide Mira**. **Tab** pauses for clickable controls and **Escape** returns to room movement.

The rescue state machine moves Mira continuously along a fixed side-airlock path, runs an abstract airlock cycle, and completes the final walk to the indoor receiver before granting shelter protection. Suit energy and dose belong to Mira, so walking the operator into a sheltered region cannot shield her. Base survival must continue through the full **12 simulated hours**. The implementation uses an illustrative **60 metres per simulated hour** route speed and **0.15 simulated hours (9 minutes)** for the cycle. These are game assumptions, not physiological or pressure-system validation. The route has a 20.30-metre approach and a 1.60-metre indoor entry. Source integration tests pass, including protection only after the complete entry and full-duration base survival.

AEGIS planning remains optional via **P** or Pause. It compares four fixed cleaner/power-saving policies over one simulated hour, holding the current protection state fixed; it does not predict Mira’s route or airlock transition. The mission stays paused and **Use this plan** changes only those switches. [Planner contract](MISSION-PLANNER.md).

The 16-page [science PDF](media/KOMAKU-Science-Guide.pdf) explains the model at everyday and technical reading levels. It has been regenerated against the final rescue model, including operator/EVA distinctions, the return/cycle/entry timing and planner limits. Stale source fingerprints are a packaging failure.

The historical, fully constructed 0.7 landscape subtree changes from **109,710 to 21,388 retained triangles**. That includes landscape geometry, route and lanterns; it does not measure the whole game, FPS or application RAM. [Landscape evidence](DESIGN-PIVOT-0.7.md). Earlier 33.7% retained-triangle and approximately 61% rendered-primitive reductions refer to historical pre-pivot work. The old headless stone-transform digest was invalid and cannot establish preserved placements; [the corrected performance record](PERFORMANCE.md) keeps those limits explicit. The shared game-test runner synchronizes development, CI and release checks.

## Preserved from 0.6

Suit Lab views and five educational experiments, four habitat callout lessons, the local academy and shared presentation configuration remain available. The dense four-panel/nine-screen room and extensive ornaments are historical 0.6 artwork, superseded by the quieter 0.7 direction. [The specification ledger](SPEC-IMPLEMENTATION.md) records exact source coverage and the larger unfinished art/campaign requirements.

## What the team can demonstrate

- Download and run the Mac universal, Windows x64 or Linux x64 build. Mac is ad-hoc signed but not notarized; Windows has no publisher certificate. Follow the one-time OS trust instructions. Native CI startup is a release gate; physical-device playtesting remains open.
- In 0.7, demonstrate **Start mission → Guide Mira → return/cycle/entry → full-duration base survival**. **Explore · no timer** visits the bounded room without consuming mission resources; Pause can start a fresh rescue or return to the title.
- Use **Outdoor EVA mission** for the earlier array inspection, personal visor cleaning and walk-in refuge. These outdoor actions are not the primary indoor operator task.
- In 0.7, use **Learn & more → Explorer suit lab** to rotate/inspect Mira and compare five teaching experiments; choose **Habitat field notes** for four architecture lessons. Both preserve paused mission resources.
- Open Mira's academy, use hints and explanations, and review locally stored progress. The tutor is a provisional Bayesian model, not a trained or validated AI educator.
- Review [authentic screenshots and gameplay](MEDIA.md), [visual handoff](VISUAL-DIRECTION.md), [changelog](../CHANGELOG.md), and [shared branding](BRANDING.md).

## Historical 0.7 validation and delivery

The complete shared `scripts/test_game.py` suite passed on the final operator source. Focused checks include 87 operator assertions and 291 specification-integration assertions. An independent review passed 36 semantic assertions, including a successful guide-and-save run through 12 simulated hours, the no-action abort, crew/observer independence, no instant shielding, pause and tour reset. These use accelerated controller steps and negative-state fixtures, not a wall-clock human playthrough.

Native Godot Linux input/capture checks passed 65 assertions across 1280×720 and 844×390. They use real engine keyboard/pointer events and verify default view, crew labels, cursor capture, Details bounds, control actions and completed entry. [Player-experience audit](PLAYER-EXPERIENCE-0.7.md) · [capture evidence](media/0.7-capture.json). The exact 0.7 archives also passed hosted native [Mac](evidence/native-launch-0.7-macos.json) and [Windows](evidence/native-launch-0.7-windows.json) launch gates. These checks do not establish physical M5 performance, hardware audio output or every downloaded-app approval route.

The unchanged historical **0.6.0 and 0.6.1 Mac/Windows executables**, plus the **0.4 Linux executable**, passed local signed 0.7 content activation, repeat healthy startup and tamper recovery. [Linux](evidence/update-0.4-to-0.7-linux.json) · [Mac 0.6.0](evidence/update-0.6.0-to-0.7-macos.json) · [Mac 0.6.1](evidence/update-0.6.1-to-0.7-macos.json) · [Windows 0.6.0](evidence/update-0.6.0-to-0.7-windows.json) · [Windows 0.6.1](evidence/update-0.6.1-to-0.7-windows.json). These use local signed artifacts and native headless launches; they do not independently prove HTTP delivery, notification clicks or automatic GUI relaunch. Starting the original 0.6.0 Mac executable directly does not repair its invalid Finder bundle signature.

## Historical 0.6.1 repair evidence

The build pipeline requires numerical/gameplay suites, Linux startup and native Mac/Windows launch gates. The evidence below belongs to published 0.6.1; the separate 0.7 evidence is above. Final release evidence records which exact artifacts passed. Runtime checks cover numerical invariants, a successful mission, capsule-based walking routes, untimed exploration, keyboard-operated dialogs, and desktop/portrait/landscape bounds. Browser fixtures cover offline updates and overlapping worker activation; physical phones are not validated by those fixtures.

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
