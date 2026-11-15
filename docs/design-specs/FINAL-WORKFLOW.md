# Final workflow: pace, effort, and automatic shelter entry

**Design reconciliation · November 15, 2026, America/New_York.** The latest supplied [Game Workflow (Words Only)](source/journey-2026-11-15/Game-Workflow-Words-Only.pdf) is archived byte-for-byte with [provenance](source/journey-2026-11-15/provenance.json). Its workflow supersedes the earlier recall mission. Its scientific labels remain design proposals, not scientific authority.

## Accepted interaction

1. The separately supplied opening video introduces Mars, the habitat, and Ren. The control room is the main playable screen, looking through a window at Ren beside a visible solar panel and shelter entrance.
2. Before **START MISSION**, the player may inspect the concepts and choose a pace. The story leads directly to this preflight screen; the eight-concept constellation is optional and no review percentage gates Start. The mission clock, brushing, cleaning, energy integration, and dose do not advance before Start.
3. During the round, a slider and **SLOWER / FASTER** controls choose a bounded work-pace multiplier. Ren stays at the panel. An authored tiredness mechanic makes sustained high pace reduce subsequent effective cleaning rate.
4. One 30-minute simulated countdown drives the warning progress, work, stored energy, and model dose. Reading, explicit pause, focus loss, and supporting views must pause the same clock.
5. At zero, Ren automatically enters shelter. There is no return walk, recall button, early-entry trade-off, or extra entry duration in this final workflow.
6. The result reports the actual panel cleaning, actual stored battery energy, and accumulated model dose. The four-group equation reveal uses that run's history and explains its WIN/PASS/LOSE band.

This document specifies the accepted workflow; source integration, UI checks, and release evidence determine implementation acceptance. It does not claim that a referenced opening-video asset has already been supplied or finalized.

## Scientific corrections retained in the interface

| Design reference wording                       | Accepted label or behavior                                                                         | Reason                                                                                                                              |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| Radiation strength in mSv/day                  | **Absorbed model dose rate, µGy/day**                                                              | The numerical reference is a tissue-like detector's absorbed dose. It cannot silently become a weighted dose-equivalent rate.       |
| Dose absorbed by Ren's body                    | **Absorbed model dose, µGy**                                                                       | The game integrates a detector-derived reference; it does not calculate actual tissue dosimetry or injury.                          |
| Sievert shows what the dose means for the body | A separate concept explaining radiation/tissue weighting, with **no computed personal Sv reading** | One aggregate µGy counter does not provide radiation composition and tissue doses.                                                  |
| Power in kWh                                   | **Stored energy in kWh**; generation and load in **kW**                                            | Power is a rate; energy accumulates over time.                                                                                      |
| Working speed in m/s                           | **Cleaning rate in sections/min**, plus a unitless pace multiplier                                 | Ren is stationary. A section is a task unit, not an invented walking distance.                                                      |
| Storm distance from far to near                | **Warning progress / time remaining**, an authored story indicator                                 | No distance or particle-propagation model is implemented.                                                                           |
| Shelter distance in metres                     | **At the shelter entrance / automatic entry at zero**                                              | No moving return route exists in this version.                                                                                      |
| Safe/risky/dangerous radiation colours         | Clearly labelled **scenario progress**, not a clinical safety scale                                | The model provides no validated medical thresholds.                                                                                 |
| Extra stars for lower dose                     | **No lower-dose bonus in fixed-duration rounds**                                                   | With the same radiation curve and 30-minute outside time, all completed rounds have the same dose.                                  |
| Faster always eventually cleans less           | Explain the actual bounded pace/effort dynamics and recorded result                                | This is an authored nonlinear task mechanic; outcomes must come from the model rather than a universal claim about real astronauts. |

## Agreed scenario equations

Use simulated minutes t, with T = 30. The full animation handoff is [VIDEO-EQUATIONS.md](../VIDEO-EQUATIONS.md).

```text
u ∈ {0.25, 0.50, 0.75, 1.00, 1.25, 1.50, 1.75}
F(0) = 0; 0 ≤ F ≤ 0.9
a(t) = 1 during active cleaning, otherwise 0
dF/dt = a(t)[0.08 max(u − 1, 0) − 0.12 max(1 − u, 0)], bounded at F limits
q(t) = 0.125 a(t) u(t) [1 − F(t)]                     sections/min
W(t) = min[4, ∫₀ᵗ q(s) ds]                      sections
C(t) = W(t)/4; dust remaining = 1 − C(t)
P(t) = 8 [0.25 + 0.75 C(t)]                     kW
E(t) = clamp[0.5 + ∫₀ᵗ(P(s) − 1)ds/60, 0, 6]   kWh
r(t) = 210 [1 + 3t/30]                          µGy/day
D(t) = ∫₀ᵗ r(s)ds / 1440                       µGy
```

The 210 µGy/day central baseline is the published historical Curiosity reference; its reported uncertainty is ±40 µGy/day. The linear radiation increase, all pace/effort coefficients, task size, panel transmission, hardware, deadline, and outcome thresholds are authored. The live NASA SDO image is educational observation only and does not drive these equations.

At T, automatically enter shelter and classify **WIN if C ≥ 0.8, PASS if 0.4 ≤ C < 0.8, otherwise LOSE**. All completed rounds give D(T) = **10.9375 µGy**. Stored energy is actual integrated kWh, not the earlier forecast-at-warning reserve. No health score, lethal dose, calorie estimate, or real astronaut training certification is implied.

## Implementation boundaries

`pace_mission.gd` owns the final model; the former `training_mission.gd` recall/forecast model is historical. Do not mix its one-minute entry, 1×/1.25× cue, flat radiation rate, or 2 kWh projected reserve into the new result screen. The original advanced EVA mission is also a separate model.

Fatigue changes only during active cleaning. At four completed sections, work and fatigue freeze; generation, stored energy, and outside dose continue until the 30-minute deadline. Integrate across pace changes and fatigue/work bounds. Repeated clicks must not create free work; small and large frame steps must agree within numerical tolerance. Pause must freeze all physical task variables. Changing artwork, audio, video, or bubble layouts must not alter numerical rules. Final equations should use actual recorded intervals and end values, never a prerecorded example presented as the player's result.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
