# Science, sources, and model limitations

## Evidence ledger

Sources checked on 2026-11-14. These are public NASA sources; no project documents are submitted to those websites.

| Input / idea                                                    | Provenance                                                                                                                                                                    | Use and limitation                                                                                                                                                                                                                |
| --------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| 0.67 mSv/day surface dose equivalent                            | [NASA, 2013: Rover results and human exploration](https://www.nasa.gov/news-release/nasa-rover-results-include-first-age-measurement-on-mars-and-help-for-human-exploration/) | Actual reported Curiosity RAD average at Gale Crater, August 2012–June 2013. Divided by 24 for an hourly background rate. The period had no major solar storms affecting Mars; not a current forecast or universal Martian value. |
| Electrodynamic surface dust removal                             | [NASA, 2025: Dust shield successfully repels lunar regolith](https://www.nasa.gov/image-article/nasas-dust-shield-successfully-repels-lunar-regolith-on-moon/)                | Demonstrated on the Moon on Blue Ghost Mission 1. Supports the mechanism concept, not the game's efficiency, Mars performance, or suit certification.                                                                             |
| Dusty, thin Martian atmosphere and variable surface environment | [NASA Science: Mars facts](https://science.nasa.gov/mars/facts/)                                                                                                              | Environmental context; does not supply the scenario weather curves.                                                                                                                                                               |

The challenge URL returned HTTP 503 during verification. The user-supplied brief is the working challenge reference; current judging rules, deadlines, sponsor offers, and age wording require verification with the official organizers. No sponsor award eligibility or NASA endorsement is claimed.

## Explicitly illustrative inputs

Every scenario storm timeline and solar particle event is synthetic. The reference prototype’s Red front peak optical depth is sourced from NASA’s published June 2018 Opportunity observation near 11; the curve around it remains invented. Battery capacities, loads, dust-deposition and cleaning rates, nine-minute return time, inspection duration, capacity bonus, recovery threshold, radiation shelter factor, and dose abort threshold are game-design assumptions. The forecast is exact in this introductory model; real forecasts are uncertain.

The first-person game uses a sourced historical radiation measurement plus NASA-supported mechanisms. The reference web prototype additionally uses NASA’s published Opportunity optical depth near 11 in its Red front scenario. It does **not** yet replay a NASA time-series dataset. Stronger competition data integration requires importing an appropriately licensed observational dataset, preserving provenance, and separating observed variables from synthetic extrapolation. Do not describe the prototype as a NASA-calibrated habitat simulator.

## Equations and units

Fixed time step: Δt = 1/120 hour. Duration: 12 simulated hours, four real minutes at normal speed.

- Habitat battery: E_next = clamp(E + (P_solar − P_load) × Δt, 0, E_capacity).
- Load: P_essential + P_operations + P_cleaning. Essential load is always present. Conservation changes only nonessential operations.
- Solar power: P_rated × inspection_factor × exp(−τ/μ) × (1 − surface_dust).
- Inspection factor: 0.75 + 0.25 × inspection_completion; this is a fictional recoverable equipment limitation.
- Surface dust: clamp(dust + (deposition_rate − cleaning_rate) × Δt, 0, 0.95).
- Suit battery: E_suit_next = max(0, E_suit − (P_suit_life_support + P_visor_cleaning) × Δt), while outside or returning. Indoor suit battery is preserved; no free charging is simulated.
- Dose: D_next = D + (background_rate + event_rate) × protection_factor × Δt.
- Inspection: clear-visor fraction × Δt / inspection_duration while outside and not returning.

Units: kW, kWh, hours, and mSv. Optical depth and fractions are dimensionless. The visor changes visibility only. Dust and radiation events are independent, so the dust storm does not trigger or forecast the particle event.

## What the model does not establish

The simplified direct-beam attenuation omits diffuse radiation, spectral response, temperature, seasonal solar distance, detailed panel geometry, and charging losses. Radiation transport is not modeled: particle spectra, secondary radiation, shielding composition, and geometry matter in real habitats. The same illustrative protection factor is applied to background and event dose, which is not a valid engineering shielding calculation. The displayed crew dose represents the more exposed explorer; independent individual dosimetry is not implemented.

The game threshold of 4 mSv is not a NASA exposure limit or a claim of imminent injury. A mission abort is an operational teaching outcome. A genuine astronaut-training claim would require subject-matter review, validated objectives, and evidence of transfer to relevant tasks.

## Fair comparisons

The fixed baseline begins sheltered with panel cleaning on and normal electrical demand. It skips the EVA inspection. Both runs use the same environmental function and abort rules. Aborted runs stop accumulating resources and dose, so the debrief displays survival time as well as status. This baseline illustrates one bad policy; it does not establish that AEGIS is optimal or universally better. The transparent adviser can also be evaluated directly in the unit tests.

## First-person implementation differences

The native first mission uses the First light weather profile. Inspection requires holding the interaction at the equipment; its work-duration parameter is 0.3 simulated hours rather than the reference prototype's 2.5-hour passive-work parameter. This is deliberately compressed tactile gameplay. Shelter is a spatial volume entered on foot, so the actual walk replaces the dashboard's nine-minute return timer. The native log tracks the exposed player as the displayed crew dose, not independent dosimetry for both characters.

The native mission clock runs 180 times faster than wall time for resource integration (0.05 simulated hours per real second, or 12 simulated hours in four real minutes), while movement uses real-time engine physics with Mars gravity. Therefore scene distances, human activity times, and environmental evolution are not one physically coherent time-scale simulation. This limitation must remain explicit in scientific claims.
