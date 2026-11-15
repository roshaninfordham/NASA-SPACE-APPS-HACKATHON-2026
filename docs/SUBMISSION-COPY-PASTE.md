# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — copy-ready submission answers

**Team Roshan Xingbo · draft for review · November 15, 2026.** Nothing has been submitted. The exact form answers are now in [SUBMISSION-FORM-ANSWERS.md](submission/SUBMISSION-FORM-ANSWERS.md); use that newer draft for submission. The material below is background copy. The three summaries below contain exactly 50, 150, and 300 words when counted by whitespace; the form may count words differently.

**Build to link now:** [published 0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1). The restoration of eight visible, updating science bubbles is implemented in the reviewed 0.11 candidate; release acceptance is still in progress. Do not describe that revision as a published 0.11 build. These answers describe the released mission and its optional science library unless a future feature is explicitly identified.

## Candidate footage for the video team

The restored 0.11 interface now has [reviewable native screenshots](media/journey-0.11/README.md) and an [actual cleaning MP4](media/journey-0.11/cleaning-live.mp4), with [capture provenance](media/journey-0.11/CLEANING-CLIP.md). The source suite and 39 native Linux navigation assertions passed; 170 states were captured. The separate 41-screen review gallery passed 22 browser tests. **This is an unpublished development preview**, not a new downloadable release. The published link remains 0.10. Exports and compatible-content update checks passed, but visual acceptance is pending and the Windows package gate needs a reliable recheck; publication is held. Label candidate footage accordingly; do not mix 0.11 interface images with a claim that the 0.10 download has that interface.

## Project name

KŌMAKU: Dust & Radiation

## Team name

Team Roshan Xingbo

## Tagline

Clear the dust. Discover the science.

## Short summary — 50 words

KŌMAKU: Dust & Radiation is a Mars learning game for ages 7–12. From an outpost window, players guide Ren’s solar-panel cleaning and discover how pace, dust, sunlight, and stored energy connect. NASA research grounds the explanations; short missions invite experimentation, while optional science cards reveal the ideas behind each result.

## Project overview — 150 words

What happens when you clean a solar panel on Mars? KŌMAKU: Dust & Radiation lets children aged 7–12 explore the answer from inside a futuristic outpost. Their teammate Ren works outside the window. Players choose her cleaning pace, watch dust clear, and see solar power become stored battery energy.

A round takes about 90 active seconds. A fictional tiredness model makes the fastest requested pace an interesting choice rather than an automatic advantage. Ren enters the shelter when the timer ends. The result explains the cleaned fraction, actual stored energy, and accumulated model dose.

NASA’s Curiosity radiation observations, Pathfinder dust research, and rover power studies ground the lesson. An optional NASA SDO viewer shows the latest available solar image, separately from the simulation. Built with Godot, the mission works offline. Team Roshan Xingbo designed it to encourage prediction, experimentation, and explanation; its educational effectiveness still needs testing with young learners.

## Project details — 300 words

KŌMAKU: Dust & Radiation turns a Mars task into a question a child can investigate: how should we clean a dusty solar panel? Designed for ages 7–12, the game puts the player inside an outpost, looking through a window at their teammate Ren. The player guides her cleaning pace while watching the panel, stored energy, and remaining time.

The round lasts about 90 active seconds, representing 30 mission minutes. Players can change pace and pause to read. A fictional tiredness rule changes the effective cleaning rate, so pushing harder does not always clear more dust. Cleaning improves the panel’s modeled light transmission. Solar power supplies the habitat’s load, and the remainder charges a battery with a fixed capacity. At the deadline, Ren enters automatically. The outcome depends on the cleaned fraction.

Optional science explanations introduce everyday analogies, then offer equations and sources. A result explanation connects the player’s run to the underlying relationships: pace and tiredness affect work; dust affects solar generation; power over time changes stored energy. A separate radiation explanation distinguishes dose rate from accumulated absorbed dose. Every completed round uses the same duration and authored radiation curve, so changing pace does not change final dose.

NASA’s historical Curiosity RAD measurement supplies the radiation reference. Pathfinder research supports the dust concept, and rover power research informs the distinction between generation, consumption, and storage. An optional NASA SDO solar-image viewer adds an observation without driving the fictional Mars storm.

The open-source Godot client runs the mission locally, with no learner account or cloud tutor required. Source code, downloadable builds, documented assumptions, and an illustrated science guide make the work inspectable. Our next steps are supervised learner testing, accessibility improvements, and more missions. We want children to try a plan, notice what changed, and explain why—not merely chase a score.

## What problem are you addressing?

Space science can become a list of unfamiliar words before children get to use any of them. We focus on one visible task: helping a teammate clean a solar panel. A child can make a prediction, change the cleaning pace, and see what happens. Power, stored energy, and radiation dose become quantities they can distinguish and explain. Our intended audience is ages 7–12; testing with that audience is still a next step.

## What is innovative about your solution?

The player stays inside mission control while guiding a teammate outside. One window, one panel, and a short round keep the problem understandable. The result connects a child’s actual choices to the science behind them. Optional explanations offer an everyday analogy first, followed by deeper reasoning and sources. The visual direction combines a futuristic Mars habitat with Asian-inspired curves, lattice details, and warm light. We are building a setting children want to explore while keeping the scientific assumptions visible.

## What can children learn?

Children can compare a rate with an accumulated quantity: requested pace versus completed work, power versus stored energy, and dose rate versus absorbed dose. They can also ask why the fastest requested pace is not always best in this fictional tiredness model. We plan to evaluate understanding through supervised play, predictions, explanations, and later recall. We have not yet demonstrated improved learning outcomes.

## NASA data and sources: what we actually use

NASA observations give the game a scientific starting point. We use one historical absorbed-dose reference, published research that supports the dust and power relationships, environmental explanations, and an optional online solar image. The game identifies which numbers come from observations and which are invented for the lesson.

| Source                                                                                                                                                                                                                                            | Actual role in the project                                                                                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| [Hassler et al., Curiosity surface radiation — NASA archive](https://ntrs.nasa.gov/citations/20180007641); [primary manuscript, Table 1](https://authors.library.caltech.edu/records/kdt88-3aw98); [DOI](https://doi.org/10.1126/science.1244797) | Historical **210 ± 40 µGy/day** in RAD’s tissue-like E detector at Gale Crater during August 2012–June 2013. The central value starts our authored curve. It is not a current Mars reading, a human-risk forecast, or a medical limit. The two archive links refer to the same study. |
| [NASA: A Dust Characterization Experiment for Solar Cells Operating on Mars](https://ntrs.nasa.gov/citations/20020031145)                                                                                                                         | Pathfinder’s experiment supports the relationship between deposited dust and reduced solar-cell output. The source says **“0.28% per day” decrease in short-circuit current**. That percentage is not a game coefficient or a universal power-loss rate.                              |
| [NASA: Power Operations of the Mars Exploration Rovers](https://ntrs.nasa.gov/citations/20230007029)                                                                                                                                              | Supports separating solar generation, consumption, and stored battery energy. Our 8 kW clear-array rating, 1 kW load, 0.5 kWh starting energy, and 6 kWh capacity are scenario settings.                                                                                              |
| [NASA Science: Mars facts](https://science.nasa.gov/mars/facts/)                                                                                                                                                                                  | Environmental context, including the approximately 24.6-hour Martian sol. The dose calculation explicitly uses an 86,400-second Earth day.                                                                                                                                            |
| [NASA/JPL: Curiosity and natural radiation shielding](https://www.nasa.gov/centers-and-facilities/jpl/how-nasas-curiosity-rover-is-making-mars-safer-for-astronauts/)                                                                             | Explains that surrounding material can change exposure. It does not certify our dome or imply zero radiation indoors.                                                                                                                                                                 |
| [NASA: Rover radiation results and human exploration](https://www.nasa.gov/news-release/nasa-rover-results-include-first-age-measurement-on-mars-and-help-for-human-exploration/)                                                                 | Background context linked from the radiation explanation. Its dose-equivalent figures are not interchangeable with the game’s absorbed-dose counter.                                                                                                                                  |
| [NASA: Mars during the May 2024 solar storm](https://www.nasa.gov/solar-system/planets/mars/nasa-watches-mars-light-up-during-epic-solar-storm/)                                                                                                  | Supporting explanation that radiation can vary. We do not replay this event or derive our storm countdown from it.                                                                                                                                                                    |
| [NASA SDO data](https://sdo.gsfc.nasa.gov/data/); [latest AIA 193 Å browse image](https://sdo.gsfc.nasa.gov/assets/img/latest/latest_512_0193.jpg); [usage rules](https://sdo.gsfc.nasa.gov/data/rules.php)                                       | The optional viewer requests NASA’s latest available solar image and labels connected, cached, stale, and bundled states. This is solar imagery, **not live Mars dose**; it does not drive the storm, score, or other mission equations.                                              |
| [US EPA: Radiation terms and units](https://www.epa.gov/radiation/radiation-terms-and-units)                                                                                                                                                      | Additional, non-NASA explanation of gray and sievert. The game does not infer a personal sievert value or health outcome.                                                                                                                                                             |

**SDO attribution:** Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.

These are references and an image service, not nine integrated numerical datasets. We do not claim a separate Space Agency Partner dataset. See the [complete source index](SOURCE-INDEX.md) and [science assumptions](SCIENCE-JOURNEY-SOURCES.md).

**Source verification note for the team:** On November 15, 2026, the Pathfinder NTRS [metadata API](https://ntrs.nasa.gov/api/citations/20020031145), landing page, and [full-text export](https://ntrs.nasa.gov/api/citations/20020031145/downloads/20020031145.txt) returned HTTP 200. Both the abstract and paper text say “0.28% per day.” We therefore preserve that wording; we do not relabel it “per sol,” assume a specific observation duration, or import it into the model.

## How is it built?

The game uses Godot 4.6.3 and typed GDScript. Godot provides the C++ engine; Python supports packaging, validation, and illustrated documentation. The mission model is separate from rendering, controls, sound, and explanatory text. Automated checks cover arithmetic, conservation of energy, state transitions, and consistency across frame sizes. GitHub hosts the source, release downloads, and build workflows.

The current lesson uses deterministic local rules. It does not rely on a trained AI tutor, machine learning, Rust, Tauri, or a cloud service for its mission calculations. The optional NASA image viewer and GitHub update checks are separate network features.

## Accessibility and privacy

Reading a science card and using Pause stop mission time. Reduced-motion and separate music/effects settings are available, and the short mission can be replayed. We aim for clear controls and concise explanations, but have not certified accessibility or completed testing across assistive technologies and all physical devices.

The mission works offline and requires no child account, microphone, health data, or cloud tutor. Preferences and limited progress remain local. Optional NASA image requests and GitHub update checks involve ordinary network connections; we do not claim those services receive no connection information.

## What is implemented, and what comes next?

**Available in the published 0.10 build:** the outpost-window mission, cleaning-pace controls, fictional tiredness, dust/power/battery calculations, automatic entry, results, an optional eight-concept Science library, result explanations, and the optional NASA solar-image viewer. Desktop archives and a web export are available; the web export needs HTTP(S) hosting. We are not claiming native Android/iOS releases or an automatically playable hosted site.

**Candidate awaiting release acceptance:** the restored eight visible, updating science bubbles around the mission view have source captures and checks. Use footage from a verified build, or label an unreleased recording as a development preview.

**Future work:** supervised tests with children and educators, accessibility improvements, clearer explanations, and additional missions. Personalized recommendations are a possible future direction, not an implemented or validated adaptive AI claim.

## Limits we explain openly

The fatigue model, radiation ramp, storm deadline, panel transmission, hardware values, and outcome thresholds are authored lesson settings. The simulation is not flight-accurate engineering, clinical training, a real dosimeter, or a live Mars forecast. Every completed default round has the same outside duration and **10.9375 µGy** of model dose; pace changes cleaning and energy, not that final dose. Outcomes depend on the cleaned fraction. NASA has not endorsed the game, and this draft makes no eligibility determination about rules we have not independently verified.

## 30-second narration

> We’re Team Roshan Xingbo. KŌMAKU: Dust & Radiation makes Mars science playable for young explorers. Choose Ren’s cleaning pace. Watch dust clear and energy collect. NASA’s Curiosity radiation measurements and Pathfinder dust research ground the lesson. Explore NASA’s latest solar image, then connect your results to simple equations. Try another plan. Discover why it works.

This is **55 words** by whitespace. Rehearse the actual recording; titles, pauses, and the ending must fit inside the team’s 30-second target. The official submission duration limit remains to be checked against the form.

| Time          | Visual to show                                                                   |
| ------------- | -------------------------------------------------------------------------------- |
| 0–3 seconds   | Team name and the habitat-window view.                                           |
| 3–12 seconds  | Choose a pace, press Start, show Ren cleaning and the energy reading changing.   |
| 12–18 seconds | A source explanation and the NASA SDO viewer, preserving its status/date/credit. |
| 18–27 seconds | Automatic entry, actual result, and the science explanation.                     |
| 27–30 seconds | Title and a short closing line.                                                  |

Select highlights from a full round; cuts are editing, not a claim that the full mission takes 30 seconds. OpenArt concept shots should be labelled **concept visualization** when they could be mistaken for gameplay. Use actual game footage for controls, readings, and results. Do not show the unfinished bubble restoration as a released feature.

## Links to paste into the form

- **Project source:** https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026
- **Available release:** https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1
- **Science sources:** https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/blob/main/docs/SOURCE-INDEX.md
- **Science guide:** https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/blob/main/docs/SCIENCE-GUIDE.md
- **Final video:** https://www.youtube.com/watch?v=eIkaDw6MwKA (confirm logged-out playback and runtime before submission).

Before sending, match the form’s actual fields and limits, confirm the selected release and video are accessible, and replace the final-video placeholder. This document is prepared copy, not an application submitted on the team’s behalf.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
