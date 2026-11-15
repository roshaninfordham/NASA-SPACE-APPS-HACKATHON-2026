# KŌMAKU: Shield Protocol — equations for the reveal video

**Final-workflow equation handoff · November 15, 2026, America/New_York.** [Download the two-page equation sheet](media/KOMAKU-Video-Equations.pdf). This replaces the earlier recall/energy-reserve reveal. It describes the agreed pace-and-fatigue mission; release validation must verify the implementation against these equations.

Use four main groups. Let **t mean simulated minutes**, with a **30-minute round**. Show the player's recorded results in the final substitutions. Do not substitute the example below for a different player's run.

## 1. Pace + effort + time → cleaning

**Short line for children:** “Your pace and effort decide how much gets cleaned.”

```text
Cleaning rate q(t) = 0.125 × a(t) × u(t) × [1 − F(t)]   sections/min
Cleaned work W(t) = min[4, ∫₀ᵗ q(s) ds]           sections
Clean fraction C(t) = W(t) / 4
```

The active-cleaning indicator **a(t) = 1** only after Start, while unpaused, before the deadline, and with work remaining; otherwise **a(t) = 0**. The pace multiplier **u** can be 0.25, 0.50, 0.75, 1.00, 1.25, 1.50, or 1.75. A section is one quarter of this fictional cleaning task, not a measured square metre. The time integral adds work across every pace change; `final rate × total time` is generally wrong.

**Smaller effort subline:**

```text
F starts at 0 and stays between 0 and 0.9.
ΔF = a × [0.08 max(u − 1, 0) − 0.12 max(1 − u, 0)] × Δt
```

Clamp F to its bounds after the change. At a fixed pace, integrate continuously and split intervals when a bound is reached. Effort F changes only during active cleaning; when all four sections are clean, work and F freeze while battery charging and dose continue until the countdown ends. F is an **authored work-slowdown mechanic**, called tiredness in the story. These coefficients are not measured astronaut physiology, a fitness assessment, or effects inferred from radiation. Pace above 1 builds F; pace below 1 reduces F; pace exactly 1 holds its current value.

## 2. Cleaner panel → more solar power

**Short line for children:** “Less dust lets more useful sunlight through.”

```text
Dust remaining = 1 − C(t)
Solar power P(t) = 8 × [0.25 + 0.75 × C(t)]       kW
```

Show dust and clean fraction as percentages by multiplying by 100. The game starts at 2 kW and reaches 8 kW at full cleaning. This linear transmission relationship and panel rating are scenario settings, not NASA hardware measurements. “100% task dust remaining” does not mean that all sunlight is blocked.

## 3. Solar power − habitat need → stored energy

**Short line for children:** “Energy left after the habitat's needs charges the battery.”

```text
E(t) = clamp[0.5 + (1/60) ∫₀ᵗ (P(s) − 1) ds, 0, 6]   kWh
```

Power is in **kW**; stored energy is in **kWh**. The factor 1/60 converts simulated minutes to hours. The battery starts at 0.5 kWh, habitat load is 1 kW, and capacity is 6 kWh. The default panel always supplies at least 2 kW, so this round charges the battery; the storage bound still belongs in the model. The old projected-at-warning reserve criterion is removed. Display the **actual accumulated energy**, not a forecast.

## 4. Radiation rate over outside time → absorbed model dose

**Short line for children:** “Dose adds up while Ren is outside.”

```text
r(t) = 210 × [1 + 3t/30]                         µGy/day
D(t) = (1/1440) ∫₀ᵗ r(s) ds                     µGy
     = (210/1440) × [t + 3t²/(2 × 30)]           µGy
D(30) = 10.9375 µGy
```

The baseline **210 ± 40 µGy/day** comes from Curiosity RAD's historical tissue-like E detector observation at Gale Crater, 2012–2013. The engine uses the central value, not sampled uncertainty. The rising multiplier from 1 to 4 is **fictional**; it is not NASA's current Mars radiation rate, a solar-particle forecast, or a value derived from the live SDO image. The factor 1/1440 converts simulated minutes to 24-hour Earth days, not Martian sols.

All completed rounds keep Ren outside for the same 30 simulated minutes. Therefore **every completed round has the same 10.9375 µGy model dose**. Cleaning pace does not change the radiation curve. Awarding lower-dose stars in this fixed-duration design would be misleading. Pauses stop the simulation clock; Ren automatically enters shelter at zero without a walking stage or early-recall control.

## Sievert stays a separate concept

**Short line:** “Sievert needs more information than our dose counter gives.”

If a technical definition is shown, keep it visibly separate from the player's numerical result:

```text
Equivalent dose: H_T = Σ_R w_R × D_(T,R)         Sv
Effective dose:  E_eff = Σ_T w_T × H_T           Sv
```

Here D\_(T,R) is absorbed dose in gray for a specified tissue T and radiation type R; w_R and w_T are appropriate radiation and tissue weights. These definitions are **not evaluated in the game**. The game lacks the necessary particle/tissue information and cannot convert its one µGy counter into a personal sievert or health score. E_eff is a radiation quantity, unrelated to battery energy E. Do not animate “µGy = Sv” or a numeric body-health reading.

## Example only: normal pace throughout

With u = 1 for the whole round, F remains zero:

| Reading                          | Exact scenario result                       |
| -------------------------------- | ------------------------------------------- |
| Cleaning rate                    | 0.125 sections/min                          |
| Work after 30 minutes            | 3.75 of 4 sections                          |
| Clean / dust remaining           | 93.75% / 6.25%                              |
| Solar power at the end           | 7.625 kW                                    |
| Actual battery energy at the end | 2.40625 kWh                                 |
| Absorbed model dose              | 10.9375 µGy                                 |
| Result                           | WIN, because clean fraction is at least 80% |

The energy example uses the entire history: solar power rises linearly from 2 to 7.625 kW, so `E = 0.5 + [(2 + 7.625)/2 − 1] × (30/60) = 2.40625 kWh`. Multiplying final solar power by the whole round would overestimate energy.

The authored outcome bands are **WIN: C ≥ 0.8; PASS: 0.4 ≤ C < 0.8; LOSE: C < 0.4**. These are game goals, not engineering or medical safety thresholds. Energy and dose explain the result; they are not additional hidden win conditions.

## Handoff to the animation team

Move the Speed and Time bubbles into group 1, with the effort subline nearby. Connect Dust to group 2 and Energy to group 3. Connect Radiation and Dose to group 4. Keep Sievert as an explanation card; let Shelter mark automatic completion. Use a warning-progress indicator for the fictional approaching storm, not a physical distance calculation.

Keep the four child-facing lines large. Equations can appear one group at a time underneath; finish with the player's actual clean percentage, stored kWh, dose, and outcome. Label scenario values as **“Our mission settings”** and the historical radiation input as **“Published Curiosity reference”**. NASA's latest available SDO image is an optional observation, never a formula input or live Mars dosimeter.

## Sources and reproducibility

- [Hassler et al. (2014), NASA archive](https://ntrs.nasa.gov/citations/20180007641) and [primary manuscript](https://authors.library.caltech.edu/records/kdt88-3aw98): historical absorbed-dose reference, Table 1.
- [NASA Pathfinder dust experiment](https://ntrs.nasa.gov/citations/20020031145): evidence that settled dust can reduce solar-cell current, not our task coefficients.
- [NASA Mars Exploration Rover power operations](https://ntrs.nasa.gov/citations/20230007029): generation, consumption, and storage context, not fictional habitat specifications.
- [EPA radiation terms and units](https://www.epa.gov/radiation/radiation-terms-and-units): different radiation quantities and units; no individual clinical inference.

The [final-workflow reconciliation](design-specs/FINAL-WORKFLOW.md) records why several units and dose-star claims in the supplied design reference were corrected. Rebuild the companion PDF with `python3 scripts/build_video_equations.py`; it uses embedded DejaVu fonts and includes their complete license notice. This sheet is not medical advice, NASA endorsement, or a validated physiological model.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
