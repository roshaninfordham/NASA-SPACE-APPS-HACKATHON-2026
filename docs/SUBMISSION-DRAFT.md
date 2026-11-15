# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — submission draft

**For Team Roshan Xingbo to review. Nothing has been submitted.** Use the [copy-ready answers](SUBMISSION-COPY-PASTE.md) for exact 50-, 150-, and 300-word options, the full source list, and the short video script. Official questions and limits have not been supplied.

**Available build: [0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1).** The next interface revision is restoring eight visible, updating science bubbles; that work is in progress and is not a published 0.11 release. The optional eight-concept Science library described below is already part of 0.10. Record the verified build, or label new interface footage as a development preview.

## Project name and tagline

**KŌMAKU: Dust & Radiation**

**Clear the dust. Discover the science.**

By **Team Roshan Xingbo**.

## One-sentence description

A short Mars learning game where children guide a teammate's solar-panel cleaning from mission control, then discover how pace, dust, sunlight, stored energy, and radiation dose connect.

## Project summary

On Mars, settled dust can reduce solar output, while radiation makes time outside an important consideration. KŌMAKU: Dust & Radiation turns these connected ideas into a mission designed for young explorers aged 7–12.

The player watches Ren work just outside the habitat window and chooses a cleaning pace. Faster work clears dust quickly at first, but a simple, clearly fictional tiredness rule can reduce the effective pace. As the panel becomes cleaner, the player sees more solar power and more stored battery energy. A short countdown gives the mission a clear ending: Ren automatically enters the shelter, and the result explains how much of the panel was cleaned.

The main view focuses on three readings: panel cleaning, stored energy and remaining time. Eight optional science ideas begin with a short explanation, diagram and everyday analogy; deeper reasoning and sources open on request. After the mission, those ideas come together in four equation groups using the player's recorded result. The aim is to make relationships visible, invite another plan, and give children a reason to ask why—not require them to memorize equations before playing.

## How does the game work?

1. **Enter the story.** A brief introduction places the player on Mars in 2059, supporting a teammate outside the window.
2. **Choose a plan.** The control room starts paused in preflight. Children may explore the science bubbles or choose a pace and press Start immediately.
3. **Watch cause and effect.** Ren's brush, the panel's dust, the speed control, and the power readings make each choice visible. Requested speed and effective cleaning rate differ when the game's fictional tiredness builds.
4. **Reach a clear result.** Standard play lasts about 90 active real seconds, representing 30 simulated minutes. Reading and Pause stop the simulation. At the deadline, Ren enters automatically. WIN, PASS, and TRY AGAIN reflect the fraction cleaned; all three end with Ren inside.
5. **Connect the science.** The result shows actual cleaned percentage, stored energy, and absorbed model dose. A separate reveal combines the eight ideas into four relationships. Children can then try another pace plan.

The current mission has a fixed outside duration. Changing cleaning pace changes work and energy, but does **not** change the final radiation dose. Dose is an explanatory quantity, not a hidden health score or another win condition.

## How did NASA's free and open data make this possible?

NASA's published observations gave us a real scientific starting point and a way to distinguish measured evidence from invented game settings.

**Curiosity's Radiation Assessment Detector (RAD)** supplies the historical absorbed-dose reference: approximately **210 ±40 microgray per day** in its tissue-like E detector during the early surface mission at Gale Crater. We use the central value to introduce dose rate and accumulation over time. Our increasing radiation curve and storm countdown are authored lesson settings, not a current Mars measurement or forecast.

**Pathfinder's dust research** shows that deposited dust can impair solar-cell performance. The cited paper reports a **0.28% per day decrease in short-circuit current**. Its NASA abstract and full text were checked on November 15, 2026; both say “per day.” We preserve that wording without relabelling it “per sol” or assuming an observation duration. That supports the game's central connection—less dust can let more useful sunlight reach the solar cells—but the percentage is not used as our cleaning rate or a universal power-loss coefficient.

**Mars Exploration Rover power research** helped us keep three quantities distinct: solar generation, the habitat's consumption, and energy stored in a battery. **Curiosity shielding observations** provide context for why surrounding material and shelter matter, without claiming that our fictional dome is an engineered radiation shield.

The app also offers a separate, optional **NASA Solar Dynamics Observatory (SDO)** viewer that requests the latest available AIA 193 Å browse image of the Sun. It labels successful online retrieval, cached imagery, stale files, and the bundled example separately. This image supports exploration; its pixels do not drive the Mars simulation or score.

Together, these sources let us build a traceable lesson: measured observations motivate the concepts, while the code and science guide disclose the simplified equations and game assumptions.

**Complete current source list and verified source wording:** [copy-ready NASA/data answer](SUBMISSION-COPY-PASTE.md#nasa-data-and-sources-what-we-actually-use). The links below are the main sources; Mars facts, the NASA radiation context articles, and EPA unit definitions are also listed there.

**Source links:** [Curiosity RAD paper / NASA archive](https://ntrs.nasa.gov/citations/20180007641) · [primary manuscript, Table 1](https://authors.library.caltech.edu/records/kdt88-3aw98) · [Pathfinder experiment](https://ntrs.nasa.gov/citations/20020031145) · [rover power operations](https://ntrs.nasa.gov/citations/20230007029) · [Curiosity shielding observations](https://www.nasa.gov/centers-and-facilities/jpl/how-nasas-curiosity-rover-is-making-mars-safer-for-astronauts/) · [NASA SDO](https://sdo.gsfc.nasa.gov/data/).

**SDO credit:** Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.

If the form asks specifically about **Space Agency Partner data**, our current implementation does not claim a separate partner-agency dataset. The NASA archive and Caltech copy of the RAD paper are access points to the same study, not two independent datasets. The full [source index](SOURCE-INDEX.md) explains each reference's actual role.

## What is different about the idea?

The player acts as a teammate in mission control. A close view of one astronaut and one panel keeps attention on a small, understandable problem. Instead of presenting disconnected facts, the game lets a child see a chain: pace changes cleaning, cleaning changes the dust layer, dust changes solar output, and output over time changes stored energy.

The eight ideas are available through **Science** when a child wants an explanation. **Learn more** and **Data & sources** keep deeper material within reach without placing it all on the first card. The result uses the player's own readings, then turns those familiar ideas into equations. A calm, futuristic visual identity and short rounds make room for experimentation without a long tutorial or a reading-completion gate.

This is our design contribution, not a claim that these ideas have never appeared in another game or that learning effectiveness has already been established.

## What do we hope children will learn?

We want children to distinguish a **rate** from an **accumulated quantity**: cleaning speed from cleaned work, power from energy, and radiation dose rate from absorbed dose. They can also discover why the highest requested speed may not produce the most work in this particular tiredness model.

Success means more than recognizing a word. A useful next step is to ask children to explain their plan, predict a different run, and describe what changed. Supervised play tests, accessible controls, and short concept checks will help us evaluate whether the game supports understanding and recall. We have not yet demonstrated educational effectiveness with the target age group.

## How is it built?

The playable client uses the open-source **Godot 4.6.3** engine and typed **GDScript**. Godot supplies the C++ engine; Python supports packaging, validation, and PDF generation. The mission equations are separated from the visual interface, animation, audio, and science explanations so the design can change without silently changing the rules. The model integrates changing cleaning rate, solar power, stored energy, and dose over simulated time; tests check arithmetic, state transitions, and numerical consistency.

The mission can run offline. The optional NASA image view uses HTTPS and a clearly labelled fallback when a current image cannot be retrieved. Progress and preferences remain local; the mission does not require a child's name, health data, microphone, account, or cloud AI service.

The repository contains source code, model documentation, source links, and an illustrated science guide. Downloadable releases are the current distribution route. Use the final release evidence for supported operating systems and installation details; a cross-platform engine alone does not establish support on every device.

## Accessibility and current limits

Reading and Pause stop the simulation. Reduced-motion and separate music/effects settings are available. The mission uses short rounds and concise explanations, with deeper material on request. Accessibility testing with children and assistive technologies remains necessary; we do not claim universal device support or accessibility certification.

Desktop downloads and a web export are published. The web export needs HTTP(S) hosting; there is no claimed native Android/iOS release. Initial operating-system trust prompts can remain for the desktop builds.

## What comes next?

We plan to test the game with young learners and educators, improve the visual explanation of each relationship, and build additional missions with different resources, astronauts, and conditions. A future learning system could suggest a useful next challenge based on a child's answers and plans, with appropriate evaluation and privacy protections.

Those are next steps. The current mission is a fixed scenario with local progress, optional science cards, and a result explanation; it is not a trained adaptive AI tutor or a validated astronaut-training system.

Today, a child can start with one panel and one clear question. Tomorrow, we hope that curiosity helps them understand the choices real explorers make.

## Links to include after final review

- **Source and documentation:** [GitHub repository](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026).
- **Download the game:** [published 0.10.0-alpha.1](https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v0.10.0-alpha.1). Replace this only after a newer build is actually published and verified.
- **Science guide:** [illustrated PDF](media/KOMAKU-Science-Guide.pdf), [readable source](SCIENCE-GUIDE.md), and [source index](SOURCE-INDEX.md).
- **Video:** Add the team's finished video URL after checking the official duration limit.

No public hosted game URL is asserted here; hosting remains deferred. Do not submit the account's unrelated custom-domain page as the game.

## Team review notes

Keep these details accurate when adapting the longer video script:

| Proposed wording                                      | Use instead                                                                                                            |
| ----------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------- |
| “Dust lowers solar power 0.28%.”                      | “Pathfinder measured a 0.28% per day decrease in solar-cell short-circuit current.”                                    |
| “Radiation on Mars is 210 µGy/day.”                   | “Curiosity recorded a historical reference of about 210 µGy/day in a tissue-like detector.”                            |
| “The live NASA feed drives the storm.”                | “NASA SDO shows the latest available solar image; the mission's storm curve is a game setting.”                        |
| “Your speed changes how much radiation Ren receives.” | “Your pace changes cleaning and energy. This fixed-duration mission gives every completed run the same model dose.”    |
| “Gather enough energy or the outpost fails.”          | “Clear enough of the panel to reach the cleaning goal; the energy reading explains what your work produced.”           |
| “The game adapts to every child.”                     | “Personalized missions are a future goal; the current game supports trying and explaining different plans.”            |
| “Published NASA research, not a live feed.”           | “Historical research grounds the model. A separate optional NASA SDO view retrieves the latest available solar image.” |

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC.
