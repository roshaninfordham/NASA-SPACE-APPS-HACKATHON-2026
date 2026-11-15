# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> — team progress

**Published prerelease: [0.8.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.8.0-alpha.1).** Released November 15, 2026 at 06:07:25 UTC (01:07:25 America/New_York), from source `8b13e027ce5e0fa941a6bbeb1e09c5873b11baee`. All ten public assets were downloaded again and matched to the accepted build. [Release evidence](evidence/release-0.8.0-alpha.1.json).

## The change the team can explain

The final 0.8 direction is **short opening → control-room preflight → pace/fatigue cleaning mission → automatic entry → result equations**. The player stays inside the habitat, looking through a calm window at Ren and a nearby panel. An optional science constellation remains available; all-eight-card review is not required before Start. The earlier operator/EVA experience remains in Advanced lab.

Preflight lets the player select a starting pace without spending mission time. During the five-minute default round, SLOWER, FASTER and the slider choose seven multipliers from 0.25 to 1.75. Fictional fatigue changes effective cleaning. Partial work improves solar output, and generation minus a 1 kW load accumulates actual battery energy. At 30 simulated minutes Ren enters automatically. There is no recall, walking or reserve forecast.

WIN/PASS/LOSE depends on final cleanliness: at least 80%, at least 40%, or less than 40%. Energy, fatigue and dose explain what happened. Shared components keep this workflow separate from replaceable visual assets. The [independent pace-model audit](evidence/pace-model-0.8-audit.json) is recorded. The final shared suite, integrated controls, native package gates and compatible-content update checks passed for the released source. The gallery contains 51 current captures and a GIF made from 17 rendered frames; these are documented captures, not a physical-device frame-rate measurement.

## Science that changed

The historical 210 ±40 µGy/day Curiosity tissue-like RAD result remains the absorbed-dose reference. The final story curve is explicitly authored: `r(t) = 210 × (1 + 3t/T)` µGy/day. The fixed outside duration gives **10.9375 µGy in every completed default round**, so no lower-dose stars are awarded. There is no inferred Sv, health threshold or wearable data.

Fatigue is fictional balancing, starting at zero and clamped to 0–0.9. Its rate is `0.08 × max(u−1,0) − 0.12 × max(1−u,0)` per simulated minute while cleaning remains. Work is `0.125 × u × (1−F)` sections/minute, capped at four. Array rating (8 kW), dirty transmission (0.25), load (1 kW), and initial/capacity energy (0.5/6 kWh) are authored. Energy is actual kWh, not a future reserve. [Model](TRAINING-MODEL.md) · [Source audit](SCIENCE-JOURNEY-SOURCES.md) · [Guide](SCIENCE-GUIDE.md).

NASA SDO's optional latest solar browse image remains a genuine online source with connected/cached/bundled/stale labels. It does not supply the radiation ramp or score. Publication metadata is not exposure time. [Live-data contract](LIVE-DATA.md) · [All sources](SOURCE-INDEX.md).

## Accepted 0.8 release

| Gate                             | Result and evidence                                                                                                                                                                                                                                                                                                                            |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shared source validation         | [Run 43683254365](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683254365) passed, including the current journey, retained advanced lab, updater and release checks.                                                                                                                                        |
| Signed build and native startup  | [Run 43683280236](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683280236) passed. Exact [macOS](evidence/native-launch-0.8-macos.json) and [Windows](evidence/native-launch-0.8-windows.json) archives passed their hosted launch gates.                                                                   |
| Existing-install content updates | [Run 43683700390](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683700390) passed all eight Mac/Windows jobs: public 0.6.0, 0.6.1, 0.7.0 and 0.7.1 installers accepted the signed 0.8 content. [Public Linux 0.4 baseline](evidence/update-0.4-to-0.8-linux.json) also passed its documented gate.          |
| Publication and public files     | [Run 43683976252](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683976252) published the accepted files. All ten were redownloaded and hash matched; four ZIP CRC checks passed. Every ZIP contains the exact reviewed 16-page science guide, two-page technical equation PDF and versioned START-HERE.txt. |

Focused source evidence includes **183 model assertions, 1,665 independent audit checks, 261 HUD assertions, 233 shell assertions, 107 full-main integration assertions, 167 local-progress assertions, 29 update-UI assertions and 29 native-navigation assertions**. These suites have distinct scopes and should not be summed into a claim of physical-device coverage. [Validation and scope](VALIDATION.md) · [Current media](MEDIA.md).

The unauthenticated public release manifest returned HTTP 200 and SHA-256 `17598cbdaa9ed4d028e64ed886d9c723dd0a192f7c4ea4096698336a031619cf`. Publication preserved the accepted artifacts. Website deployment was skipped because the owner deferred public hosting; the Web ZIP is available for separate hosting.

Native content gates use local signed artifacts to verify activation, repeated healthy startup and recovery. They do not independently prove HTTP transfer, notification clicks or automatic graphical relaunch. Hosted macOS/Windows results do not establish physical M5, phone, GPU or device-audio behavior. Mac remains ad-hoc signed without notarization, Windows unsigned, and no production Android/iOS native installer is supplied.

## Historical 0.7.1 delivery evidence

Published **0.7.1-alpha.1** comes from `c86ad73da7810176e437e33e192a8d8475ae72a8`, with four platform ZIPs, a standalone PDF, and five update/manifest/checksum assets. [Release evidence](evidence/release-0.7.1-alpha.1.json) records the ten verified files. [Downloads](DOWNLOADS.md).

Its validation, signed build/native launch, six native updater jobs, and publication completed. Public Linux 0.4 and Mac/Windows 0.6.0, 0.6.1, and 0.7.0 executables passed local signed 0.7.1 activation, healthy repeat startup, and same-size tamper recovery. These tests do not independently prove notification clicks, HTTP delivery, or automatic graphical relaunch. [Update evidence and scope](UPDATES.md).

The Mac app is ad-hoc signed without Developer ID or notarization; Windows is unsigned. Initial OS trust prompts can remain. The earlier damaged Mac bundle needs one corrected full installation; a content update cannot repair an app that cannot open. No production native Android/iOS package is published, and public web hosting remains deferred by owner choice.

## Open product work

The follow-up [result-screen copy](RESULT-SCREEN-COPY.md), [words-only equation notes](VIDEO-EQUATIONS-SIMPLE.md) and [one-page simple equation PDF](media/KOMAKU-Video-Equations-Simple.pdf) are repository documentation created after the release build. They are **not included in the published 0.8 ZIPs**. Those ZIPs contain the reviewed technical two-page equation PDF. New result wording is a future design change, not an already shipped UI update.

Final authored art and character animation, more curriculum and missions, expert scientific review, physical-device performance/audio/accessibility, and evidence of learning transfer remain open. The team can iterate modular visuals without rewriting the short mission model, but collision, input, source, and device checks still matter.

The GitHub About fields were configured by the owner. Any remaining renamed description change requires owner administration because the integration received HTTP 403; no new authentication or repeated sidebar edit is needed for this release work. GitHub derives contributor/language/activity counts. Meaningful reviewed commits and safe parallel ownership matter; artificial contribution counts do not.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
