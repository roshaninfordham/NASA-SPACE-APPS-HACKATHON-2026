# The short clean–plan–return mission

The player is inside the habitat. Their crewmate is outside at dusty solar equipment. The task is to complete enough cleaning to improve the future output margin, then bring the crewmate inside before a fictional warning countdown ends. **The result is a planning target met or missed; the game does not calculate injury or death.**

The new `window-training-v1` model is independent of the earlier 12-hour battery mission. The earlier mission remains an optional advanced activity; its battery, load and dose-equivalent equations must not be mixed with this model's output-margin and absorbed-dose quantities.

## What one round means

The scenario gives 30 simulated minutes before the deadline. Standard play advances six simulated seconds per active play second, so the maximum round lasts five minutes. Cleaning one section takes six simulated minutes, or one minute of standard play. The return takes nine simulated minutes, or 90 seconds of standard play.

Relaxed play advances three simulated seconds per play second. Quick practice advances twelve. Both run **the same simulated mission**, with the same work, distance, absorbed dose and outcomes; they only change how long the person waits and acts. Reading, menus and paused time are handled by the controller, which stops calling the model's `advance` function. There is no click-frequency bonus or wearable-derived fitness score.

## Inputs, units and provenance

Every current value comes from `DEFAULTS` in [training_mission.gd](../game/scripts/training_mission.gd). Snapshots and results include a detached copy of those settings so interface equations do not duplicate hidden constants.

| Quantity                           |                    Default | What it means                                                                                                                                                                                                                                            |
| ---------------------------------- | -------------------------: | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Warning window, `W`                |    1,800 simulated seconds | Fictional planning deadline, not a guaranteed NASA warning time.                                                                                                                                                                                         |
| Distance, `d`                      |                      432 m | Scenario distance. The small visible 3D route is a compressed illustration, not a scale survey.                                                                                                                                                          |
| Walking speed, `v`                 |                    0.8 m/s | Scenario choice, not a measured capability of the child or a guaranteed suited walking speed.                                                                                                                                                            |
| Work per section, `τ`              |      360 simulated seconds | Chosen cleaning-work duration.                                                                                                                                                                                                                           |
| Available sections                 |                          4 | Chosen task size. Each completed section can earn its gain only once.                                                                                                                                                                                    |
| Starting output margin, `S₀`       |         1 percentage point | Chosen output margin above the scenario's needs, not battery energy.                                                                                                                                                                                     |
| Margin gain per section, `g`       |        2 percentage points | Chosen cleaning benefit, not a measured Mars cleaning yield.                                                                                                                                                                                             |
| Future dust trend, `k`             | 0.28 percentage points/sol | A deliberately simplified scenario extrapolation inspired by Pathfinder evidence; see the distinction below.                                                                                                                                             |
| Margin-horizon target              |                    15 sols | Fictional planning goal. It is not a claim that oxygen, heat or stored energy will last 15 sols.                                                                                                                                                         |
| Historical absorbed-dose reference |    210 µGy per 24-hour day | Central value from the RAD E detector's tissue-like absorbed-dose result, about 210 ± 40 µGy/day during the first roughly 300 sols at Gale Crater, August 2012–June 2013. Used as a constant teaching reference, not live weather or personal dosimetry. |
| Rate-normalization day             |             86,400 seconds | A terrestrial 24-hour day for converting that published daily rate. A Mars sol is longer; the two are not silently exchanged.                                                                                                                            |

Hassler et al., _Mars' Surface Radiation Environment Measured with the Mars Science Laboratory's Curiosity Rover_ (2014), DOI [10.1126/science.1244797](https://doi.org/10.1126/science.1244797), reports the absorbed-dose result in Table 1. [Primary author manuscript](https://authors.library.caltech.edu/records/kdt88-3aw98) · [NASA NTRS record](https://ntrs.nasa.gov/citations/20180007641). The separate 0.67 mSv/day dose-equivalent result is not interchangeable with the absorbed-dose number. This game does not derive sievert from microgray or Apple Watch data.

The Pathfinder paper reports a **0.28% per day decrease in solar-cell short-circuit current**, not “0.28 units of battery lost,” dust coverage, or a universal percentage-point loss per sol. [NASA NTRS 20020031145](https://ntrs.nasa.gov/citations/20020031145). Using `k = 0.28 percentage points/sol` in a future-margin illustration is a chosen simplification. During this short round the model does not additionally accumulate deposited dust; it starts from a chosen existing margin and estimates the consequence of an assumed future trend.

## The equation chain

The return duration is derived from distance and chosen speed:

`t_return = d / v = 432 m / 0.8 m/s = 540 s`

The scene labels the last tenth of the return as an airlock-entry approach. It does not add a pressure-cycle delay to the equation and does not simulate pressure or validate an EVA procedure. The crewmate is considered inside only at completed entry. A future physical airlock model would need an explicit additional time term and new scenario version.

For a plan that starts cleaning immediately and returns after `n` completed sections:

`T_outside = n × τ + d / v`

Any idle time in an actual run is also part of `T_outside`. Pausing the cleaning task does not pause the mission clock; opening a learning card does, through the controller.

The greatest number of whole sections that can fit before departure is:

`n_max = clamp(floor((W − d / v) / τ), 0, available sections)`

This formula does not prove the zero-section return is possible when `d / v > W`; the model checks return feasibility separately. The current scenario fits three sections. The minimum count for the future-margin goal is:

`n_needed = max(0, ceil((target × k − S₀) / g)) = 2`

The simplified future output-margin horizon is:

`H = (S₀ + g × n) / k`

The units are `(percentage points) / (percentage points per sol) = sols`. This is **not stored energy divided by a load**, and must not be labeled “battery days” or guaranteed “days of power.” It assumes the selected trend continues, and omits weather variation, cleaning events, degradation, load changes and energy storage.

Accumulated absorbed dose while outside is:

`D = (210 µGy / 86,400 s) × T_outside`

The model does not introduce a fictional dose jump at the warning. The round ends at entry or the deadline, whichever comes first. For a late plan, accumulated dose is shown only up to the deadline; the missing future event forecast is not invented. The curve ending at shelter is the end of the simulated round, not a claim of zero radiation indoors.

## Independently calculated examples

These plans begin cleaning immediately, have no idle time and use standard pace.

| Sections completed before returning |    Planned return completion | Modelled time before the round ends | Output-margin horizon | Absorbed reference dose | Outcome                             |
| ----------------------------------- | ---------------------------: | ----------------------------------: | --------------------: | ----------------------: | ----------------------------------- |
| 0                                   |  9 simulated min / 1:30 play |                               540 s |            3.571 sols |              1.3125 µGy | Margin target missed                |
| 1                                   | 15 simulated min / 2:30 play |                               900 s |           10.714 sols |              2.1875 µGy | Margin target missed                |
| 2                                   | 21 simulated min / 3:30 play |                             1,260 s |           17.857 sols |              3.0625 µGy | Both targets met                    |
| 3                                   | 27 simulated min / 4:30 play |                             1,620 s |           25.000 sols |              3.9375 µGy | Both targets met                    |
| 4                                   | 33 simulated min / 5:30 play |               1,800 s, the deadline |           32.143 sols |              4.3750 µGy | Return target missed; still outside |

The latest departure is `1,800 − 540 = 1,260 simulated seconds`, or 3:30 into standard play. Entry exactly at the deadline counts as on time. A later departure does not grant shelter through rounding. Two sections meet the margin goal with less time outside and a larger return-time reserve than three; more work is not automatically a better plan.

## Interface contract

The model extends `RefCounted` without a new global `class_name`. Callers explicitly preload its resource path, preserving the existing signed-content bootstrap contract.

| Method                                           | Contract                                                                                                                                                                                                                                                                      |
| ------------------------------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `reset(options = {}) -> bool`                    | Resets to canonical defaults plus validated scenario overrides. Rejects unknown, nonnumeric, nonfinite or out-of-range settings without altering an existing run. An invalid constructor argument falls back to a fully initialized default run.                              |
| `advance(real_seconds)`                          | Advances only finite positive active-play time while status is `running`. Event-boundary integration resolves complete sections, route stages, minute samples, arrival and deadline in order. Oversized time is bounded by the deadline.                                      |
| `start_cleaning() -> bool`                       | Starts/resumes work only while outside and sections remain. Repeated presses do not restart progress or multiply the rate.                                                                                                                                                    |
| `stop_cleaning() -> bool`                        | Stops work, retaining partial section progress. Time outside still advances when the controller calls `advance`.                                                                                                                                                              |
| `request_return() -> bool`                       | Starts a one-way return, cancels incomplete section work and retains completed gains. Repeated commands cannot restart or shorten the route.                                                                                                                                  |
| `set_pace(0.5 / 1.0 / 2.0) -> bool`              | Chooses relaxed, standard or quick real-time pacing. Already elapsed real and simulated time, current work and dose remain intact.                                                                                                                                            |
| `snapshot() -> Dictionary`                       | Detached settings, state, events and history. The interface cannot mutate the model through a returned dictionary.                                                                                                                                                            |
| `plan_for_sections(n, speed = -1) -> Dictionary` | Independent, immediate-clean-then-return plan from scenario start. Returns `valid: false` for invalid input. Includes separate deadline/margin checks, minimum sections and latest departure. It is not a prediction of subsequent player choices or a validated safety plan. |
| `result() -> Dictionary`                         | Snapshot plus zero-to-four-section comparison plans, equation labels and the medical-model limitation. Can be inspected at any time; `status` identifies whether a run has ended.                                                                                             |

Important snapshot keys:

- `elapsed_seconds` is actual accumulated active play time; `remaining_seconds` is remaining simulated time divided by the **current** pace. Changing pace can change that countdown estimate without rewriting elapsed play time.
- `sim_elapsed_seconds`, `sim_remaining_seconds`, `warning_seconds` and `walk_sim_seconds` use simulated seconds.
- `phase` is `outside`, `returning`, `airlock` or `sheltered`. A late result retains the actual incomplete location phase rather than teleporting the actor.
- `status` is `running`, `success`, `power-shortfall` or `late`. Ended states reject further actions and time advances.
- `sections_cleaned`, `section_progress`, `cleaning`, `sections_needed` and `max_additional_sections` drive the cleaning interface. Only completed sections earn margin.
- `return_progress`, `return_seconds_remaining`, `return_slack_seconds`, `can_return_on_time` and `crew_sheltered` describe the return. The model owns protection/arrival; the scene only illustrates it.
- `dose_ugy` and `dose_rate_ugy_per_hour` are absorbed-dose/reference-rate quantities. Neither is a medical risk bar or a sievert value.
- `history` contains one sample per simulated minute plus the exact terminal instant; each row includes `sim_seconds`, `real_seconds`, `dose_ugy`, `power_margin_sols`, `sections_cleaned` and `phase`.
- `events` is a bounded list of the most recent 128 action/transition records. It is local model evidence, not learner telemetry or a mastery score.

## Local progress and preferences

[journey_progress.gd](../game/scripts/journey_progress.gd) stores an independent `user://journey-progress.json` document. It keeps audio preferences, the supplied/original soundtrack choice, reduced motion, pacing, the eight reviewed concept IDs and the latest ten completed mission summaries. Each summary contains only outcome, active/simulated duration, completed sections, absorbed model dose and the bounded first-answer practice record. It does not retain names, ages, health information, full histories, event logs or arbitrary caller fields. Opening a concept records review, not demonstrated mastery.

The constructor calls `load_data(path_override = "")`. Public `settings`, `reviewed_ids` and `runs` are immediately available. `set_setting(key, value)`, `record_reviewed(ids)` and `record_result(result, quiz = {})` validate inputs and save automatically; `save_data()` permits an explicit save. A `false` return with `last_error` explains invalid input or unavailable storage. Valid changes stay usable in memory when saving fails; `storage_available` reports that limitation. Record a completed result once, after the optional first-answer practice, to avoid adding the same run twice.

Writes use a verified temporary file and a same-directory rename. The loader limits file size to 64 KiB and rejects malformed, unrecognized or unsupported documents without modifying them. An optimistic content check prevents a stale game window from overwriting an already changed file; explicit reload is required afterward. Path overrides are restricted to existing directories under `user://`, and symbolic links are rejected. This does not claim locking against a simultaneous filesystem race or durable storage through physical power loss on every device.

The isolated persistence tests cover valid round trips, strict field types, bounded history, discarded caller data, corrupted/oversize files, unsafe paths, symbolic links and stale writers:

```sh
godot --headless --path game --script res://tests/journey_progress_test.gd
```

## Verification and limits

[training_mission_test.gd](../game/tests/training_mission_test.gd) checks independently calculated zero-to-four-section outcomes, dose conversion, deadline ties and misses, continuous return/entry, incomplete work cancellation, one-time gains, finite input validation, reset isolation, custom speed, zero-distance entry, impossible routes, three accessibility paces, changing pace mid-work, different frame partitions and detached/bounded exported data. Run it with:

```sh
godot --headless --path game --script res://tests/training_mission_test.gd
```

These checks verify the implemented teaching model. They do not certify radiation protection, spacewalk procedure, solar-array design, human performance, medical safety or educational effectiveness. There is no pressure/radiation correlation model, false-alarm probability, personal health inference or cloud learner-data collection in this engine. Those claims from the shared discussion are not carried into the implementation without suitable evidence and a separate validated model.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
