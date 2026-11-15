# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — core proposal and evidence

**The engineering question is still the original one:** can a player coordinate habitat, suit and visor protection through independent dust and radiation hazards without exhausting the energy needed to recover?

This document connects the original brainstorming to the current playable product. [The core brief](CORE-BRIEF.md) defines the experience; [the science ledger](SCIENCE.md) owns equations and assumptions; [the design-specification ledger](SPEC-IMPLEMENTATION.md) tracks the later visual expansion. A new character, building style or inspection activity must support this core rather than quietly turn it into an unrelated colony simulator.

## Accepted scope

The product name is **<!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->**. AEGIS is the fictional environmental decision-support system; “The Shape of Survival” is an earlier working title. The intended learners are ages 7–12, with adult assistance where reading or controls require it. The player is the first-person explorer and Mira is the companion; the current mission does not simulate independent inventories, movement or radiation histories for two crew members.

One mission takes four real minutes and represents twelve simulated hours. It has two electrical stores and three linked intervention scales:

| Scale     | Player action                                                         | Benefit                                                                         | Cost or limitation                                                                                             |
| --------- | --------------------------------------------------------------------- | ------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------------------- |
| Habitat   | Inspect the array; switch panel cleaning; conserve nonessential power | Restore modeled array capacity, remove deposited dust, preserve recovery energy | Inspection takes time; cleaning uses habitat energy; conservation reduces modeled nonessential research        |
| Astronaut | Decide when to stop exterior work and enter the marked refuge         | Installed shielding reduces the modeled dose rate                               | Time outside uses suit energy and accumulates exposure; unfinished inspection leaves some capacity unavailable |
| Visor     | Switch visor cleaning                                                 | Clearer sight improves inspection progress                                      | Uses the suit battery; it cannot clear the sky or shield ionizing radiation                                    |

Dust in the atmosphere and dust deposited on equipment remain separate variables. The solar particle event is independent of the dust storm. Life support is automatic, not a switch the child can turn off. Passive refuge shielding remains effective without a “shield power” button. Water, food, pressure and detailed thermal control are assumed background systems, not independently simulated colony subsystems.

Success requires reaching the end of the scenario with the displayed exposure and energy abort rules satisfied and at least the modeled recovery reserve remaining. An abort is a gentle teaching outcome, not a claim of imminent injury. The 4 mSv abort threshold and 2.4 kWh recovery reserve are game assumptions, not NASA operational limits.

## Why the choices interact

A dirty visor slows the exterior inspection. Cleaning it makes inspection easier but drains the suit battery faster. Completing the inspection restores part of the habitat's available solar capacity; staying outside longer also increases exposure. Panel cleaning can improve a dirty panel while still giving little useful power under an opaque sky. Conserving electrical demand preserves critical loads but sacrifices the model's nonessential research activity.

These causal links are the proposed distinguishing contribution: a small, legible mission connects protection decisions at three scales and lets the learner explain their consequences. Neither adaptive environmental protection nor educational resource-management games are new inventions. Novelty should be argued from this particular implementation and evaluated experience, not an unsupported “first ever” claim.

## Published 0.6.1 baseline

| Original proposal requirement                 | Implemented evidence                                                                                                                            | Limit of the claim                                                                                                                                                                      |
| --------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| One short, replayable emergency               | First-person mission, inspection, power controls, visor cleaning, passive refuge and debrief; [gameplay checks](../game/tests/gameplay_test.gd) | One deterministic introductory scenario; complete rescue/escort and multi-sol campaigns are absent                                                                                      |
| Separate measurable quantities                | Hours, kW, kWh and mSv in [mission model](../game/scripts/mission.gd); [numerical checks](../game/tests/mission_test.gd)                        | Simplified teaching model with synthetic weather and hardware assumptions                                                                                                               |
| Compare an adaptive run with a fixed strategy | Debrief displays the player's result and a declared fixed sheltered/cleaning-on/normal-load baseline                                            | Same weather function and abort rules; the comparator starts sheltered and skips inspection. It is not a controlled experiment isolating one variable or proof of universal superiority |
| Adaptive learning support                     | Five-concept local academy with authored feedback and provisional review estimates; [learning design](LEARNING-DESIGN.md)                       | No trained model, validated ability score or measured learning gain                                                                                                                     |
| Tactile learning around the original controls | Untimed exploration, five Suit Lab experiments and four architecture lessons                                                                    | Practice models are separate from mission state and are not suit certification tests                                                                                                    |
| Evolving visual identity                      | Shared brand/style data, replaceable scene slots and detached visual snapshots; [handoff](DESIGN-HANDOFF.md)                                    | Art can evolve without changing equations; collision changes still require route tests                                                                                                  |
| Efficient broad distribution                  | Godot native desktop and Web archives; signed compatible desktop content updates                                                                | Physical MacBook M5, Windows and phone performance remains unmeasured; native Android/iOS public installers are absent                                                                  |

A transparent predictive adviser was present in the earlier reference simulation. The native planner described below is a source addition after the published 0.6.1 packaging hotfix; identify it by its own release notes and tests before describing it as shipped. A forecast based on the scenario's known future is a teaching counterfactual, not a real Mars weather forecast or an autonomous learning system.

## Native planner in the current source

The planner brings the original brief's anticipatory decision support into the first-person mission. It is a local deterministic teaching comparison, not trained AI or a real-time Mars forecast. **P** or **Pause → Compare mission plans** pauses the running mission and projects one simulated hour from the same current state with four fixed settings:

| Plan | Nonessential work  | Panel cleaner |
| ---- | ------------------ | ------------- |
| 1    | Normal             | Off           |
| 2    | Normal             | On            |
| 3    | Power conservation | Off           |
| 4    | Power conservation | On            |

All four use the actual [mission equations](../game/scripts/mission.gd) through the [adviser](../game/scripts/mission_adviser.gd), with the same scripted future weather. The prediction holds location/shelter and visor settings constant and performs no additional inspection. It stops at the horizon, mission end or an abort. Each result exposes elapsed time, status, habitat energy, suit energy, cumulative dose and research work. During modeled exterior work, conservation reduces the optional work rate to one quarter while maintaining essential life support; sheltered runs accrue no exterior research in either mode. This is a declared game rule, not a measured outpost productivity effect.

Compare one change at a time: plans 1 and 2 isolate cleaning at normal work, while plans 1 and 3 isolate conservation with cleaning off. The tool does not combine all outcomes into one “best astronaut” score. A shorter failed run can retain more energy simply because it stopped earlier; duration and status are part of the explanation. The model's exact future weather makes these counterfactuals internally consistent but more certain than operational forecasts.

**Use this plan** is an explicit player choice that changes only the two habitat switches. Browsing plans and opening the maths do not mutate the mission. The planner cannot walk to shelter, clear the visor, complete inspection or guarantee a safe route. It complements the end-of-mission fixed-baseline comparison rather than replacing it.

[Model checks](../game/tests/mission_adviser_test.gd) cover analytical one-step energy/dose, unchanged live state, independent mission integration, cleaning's changing value, early aborts and bounded horizons. [UI checks](../game/tests/mission_planner_test.gd) and [integration checks](../game/tests/planner_integration_test.gd) cover the interface and explicit plan application; their exact run results belong in the release validation record. These are implementation checks, not evidence of learning efficacy. This feature is being prepared after 0.6.1 and must not be represented as part of that published installer.

## Evidence for the five working judging criteria

The five labels below come from the supplied challenge/judging text. Both official challenge and submission-guide URLs returned HTTP 503 again on November 14, 2026. Their current rules, dates and sponsor eligibility therefore remain unverified. [The source-check record](evidence/challenge-source-check.json) records requests, statuses and hashes of the original briefs; the two long brainstorming inputs are byte-identical.

| Criterion from supplied brief | Demonstrate now                                                                                                                 | Evidence still needed                                                                                                     |
| ----------------------------- | ------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| Impact                        | A short no-account game for a specific learner audience, accessible practice and low-stakes retries                             | Supervised usability, comprehension and delayed-recall evaluation; actual accessibility findings                          |
| Creativity                    | First-person coordination of habitat, suit and visor; craft-informed futuristic art; comparison of decisions                    | Design-team review and observed engagement; no unsupported originality ranking                                            |
| Validity                      | Explicit units and equations, numerical invariants, successful playable routes, release/update checks                           | Science-expert review, real-device memory/frame pacing and learner testing                                                |
| Relevance                     | A historical Curiosity radiation measurement actually enters the model; cleaning and shelter decisions affect outpost resources | Verified current challenge wording and richer observational data integration without concealing synthetic extrapolation   |
| Presentation                  | A working download, a coherent decision story, real screenshots and a source/assumption explanation                             | Final team recording, project-page copy checked against the exact submitted version, and official submission requirements |

The [demonstration script](DEMO-SCRIPT.md) gives a practical sequence. A judge should be able to identify the action, observe its cost, inspect the equation behind it and find its source or assumption without relying on a verbal promise.

## NASA source boundary

The November 14 source recheck returned HTTP 200 for the existing NASA radiation, lunar dust-shield, Mars facts and Opportunity dust articles. It confirms the reported **0.67 mSv/day** at Gale Crater during **August 2012–June 2013**, a period without major solar storms affecting Mars. The game divides that historical average by 24 for its background hourly dose rate. It is not a current forecast or a universal surface value.

NASA's dust-shield article confirms a lunar demonstration on Blue Ghost Mission 1. It supports the cleaning mechanism concept; it does not establish the game's Mars cleaning rate, energy demand or suit implementation. The Opportunity article reports optical depth near 11 during the 2018 storm; that numerical summary belongs to the reference prototype's extreme-dust scenario, not a replayed native-game dataset. [Science sources and equations](SCIENCE.md) remain the detailed authority.

The game currently transcribes published numerical summaries. It does not ingest a raw instrument time series or calculate engineering-grade radiation transport. Stronger data integration should preserve the measured variable, site, observation interval, units, uncertainty and processing steps, and visibly distinguish gaps filled by synthetic scenario design.

## Privacy and maintenance boundaries

The source repository and release artifacts are intentionally public. Learner profiles and mission records stay local in the application; update requests retrieve public GitHub metadata and files. A network service still receives ordinary request metadata. No additional cloud tutor, sponsor API or account is required for play.

The source verification for this document requested only public official URLs. It did not upload project documents or learner data. Account-level retention settings of development services are separate from game code and cannot be enforced by this repository.

Keep the first mission as a regression fixture while expanding the experience. New graphics, sound, research integrations and models need a documented purpose, measurable acceptance checks, licenses, and an explicit way to remain offline. Add languages or external services for a demonstrated requirement, not as evidence of sophistication by themselves.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
