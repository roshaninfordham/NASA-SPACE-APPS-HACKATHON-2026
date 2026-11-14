# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> — team progress

**Current package version: 0.6.1-alpha.1, November 14, 2026.** This is a packaging/update repair for the 0.6 gameplay release. The [release list](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases) and each archive's manifest identify the published source and downloads. Four platform ZIPs plus signed content, its manifest/signature, release manifest and checksums make nine assets.

The repair enables Mac ad-hoc bundle signing and includes an explicit-consent installer, adds native Mac/Windows launch gates, checks Windows ANGLE fallback startup, and checks for updates at every fresh startup. [Root cause and limits](MACOS-LAUNCH-REPAIR.md). A blocked 0.6 Mac app needs one corrected full installation; it cannot repair its own bundle via content updates.

The game now has a shared brand configuration, a walkable ornamented habitat and holographic control room, a shielded refuge, Mira's redesigned suit, a new scanner, lantern-lit terrain and an untimed exploration mode. It retains the four-minute first-person science mission, separate energy stores, dust/radiation decisions, and five-concept local practice academy. The new scenes are procedural interpretations of supplied designs; final photoreal art and a complete escort/rescue campaign are not delivered.

## New in 0.6

The 0.6 release adds live Suit Lab views and five educational experiments, four habitat callout lessons, denser control-room telemetry and geodesic hologram geometry, architectural/suit material detail, and a shared presentation style file. [The specification ledger](SPEC-IMPLEMENTATION.md) records exact source coverage and the larger unfinished art/campaign requirements.

## What the team can demonstrate

- Download and run the Mac universal, Windows x64 or Linux x64 build. Mac is ad-hoc signed but not notarized; Windows has no publisher certificate. Follow the one-time OS trust instructions. Native CI startup is a release gate; physical-device playtesting remains open.
- Choose **Explore the habitat** to inspect the room without consuming mission time, batteries or dose. Choose the timed mission separately to test the survival decisions.
- Use actual consoles, inspect the solar array, conserve power, manage visor/panel cleaning and walk into the passive refuge. The numerical rules were preserved through the visual pivot.
- Open **Explorer Suit Lab** to rotate/inspect Mira and compare five teaching experiments; choose **Habitat Field Notes** for four architecture lessons. Both preserve paused mission resources.
- Open Mira's academy, use hints and explanations, and review locally stored progress. The tutor is a provisional Bayesian model, not a trained or validated AI educator.
- Review [authentic screenshots and gameplay](MEDIA.md), [visual handoff](VISUAL-DIRECTION.md), [changelog](../CHANGELOG.md), and [shared branding](BRANDING.md).

## Verified delivery and update behavior

The build requires numerical/gameplay suites, Linux startup and native Mac/Windows launch gates. Final release evidence records which exact artifacts passed. Runtime checks cover numerical invariants, a successful mission, capsule-based walking routes, untimed exploration, keyboard-operated dialogs, and desktop/portrait/landscape bounds. Browser fixtures cover offline updates and overlapping worker activation; physical phones are not validated by those fixtures.

The **actual published 0.4 Linux executable** verified and mounted the new signed 0.6 pack, acknowledged healthy startup, repeated startup and recovered its original version after same-size pack tampering. Its executable hash stayed unchanged. [Exact evidence](evidence/update-0.4-to-0.6.json). This gate used local verified artifact bytes and headless launches. Separately, the earlier [0.4 synthetic-fixture acceptance](evidence/update-0.4.0-alpha.1.json) passed real GitHub transfers and automatic GUI relaunch under Xvfb. These are distinct scopes; neither proves physical Mac/Windows updating.

Players on 0.4 can receive compatible content through **Updates → download → restart**. Earlier installers need one initial upgrade. The rename preserves save paths and signing identity; older installed application bundles can keep their historical filename. Engine/native dependency changes still require a full installer.

## Platform and repository limits

Public hosting is deferred by owner choice. Pages deployment succeeded, but verification found an inherited custom-domain redirect to another website. Automatic web deployment is disabled until a separate game address is chosen. The Web archive remains available for self-hosting.

Android tooling produced an earlier internal arm64 APK with a disposable test identity; no production Android/iOS native package, mobile self-updater or physical-device result is claimed. [Mobile routes](MOBILE-DISTRIBUTION.md).

The repository has releases, source commits, workflows, media and documentation. The About description still needs the owner to apply the new name because the integration returned HTTP 403. Downloads belong in Releases; the Packages registry is not required. Stars, watchers and forks reflect real users, not project tasks.

## Remaining work

Design review and authored high-fidelity assets; a production character rig, rescue interactions and a sealed habitat/airlock cycle; broader curriculum and missions; reduced-effect/device performance profiles; physical Mac/Windows/mobile input and update testing; accessibility/device-cutout review; science-expert and supervised learner evaluation. The [roadmap](ROADMAP.md) keeps these separate from delivered code.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
