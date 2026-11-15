# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — team progress

**Video delivered:** [29.5-second 1080p MP4](media/submission-demo/KOMAKU-30-second-demo.mp4), with [captions, AI-voice credits and capture provenance](media/submission-demo/README.md). It uses actual prototype engine footage, edited into a 24 fps presentation; it is not a child playtest or a new release announcement. The public GitHub bytes were verified and the complete video passed FFmpeg decoding.

**Published [0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1) — November 15, 2026, 13:53:05 UTC.** Built from `26f19540baf330b00b0ac4a1b470d0e1439f7382`. This release simplifies the interface and corrects the installation handoff while preserving the 90-second mission and its equations. [Release notes](releases/0.10.0-alpha.1.md).

## Current visual and learning source — not released

Ren’s face and brush are more visible; terrain, lighting/reflections, the dust and beveled panel, and the glass/frame/rail have been revised together. Story and result presentation also have new treatments. Visual acceptance remains a review task, not something proved by implementation.

The new local coaching responds once per relevant event during the run. **Your training**, available from Home and Menu, adds recent outcomes, explored ideas and the existing pace/fatigue practice result. Schema 3 keeps up to 30 detailed recent runs and cumulative counters. Migrated profiles identify incomplete older history; neither card visits nor these game records establish mastery or real astronaut readiness.

The shared native game suite passed after integration, including 401 training-journal and 377 progress assertions; the supplemental actual-main training flow passed 53 assertions. The final targeted navigation-label recheck also passed all 53 assertions. The earlier C1 build, update matrix and 41-screen gallery below do **not** cover these newer visuals, coaching or journal. Published downloads remain 0.10. [Current change details](VISUAL-LEARNING-UPDATE.md).

The optional [Cloudflare NASA context cache](../services/nasa-context-worker/README.md) has 17 isolated tests, a Wrangler dry run and a NASA probe. It is not deployed or connected to the client; account permission would be required to deploy it. The existing direct NASA image view and offline lesson still operate independently.

## Earlier 0.11 C1 candidate — historical acceptance scope

**Historical C1 candidate; not published.** This earlier interface restored the outpost-window presentation and eight visible science bubbles, with **View → Science window / Focused window**, direct Home navigation, and captioned radio feedback. It retains the 0.10 short wording, typography, 90-second mission and equations. [Candidate design contract](design-specs/JOURNEY-0.11.md). Downloads and published acceptance below still refer to 0.10 until the new build passes its own release checks.

The player remains inside the outpost, looking through the window at Ren and the panel. **Science window** restores eight visible bubbles with model-linked readings; **Focused window** keeps the view quieter. **View** changes presentation only. Existing short card wording and fonts remain. Opening a concept pauses the mission; detailed equations and sources stay available on request.

**Home** is explicit in Menu, and Home offers direct access to view and sound settings. Scripted player/Ren captions acknowledge Start and pace changes. Profile schema 2 saves the chosen view and migrates recognized schema 1 settings/history; this is local preference storage, not a new intelligence or health layer.

The equations, 90-second standard round, automatic entry and outcome rules are unchanged. Candidate source `20e361a2099f7bc67aacb0e7eedb65c7eab9d0a0` passed the complete shared source suite. The [0.11 gallery](media/journey-0.11/README.md) records **170 captured states across five viewports**, [native Linux navigation](evidence/journey-native-0.11.json) passed **39 assertions**, and the **41-screen review gallery** passed **22 browser tests**. [Download the actual cleaning MP4](media/journey-0.11/cleaning-live.mp4) for editing; retain its [capture scope and timing](media/journey-0.11/CLEANING-CLIP.md).

[Build 43729552243](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43729552243) completed exports and [Mac startup](evidence/native-launch-0.11-macos.json). All [fourteen Mac/Windows update jobs](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43730091761) and the [Linux 0.4 gate](evidence/update-0.4-to-0.11-linux.json) passed. The [Windows package report](evidence/native-launch-0.11-windows.json) records three passed startup probes followed by a file-lock cleanup error; its retained overall success flag is unreliable, so the package gate awaits a corrected-harness recheck.

**Publication is held, and visual acceptance remains pending.** The [public 41-screen review gallery](https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/review/0.11.0-alpha.1/) is available for feedback with [22 passed browser tests and deployment evidence](evidence/screen-review-0.11.0-alpha.1.json). This is not a 0.11 game release. Technical checks do not establish that the visual design meets the team’s expectations. Published downloads remain **0.10**.

## What the team can explain about published 0.10

The new direction is **three short story scenes → preflight → 90-second cleaning round → result → animated science connection**. The player stays inside the habitat, close enough to see Ren's brush and the dusty solar panel through the window. Three main readings—panel cleaned, energy stored and real play time—sit beside one red pace control. The optional Science library holds the eight concepts, so the window stays focused on Ren’s work.

The real-time countdown starts at about 1:30 at standard pacing. It represents 30 simulated minutes, with every physical teaching-model equation unchanged. Slower/Faster and the stepped slider choose seven requested multipliers from 0.25 to 1.75. The fictional tiredness rule changes effective cleaning rate; partial cleaning immediately improves modeled solar output. Generation minus habitat load accumulates actual battery energy. Reading and Pause freeze the whole model.

At zero, Ren automatically enters. The result appears first, with actual cleaned percentage, stored kWh and absorbed model µGy. **See how science connects** animates the eight concepts into four short science relationships, with precise equations and graphs available under **Explore my numbers and graphs**; **Back to results**, **Try another plan** and **Home** make the ending easy to revisit or record.

WIN/PASS/TRY AGAIN is determined by cleaned fraction: at least 80%, at least 40%, or below 40%. Ren is inside in every category. Energy and dose explain the run, not additional hidden success tests. Every completed default round has the same 10.9375 µGy model dose because outside time and the authored radiation curve are fixed.

## Published 0.10 presentation and handoff

- **Name:** KŌMAKU: Dust & Radiation comes from the shared brand source. New packages use `KOMAKU-Dust-and-Radiation`; save/update identities and existing OS app names remain compatible.
- **Story:** exterior, astronaut and interior illustrations are newly generated, unlettered adaptations of the team's references. Their [provenance](../game/assets/art/journey/provenance.json) identifies them separately from gameplay captures.
- **Interface:** concise opening/result copy, real scene-loading feedback with cancellation, and optional short science cards reduce first-screen reading. **Learn more** and **Data & sources** retain the full explanation and evidence.
- **Audio:** softer original pace, discovery and open/close cues support interaction; countdown/warning/urgent beeps still support the visual timer. The Drive recording could not be accessed and is not represented as included. Existing music credits and controls remain. [Audio credits](AUDIO-CREDITS.md).
- **Science:** three regenerated PDFs explain the same model and 90-second presentation. The current package includes all three; the published 0.8 archives retain their original two PDFs.
- **Submission:** [exact 50/150/300-word answers and source list](SUBMISSION-COPY-PASTE.md), [longer draft](SUBMISSION-DRAFT.md) and a [55-word video script with recording notes](VIDEO-PITCH.md) are ready for the team to review. No submission has been made, and the official questions/word limits are still unknown.

Historical Curiosity RAD measurements ground the starting dose rate; Pathfinder supports the dust mechanism. The correct Pathfinder wording is **0.28% per day decrease in solar-cell short-circuit current**. NASA SDO provides a separate latest-image viewer; it does not drive the Mars storm or score. [Model](TRAINING-MODEL.md) · [All sources](SOURCE-INDEX.md).

## Published 0.10.0 acceptance

The [source validation](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43720618321), [signed build/native startup](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43720633663), [twelve Mac/Windows update jobs](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43721023112) and [publication](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/actions/runs/43721296427) passed for `26f19540baf330b00b0ac4a1b470d0e1439f7382`. Exact [Mac](evidence/native-launch-0.10-macos.json) and [Windows](evidence/native-launch-0.10-windows.json) archives passed hosted startup. Six original installer versions on each native platform, plus [Linux 0.4](evidence/update-0.4-to-0.10-linux.json), passed signed-content activation, repeated healthy startup and recovery. [Public-file verification](evidence/release-0.10.0-alpha.1.json) matched all ten downloads to the accepted build. All four ZIPs passed integrity checks and contain the current instructions and exact three reviewed PDFs. The public manifest returned HTTP 200 without authentication.

The 29-assertion native Linux navigation check also passed. The gallery covers 135 states across five viewports with zero layout findings and unchanged recorded source hashes. These layout and hosted native checks do not establish physical-device performance or learning effectiveness.

The [0.10 gallery](media/journey-0.10/README.md) records the new interface with source and fixture provenance. The [0.9 gallery](media/journey-0.9/README.md) remains historical evidence for its earlier interface. The 0.8 gallery and acceptance records below keep their original scope. Code tests, native runner tests, physical-device usability and learning effectiveness remain distinct. [Validation](VALIDATION.md) · [Media](MEDIA.md).

## Published 0.9 baseline — historical evidence

[0.9.0 public-file verification](evidence/release-0.9.0-alpha.1.json) records the accepted source and assets. Its gameplay introduced the current 90-second presentation; the underlying mission equations already existed in 0.8. Its bundled download guide still foregrounded old filenames and links, which 0.10 corrects without changing the old artifacts.

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
