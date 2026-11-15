# <!-- brand:display_name -->KŌMAKU: Shield Protocol<!-- /brand --> — team progress

**Release source snapshot: 0.8.0-alpha.1.** Prepared November 15, 2026, America/New_York. Publication was pending when this source snapshot was prepared; check the [release index](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases) for available files and the final acceptance record. A versioned source document alone is not proof of publication.

## The change the team can explain

The final 0.8 direction is **short opening → control-room preflight → pace/fatigue cleaning mission → automatic entry → result equations**. The player stays inside the habitat, looking through a calm window at Ren and a nearby panel. An optional science constellation remains available; all-eight-card review is not required before Start. The earlier operator/EVA experience remains in Advanced lab.

Preflight lets the player select a starting pace without spending mission time. During the five-minute default round, SLOWER, FASTER and the slider choose seven multipliers from 0.25 to 1.75. Fictional fatigue changes effective cleaning. Partial work improves solar output, and generation minus a 1 kW load accumulates actual battery energy. At 30 simulated minutes Ren enters automatically. There is no recall, walking or reserve forecast.

WIN/PASS/LOSE depends on final cleanliness: at least 80%, at least 40%, or less than 40%. Energy, fatigue and dose explain what happened. Shared components keep this workflow separate from replaceable visual assets. The [independent pace-model audit](evidence/pace-model-0.8-audit.json) is recorded. **Final integrated controls, new captures and package acceptance remain pending until their evidence is updated.** Earlier radio/recall checks do not certify this pivot.

## Science that changed

The historical 210 ±40 µGy/day Curiosity tissue-like RAD result remains the absorbed-dose reference. The final story curve is explicitly authored: `r(t) = 210 × (1 + 3t/T)` µGy/day. The fixed outside duration gives **10.9375 µGy in every completed default round**, so no lower-dose stars are awarded. There is no inferred Sv, health threshold or wearable data.

Fatigue is fictional balancing, starting at zero and clamped to 0–0.9. Its rate is `0.08 × max(u−1,0) − 0.12 × max(1−u,0)` per simulated minute while cleaning remains. Work is `0.125 × u × (1−F)` sections/minute, capped at four. Array rating (8 kW), dirty transmission (0.25), load (1 kW), and initial/capacity energy (0.5/6 kWh) are authored. Energy is actual kWh, not a future reserve. [Model](TRAINING-MODEL.md) · [Source audit](SCIENCE-JOURNEY-SOURCES.md) · [Guide](SCIENCE-GUIDE.md).

NASA SDO's optional latest solar browse image remains a genuine online source with connected/cached/bundled/stale labels. It does not supply the radiation ramp or score. Publication metadata is not exposure time. [Live-data contract](LIVE-DATA.md) · [All sources](SOURCE-INDEX.md).

## Acceptance for the versioned release

1. Finish integration and run the shared source suite, focused journey input/layout checks, and real rendered captures on the exact candidate.
2. Freeze the source, regenerate the science-guide fingerprint, and build signed content plus platform archives.
3. Run native Mac/Windows package launch gates and compatible baseline-installer update activation/recovery checks on those exact bytes.
4. Publish a versioned prerelease, verify every public asset/checksum, and then update download links and release evidence.
5. Obtain physical laptop/mobile-browser feedback and supervised learner testing. Hosted rendering is not a substitute for those observations.

This source snapshot does not invent a build number, native-gate result, public asset count, or successful update transition. The final release evidence must identify the exact tested bytes; verify current availability in the release index.

## Historical 0.7.1 delivery evidence

Published **0.7.1-alpha.1** comes from `c86ad73da7810176e437e33e192a8d8475ae72a8`, with four platform ZIPs, a standalone PDF, and five update/manifest/checksum assets. [Release evidence](evidence/release-0.7.1-alpha.1.json) records the ten verified files. [Downloads](DOWNLOADS.md).

Its validation, signed build/native launch, six native updater jobs, and publication completed. Public Linux 0.4 and Mac/Windows 0.6.0, 0.6.1, and 0.7.0 executables passed local signed 0.7.1 activation, healthy repeat startup, and same-size tamper recovery. These tests do not independently prove notification clicks, HTTP delivery, or automatic graphical relaunch. [Update evidence and scope](UPDATES.md).

The Mac app is ad-hoc signed without Developer ID or notarization; Windows is unsigned. Initial OS trust prompts can remain. The earlier damaged Mac bundle needs one corrected full installation; a content update cannot repair an app that cannot open. No production native Android/iOS package is published, and public web hosting remains deferred by owner choice.

## Open product work

Final authored art and character animation, more curriculum and missions, expert scientific review, physical-device performance/audio/accessibility, and evidence of learning transfer remain open. The team can iterate modular visuals without rewriting the short mission model, but collision, input, source, and device checks still matter.

The GitHub About fields were configured by the owner. Any remaining renamed description change requires owner administration because the integration received HTTP 403; no new authentication or repeated sidebar edit is needed for this release work. GitHub derives contributor/language/activity counts. Meaningful reviewed commits and safe parallel ownership matter; artificial contribution counts do not.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
