# <!-- brand:display_name -->KŌMAKU: Dust & Radiation<!-- /brand --> — simple video equations

[Download the landscape video sheet](media/KOMAKU-Video-Equations-Simple.pdf).

This is the word-only handoff for the bubble-combining video. The technical equation sheet remains separate and explains the same model with units and numerical examples. The video page contains no numerical values, equation indices, dates, or page numbers.

## Speed + Time → less Dust

**Panel cleaned = average cleaning speed × cleaning time**

In this game, tiredness can reduce the effective cleaning speed. Use the average effective speed across the cleaning time, not only the final slider setting.

## Dust → Power

**Solar power = clear-panel power × sunlight getting through dust**

Here, sunlight getting through dust means the **fraction** that gets through. Less dust lets the panel collect more useful sunlight.

## Power + Time → stored energy

**Energy stored = starting energy + energy collected − energy used**

Power is a rate; energy builds up over time. The battery has a capacity limit. In this mission's default settings, that limit does not alter the equation shown.

## Radiation + Time → Dose

**Absorbed dose = average radiation strength × time outside**

Use the average radiation dose rate across the outside time. This remains accurate when the rate changes; the final rate alone would give the wrong total.

## Shelter connects to outside time

**Shelter ends the outside-time count for this mission.**

This means the outside-dose activity ends when Ren enters. It does not mean radiation inside a real shelter is zero.

## Sievert stays a separate explanation

**Radiation type and body tissue matter.**

The game does not calculate a personal sievert reading or health score. Keep the Sievert bubble beside the chain as an explanation; do not convert the dose counter into a medical reading.

## Animation handoff

Connect Speed and Time to the Dust change. Connect Dust to Power. Let Power and Time explain stored energy. Connect Radiation and Time to Dose, with Shelter ending the outside-time count. Keep Sievert as a separate explanatory bubble. These are the eight concepts represented by the interface. The compact game labels may say **Clean pace**, **Energy**, and **Microgray** for Speed, Power/energy, and Dose. Stored energy is explained by power collected over time; it is not a ninth required bubble.

Use the four large equations as the primary video text. The smaller lines clarify effective speed, sunlight fraction, storage capacity, and changing radiation rate. The NASA solar-image view is not an input to this chain.

Rebuild this separate sheet with `python3 scripts/build_video_equations_simple.py`. The [technical handoff](VIDEO-EQUATIONS.md) and [science guide](SCIENCE-GUIDE.md) retain exact units, scenario assumptions, and implementation evidence.

Made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
