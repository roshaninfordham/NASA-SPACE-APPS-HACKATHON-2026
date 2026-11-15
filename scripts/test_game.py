#!/usr/bin/env python3
"""One authoritative native-game validation suite for development, CI and releases."""
import os
from pathlib import Path
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parent.parent
GODOT_SUITES = (
    "pace_mission_test", "pace_audit_test", "training_mission_test", "energy_audit_test", "live_solar_feed_test", "solar_panel_test", "training_panel_test", "training_astronaut_test", "journey_audio_test", "journey_progress_test",
    "navigation_policy_test", "journey_input_guard_test", "training_hud_test",
    "journey_shell_test", "journey_integration_test", "journey_update_ui_test",
    "mission_test", "learning_test", "gameplay_test", "art_contract_test",
    "design_world_test", "dialog_contract_test", "visual_style_test",
    "interior_spec_test", "exterior_spec_test", "suit_lab_test",
    "spec_integration_test", "mission_adviser_test", "mission_planner_test",
    "planner_integration_test", "clean_interface_test", "operator_rescue_test", "play_area_test", "window_presentation_test",
    "render_budget_test", "lazy_world_test", "lazy_exhibit_test", "update_client_test", "update_ui_test",
)
PYTHON_SUITES = ("test_release_tools.py", "test_publish_workflow.py", "test_native_package.py", "test_native_content_baselines.py")


def checked(command, environment):
    print("CHECK: " + " ".join(command), flush=True)
    result = subprocess.run(command, cwd=ROOT, env=environment, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=180)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "\nERROR:" in result.stdout:
        print(result.stdout, flush=True)
        raise RuntimeError("Game validation failed: " + " ".join(command))
    print(result.stdout[-1200:], flush=True)


def main():
    # The supported suite runner is Linux (native Mac/Windows package checks
    # use separate fresh-runner harnesses). Never touch a developer's profile.
    if not sys.platform.startswith("linux"):
        raise SystemExit("Run this full suite on Linux; use the documented native package gates on Mac/Windows.")
    with tempfile.TemporaryDirectory(prefix="komaku-game-suite-") as profile:
        environment = os.environ | {"XDG_DATA_HOME": profile}
        checked(["godot", "--headless", "--path", "game", "--editor", "--import"], environment)
        for suite in GODOT_SUITES:
            # Each executable suite owns a fresh player profile. Integration
            # persistence must not silently seed a later test's first launch.
            suite_environment = environment | {"XDG_DATA_HOME": str(Path(profile) / suite)}
            checked(["godot", "--headless", "--path", "game", "--script", f"res://tests/{suite}.gd"], suite_environment)
        checked([sys.executable, "scripts/build_science_guide.py", "--check"], environment)
        checked([sys.executable, "scripts/build_video_equations.py", "--check"], environment)
        for script in ("test_updater.py", "test_update_bootstrap.py"):
            checked([sys.executable, "scripts/" + script], environment)
        for suite in PYTHON_SUITES:
            checked([sys.executable, "-m", "unittest", "discover", "-s", "tests", "-p", suite], environment)
    print("PASS: complete shared native-game suite", flush=True)


if __name__ == "__main__":
    main()
