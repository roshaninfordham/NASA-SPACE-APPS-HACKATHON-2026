# Validation record

## First-person Godot game

Verified with Godot 4.6.3 in the Linux build environment:

- Nine numerical checks: habitat energy conservation, separate suit/visor power, visibility and inspection, viable shelter/conservation policy, indoor suit behavior, calculated fixed-policy failure, unsheltered dose abort, and terminal-state invariance.
- Ten interaction checks: launch, HUD positioning, equipment proximity, held inspection, cleaning switch, conservation kiosk, physically entering refuge, pause, successful complete mission, and debrief.
- Art replacement contract: custom scene injection and detached snapshots do not change mission state.
- Headless full-scene startup and exported Linux binary startup.
- Web export opened and launched in Chromium with no captured browser errors. Screenshots exposed a HUD anchoring issue that was corrected and covered by the integration check.
- macOS universal export inspected for both arm64 and x86_64 Mach-O slices. This does not establish that it has launched on a Mac.

## Earlier web simulation prototype

- Eighteen model tests, including meaningful visor-cleaning trade-offs and the sourced Opportunity opacity scenario.
- Eight browser checks across desktop/mobile viewport configurations: interactions, complete mission and export, WebGL context loss/restoration, and automated WCAG checks on briefing, cockpit, and guide.
- Production offline reload and zero third-party runtime requests during the tested flow.

These accessibility results apply to the web prototype, not automatically to Godot's canvas UI.

## Release gates still open

- Physical MacBook M5 launch and profiling: frame pacing, memory, battery use, input, and thermal behavior.
- Windows desktop launch, broader Linux graphics coverage, and actual Safari/WebKit, iOS, and Android devices.
- Apple signing/notarization and Windows signing; native Android/iOS packaging.
- Native screen-reader accessibility, localization, portrait/mobile safe areas, and stronger controller-navigation coverage.
- Scientist/engineer review of shielding, energy, and atmosphere simplifications; current challenge and sponsor-rule verification.
- Supervised playtesting with ages 7–12 for comprehension, engagement, and learning transfer. No children have been recruited and no user-study results exist.
- Final design-team art, animation, audio direction, and optimized replacement assets.

## Measurable next targets

After a guided mission, aim for at least 80% of pilot participants to explain why clean panels may still generate little power under a dusty sky, and to distinguish suit energy from habitat energy. These are proposed acceptance criteria, not results.

Measure cached launch time, stable 30/60 fps presets, and memory across ten restarts on agreed physical devices. Set hard memory budgets from those observations. Software-rendered cloud Chromium is not a substitute for Apple Silicon GPU measurements.
