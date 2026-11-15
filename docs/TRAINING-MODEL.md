# Cleaning pace, fatigue and stored energy

The introductory mission is **Dust Off the Solar Panel — Power Up the Outpost**. The player stays inside the habitat and sets how quickly Ren cleans a nearby solar panel. Requested pace affects fictional fatigue, effective cleaning, solar generation and actual battery energy. At the fixed deadline Ren automatically enters the shelter. [pace_mission.gd](../game/scripts/pace_mission.gd) owns the final workflow's equations.

This contract follows the team's November 15, 2026 **Game Workflow (Words Only)** PDF, with the scientific corrections below. Earlier walking, radio/recall and warning-time reserve forecasts do not describe this mission.

## One round

The control room opens in **preflight**. The player can inspect science bubbles and set a starting pace without changing time, fatigue, work, energy or dose. **START MISSION** begins the simulation. The science constellation is optional; reading all eight cards is not a prerequisite for play.

During play, SLOWER, FASTER and the stepped slider choose one of seven dimensionless multipliers: **0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75**. Ren remains at the panel. There is no recall, walking route, manual work hold or early-entry command. Reading and Pause freeze the whole model, so pausing cannot recover fatigue while other quantities advance.

The duration is **T = 1,800 simulated seconds = 30 simulated minutes**. Standard play advances six simulated seconds per active real second, giving a five-minute round. Accessibility clock pacing, if offered, changes real duration rather than the equations at a given simulated time.

At T, Ren steps directly inside and the round ends. If all four section equivalents are cleaned earlier, cleaning and fatigue stop changing; solar generation, battery energy, the clock and outside dose continue until T.

## Parameters and provenance

| Quantity                             |                       Default | Meaning                                               |
| ------------------------------------ | ----------------------------: | ----------------------------------------------------- |
| Mission duration                     |              30 simulated min | Authored task duration, not real storm warning.       |
| Standard clock scale                 | 6 simulated s / active real s | Presentation pacing.                                  |
| Requested pace u                     |          0.25–1.75, step 0.25 | Dimensionless player choice.                          |
| Initial fatigue F                    |                             0 | Fictional game state.                                 |
| Fatigue limits                       |                         0–0.9 | Authored balancing bounds.                            |
| Fatigue growth/recovery coefficients | 0.08 / 0.12 per simulated min | Authored, not physiological measurements.             |
| Base cleaning rate                   |            0.125 sections/min | Eight minutes per section at pace 1 without fatigue.  |
| Work capacity                        |         4 section equivalents | Continuous work, including partial sections.          |
| Clear-array output                   |                          8 kW | Authored fixed-sunlight rating.                       |
| Initially dirty transmission         |                          0.25 | Authored output fraction.                             |
| Habitat load                         |                          1 kW | Authored constant demand.                             |
| Initial battery energy / capacity    |                   0.5 / 6 kWh | Authored ideal storage.                               |
| Historical absorbed-dose reference   |                   210 µGy/day | Central tissue-like RAD E detector result.            |
| Reference day                        |                      86,400 s | Earth-day conversion.                                 |
| Radiation multiplier                 |                      1 + 3t/T | Authored ramp from 1× to 4× the historical reference. |
| Outcome thresholds                   |           40% and 80% cleaned | Authored learning-game categories.                    |

Hassler et al., _Mars' Surface Radiation Environment Measured with the Mars Science Laboratory's Curiosity Rover_ (2014), DOI [10.1126/science.1244797](https://doi.org/10.1126/science.1244797), reports approximately **210 ±40 µGy/day** in the tissue-like RAD E detector during the first roughly 300 sols at Gale Crater, August 2012–June 2013. See Table 1 in the [primary author manuscript](https://authors.library.caltech.edu/records/kdt88-3aw98) and the [NASA NTRS record](https://ntrs.nasa.gov/citations/20180007641). The paper does not supply this game's increasing radiation curve.

The [Pathfinder study, NASA NTRS 20020031145](https://ntrs.nasa.gov/citations/20020031145), reports a **0.28% per day decrease in solar-cell short-circuit current**. It supports teaching that deposited dust can impair solar performance. It does not provide the cleaning rate, fatigue law, linear transmission curve or battery parameters. That percentage is not a runtime coefficient.

## Connected equations

### Pace and fictional fatigue

While cleaning work remains, with τ measured in simulated **minutes**:

`dF/dτ = 0.08 × max(u − 1, 0) − 0.12 × max(1 − u, 0)`

`F = clamp(F, 0, 0.9)`

Above pace 1 fatigue grows; below 1 it recovers; at exactly 1 existing fatigue stays unchanged. It freezes when work reaches its cap. This is invented game balancing, not an astronaut endurance, child health, suit or radiation-injury model. No personal or wearable measurements are used.

### Cleaning work

`q(τ) = 0.125 × u(τ) × [1 − F(τ)] sections/min`

`w(τ) = min(4, ∫ q(s) ds)`

`clean_fraction = w/4`; `dust_fraction = 1 − clean_fraction`

Requested pace and effective rate are different. For example, pace 1.5 at fatigue 0.6 yields **0.075 sections/min**, less than the unfatigued base rate. Partial work counts immediately; a whole-section counter is only a display aid.

### Solar generation and actual battery energy

`P_solar = 8 × [0.25 + 0.75 × w/4] = 2 + 1.5w kW`

For t measured in simulated **seconds**:

`E(t) = E₀ + ∫ [P_solar(s) − P_load] ds / 3,600`

`E = clamp(E, 0, 6) kWh`

Solar generation starts at 2 kW and reaches 8 kW when clean. The linear transmission relation is an authored approximation. Dividing seconds by 3,600 converts power into energy. **kW is power; kWh is stored energy.** The debrief reports actual accumulated energy, not a future reserve forecast.

Integration must use each interval's changing fatigue and work. Multiplying the final solar reading by all elapsed time would give the wrong result. Clipping at empty/full must not create energy. The ideal battery omits chemistry, thermal effects, efficiency and degradation.

### Authored radiation ramp and absorbed dose

For t from 0 to T = 1,800 seconds:

`r(t) = 210 × [1 + 3t/T] µGy/day`

`D(t) = ∫ r(s) ds / 86,400 = (210 / 86,400) × [t + 3t²/(2T)] µGy`

The rate starts at 210 and ends at 840 µGy/day. The multiplier is fictional; NASA's SDO image and a measured storm distance do not determine it.

`D(T) = (210 / 86,400) × 2.5 × 1,800 = 10.9375 µGy`

Every completed default round has the same outside duration and rate curve, so **every completed round has the same dose**. Faster cleaning cannot earn a lower-dose bonus in this workflow. There are no extra stars for dose, no medical danger threshold, and no numerical conversion to sievert. The sievert concept explains weighting and missing information instead.

## Results and independent examples

At automatic entry, cleaned fraction determines **WIN** (at least 0.80), **PASS** (at least 0.40 but below 0.80), or **LOSE** (below 0.40). These are learning-game targets. Actual energy is explained alongside them, not used as a hidden reserve threshold. Ren enters in every category; no injury or death is calculated.

The following analytical examples use a constant requested pace, zero initial fatigue and the full 30 simulated minutes. They are test comparisons, not prerecorded player results.

| Requested pace |         Final work | Cleaned fraction | Actual final battery | Result |
| -------------- | -----------------: | ---------------: | -------------------: | ------ |
| 0.25           | 0.9375000 sections |         23.4375% |        1.3515625 kWh | LOSE   |
| 0.50           | 1.8750000 sections |         46.8750% |        1.7031250 kWh | PASS   |
| 0.75           | 2.8125000 sections |         70.3125% |        2.0546875 kWh | PASS   |
| 1.00           | 3.7500000 sections |         93.7500% |        2.4062500 kWh | WIN    |
| 1.25           | 3.2812500 sections |         82.0313% |        2.4062500 kWh | WIN    |
| 1.50           | 2.4609375 sections |         61.5234% |        2.2788086 kWh | PASS   |
| 1.75           | 2.1328125 sections |         53.3203% |        2.1689453 kWh | PASS   |

All rows end with automatic entry and **10.9375 µGy**. At pace 1.5, fatigue reaches its 0.9 cap after 22.5 minutes; at pace 1.75, after 15 minutes. The remainder must use the capped value. Paces 1 and 1.25 happen to store the same energy despite different final cleanliness: earlier generation and later fatigue compensate. Mixed-pace runs must use their actual interval history.

## Scientific corrections to the reference PDF

| Reference wording                                 | Implementation                                                                                 |
| ------------------------------------------------- | ---------------------------------------------------------------------------------------------- |
| Radiation in mSv/day beside absorbed µGy          | Absorbed-dose rate in µGy/day and total in µGy; no unsupported interchange with weighted dose. |
| Sievert “shows what that dose means for the body” | Explanatory card; no inferred Sv, health or injury reading.                                    |
| “Power” in kWh                                    | Battery **energy** in kWh; generation and load in kW.                                          |
| Working speed in metres per second                | Requested pace multiplier and effective **sections per simulated minute**.                     |
| Storm distance                                    | Authored **countdown progress**, not kilometres or a measured propagation speed.               |
| Shelter distance                                  | Beside the entrance; automatic-entry state, without a route calculation.                       |
| Lower-dose bonus stars                            | Omitted because fixed outside time and the common rate curve give equal completed-run dose.    |
| Physiological tiredness                           | Explicitly fictional fatigue for balancing the game.                                           |

NASA SDO imagery remains a separate observational feature with connected/cached/bundled/stale labels and publication age. It does not supply the numerical coefficients above. See [LIVE-DATA.md](LIVE-DATA.md).

## Runtime boundary

The controller owns preflight and Start. Constructing/resetting the model initializes an unadvanced `running` state; it has no automatic timer. The controller must not call `advance(real_seconds)` until Start, or while paused. `set_cleaning_speed(u)` selects one of the seven work multipliers; `set_pace(0.5/1/2)` controls accessibility clock speed. They are different settings.

`snapshot()` returns detached values including `selected_multiplier`, `fatigue`, `cleaned_work`, `clean_fraction`, `solar_power_kw`, `battery_kwh`, `radiation_rate_ugy_per_day`, `dose_ugy`, histories and the energy ledger. `cleaning_rate_sections_per_minute` is zero after the work cap or terminal state; `effective_rate_sections_per_minute` retains the hypothetical capability at the current pace/fatigue and must not be presented as ongoing work. `storm_progress` and the compatibility field `storm_distance_normalized` are countdown fractions, not physical distance.

At T, status becomes `win`, `pass` or `lose`, phase becomes `sheltered`, and terminal state rejects further advancement. `result()` adds equation explanations, outcome basis and `dose_bonus_awarded = false`. Bounded pace segments/history must not be represented as an unlimited event log.

## Evidence and limits

Local progress retains preferences, explored concepts and bounded completed summaries. Older lessons and quizzes keep their original identities; walking or recall answers must not be relabeled as evidence about fatigue. Reviewing a card records exploration, not mastery. No names, ages, health data or cloud learner profile are needed.

The [independent numerical audit](evidence/pace-model-0.8-audit.json) records 1,665 checks against the exact model/harness hashes, covering constant-pace examples, fatigue bounds/recovery, mixed pace, work cap, automatic entry, energy conservation, frame partitioning and equal final dose. Preflight and paused-reading tests must show no changes to mission quantities. **Final pace-workflow integration and release acceptance are pending until the corresponding new evidence is recorded.** Earlier radio/recall results verify their own source snapshots, not this model.

Run the focused model checks with `godot --headless --path game --script res://tests/pace_mission_test.gd`; the shared runner and release evidence determine accepted scope.

The model is an educational abstraction, not operational storm prediction, personal dosimetry, professional EVA training or a validated biomedical fatigue model.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
