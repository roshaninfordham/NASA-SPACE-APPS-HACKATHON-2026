# The science behind the mission journey

KŌMAKU: Shield Protocol is a learning game for ages 7–12. The mission connects four useful ideas: **dust blocks sunlight; cleaning takes time; returning takes time; absorbed radiation dose accumulates with exposure time**. It uses observations to explain the ideas and explicit scenario settings to make a short, playable activity.

This document describes the 0.8 journey model, not the retained legacy first-person or dashboard experiments. The child-facing source of truth is [mission-concepts.json](../game/data/mission-concepts.json). Implementation acceptance is recorded in [JOURNEY-0.8.md](design-specs/JOURNEY-0.8.md). Scientific sources were checked on 2026-11-14 (2026-11-15 UTC).

## What is measured, and what is invented?

| Quantity or idea                                    | Evidence                                                                                                                                                                                                                                                                                                                                                                                                                                           | How this mission uses it                                                                                                                                                                                                                                                                |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Historical absorbed dose rate: **210 ± 40 µGy/day** | Hassler et al., _Science_ 343, 1244797 (2014), Table 1: tissue-like **E detector** on Curiosity's Radiation Assessment Detector (RAD). Gale Crater, approximately the first 300 sols, 7 August 2012–1 June 2013, near solar maximum. [NASA archive](https://ntrs.nasa.gov/citations/20180007641), [primary author manuscript at Caltech](https://authors.library.caltech.edu/records/kdt88-3aw98), [DOI](https://doi.org/10.1126/science.1244797). | Uses the central value as a constant educational baseline. It is a historical detector observation, not live space weather, a universal Mars value, an actual astronaut's dosimeter, or a medical limit. The published uncertainty is explained here; it is not randomized in gameplay. |
| Gray and sievert are different quantities           | [EPA: Radiation terms and units](https://www.epa.gov/radiation/radiation-terms-and-units). Absorbed dose is energy per mass, 1 Gy = 1 J/kg. Effective dose weights absorbed dose for radiation type and relative organ sensitivity.                                                                                                                                                                                                                | The counter displays **µGy only**. No fabricated conversion to sieverts, heart rate, injury, or a health score. Sievert is taught as a separate concept.                                                                                                                                |
| Dust can reduce panel output                        | [NASA: A Dust Characterization Experiment for Solar Cells Operating on Mars](https://ntrs.nasa.gov/citations/20020031145), citing the Pathfinder Materials Adherence Experiment. The abstract reports a **0.28% per day decrease in short-circuit current**.                                                                                                                                                                                       | Supports the direction of the relationship. It does not establish dust coverage, erosion, a universal constant, or a linear power-margin decrease of 0.28 percentage points per sol.                                                                                                    |
| Real rover power depends on many inputs             | [NASA: Power Operations of the Mars Exploration Rovers](https://ntrs.nasa.gov/citations/20230007029). The model included solar-array and battery data, dust, optical depth, temperature, terrain attitude, season, shadows, and load schedules.                                                                                                                                                                                                    | Explains why the introductory margin forecast is deliberately simpler than an engineering power model.                                                                                                                                                                                  |
| A Martian sol lasts approximately 24.6 Earth hours  | [NASA Science: Mars facts](https://science.nasa.gov/mars/facts/).                                                                                                                                                                                                                                                                                                                                                                                  | Forecast duration uses **sols**; mission time uses seconds/minutes. The historical dose-rate conversion uses a 24-hour Earth day, explicitly 86,400 seconds. These clocks are not interchangeable.                                                                                      |
| Natural terrain can change radiation exposure       | [NASA/JPL: How Curiosity is making Mars safer for astronauts](https://www.nasa.gov/centers-and-facilities/jpl/how-nasas-curiosity-rover-is-making-mars-safer-for-astronauts/), 15 November 2021. RAD measured about **4% less overall radiation** and **7.5% less neutral-particle radiation** beside Murray Buttes, 9–21 September 2016.                                                                                                          | Supports discussing shielding. It does not validate this game's habitat geometry, fictional suit, or a universal shelter factor. The activity stops tracking outside dose on completion; that is not zero radiation inside.                                                             |
| Radiation events vary greatly                       | [NASA: Mars during the May 2024 solar storm](https://www.nasa.gov/solar-system/planets/mars/nasa-watches-mars-light-up-during-epic-solar-storm/). NASA reports an **8,100 µGy** event dose near Curiosity, the largest RAD surge measured there at that time. Hassler et al. describe sporadic solar-particle events, onset times of minutes to hours, and durations of hours to days.                                                             | Explains why a constant historical rate and a fixed warning must be labelled as simplifications. The game does not reproduce this event or infer a health outcome from it.                                                                                                              |

The NASA archive record for Hassler et al. is metadata-only. The primary manuscript was checked at Caltech; Table 1 explicitly names the tissue-like E detector and reports **0.21 ± 0.04 mGy/day**, equivalent to **210 ± 40 µGy/day**. The paper distinguishes its approximately 300-sol observation interval from the per-day dose rates. We use the Earth-day rate convention in the numerical model rather than silently changing the denominator to a sol.

NASA's December 2013 news release reports **0.67 mSv/day** for the same broad observation period. The primary manuscript gives **0.64 ± 0.12 mSv/day** with an average radiation quality factor. Both are dose-equivalent figures, not the absorbed-dose input used here. We do not substitute either number for µGy or infer a general conversion factor from their ratio.

## The small model, step by step

Every quantity in the following scenario table is a **game-design assumption**, except the explicitly sourced absorbed-dose baseline. None is a NASA operating procedure, safe exposure limit, or claim about a future inhabited base.

| Symbol | Meaning                               |      Default | Units                                |
| ------ | ------------------------------------- | -----------: | ------------------------------------ |
| W      | Return deadline from mission start    |        1,800 | simulated seconds                    |
| d      | Route length back to shelter          |          432 | metres                               |
| v      | Planned return speed                  |          0.8 | metres / simulated second            |
| τ      | Time to complete one cleaning section |          360 | simulated seconds / section          |
| n      | Number of completed sections          |          0–4 | sections                             |
| S₀     | Initial spare solar-power margin      |            1 | percentage point of reference output |
| g      | Added margin per completed section    |            2 | percentage points / section          |
| k      | Assumed future linear decline         |         0.28 | percentage points / sol              |
| r      | Constant absorbed-dose baseline       | 210 / 86,400 | µGy / simulated second               |
| a      | Normal play clock multiplier          |            6 | simulated seconds / real second      |
| G      | Forecast-margin training target       |           15 | sols                                 |

A **percentage point** is an absolute change in a percentage: moving from 1% to 3% is an increase of 2 percentage points. This differs from a relative increase of 2%. The margin calculation uses percentage points consistently. Its decline of 0.28 points/sol is an **invented linear teaching trend inspired by, but not equal to**, Pathfinder's relative current-loss result.

1. **Reserve the return time.** `t_return = d / v = 432 / 0.8 = 540 seconds = 9 minutes`.
2. **Estimate how much work fits.** At the start, `n_fit = floor(max(0, W − t_return) / τ)`, capped by the four available sections. This yields three sections with time for the return. In live play, elapsed time and remaining work also matter; idling uses the same deadline.
3. **Advance work and travel on the same mission clock.** `Δt_sim = a × Δt_real`. Paused frames add zero. Completed sections earn margin; unfinished sections do not earn the full section reward. The displayed route is a schematic, not a calibrated 432-metre scene.
4. **Accumulate absorbed model dose while outside.** `D_next = D + r × Δt_outside`. Only the outside part of a time step counts. The counter is nonnegative and cumulative; going inside does not undo absorbed dose.
5. **Calculate spare output.** `S = S₀ + g × n`. The score describes surplus output relative to an illustrative reference, not kWh stored in a battery.
6. **Forecast time until that margin reaches zero.** Under the chosen linear trend, `S_future(s) = max(0, S − k × s)`, so `L = S / k` in sols. This is a **forecast of margin**, not battery autonomy or a guarantee the habitat will remain powered for L sols.
7. **Explain the result.** The training goal is to arrive within the deadline with forecast margin of at least 15 sols. A missed target invites a revised plan. It does not assert that Ren dies, is injured, or has crossed a medical threshold.

The continuous expressions above describe the mathematics. The runtime's event handling must stop integration exactly at arrival/deadline boundaries, retain fractional accumulated dose, and never award a completed-section reward twice. The engine tests and live debrief are the authority for what shipped; this document is not a substitute for executing them. The runtime also offers 0.5× and 2× comfort speeds around the normal clock multiplier. These change real play duration, not the simulated route, dose rate, or work required.

### Worked example

Clean three sections, then return without waiting:

- Cleaning: `3 × 360 = 1,080 seconds` (18 mission minutes).
- Return: `432 / 0.8 = 540 seconds` (9 mission minutes).
- Total outside time: `1,620 seconds` (27 mission minutes; 270 real seconds at ×6).
- Deadline margin: `1,800 − 1,620 = 180 seconds` (3 mission minutes).
- Absorbed model dose: `(210 / 86,400) × 1,620 = 3.9375 µGy`, displayed with sensible rounding.
- Spare output: `1 + 2 × 3 = 7 percentage points`.
- Forecast margin: `7 / 0.28 = 25 sols` under the invented linear trend.

The number **3.9375 µGy is not a health verdict**. The purpose is to see the proportional relationship between a constant rate and time. The 25-sol result is not “25 days of battery.” A partial section, time spent waiting, or an early return changes the outcome, so debrief values must come from the player's actual run rather than this example.

## What this version deliberately does not calculate

There is no live NASA telemetry feed, real-time storm prediction, personal dosimeter, radiation-transport solver, pressure-to-radiation regression, medical model, battery charge model, oxygen model, or life-support certification in this introductory mission. Historical NASA-supported measurements and links are evidence for the concepts; game parameters supply the short scenario.

Real absorbed dose and dose equivalent depend on particle type, energy spectrum, shielding composition and geometry, secondary particles, location, atmospheric column, and solar conditions. Real electrical energy requires integrating power over time with storage, losses, and loads. A calm window scene and an animated astronaut do not establish physically validated terrain, suit motion, or weather.

Heart rate, step count, and ordinary Apple Watch health readings cannot determine absorbed space-radiation dose or sieverts. This release does not collect such data. “Gray strength” is replaced with **absorbed dose**; gray is a unit, not a force or strength.

## Corrections to the supplied discussion

The supplied PDFs and chat are preserved as references, including statements that were not adopted. Their presence in GitHub does not certify their science.

| Reference claim                                                            | Accepted correction                                                                                                                                                                     |
| -------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| “0.03 mSv/min background” and a fivefold storm rate                        | These were invented values. The journey uses a clearly identified historical absorbed-dose baseline in µGy and no invented medical storm threshold.                                     |
| “0.28% dust erosion per day”                                               | The cited experiment measured a decrease in short-circuit current caused by dust obscuration. It did not measure erosion or prove a universal decay rate.                               |
| Surplus divided by dust rate gives “days of power”                         | It gives a forecast time to zero surplus only under the chosen linear assumption. Battery autonomy would require energy/storage modelling.                                              |
| Exactly 30 minutes of reliable warning, or a fixed false-alarm percentage  | These are not established by the checked sources. The deadline is a disclosed story setting.                                                                                            |
| A human's microgray value predicts when they die                           | The game uses no lethal threshold. Absorbed detector dose alone does not determine an individual's health outcome.                                                                      |
| A guaranteed “fresh / tired / exhausted” result from dose                  | Fatigue and injury cannot be inferred from this model. Feedback describes planning, timing, and margin.                                                                                 |
| Speed, dust, and radiation are directly inversely correlated               | At fixed rate, longer outside time increases cumulative dose; cleaning improves model margin. Faster movement does not itself reduce ambient radiation. Real safe speed is constrained. |
| A named correlation such as 0.84, 0.96, or simulated 20,000-run validation | No corresponding reproducible analysis was supplied or verified. These numbers are not advertised as evidence.                                                                          |
| 100% readiness proves the child learned everything                         | It records that all eight cards were reviewed. Reflection and a question can reveal understanding; neither certifies astronaut training.                                                |

## Source access and reproducibility

All eight concept cards include an HTTPS source link, a real-world fact with context, and a separate scenario assumption. Sources open only on an explicit click; the mission pauses while a card is read. Facts remain available offline in the installed catalog. Opening external evidence needs connectivity.

Reviewed source pages returned HTTP 200 during this audit. The canonical DOI may be access-restricted at the publisher; the Caltech author manuscript supplies the verified Table 1. Links may change later, so source labels and historical context remain in the local catalog. No copyrighted research paper is bundled here. User-supplied design references are archived with byte counts and SHA-256 hashes in [the provenance manifest](design-specs/source/journey-2026-11-14/provenance.json).

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
