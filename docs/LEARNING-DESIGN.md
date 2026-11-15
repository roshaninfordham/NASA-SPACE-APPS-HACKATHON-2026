# Learning through exploration

<!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> serves ages 7–12. The child is the first-person astronaut; Mira is a companion. The aim is curiosity, useful feedback, and the desire to try another plan. The current academy is a small, offline prototype alongside one 3D mission, not a complete curriculum or a proven intelligent tutor.

## Implemented on main

Five field lessons cover separate batteries, surface versus atmospheric dust, passive shielding, energy reserves, and fair experiments. Each has two authored questions, four shuffled choices, an optional hint, a causal explanation, and a suggested action in the outpost. All lessons are available; Mira recommends a next concept or review. No lesson blocks the mission.

The title menu and mission debrief open the academy. A dose, suit, or habitat failure changes the recommended support topic without awarding or removing knowledge. Winning the game is not evidence of scientific understanding. This keeps accessibility, navigation skill, and learning evidence separate.

The interface, lesson data, review policy, and simulation have separate modules:

- `game/data/lessons.json`: editable, authored prompts and explanations.
- `game/scripts/learning.gd`: bounded local profile, question rotation, review policy, and estimate calculation.
- `game/scripts/academy.gd`: replaceable practice presentation; uses the shared palette/font profile and optional theme.
- `game/scripts/mission.gd`: mission equations; the tutor cannot alter them.

## Review algorithm and its limits

This is a hand-parameterized Bayesian knowledge-tracing prototype, not a trained neural network or calibrated ability measurement. For each concept, the starting estimate is 0.20, guess probability 0.25, slip probability 0.10, and learning transition 0.12. These are initial engineering choices requiring evaluation with the actual audience.

For prior estimate `p`, the posterior after an independent correct answer is:

```text
posterior = p × (1 − slip) / [p × (1 − slip) + (1 − p) × guess]
```

For an incorrect answer:

```text
posterior = p × slip / [p × slip + (1 − p) × (1 − guess)]
```

Then `next = posterior + (1 − posterior) × learn`, bounded to 0.01–0.99. Estimates are internal scheduling signals; the interface does not display them as grades or mastery percentages. Questions shown with a hint supply no independent evidence. Repeating the same question within 24 hours supplies no additional evidence. Returning to a new prompt checks transfer only in a very limited sense; two prompts cannot establish mastery.

New concepts are recommended first. Once each has an independent attempt, the earliest scheduled review is recommended. Reviews are due in one day after an incorrect answer or estimate below 0.55, three days below 0.80, and seven days otherwise. These intervals are a simple policy, not Duolingo's fitted half-life regression. There is no fitted forgetting curve or background notification. The device clock determines due dates; changing it may change review timing. It is not a trusted clock for competitive rewards.

## Research informing the design

| Source                                                                                                                                                                                                | Relevant idea                                                | What <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> actually uses                      |
| ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------- |
| Corbett & Anderson, _Knowledge tracing: Modeling the acquisition of procedural knowledge_, User Modeling and User-Adapted Interaction 4, 253–278 (1994), [DOI](https://doi.org/10.1007/BF01099821)    | Bayesian estimates updated from student responses            | A small, uncalibrated implementation of the response/transition equations; no copied package code          |
| Settles & Meeder, _A Trainable Spaced Repetition Model for Language Learning_, ACL 2016, [paper](https://aclanthology.org/P16-1174/)                                                                  | Duolingo research on predicting recall for spaced review     | Motivation for later recall and a future comparison baseline; half-life regression is not implemented      |
| Roediger & Karpicke, _Test-enhanced learning: Taking memory tests improves long-term retention_, Psychological Science 17(3), 249–255 (2006), [DOI](https://doi.org/10.1111/j.1467-9280.2006.01693.x) | Retrieval practice can support later retention               | Low-stakes predictions with explanation and later alternate questions; efficacy has not been measured here |
| [CAHLR/pyBKT](https://github.com/CAHLR/pyBKT)                                                                                                                                                         | Open-source fitting and analysis tools for knowledge tracing | Inspected as a future offline research tool; not bundled or executed in the game                           |

Evidence from language learning or laboratory memory tasks does not automatically transfer to children learning mission science. Before claiming benefit, run supervised usability sessions, pre/post concept checks, delayed recall, and comparison against a fixed review order. Check age/readability, hints, frustration, accessibility, and differences in device/control familiarity. See [playtesting](PLAYTEST.md).

## Local data and recovery

`user://learning-progress.json` contains concept identifiers, bounded estimates/counts, due timestamps, and last independent response times for the authored prompts. It contains no name, age, email, chat text, or account ID. Writes use a temporary file and rename, with a previous valid backup. A corrupt or oversized primary falls back to its backup or a fresh profile. The academy's confirmed reset removes primary, temporary, and backup copies. This is a local single-player profile; shared-device users currently share it. Browser storage can be cleared by the browser. It is not cloud sync or an encrypted profile.

No response, mission record, or learner profile is uploaded. A future cloud tutor must be a separate, optional feature with explicit product/privacy design. Cloudflare could host static releases or an API; Gemini could provide a constrained conversational layer. Neither is configured or required. Authored scientific feedback remains the baseline, and generated content must not silently change equations, invent safety rules, or be presented as verified research.

## Next experience work

Convert more predictions into tactile in-world experiments, expand authored levels and alternate problems, add suitable narration and audio controls, and test the reading burden with ages 7–12. Keep short sessions and voluntary review. No paid lives, streak-loss pressure, public child leaderboards, or claims of clinical/educational diagnosis. The practice screen remains provisional presentation for the design team.
