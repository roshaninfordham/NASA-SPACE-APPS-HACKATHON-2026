#!/usr/bin/env python3
"""Capture actual Suit Lab and habitat notes UI from the assembled Godot project.

Uses Mesa software rendering on a private authenticated Xvfb display. These are
UI/layout evidence, not a frame-rate benchmark or a comparison-image composite.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from verify_native_update_acceptance import private_display

ROOT = Path(__file__).resolve().parents[1]
GODOT_SCRIPT = '''extends SceneTree
func _initialize(): call_deferred("capture")
func capture():
    var args := OS.get_cmdline_user_args()
    var mode := args[0]
    var output := args[1]
    root.size = Vector2i(int(args[2]), int(args[3]))
    for i in range(5): await process_frame
    var game = load("res://main.tscn").instantiate()
    root.add_child(game)
    for i in range(8): await process_frame
    if mode == "suit": game.show_suit_lab()
    else: game.show_habitat_inspector()
    for i in range(12): await process_frame
    if not is_instance_valid(game.exhibit):
        push_error("Requested exhibit did not open")
        quit(1)
        return
    if mode == "habitat":
        var bounds := root.get_visible_rect()
        for control in [game.exhibit._card, game.exhibit._heading, game.exhibit._done]:
            if not bounds.encloses(control.get_global_rect()):
                push_error("Rendered habitat UI out of bounds: " + str(control.get_global_rect()))
                quit(1)
                return
    await RenderingServer.frame_post_draw
    var error := root.get_texture().get_image().save_png(output)
    print("SPEC_UI_CAPTURE ", mode, " window=", root.size, " viewport=", root.get_visible_rect().size)
    quit(error)
'''

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("/tmp/komaku-spec-review"))
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--layout", choices=["desktop", "portrait", "landscape", "all"], default="all")
    parser.add_argument("--mode", choices=["suit", "habitat", "all"], default="all")
    options = parser.parse_args()
    output = options.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    records = []
    with tempfile.TemporaryDirectory(prefix="komaku-spec-capture-") as temporary:
        work = Path(temporary)
        (work / "logs").mkdir()
        script = work / "capture.gd"
        script.write_text(GODOT_SCRIPT)
        with private_display(work, options.xvfb, os.environ.copy()) as env:
            for mode in (["suit", "habitat"] if options.mode == "all" else [options.mode]):
                for label, width, height in [("desktop", 1280, 720), ("portrait", 390, 844), ("landscape", 844, 390)]:
                    if options.layout != "all" and options.layout != label:
                        continue
                    name = f"{mode}-{label}"
                    image = output / (name + ".png")
                    command = [options.godot, "--path", str(ROOT / "game"), "--script", str(script), "--", mode, str(image), str(width), str(height)]
                    result = subprocess.run(command, env=env, text=True, capture_output=True, timeout=240)
                    log = result.stdout + "\n" + result.stderr
                    (output / (name + ".log")).write_text(log)
                    errors = result.returncode != 0 or "ERROR:" in log
                    record = {"view": mode, "size": [width, height], "file": image.name, "exit_code": result.returncode, "engine_errors": errors}
                    if image.exists():
                        record["sha256"] = hashlib.sha256(image.read_bytes()).hexdigest()
                        record["bytes"] = image.stat().st_size
                    records.append(record)
                    print(json.dumps(record), flush=True)
    evidence = {
        "capture": "Actual Godot assembled game; explicit exhibit opening and fixed viewport size",
        "renderer": "Mesa software OpenGL under private Xvfb; no performance claim",
        "source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(),
        "working_tree_changes": subprocess.check_output(["git", "status", "--short"], cwd=ROOT, text=True).splitlines(),
        "records": records,
    }
    (output / "capture.json").write_text(json.dumps(evidence, indent=2) + "\n")
    if any(record["engine_errors"] for record in records):
        raise SystemExit("Capture failed; inspect per-view logs")

if __name__ == "__main__":
    main()
