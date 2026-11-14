# Mission planner

AEGIS lets the player compare a few choices before acting. It answers a narrow question: **“What would happen over the next simulated hour if I kept these settings?”** It runs locally using the same equations as the mission. It is deterministic decision support, not a trained AI model, live NASA forecast or proof of a safe real mission.

In the default indoor mission, the suit and dose readings belong to **Mira**. The preview holds her current protection state fixed and does not simulate her return, airlock cycle or indoor entry. Her real journey pauses while the planner is open. In the optional outdoor EVA mission, these readings instead belong to the first-person explorer. This distinction is also shown inside the planner.

## What a young explorer can try

During a mission, press **P**, or pause and choose **Compare Mission Plans**. Opening the planner pauses the mission. Compare four cards: normal work or power saving, each with panel cleaning on or off. Look at the battery, dust and work estimates. Choose a plan explicitly, or close the planner and keep the current settings. Opening the preview does not change the mission.

Useful questions for a teammate or teacher:

- **“Will clean panels help when the sky is dark?”** Cleaning removes deposited dust. It cannot remove airborne dust that blocks sunlight.
- **“Why did this plan stop early?”** Read the reason and duration. A failed short run with energy left is not better than a longer run that keeps operating.
- **“Does saving habitat power refill my suit?”** No. They are separate batteries. A clear visor uses suit energy and does not block radiation.
- **“Why does power saving change the work estimate?”** In this game it reduces optional research to a quarter of its normal rate while outside; it does not stop all research. Both settings retain the essential life-support demand.
- **“Is the biggest battery always the best choice?”** No. The player also cares about exposure, time, inspection and useful work. The planner does not combine those into a made-up safety score.

These are teaching examples. The scenario's dose limit, equipment loads, cleaning efficiency and shielding factor are illustrative. The [science ledger](SCIENCE.md) identifies the sourced historical radiation input and the model's limits.

## What is actually calculated

`game/scripts/mission_adviser.gd` copies the current mission state into one private projection model for each of the four alternatives. It calls the existing `Mission.step()` and `Mission.environment()` methods; it does not maintain a second set of physics equations. This preserves scenario parameters such as background dose, dust severity and particle-event timing.

The preview defaults to **one simulated hour**, bounded to at most two hours and the time remaining in the mission. This is approximately 20 or 40 real mission seconds at the current 180× resource clock. Movement uses real-time physics; the preview does not simulate a walking route.

All alternatives:

1. Begin from the same batteries, exposure, dust, inspection progress and scenario time.
2. Keep the selected conservation and cleaning settings fixed throughout the preview.
3. Keep the current shelter and visor-cleaning state. The player stays where they are and performs no additional inspection work.
4. Stop at the preview horizon, an abort, or the mission ending.

A plan shows both its actual elapsed time and the requested preview horizon. An aborted run's dose and energy totals cover less time. Energy comparisons are made only when both compared options reach the common horizon; no hourly normalization disguises an early abort.

The controller compares cleaning on/off while holding the work setting constant. It separately compares conservation while holding the cleaner setting constant. The energy preference concerns that horizon only. A difference below 0.01 kWh is described as nearly the same; this is a display tolerance, not a scientific safety threshold. It is not a globally optimal schedule: a cleaner that costs energy during this window may help later, and changing settings during a run can produce a different result.

The separate safety note flags the scenario's active or approaching particle event, predicted suit exhaustion, or dose abort. It directs attention to the marked refuge without claiming to calculate a safe route or arrival time. Forecasts use the scenario's known scripted conditions; real weather and radiation forecasts are uncertain.

## Quantities shown

| Field                       | Unit                   | Meaning                                                                                                     |
| --------------------------- | ---------------------- | ----------------------------------------------------------------------------------------------------------- |
| Habitat battery             | kWh                    | Remaining stored energy, clamped to the mission's capacity                                                  |
| Suit battery                | kWh                    | Remaining independent suit energy; no free charging in shelter                                              |
| Exposure                    | mSv                    | Modeled cumulative dose, not a medical diagnosis or certified limit                                         |
| Panel dust                  | Fraction or percent    | Deposited surface dust; separate from atmospheric optical depth                                             |
| Work estimate               | Model hour-equivalents | Existing optional-research accumulator; normal rate 1, saving rate 0.25 while outside, zero while sheltered |
| Elapsed / requested time    | Simulated hours        | Actual forecast duration versus the intended comparison window                                              |
| Generated / consumed energy | kWh                    | Integrated solar input and electrical demand, including energy that may be discarded at battery capacity    |

Work hour-equivalents are a game-design proxy, not measured productivity or a learner score. Due to battery saturation, generated minus consumed energy can exceed the change in stored energy. The planner uses the actual clamped battery result.

## Integration contract

Use the explicit preload and call `analyze(mission, horizon_hours = 1.0)`. The returned dictionary includes source time, initial batteries and dose, `habitat_capacity_kwh`, requested horizon, summary, safety note, assumptions and four option records. Each option carries explicit setting flags, elapsed duration, terminal status, resource outcomes and whether it reached the requested horizon.

The report is detached from the live mission and private model. Changing report values cannot change either one. The calculation does not apply a setting, move the player, alter learning progress or write files. The planner interface and game controller own the user's explicit selection, availability rules and pause/return behavior.

Call the adviser synchronously on the main thread. It reuses a private model so previews avoid file reads and object creation per alternative after initial setup. A full two-hour comparison uses at most 960 normal integration steps. Future background-worker use requires a separate model per worker or equivalent synchronization; the current shared instance is not a concurrent simulation service.

Branding, illustrations, scene geometry and motif choices do not enter this calculation. Physics changes belong in `mission.gd` and its tests; visual changes belong in the presentation modules.

## Validation and limits

`game/tests/mission_adviser_test.gd` checks one-step energy and dose calculations, cleaner power cost, conservation/work tradeoffs, battery capacity, deterministic results and state isolation. A scenario matrix independently advances the real mission for all four settings across different start times, initial battery levels, dust severity, custom particle-event windows, shelter states, suit exhaustion and dose aborts. It compares batteries, dose, dust, work, elapsed duration and stop reason against the preview.

These tests establish consistency with the game's current model. They do not validate that model as spacecraft engineering, prove educational outcomes, or establish physical-device performance. The title-screen and equipment interactions have separate integration and rendered-layout checks.

The planner calls no external service, sends no learner telemetry and trains no model. It does not control the host platform's account or data-retention settings. Existing local mission summaries and academy progress have their own behavior documented in the [learning design](LEARNING-DESIGN.md).
