# KŌMAKU: Shield Protocol — short video pitch

**0.8.0-alpha.1 source pitch; publication and final pace-workflow acceptance are pending.** The final direction follows the November 15, 2026 words-only workflow: set a cleaning pace in preflight, press Start, balance fictional fatigue and cleaning, then enter automatically at the deadline. Historical 0.7.1 downloads contain the earlier mission.

## Simple description

KŌMAKU is a Mars learning game for ages 7–12. From a calm habitat window, the player chooses Ren's cleaning pace and sees how dust, solar generation and actual battery energy connect. Optional science bubbles and a result-based equation reveal explain the choices. NASA SDO provides a separate latest-image view of the real Sun.

## Narration: 30 seconds maximum

> We’re Team Roshan Xingbo. KŌMAKU: Shield Protocol makes Mars science playable. Set Ren’s cleaning pace, press Start, and balance speed against a simple tiredness model. Watch dust clear and battery energy grow. Explore NASA’s latest solar image, then see the equations behind your result. Children learn by trying another plan, with clear controls and a calm window view.

**58 words**, counted by whitespace. Rehearse to about 28 seconds, allowing a two-second buffer. The exported video must be **30 seconds or shorter**, including titles, fades and any end card. Word count alone does not verify duration.

| Time    | Actual game capture                                     | Caption                           |
| ------- | ------------------------------------------------------- | --------------------------------- |
| 0–3 s   | Team name and calm window view                          | Team Roshan Xingbo                |
| 3–7 s   | Preflight pace selection, then START MISSION            | Choose a pace. Press Start.       |
| 7–15 s  | Slower/faster changes and the fatigue/work relationship | Find a workable pace.             |
| 15–19 s | Real NASA SDO viewer, retaining its status/date/credit  | NASA SDO · latest available image |
| 19–28 s | Automatic entry, actual result and equations            | Discover why your plan worked.    |
| 28–30 s | Optional end card if timing permits                     | KŌMAKU: Shield Protocol           |

Use real candidate gameplay, not concept artwork labeled as gameplay. Any edit that skips mission time is a video edit, not evidence that the round runs that quickly. Final captures must show the new pace workflow; earlier recall controls and reserve forecasts are outdated. Keep music below narration and preserve [audio credits](AUDIO-CREDITS.md).

## What is factual and what is authored?

Use the [video equation cards](media/KOMAKU-Video-Equations.pdf) and [equation notes](VIDEO-EQUATIONS.md) for supporting graphics. They are explanation material, not extra narration beyond the 30-second limit.

- **NASA SDO:** the viewer requests the latest available AIA 193 Å solar browse image, with connected/cached/bundled/stale labels. HTTP publication time is not verified exposure time. The image does not drive Mars radiation, fatigue, battery or scoring. See [LIVE-DATA.md](LIVE-DATA.md).
- **Curiosity RAD:** 210 ±40 µGy/day is the historical tissue-like detector result used as the central reference. The rising rate `210 × (1 + 3t/T)` is an authored story curve, not a measured storm or live Mars telemetry.
- **Pathfinder dust research:** observed dust-related short-circuit-current decline supports the dust concept. Its reported 0.28% per day is not the game's cleaning or power coefficient.
- **Game assumptions:** requested pace, fictional fatigue, panel transmission/rating, load, battery limits, 30-minute duration and outcome thresholds are authored.

The final lesson connects **pace and fatigue → cleaning work → dust transmission → solar generation → actual battery energy**, while the authored rate curve integrates to absorbed model dose. Power is in kW; energy is in kWh; cleaning is in sections per simulated minute. Every completed default round ends at the same time with **10.9375 µGy**, so there are no lower-dose bonus stars. There is no Sv conversion, health inference or medical danger score. See [the complete model](TRAINING-MODEL.md).

## Sources for the description

- [NASA SDO: The Sun Now](https://sdo.gsfc.nasa.gov/data/). **Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.**
- [NASA archive: Curiosity surface radiation](https://ntrs.nasa.gov/citations/20180007641); primary Table 1 in the [Caltech author manuscript](https://authors.library.caltech.edu/records/kdt88-3aw98).
- [NASA: Dust Characterization Experiment for Solar Cells Operating on Mars](https://ntrs.nasa.gov/citations/20020031145).
- [NASA: Power Operations of the Mars Exploration Rovers](https://ntrs.nasa.gov/citations/20230007029).
- [NASA Science: Mars facts](https://science.nasa.gov/mars/facts/).
- [EPA: Radiation Terms and Units](https://www.epa.gov/radiation/radiation-terms-and-units).

The [source index](SOURCE-INDEX.md) distinguishes publications, historical observations and an online image service. These are not ten integrated numerical NASA datasets. Research links do not establish NASA endorsement, clinical validity, measured learning outcomes or unverified contest eligibility.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
