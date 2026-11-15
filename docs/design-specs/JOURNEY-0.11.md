# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — 0.11 candidate interface contract

**Unpublished candidate · November 15, 2026.** The available download remains [0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1). This contract restores the outpost-window setting and eight visible science bubbles while keeping the concise wording and typography introduced in [0.10](JOURNEY-0.10.md). Implementation, test acceptance and publication are separate milestones.

## The window and its eight concepts

The player stays inside the outpost, looking at Ren and the dusty panel just outside. The visible habitat frame must establish that indoor viewpoint without hiding the task. **Science window** is the default view. Its eight concepts—radiation, dose, sievert, dust, power, time, speed and shelter—remain visible as bubbles with readings or context from the current mission.

“Live” here means updated from the local simulation; it does not mean eight real sensors or NASA telemetry streams. Sievert is explanatory context, never an invented personal reading. The optional SDO solar-image viewer remains separately labelled and cannot drive the Mars model.

A bubble opens the existing brief explanation, diagram and analogy. Reading pauses the mission. **Learn more** and **Data & sources** retain the deeper reasoning and source links. The 0.10 wording, shared fonts and readability choices remain; restoration must not reintroduce dense text on every bubble or a reading-completion gate.

## View, Menu and Home

**View** offers **Science window** and **Focused window**. Focused window reduces surrounding information while preserving the same mission, core readings and pace controls. Switching view must not restart the round, change a result, skip time or modify physics. Small portrait and short-landscape layouts must retain usable controls and access to every concept without covering Ren’s work.

**Menu** provides an explicit **Home** action; Home offers direct access to view and sound settings. Back and Resume return to the correct caller, and Home leaves the mission cleanly. Preflight, an active round, reading, paused play and a terminal result must each retain their appropriate clock behavior. Returning from focus loss or a source link must not silently advance an unseen mission.

## Radio captions and saved preference

Brief scripted exchanges acknowledge Start and pace changes: the player gives a direction and Ren replies. These are captioned feedback, not microphone input, synthesized personal advice or a language-model conversation. They must coexist with pause, focus loss, reduced motion, and existing audio settings without obscuring controls or results.

Local profile **schema 2** adds `mission_view`. Recognized schema 1 files migrate with existing settings, reviewed concepts and bounded run history preserved; the new view defaults to Science window. An ordinary save writes the new schema while retaining existing conflict checks. Malformed or unsupported profiles must not be silently overwritten. Application IDs, save location and content-update signing trust remain stable.

## The mission stays the same

Standard play remains about **90 active real seconds**, representing 30 simulated minutes. The pace/fatigue, partial-cleaning, solar power, battery and absorbed-dose equations are unchanged. All complete runs end with automatic entry and the same **10.9375 µGy** model dose. WIN/PASS/TRY AGAIN depends on cleaned fraction alone; energy and dose explain the result. No recall route, health score, neural network or new scientific validation is introduced by this interface work.

The existing result-first flow, optional science connection animation, exact equations/graphs and source explanations remain available. Opening and result copy are not rewritten as part of the restoration.

## Acceptance before publication

Record candidate-specific evidence for responsive layouts and visible bubble readings, view/profile migration, pause/focus/terminal navigation, radio captions, and the result flow. Capture the integrated scene with source and fixture provenance. Published 0.10 screenshots remain historical evidence and must not be relabelled as 0.11.

Before publication, require source checks, exported startup, compatible signed-content update checks, exact packaged documentation/PDF verification, and public-file verification. Do not infer physical-device performance, assistive-technology compatibility or learner effectiveness from automated checks. Keep the published 0.10 links active until the release actually exists and its files have been verified.

[Team status](../TEAM-STATUS.md) · [Request tracker](../REQUEST-TRACKER.md) · [Roadmap](../ROADMAP.md) · [Submission answers](../SUBMISSION-COPY-PASTE.md).

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
