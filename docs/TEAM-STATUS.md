# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — team progress

**Current source candidate: 0.9.0-alpha.1; not yet published.** The latest published prerelease is [0.8.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.8.0-alpha.1). New source, captures, packages and updates need their own exact-source acceptance. [Candidate notes](releases/0.9.0-alpha.1.md) · [Current design contract](design-specs/JOURNEY-0.9.md).

## What the team can explain

The new direction is **three short story scenes → preflight → 90-second cleaning round → result → animated science connection**. The player stays inside the habitat, close enough to see Ren's brush and the dusty solar panel through the window. Larger text, bubbles and colored pace controls make the choice easier to read; the mission leaves less of the screen to empty desert.

The real-time countdown starts at about 1:30 at standard pacing. It represents 30 simulated minutes, with every physical teaching-model equation unchanged. Slower/Faster and the stepped slider choose seven requested multipliers from 0.25 to 1.75. The fictional tiredness rule changes effective cleaning rate; partial cleaning immediately improves modeled solar output. Generation minus habitat load accumulates actual battery energy. Reading and Pause freeze the whole model.

At zero, Ren automatically enters. The result appears first, with actual cleaned percentage, stored kWh and absorbed model µGy. **See how science connects** animates the eight concepts into four readable equation groups; **Back to results**, **Try another plan** and **Home** make the ending easy to revisit or record.

WIN/PASS/TRY AGAIN is determined by cleaned fraction: at least 80%, at least 40%, or below 40%. Ren is inside in every category. Energy and dose explain the run, not additional hidden success tests. Every completed default round has the same 10.9375 µGy model dose because outside time and the authored radiation curve are fixed.

## What changed in presentation and handoff

- **Name:** KŌMAKU: Dust & Radiation comes from the shared brand source. New packages use `KOMAKU-Dust-and-Radiation`; save/update identities and existing OS app names remain compatible.
- **Story:** exterior, astronaut and interior illustrations are newly generated, unlettered adaptations of the team's references. Their [provenance](../game/assets/art/journey/provenance.json) identifies them separately from gameplay captures.
- **Audio:** original countdown/warning/urgent beeps support the visual timer. The Drive recording could not be accessed and is not represented as included. Existing music credits and controls remain. [Audio credits](AUDIO-CREDITS.md).
- **Science:** three regenerated PDFs explain the same model and 90-second presentation. The next packaging configuration includes all three; the published 0.8 archives retain their original two PDFs.
- **Submission:** [editable draft answers](SUBMISSION-DRAFT.md) and a [55-word video script with recording notes](VIDEO-PITCH.md) are ready for the team to review. No submission has been made, and the official questions/word limits are still unknown.

Historical Curiosity RAD measurements ground the starting dose rate; Pathfinder supports the dust mechanism. The correct Pathfinder wording is **0.28% per day decrease in solar-cell short-circuit current**. NASA SDO provides a separate latest-image viewer; it does not drive the Mars storm or score. [Model](TRAINING-MODEL.md) · [All sources](SOURCE-INDEX.md).

## Acceptance still required for 0.9

The candidate must pass integrated gameplay and responsive layout checks, exact-source native builds, package launch gates, signed-content activation/recovery on supported original installers, and public-file verification. The expanded native update matrix contains five baseline versions on both Mac and Windows, including 0.8, plus the documented Linux 0.4 check. A configured matrix is not a passed matrix.

The [0.9 gallery](media/journey-0.9/README.md) and [cleaning clip](media/journey-0.9/CLEANING-CLIP.md) now provide source captures with source and fixture provenance. The 0.8 gallery and acceptance records below keep their original scope. Code tests, native runner tests, physical-device usability and learning effectiveness remain distinct. [Validation](VALIDATION.md) · [Media](MEDIA.md).

## Published 0.8 baseline — historical evidence

| Gate                             | Result and evidence                                                                                                                                                                                                                                                                                                                            |
| -------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Shared source validation         | [Run 43683254365](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683254365) passed, including the current journey, retained advanced lab, updater and release checks.                                                                                                                                        |
| Signed build and native startup  | [Run 43683280236](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683280236) passed. Exact [macOS](evidence/native-launch-0.8-macos.json) and [Windows](evidence/native-launch-0.8-windows.json) archives passed their hosted launch gates.                                                                   |
| Existing-install content updates | [Run 43683700390](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683700390) passed all eight Mac/Windows jobs: public 0.6.0, 0.6.1, 0.7.0 and 0.7.1 installers accepted the signed 0.8 content. [Public Linux 0.4 baseline](evidence/update-0.4-to-0.8-linux.json) also passed its documented gate.          |
| Publication and public files     | [Run 43683976252](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43683976252) published the accepted files. All ten were redownloaded and hash matched; four ZIP CRC checks passed. Every ZIP contains the exact reviewed 16-page science guide, two-page technical equation PDF and versioned START-HERE.txt. |

Focused source evidence includes **183 model assertions, 1,665 independent audit checks, 261 HUD assertions, 233 shell assertions, 107 full-main integration assertions, 167 local-progress assertions, 29 update-UI assertions and 29 native-navigation assertions**. These suites have distinct scopes and should not be summed into a claim of physical-device coverage. [Validation and scope](VALIDATION.md) · [Historical media](MEDIA.md).

The unauthenticated public release manifest returned HTTP 200 and SHA-256 `17598cbdaa9ed4d028e64ed886d9c723dd0a192f7c4ea4096698336a031619cf`. Publication preserved the accepted artifacts. Website deployment was skipped because the owner deferred public hosting; the Web ZIP is available for separate hosting.

Native content gates use local signed artifacts to verify activation, repeated healthy startup and recovery. They do not independently prove HTTP transfer, notification clicks or automatic graphical relaunch. Hosted macOS/Windows results do not establish physical M5, phone, GPU or device-audio behavior. Mac remains ad-hoc signed without notarization, Windows unsigned, and no production Android/iOS native installer is supplied.

## Historical 0.7.1 delivery evidence

Published **0.7.1-alpha.1** comes from `c86ad73da7810176e437e33e192a8d8475ae72a8`, with four platform ZIPs, a standalone PDF, and five update/manifest/checksum assets. [Release evidence](evidence/release-0.7.1-alpha.1.json) records the ten verified files. [Downloads](DOWNLOADS.md).

Its validation, signed build/native launch, six native updater jobs, and publication completed. Public Linux 0.4 and Mac/Windows 0.6.0, 0.6.1, and 0.7.0 executables passed local signed 0.7.1 activation, healthy repeat startup, and same-size tamper recovery. These tests do not independently prove notification clicks, HTTP delivery, or automatic graphical relaunch. [Update evidence and scope](UPDATES.md).

The Mac app is ad-hoc signed without Developer ID or notarization; Windows is unsigned. Initial OS trust prompts can remain. The earlier damaged Mac bundle needs one corrected full installation; a content update cannot repair an app that cannot open. No production native Android/iOS package is published, and public web hosting remains deferred by owner choice.

## Remaining product work

Physical MacBook/M5, Windows hardware, mobile-browser, audio and accessibility checks remain necessary. Mac is ad-hoc signed without Developer ID/notarization; Windows is unsigned. No production native Android/iOS installer is published, and public hosting remains deferred by owner choice.

Further character/art refinement, more missions, expert scientific review and supervised learning studies remain on the roadmap. Personalized AI-guided progression is a future proposal, not a shipped capability or measured learning result.

The owner configured GitHub About fields. A renamed sidebar description may require owner administration because the integration previously received HTTP 403. GitHub derives contributor, language and activity counts; meaningful reviewed commits are the progress record.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
