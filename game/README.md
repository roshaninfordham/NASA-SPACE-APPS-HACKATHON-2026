# Red Veil — first-person game

This is the primary game implementation, built with Godot 4.6.3. The JavaScript application at the repository root remains a simulation/reference prototype; it is not the chosen final game presentation.

Open `project.godot` in Godot 4.6.3 or run `godot --path game` from the repository root. Play as the astronaut: WASD/left stick to move, mouse/right stick to look, E/X to interact, Q/Y to toggle visor cleaning, Space/A to hop, Escape/Start to pause. Touch controls are included for landscape browser play, with physical mobile-device validation still required.

## Current playable scope

One four-minute Mars mission: inspect the solar array, manage panel and visor cleaning, conserve habitat power, physically reach a shielded refuge, and recover the outpost. Mira is the companion on the radio. Missions end in a debrief with a fixed-policy comparison. The latest mission summary is saved locally in Godot's application data directory; it is never uploaded.

## Modules

- `scripts/mission.gd`: pure numerical model and explicit units.
- `scripts/player.gd`: first-person movement, Mars gravity, camera, scanner.
- `scripts/world.gd`: provisional outpost, collision geometry, visual adapters.
- `scripts/game.gd`: mission orchestration, interaction routing, current HUD.
- `scripts/art_profile.gd` and `art/default_art.tres`: replaceable scenes and shared palette.
- `data/nasa-observations.json`: documented numerical observations, bundled offline.

## Design changes

The current geometry is provisional. The design team owns the evolving sci-fi direction: wondrous, futuristic, unconventional, playful, and memorable. Scientific constraints must stay explicit, while artistic treatment can change independently.

In `default_art.tres`, assign scene replacements for landscape, habitat, refuge, solar array, companion, and scanner. World scene replacements sit at documented anchors and preserve current collision geometry. A changed footprint or shelter volume is a gameplay change and must be revalidated. A replacement may implement `apply_mission_visuals(snapshot: Dictionary)` to animate from a detached state snapshot. It must not write mission rules.

The main game node also accepts a `hud_scene` and `interface_theme`. A custom HUD must provide unique-name nodes: HUD, Menu, Objective, Metrics, Radio, Prompt, Clock, Visor, Begin, Guide, and Sound. The generated fallback remains available when no replacement is assigned.

## Validation

```sh
godot --headless --path game --editor --import
godot --headless --path game --script res://tests/mission_test.gd
godot --headless --path game --script res://tests/gameplay_test.gd
godot --headless --path game --script res://tests/art_contract_test.gd
godot --headless --path game --script res://tests/learning_test.gd
python3 scripts/test_updater.py
godot --headless --path game -- --smoke-test
```

Native tests cover numerical invariants, a complete successful interaction sequence, pause behavior, viewport anchoring, and visual replacement without model mutation. Browser export has been opened in Chromium. macOS universal, Windows x64, Linux x64, and Web export presets are provided. Alpha 0.3.0-alpha.1 packages are published in GitHub Releases, including checksums and a source-commit manifest. Do not infer real-device validation from an export preset or a successful cross-export.

## Honesty about readiness

This is an early playable alpha, not final artwork or validated astronaut training. macOS and Windows exports have not yet been run on those operating systems. Apple signing/notarization, physical-device performance and input testing, scientific expert review, and age-appropriate playtesting remain outstanding. A transparent rules-based companion is used; no machine-learning model is claimed.

## Field Academy

The title menu and mission debrief open five short authored science lessons. `learning.gd` owns local practice estimates/review scheduling and a recoverable profile; `academy.gd` owns presentation; `data/lessons.json` owns the prompts. Hints and same-day repetition do not award independent evidence. The academy includes a confirmed reset. See [learning design](../docs/LEARNING-DESIGN.md) for research, parameters, and limits. This is a provisional tutor and presentation, not measured educational efficacy.

---

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
