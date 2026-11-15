"""Capture the actual offline main scene and new guide, using an isolated profile."""
import argparse
import hashlib
import json
import os
import subprocess
import tempfile
from pathlib import Path
from capture_journey import fingerprints
from verify_native_update_acceptance import private_display
ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=ROOT / "docs/media/offline-polish")
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = fingerprints()
    with tempfile.TemporaryDirectory(prefix="komaku-polish-") as tmp:
        work = Path(tmp)
        (work / "logs").mkdir()
        environment = os.environ | {"XDG_DATA_HOME": str(work / "profile")}
        with private_display(work, args.xvfb, environment) as env:
            result = subprocess.run([
                args.godot, "--path", str(ROOT / "game"), "--rendering-method", "gl_compatibility",
                "--script", "res://tests/capture_offline_polish.gd", "--", str(output),
            ], env=env, capture_output=True, text=True, timeout=180)
    log = result.stdout + result.stderr
    if result.returncode or "SCRIPT ERROR:" in log or "\nERROR:" in log:
        raise RuntimeError(log)
    if before != fingerprints():
        raise RuntimeError("Sources changed while capturing")
    provenance = {
        "method": "Actual Godot main scene, Balanced graphics; deterministic 36-second model fixture, paused for capture; no human playtest or hardware FPS claim. Offline default, no cloud coach.",
        "source_sha256": before,
        "capture_script_sha256": hashlib.sha256((ROOT / "game/tests/capture_offline_polish.gd").read_bytes()).hexdigest(),
        "images": {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in output.glob("*.png")},
    }
    (output / "provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
    print(result.stdout)


if __name__ == "__main__":
    main()
