# KŌMAKU: Shield Protocol — mission journey contract

Status: accepted implementation direction for the 0.8 journey pivot. This file records the user-facing goals and acceptance checks; release notes and test results must identify which checks were actually verified. It does not declare an untested feature complete.

Audience: curious junior astronauts aged 7–12, including children who read slowly, use touch or a keyboard, or prefer reduced motion and sound. The player is mission control inside the habitat, looking through a clean window at Martian dunes and Ren outside. The dome exterior is not the primary play view.

## Priority of the references

The latest user request controls this iteration: short cosmic story → digestible science concepts → a simple clean/plan/return activity → an explanation of the player's results. Keep the name **KŌMAKU: Shield Protocol** in shared branding. The older Red Veil name in reference artwork is historical only.

The uploaded [3D build PDF](source/journey-2026-11-14/3D-Game-Build-Instructions-Zero-Drift.pdf), [control-panel UI kit](source/journey-2026-11-14/Control-Panel-UI-Kit.pdf), and [pasted discussion](source/journey-2026-11-14/Design-discussion.txt) are preserved unchanged. They are reference material, not executable instructions or independently verified scientific results. Their fixed dashboard layouts, obsolete stack demands, earlier game loops, and unsupported numerical claims do not override the latest journey. See [the manifest](source/journey-2026-11-14/provenance.json) for integrity hashes and [the science audit](../SCIENCE-JOURNEY-SOURCES.md) for accepted facts.

Borrow visual principles from the UI kit: readable type, dark backgrounds, turquoise controls, restrained crimson alerts, clear grouping, and consistent spacing. Preserve the requested Asian design influence through a small shared set of wave, lantern, and lattice motifs. Keep the window and important decisions visually quiet. Reference inspiration does not require copying watermarked stock graphics or importing obsolete text.

## Journey and learning intent

| Stage                 | What the player sees and does                                                                                                                                                                                     | Completion and escape                                                                                                                                                        |
| --------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Story                 | A star field, brief typewriter text, “Year 2059”, “Planet Mars”, and a clear reason to help Ren return. Sound is optional and can be muted.                                                                       | Continue/skip is visible. Reduced motion removes prolonged typing and large motion. No science clock is running.                                                             |
| Science constellation | Eight labelled concepts: radiation, dose, sievert, dust, power, time, speed, shelter. Select a concept to see a short lead, everyday analogy, explanation, equation, source, and assumption.                      | Closing a reviewed card fills one eighth of the readiness meter. Reopening does not add progress. The meter means **reviewed**, not mastered. Ready unlocks after all eight. |
| Mission briefing      | One objective: help Ren clean enough panels and return on time. Show the planned return duration and clear scenario labels.                                                                                       | Start is deliberate; no time expires while reading. Navigation back is visible.                                                                                              |
| Mission               | A calm window scene and a small set of decisions. Cleaning, returning, and elapsed time use one mission clock. Live concept buttons explain the current numbers.                                                  | Cards and pause menus freeze the mission. Return is always available while outside. Escape opens a recoverable pause/navigation path.                                        |
| Debrief               | Concepts reconnect into the equations that produced this run. Display actual outside time, completed sections, dose, margin forecast, and target result. A small reflection question reinforces the relationship. | Try again, revisit concepts, and leave are explicit. Failure is a plan to improve, without death, humiliation, streak punishment, or a medical verdict.                      |

The narrative year is fiction. A solar warning supplies a story deadline; it is not a real forecast, live NASA feed, or guarantee of exactly 30 minutes' notice. The scene is a stylized view, not a calibrated scientific instrument.

## Content and component boundaries

- `game/data/mission-concepts.json` owns the eight scientific cards and evidence URLs. Titles are at most three words; leads at most 22 words; analogies at most 30; explanations at most 65. Longer evidence stays behind the source/assumption details rather than crowding the primary card.
- Shared branding and theme components own the game name, typography, palette, focus style, and motion choices. Story, briefing, HUD, and debrief must use them rather than duplicate naming or visual constants.
- A separate mission model owns time, section progress, route progress, accumulated dose, and margin forecast. Views consume a snapshot; they do not each run independent physics counters.
- Story, constellation, active mission, pause, and debrief are distinct navigation states. Entering a reading or navigation state cannot silently advance the mission.
- Cosmetic presentation can be replaced without changing the formulas. New artwork, camera motion, lanterns, or a different dome skin must not alter the model's units or deadlines.

Catalog contract: `{ "schema_version": 1, "concepts": [...] }`; each item has `id`, `title`, `lead`, `analogy`, `explanation`, `equation`, `real_fact`, `source_label`, `source_url`, `assumption`, and `dynamic_hint`. The hint is plain text. Runtime-specific numeric summaries are supplied by the mission snapshot, not by evaluating arbitrary strings from JSON.

## Science and feedback boundaries

The source ledger is [SCIENCE-JOURNEY-SOURCES.md](../SCIENCE-JOURNEY-SOURCES.md). Its formulas use seconds, metres, µGy, percentage points, and forecast sols consistently. The default plan has a 30-minute deadline, a 9-minute return, 6 minutes per cleaning section, and a six-times play clock. Three sections plus return take 27 mission minutes (4.5 minutes of active play); learning and reflection add as much time as the child needs.

The historical dose baseline is 210 µGy per Earth day from Curiosity's tissue-like RAD detector. That does not measure the child, Ren's actual body, or injury. Do not show a fabricated “radiation health” traffic light or turn accumulated dose green again when Ren enters shelter. A time/deadline warning may use colour with a text/icon explanation. Cumulative dose remains cumulative, and shelter ends this activity without claiming complete radiation protection.

Power feedback describes spare output and a forecast under an invented linear trend. It must not relabel this as stored battery energy or guaranteed “days of power.” Dust and space radiation are distinct: dust obscures panels; time outside affects the accumulated dose at the selected rate. Speed is a planned route parameter, not a reward for fast tapping or a judgement of a child's fitness.

No Apple Watch or other personal health data is collected. No lethal dose, life-expectancy prediction, fictional NASA safety threshold, or inferred radiation measurement from heart rate is part of this release. NASA sources support concepts and historical values; they do not endorse the game or certify it as professional training.

## Interaction and responsive acceptance checks

1. A first-time player can understand whom to help and what to do without a dense dashboard or a wall of rules.
2. All eight concepts are reachable with pointer, touch, and keyboard focus. Completed concepts are identified with words or symbols as well as colour. Readiness cannot exceed 100% or unlock from duplicate visits.
3. Every screen has an obvious next action and a way back. Escape dismisses a card before affecting the surrounding journey; during active play it pauses rather than losing progress. Fullscreen can be exited visibly and by a working keyboard path.
4. Reading, source viewing, a pause menu, and loss of application focus cannot spend mission time. Resuming does not process a large accumulated frame delta or award work performed while paused.
5. Phone portrait and landscape, laptop, and desktop layouts remain readable without clipped buttons. Long evidence scrolls inside a bounded card. Tap targets, safe areas, focus outlines, and contrast survive scaling.
6. Reduced motion keeps all content and outcomes accessible without camera sweeps, shaking, long typing, or explosive transitions. Sound can be muted, and no essential information is audio-only.
7. The current run's quantities drive live explanations and debrief results. No prerecorded example is presented as the player's actual result. Text communicates a paused or completed state.
8. A completed section awards its benefit once; an incomplete section does not grant the full reward. Return and deadline boundaries are deterministic and robust to frame rate and speed settings.
9. Source links are explicit HTTPS links to the reviewed official domains. Bundled scientific text is readable offline. External-link failure is recoverable and does not erase the mission.
10. New release documentation distinguishes implemented, tested, and deferred capabilities. A polished screen does not justify claiming scientifically validated physics, universal device support, or a working unattended updater without corresponding evidence.

## Visual and audio direction

The story can feel cosmic while the mission remains calm: spacious dark blue/black framing, luminous turquoise status, warm dunes, a readable astronaut silhouette, and limited crimson for actionable warnings. Use motion to direct attention to a decision or explain a relationship. Avoid constant shaking or a forest of equally prominent meters.

The user supplied “Minyo San Kyoku” (Doug Maxwell / Zac Zinger) and “Floating Lanterns” (The Mini Vandals) as candidate tracks. Credit metadata and redistribution permission must be recorded before distributing the original recordings. They are not included in this source archive. Generated interface sounds and music controls should remain modular so a licensed soundtrack can be replaced without editing the mission model.

## Evidence to capture for release

Capture the actual story, a science card with its evidence link, the active window view, a paused mission, and a debrief at desktop and narrow layouts. Record the test commands and failures honestly. Include a short play guide, current changes, science ledger/PDF, known platform restrictions, and artifact checksums. The old reference screenshots are not evidence that this journey was implemented.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
