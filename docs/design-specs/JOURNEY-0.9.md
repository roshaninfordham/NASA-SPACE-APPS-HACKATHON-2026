# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — 0.9 presentation contract

**Candidate design and acceptance contract · November 15, 2026.** This updates the presentation of the [accepted pace/fatigue workflow](FINAL-WORKFLOW.md). The current source is a 0.9.0-alpha.1 candidate; a finished design document is not a published or device-accepted release.

## Player and purpose

The intended player is a young explorer aged 7–12, inside mission control. They should immediately understand who needs help, see the brush and panel, change a pace, and reach an understandable ending. Preserve a calm futuristic Mars atmosphere and restrained Asian-inspired details while making the work, words and choices easier to see.

## Opening

Use three brief scenes in order: **exterior habitat → astronaut → control-room interior**. The game name is the strongest text element. Short, bold story text is separate from the artwork, preserving readable contrast and allowing future renames without repainting lettering. Continue and Skip are visible keyboard/touch actions. Sound requires an initial user gesture; reduced motion removes unnecessary typing/animation delays.

The current backgrounds are newly generated unlettered adaptations of the user's inline reference direction. Original inline images were visible in the conversation but unavailable as local files. [Asset provenance](../../game/assets/art/journey/provenance.json) records the generated assets; do not describe them as pixel-exact originals, licensed stock photographs, or real-time gameplay captures.

## Preflight and window view

The story leads to preflight. Nothing changes until Start, including brushing, work, fatigue, energy, dose or clocks. Science cards are optional; an eight-card review percentage never blocks play.

Ren and the solar panel occupy substantially more of the clear window. Fit the working scene to the area left by the header, science controls and footer. The camera must keep the cleaning surface and hand visible on wide screens, short landscape screens and narrow portrait layouts; the interface must not conceal the action that it controls. The player stays indoors, and Ren works at the entrance without a return walk.

Shared scene framing should change camera composition rather than moving Ren or the panel into a different physical relationship. The brush animation and the panel's work-driven dust shader remain separate from the mission equations.

## Pace, timer and warnings

- The stepped pace control selects **0.25–1.75**, in increments of **0.25**. SLOWER/FASTER, keys 1/3 and the red slider address the same state.
- Bigger labels and clearly marked slider steps show what changed. Visible brushing cadence follows effective cleaning rate; a higher setting should be noticeable immediately without inventing extra work.
- The model retains **30 simulated minutes**. At standard pacing it advances **20 simulated seconds per active real second**, giving a **90-second round**.
- The primary timer shows active real time remaining. Secondary text explains simulated time. Pause and reading stop both; accessibility clock pace changes actual duration without changing the model at a given simulated time.
- Storm progress is an authored countdown indicator, never kilometres or a measured solar-particle propagation speed.
- Original countdown/warning/urgent beeps support visible urgency. They share throttling and stop on pause, focus loss or mute. The inaccessible Drive alert recording is not included. [Audio provenance](../../game/assets/audio/journey/cue-provenance.json).

## Results before equations

At the fixed deadline, Ren enters automatically and the result appears immediately. No additional walking sequence or compulsory long lesson hides the ending.

| Result    | Cleaning fraction       | Main words                  |
| --------- | ----------------------- | --------------------------- |
| WIN       | At least 80%            | You powered up the outpost! |
| PASS      | At least 40%, below 80% | Good progress, astronaut!   |
| TRY AGAIN | Below 40%               | Try a new cleaning plan!    |

Every result shows the run's actual **panel cleaned (%)**, **energy stored (kWh)** and **absorbed model dose (µGy)**. Classify before rounding. Ren is inside in all categories; a lower outcome does not imply death, injury, lost life support or an empty battery. [Result copy](../RESULT-SCREEN-COPY.md).

The three primary actions are **See how science connects**, **Try another plan** and **Home**. The first opens the bubble merge. Retry resets to preflight; Home returns to navigation. Back/Escape must resolve the current layer predictably.

## Eight concepts, four relationships

Animate the eight concept bubbles toward their relationship groups, then show large, readable equation cards. Skip and reduced motion reach the same content. **Back to results** restores the same recorded outcome rather than starting a new mission.

1. **Cleaning:** panel cleaned = average effective cleaning rate × cleaning time. A final slider value is not the average rate; fictional tiredness can reduce effective work.
2. **Solar power:** clear-panel power × fraction of sunlight getting through dust. Do not multiply by dust again, as the reference mockup did.
3. **Stored energy:** starting energy + collected energy − used energy, within battery bounds. kW and kWh stay distinct.
4. **Absorbed dose:** average radiation dose rate × outside time. The final rate alone is not the average.

Shelter ends this activity's outside-time count; it does not imply zero real radiation indoors. Sievert remains an explanation about radiation/tissue weighting, with no personal Sv calculation. The compact game labels can say Clean pace, Energy and Microgray for the corresponding concepts. [Simple equations](../VIDEO-EQUATIONS-SIMPLE.md) · [Exact model](../TRAINING-MODEL.md).

The only numerical change to the mission defaults is the real-to-simulated clock ratio. Completed rounds keep the same work/energy outcomes for the same pace history in simulated time, and all share 10.9375 µGy of model dose. Energy and dose are explanations, not new success thresholds.

## Acceptance and delivery

Check preflight/pause, clock invariance, meaningful speed/cleaning feedback, actor/panel visibility, text bounds, 48-pixel control targets where specified by the UI, keyboard focus, fullscreen/focus recovery, all result bands, merge/skip/reduced motion, back/retry/home, and source-linked explanations. Include desktop, 390×844 portrait, 844×390 landscape, 960×540 and 320×568where supported by existing fixtures.

Capture actual runtime screens and cleaning motion separately under `docs/media/journey-0.9/`, with exact source hashes and fixture/renderer disclosure. Keep older media immutable. New art previews are not evidence of game animation, performance or physical-device behavior.

The release must pass frozen-source validation, all platform exports, native Mac/Windows launch gates, signed-content transitions from the five supported native baseline versions plus Linux 0.4, and public-file verification. All three science PDFs must be the fingerprint-checked files in each archive. [Validation](../VALIDATION.md) · [Update contract](../UPDATES.md).

Shared branding supplies **KŌMAKU: Dust & Radiation** and new 0.9 package names. Preserve app/save IDs, update trust, content filename and runtime contract. Existing updated apps can retain their old OS filenames. Historical release artifacts are never renamed or rebuilt.

The team records its own video and reviews the [submission draft](../SUBMISSION-DRAFT.md) before submitting. Public hosting remains deferred; no unrelated account domain should be advertised as the game.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
