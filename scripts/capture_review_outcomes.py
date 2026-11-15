#!/usr/bin/env python3
"""Capture real PASS/TRY AGAIN outcomes and the idle update menu for review."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

from capture_journey import fingerprints
from verify_native_update_acceptance import private_display

ROOT = Path(__file__).resolve().parent.parent
GAME_COMMIT = "26f19540baf330b00b0ac4a1b470d0e1439f7382"
HELPERS = ["game/tests/capture_review_outcomes.gd", "scripts/capture_review_outcomes.py"]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--xvfb", type=Path)
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    if output.exists():
        parser.error("Use a new output directory; existing captures are never overwritten.")
    before = fingerprints()
    for name, digest in before.items():
        recorded = subprocess.run(["git", "cat-file", "blob", f"{GAME_COMMIT}:{name}"], cwd=ROOT, check=True, capture_output=True).stdout
        if hashlib.sha256(recorded).hexdigest() != digest:
            raise SystemExit(f"Game capture input differs from {GAME_COMMIT}: {name}")
    helper_hashes = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in HELPERS}
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="komaku-review-outcomes-") as temporary:
        work = Path(temporary)
        (work / "logs").mkdir()
        (work / "user-data").mkdir()
        base = dict(os.environ) | {"XDG_DATA_HOME": str(work / "user-data")}
        with private_display(work, args.xvfb, base) as env:
            with (output / "capture.log").open("w") as log:
                result = subprocess.run([args.godot, "--path", str(ROOT / "game"), "--rendering-method", "gl_compatibility", "--script", "res://tests/capture_review_outcomes.gd", "--", "--output", str(output)], env=env, stdout=log, stderr=subprocess.STDOUT, timeout=120)
    log = (output / "capture.log").read_text()
    print(log[-8000:])
    if result.returncode or "SCRIPT ERROR:" in log or "\nERROR:" in log:
        raise SystemExit(result.returncode or 1)
    manifest_path = output / "capture-manifest.json"
    manifest = json.loads(manifest_path.read_text())
    after = fingerprints()
    helpers_after = {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in HELPERS}
    manifest.update(gameSourceCommit=GAME_COMMIT, source_sha256=before, helper_sha256=helper_hashes, source_changed_during_capture=before != after or helper_hashes != helpers_after)
    for record in manifest["captures"]:
        record["sha256"] = hashlib.sha256((output / record["file"]).read_bytes()).hexdigest()
    manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
    if manifest["source_changed_during_capture"] or manifest["failures"]:
        raise SystemExit("Capture is not publishable; inspect the source/fixture findings.")
    print(f"Verified {len(manifest['captures'])} native review screens from unchanged game {GAME_COMMIT}.")


if __name__ == "__main__":
    main()
