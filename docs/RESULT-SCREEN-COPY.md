# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — result-screen copy

**Result-screen copy contract for the 0.10 presentation.** The result should appear when the short round ends, with a separate action for the animated equation reveal. This document fixes the meaning and words behind the visual design; it does not change the model or modify previously published releases.

Every completed round ends with Ren inside the shelter. The outcome comes from the actual fraction of the solar panel cleaned. Keep each screen encouraging, readable, and focused on one useful scientific connection.

## WIN

**Title:** You powered up the outpost!

**Message:** Ren is inside. The panel is mostly clear.

**Science connection:** Less dust → more sunlight → more solar power.

**Use when:** The clean fraction is at least 80%.

The title celebrates the cleaning goal. It does not mean the battery is full or that all real habitat life-support requirements have been certified.

## PASS

**Title:** Good progress, astronaut!

**Message:** Ren is inside. You cleared part of the panel.

**Science connection:** Dust left on the panel still blocked some sunlight.

**Use when:** The clean fraction is at least 40% and below 80%.

Tiredness here is the game's authored pace-dependent slowdown, not a measurement of a real person's body. The explanation describes a possible relationship; it should not claim that fatigue caused this particular result unless the recorded run supports that explanation.

## LOSE

**Title:** Try a new cleaning plan!

**Message:** Ren is inside. There is more dust to clear.

**Science connection:** A balanced pace can remove more dust before the storm.

**Use when:** The clean fraction is below 40%.

Keep the presentation supportive. The result means the cleaning target was missed; it does not mean Ren was injured, the battery failed, or the outpost lost life support.

## Shared result readings

Use the same three readings on every outcome screen, populated from that run:

| Label               | Value to show           | Meaning                                                               |
| ------------------- | ----------------------- | --------------------------------------------------------------------- |
| Panel cleaned       | Actual clean percentage | Completed work divided by total task work.                            |
| Energy stored       | Actual stored kWh       | Accumulated battery energy at the end, not final power or a forecast. |
| Absorbed model dose | Actual recorded µGy     | The simulation's integrated dose; not a personal medical measurement. |

Classify the outcome from the underlying clean fraction **before display rounding**. A rounded percentage must not silently move a result into another band. Preserve consistent precision and readable units across outcomes.

All completed default rounds share the same outside duration and radiation curve, so they have the same model dose. Do not award lower-dose stars, imply that a WIN has a healthier dose, or use dose as an additional hidden success condition. Do not calculate a personal sievert reading or health score.

## Shared actions

- **See how science connects** — open the explanation using the player's recorded result.
- **Try another plan** — return to a fresh preflight state so the player can choose a starting pace.
- **Home** — return to the game's main navigation.

Keep these labels and their order consistent across WIN, PASS, and LOSE. The equation view includes **Back to results**. Four brief visual relationships appear first; **Explore my numbers and graphs** opens the exact equations, recorded history and optional practice. Result meters show cleaning and stored energy, never a dose-as-health bar. The bubble animation may be skipped or reduced without hiding the equations or trapping navigation. The team's visual theme can change colours, illustrations, motion, and layout without changing the outcome rules or the meaning of the readings. Do not rely on colour or sound alone to communicate the result.

## Equation reveal and factual boundaries

Use the [simple video equations](VIDEO-EQUATIONS-SIMPLE.md) for the short explanation and the [technical handoff](VIDEO-EQUATIONS.md) for exact formulas. Speed and Time explain cleaning; Dust changes solar Power; power over Time changes stored energy; Radiation over outside Time accumulates Dose. Shelter ends the outside-time count. Sievert stays a separate explanation about radiation type and body tissue, not a computed health score.

For a changing cleaning pace, show **average effective cleaning rate × cleaning time**, not the final slider value multiplied by the whole round. For the increasing radiation curve, use **average radiation dose rate × outside time**. Solar power is **clear-panel power × sunlight transmission**; do not multiply by dust again. Use actual result readings rather than the design image’s example values.

The default battery receives more solar power than the habitat load throughout the round. A lower cleaning result therefore must not be described as a battery failure. The real NASA solar-image view is educational observation, not an input that determined this outcome.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
