# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — demonstration script

The main mission and learning tour below use the published 0.6.1-alpha.1 baseline. The optional planner segment applies only to a build containing the later planner integration. Use the exact release version visible in the update screen and its release notes. Later source-only features must not be presented as part of an older installer. [Core proposal and judging evidence](CORE-PROPOSAL.md) · [Downloads](DOWNLOADS.md) · [Versioned media](MEDIA.md).

## Opening line

“You are a junior explorer on Mars. Dust is dimming the sky, a separate particle warning is approaching, and two batteries must keep your crew and outpost going. A cleaner panel is not always worth the energy. What will you change first?”

The audience is ages 7–12. Explain one decision at a time and let the player predict an outcome before giving the explanation. Use the product name **<!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand -->**; AEGIS is the fictional protection system inside the story.

## Preparation

Use a known release and rehearse on the actual presentation laptop. Check first launch, keyboard/mouse or controller, readable screen size, sound and mute controls. The 0.6.1 Mac app is ad-hoc signed but has no Apple Developer ID or notarization; Windows remains unsigned. Rehearse any trusted-download installation consent before the presentation. Native CI launch checks do not replace testing the actual presentation laptop. Keep a labeled local recording and the [source ledger](SCIENCE.md) available in case the venue's display or input setup fails.

Reset only a disposable demonstration learning profile, or use a separate local operating-system account. Do not erase a real player's progress. No live internet connection is required for the mission. Leave update installation until after the demonstration.

## Four-minute mission plus debrief

The timings below describe presentation beats, not guaranteed player timings or an automatic script. Pausing stops simulated mission time; use that space for explanation. The simulation represents twelve hours in four minutes and is not a physically coherent real-time engineering exercise.

| Beat                | Show and do                                                                                                                                                    | Explain or ask                                                                                                                                                         |
| ------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Before starting     | Point out **Begin Mission**, **Explore the Habitat**, **Explorer Suit Lab** and **Habitat Field Notes**                                                        | “The mission has a time limit; the other activities let you investigate at your own pace.”                                                                             |
| Early mission       | Start the mission, follow the route to the solar array and hold **E** to inspect. Briefly switch visor cleaning with **Q**, then switch it off                 | “Which battery powers this cleaner?” Show that the suit and habitat are separate stores. Clearer sight improves inspection, but costs suit energy                      |
| Early power choice  | Visit the power kiosk or control room and enable conservation with **E**                                                                                       | “We slow optional work to save power; essential life support stays on.” This trades nonessential activity for reserve rather than turning life support off             |
| Warning and retreat | Read Mira's warning and enter the **marked REFUGE** before the scenario's particle event. Do not substitute the open-window laboratory for the shielded refuge | “Installed material reduces exposure. It does not need a glowing shield switch.” The dust storm did not cause the particle event                                       |
| Darker sky          | Observe weather and habitat reserve. If showing cleaning, explain the switch and monitor its energy cost; do not leave it on merely for the effect             | “Cleaning removes dust on equipment. Can it remove dust floating high in the sky?” Invite a prediction before explaining                                               |
| Recovery and ending | Remain in the refuge and let the introductory scenario finish; show the actual outcome rather than promising success in advance                                | “Survival alone is not the full goal—we need enough reserve to recover.” If the attempt aborts, use its reason as the next experiment                                  |
| Debrief             | Show remaining energy, dose, inspection and survived time alongside the declared fixed baseline                                                                | “What changed in your plan?” The baseline starts sheltered with cleaning on and normal power; it is a declared example policy, not proof that one strategy always wins |

The automated gameplay check demonstrates that a sequence of inspection, conservation and shelter can succeed under this model. It does not establish that every live player will follow the route quickly enough. Do not conceal a failed attempt by claiming the game is rigged for success; show the reason and retry or use the labeled backup recording.

## Optional 60–90-second planner segment — later source build only

Use this segment only in a build that includes the native planner; the published 0.6.1 installer does not. Identify the demonstrated source/release. It adds explanation time while the four-minute mission clock is paused.

1. Start the mission and press **P**, or open **Pause → Compare mission plans**. Point to the one-simulated-hour preview and the paused mission. Ask: “Will cleaning leave us more battery at this moment?”
2. Compare **Normal work · cleaner off** with **Normal work · cleaner on**. Read the resulting energy, duration and status. Explain that this removes panel dust, not the dust in the sky, and the answer can change with the time and starting state. Do not promise that cleaning is always beneficial or always wasteful.
3. Compare the same cleaner setting with **Save power**. Read the optional-work consequence as well as stored energy. “We save energy by slowing extra work. Essential life support stays on.” A taller bar does not establish a better or safer plan.
4. Open **Show the maths and assumptions**. Show the separate suit battery and dose. “These are the same game equations for the same next hour under four choices. We stay in this place, do no new inspection, and keep the visor setting. Real forecasts are uncertain.” If a run stops early, explain its abort and duration before comparing reserves.
5. Ask the player to explain their choice, then select **Use this plan**. Only panel cleaning and conservation change. If opened from Pause, resume the restored pause menu. Walk to the refuge yourself before the scenario's particle event; the planner does not perform or validate that route.

A failed prediction is useful discussion, not a failed learner. Repeat at a different mission time only if safe within the scenario; do not claim a measured learning improvement from a single demonstration. For a short edited video, replace part of the power-choice/debrief footage with one clearly labeled planner comparison rather than pretending it exists in the older release.

## Optional two-minute learning tour

Open **Explorer Suit Lab**. Select front, back or a detail camera, then switch a cosmetic theme. Explain that the crane, wave and obi-inspired elements change presentation, not radiation physics. For one experiment, predict before running: compare a short and a long outside interval in the radiation exercise, or compare the net heat at less than, equal to and more than the toy plate's loss. Read the assumptions with the result. Do not describe the sliders as certified suit settings.

Open **Habitat Field Notes** and choose **Regolith**. Ask why added material might help, then read the explanation. Explain that actual attenuation depends on thickness, composition and particle energy. The architectural opening and airlock in this alpha are not a working pressure-cycle simulation. The learner can reach the four lessons through tabs even when an on-screen card obscures a projected anchor.

Finally open **Mira's Academy**, use a question or hint, and show a short causal explanation. The review plan is local and provisional. A correct answer, a successful mission or a completed experiment is not proof of long-term learning.

## Ninety-second recorded version

Use a clearly labeled edited recording of the same release. Do not imply that several minutes of mission evolution occurred live in ninety seconds.

| Time    | Shot and message                                                                                                                                                         |
| ------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| 0–12 s  | First-person view, Mira and the outpost. “A four-minute Mars engineering decision for ages 7–12.”                                                                        |
| 12–30 s | Inspect the array and switch visor cleaning. Point out the two batteries and the inspection benefit/cost                                                                 |
| 30–47 s | Cut to the darker sky. Contrast surface dust with atmospheric opacity and show power conservation                                                                        |
| 47–62 s | Enter the marked refuge; explain the independent particle warning and passive shielding                                                                                  |
| 62–78 s | Show the actual debrief, survived time and declared fixed comparator. Name one decision the player would change                                                          |
| 78–90 s | Show the NASA historical observation next to an explicitly illustrative game parameter. Close with the next evidence gate: science review and supervised learner testing |

Credit the team, engine and bundled licensed assets in the accompanying project page or video description. Show concept art only with a clear concept-art label; use actual game captures for claims about implemented behavior. [Media provenance](MEDIA.md) identifies what the existing screenshots and recordings demonstrate.

## Questions the team should be ready to answer

| Question                                   | Defensible answer                                                                                                                                                                                                                                              |
| ------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| What NASA data changes the simulation?     | The historical Curiosity surface dose-equivalent average supplies the background rate. The current native game does not replay a raw observational time series; emergency timelines and hardware parameters are illustrative                                   |
| Is this trained AI?                        | No. The academy uses provisional Bayesian scheduling signals and authored explanations. In builds that include the planner, it runs the actual deterministic mission equations locally for four fixed policies; no model training or cloud service is involved |
| What makes it different?                   | A first-person experiment connects habitat, suit and visor decisions with two energy stores and a declared outcome comparison. The specific implementation is the contribution; the underlying ideas are not claimed as unprecedented                          |
| Does it train real astronauts?             | It is an educational prototype for junior learners. Certified training, engineering validation and measured educational efficacy are not established                                                                                                           |
| Does it run well on every device?          | Desktop/Web packages and automated checks exist. Physical-device performance, native mobile distribution and broader input/accessibility testing remain separate gates                                                                                         |
| Will it win or qualify for sponsor awards? | No guarantee or eligibility claim is made. The official challenge/submission pages were still unavailable during the recorded source check, so current requirements must be confirmed before submission                                                        |

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
