# KŌMAKU: Shield Protocol — final mission journey

The controlling interaction reference is the team's November 15, 2026 **Game Workflow (Words Only)** PDF, with scientific corrections in [TRAINING-MODEL.md](../TRAINING-MODEL.md). This direction supersedes walking, radio/recall and reserve-forecast prototypes. Final implementation acceptance remains pending until fresh evidence is recorded.

The audience is junior astronauts aged 7–12. The player is inside a habitat, looking through a clean window at Martian dunes and Ren cleaning a nearby solar panel. The dome exterior is not the primary view. The mission title is **Dust Off the Solar Panel**, with **Power Up the Outpost** beneath it.

## The journey

| Stage                  | Experience                                                                                                                                                               | Navigation and completion                                                                    |
| ---------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ | -------------------------------------------------------------------------------------------- |
| Opening                | Brief Mars story; a separate video asset may replace its presentation.                                                                                                   | Continue/skip and accessible sound/motion choices. No mission clock.                         |
| Control-room preflight | Window, eight science bubbles, seven-step pace control and START MISSION. The player chooses a starting pace.                                                            | Nothing in the model advances before Start. Reading all eight cards is not required.         |
| Active mission         | Ren cleans automatically. SLOWER, FASTER or the slider adjust pace. Fictional fatigue reduces effective work; work changes dust, solar output and actual battery energy. | Readings and menus pause. No recall, walking, manual work hold or early-entry button.        |
| Automatic entry        | At 30 simulated minutes Ren steps directly inside.                                                                                                                       | No extra click, route or entry delay. Full cleaning earlier does not end outside time early. |
| Result and equations   | Actual cleaned fraction, battery kWh, model dose and WIN/PASS/LOSE connect to this run's equations/history.                                                              | Replay, review and Home are visible. No medical judgement or death outcome.                  |

The science constellation remains optional preparation with its own reviewed-card sequence. Its eight-card completion gate does not prevent leaving through Home and starting the control-room mission. Readiness means explored, not mastered.

## Controls and state

Requested pace has seven values: **0.25–1.75 in steps of 0.25**. Minus/SLOWER, plus/FASTER and the slider change the same quantity. Keyboard **1** means slower, **3** means faster and **Enter** starts only from preflight. Escape handles one navigation layer or pauses play; F11 toggles fullscreen. Hidden mission controls cannot activate beneath a reading card, solar viewer or confirmation.

Requested pace is dimensionless. Effective cleaning is **sections per simulated minute**, not metres per second. Distinguish both so the child can see why fatigue can reduce the result of a high setting. The mission title remains visible near the controls.

The top countdown and time bubble share one model clock. Storm progress represents the authored deadline, not kilometres or a measured forecast. The shelter bubble explains automatic entry beside the door. Decorative dome/terrain screens do not imply additional required actions or calibrated instruments.

## Modular boundaries

- [pace_mission.gd](../../game/scripts/pace_mission.gd) owns time, fatigue, continuous work, generation, battery energy, dose and outcome. Views read one snapshot.
- `game/data/mission-concepts.json` owns the eight concepts and reviewed evidence links. Brief analogies precede optional detail; scientific text works offline.
- Shared branding and theme components own naming, typography, colour, focus and reduced motion. Art and audio replacements cannot silently change numerical rules.
- Preflight, play, paused readings, navigation and completed results are separate states. Modal transitions cannot spend time or trigger two actions from one input.

The concepts remain radiation, absorbed dose, sievert, dust, battery/power, time, cleaning pace and shelter. Bars need meaningful units or an explicit explanatory state. No invented sievert/health meter or clinical safe/dangerous threshold is added. Text/icons accompany colour.

## Scientific contract

Standard play advances six simulated seconds per active real second for a 30-minute simulated round. Fatigue starts at zero and is clamped to 0–0.9. While work remains:

`dF/dminute = 0.08 × max(u − 1, 0) − 0.12 × max(1 − u, 0)`

`cleaning rate = 0.125 × u × (1 − F) sections/minute`

Continuous work is capped at four section equivalents. Generation is `8 × (0.25 + 0.75 × work/4) kW`. Actual battery energy starts at 0.5 kWh, integrates generation minus a 1 kW load and is capped at 6 kWh. There is no future-energy reserve forecast. At the work cap, cleaning and fatigue stop changing while energy, time and dose continue.

The historical absorbed-dose reference is 210 µGy per Earth day. The story uses the **authored** ramp `210 × (1 + 3t/T) µGy/day`, with T = 1,800 seconds. Every completed default round accumulates **10.9375 µGy**. The ramp is not a NASA storm measurement, and there are no lower-dose bonus stars.

The cleaned fraction determines **WIN** at 80% or more, **PASS** from 40% to below 80%, and **LOSE** below 40%. Fractional work counts. Energy explains the result without becoming a hidden reserve target. Every category ends with automatic entry.

Fatigue is fictional game balancing, not astronaut physiology. No wearable, heart rate, inferred sievert, lethal dose or injury prediction is used. Pathfinder's historical dust observation supports the concept but is not a runtime coefficient. See [SCIENCE-JOURNEY-SOURCES.md](../SCIENCE-JOURNEY-SOURCES.md) and [TRAINING-MODEL.md](../TRAINING-MODEL.md).

NASA SDO's latest AIA 193 Å browse image is separate observational content. Retain connected, cached, bundled and stale labels, publication metadata and NASA credit. It does not drive the ramp, dust, energy or score. Its implementation contract remains [LIVE-DATA.md](../LIVE-DATA.md).

## Acceptance checks

1. Opening leads to control-room preflight without mandatory eight-card reading. Selecting a starting pace spends no time.
2. Faster/slower/slider all affect one model. Lower pace can recover fictional fatigue while cleaning continues; Pause freezes every quantity.
3. Ren stays at the panel until automatic entry. There is no route, recall, hidden delay or early finish after full cleaning.
4. Cards have visible Back/Close, source access and keyboard/touch navigation. Closing one cannot also resume and activate a hidden control.
5. Fullscreen Escape exits and pauses. Later presses handle one layer. Source viewing and focus loss never spend mission time.
6. Desktop, laptop, portrait and landscape keep the window readable and actions reachable. Long explanations scroll inside their cards.
7. Reduced motion and mute preserve all information. No required cue is audio-only.
8. Debrief uses actual values and history. Every default completed run has equal dose, without fabricated dose rewards.
9. Outcomes and automatic entry are independent of frame partitioning. Replay resets to preflight; a result is saved once.
10. Release notes and screenshots identify this final workflow. Earlier prototype captures and tests are not evidence for it.

## Visual, audio and release evidence

Keep the cosmic introduction expressive and the mission calm: dark spacious framing, turquoise controls, warm dunes and a readable crewmate. Motion should explain a change or lead attention to a decision. Fatigue should look like a game concept, not a clinical instrument.

Team-supplied recordings, original alternative ambience and rights/credit details are maintained in [AUDIO-CREDITS.md](../AUDIO-CREDITS.md). Music and effects remain separately controllable. Producing an opening video is separate from verifying the gameplay loop.

Capture actual preflight with a changed pace, active cleaning, a paused science card, fatigue trade-offs and completed equations at desktop and narrow sizes. Include the current science PDF, model tests, controller evidence, platform limits and artifact checksums before declaring release acceptance complete.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
