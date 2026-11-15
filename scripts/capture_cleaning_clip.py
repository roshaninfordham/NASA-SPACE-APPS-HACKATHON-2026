#!/usr/bin/env python3
"""Capture six seconds of ordinary native gameplay, then encode its full frames."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from PIL import Image
from capture_journey import fingerprints
from verify_native_update_acceptance import private_display

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("/tmp/komaku-cleaning-clip"))
    parser.add_argument("--publish-to", type=Path)
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    before = fingerprints()
    with tempfile.TemporaryDirectory(prefix="komaku-cleaning-animation-") as temporary:
        work = Path(temporary)
        (work / "logs").mkdir()
        env_base = dict(os.environ) | {"XDG_DATA_HOME": str(work / "userdata")}
        with private_display(work, args.xvfb, env_base) as env:
            with (output / "capture.log").open("w") as log:
                result = subprocess.run([args.godot, "--path", str(ROOT / "game"), "--rendering-method", "gl_compatibility", "--script", "res://tests/capture_cleaning_clip.gd", "--", "--output", str(output)], env=env, text=True, stdout=log, stderr=subprocess.STDOUT, timeout=70)
    log_text = (output / "capture.log").read_text()
    print(log_text[-4000:])
    if result.returncode or "SCRIPT ERROR:" in log_text or "\nERROR:" in log_text: raise SystemExit(result.returncode or 1)
    record_path = output / "clip-provenance.json"
    record = json.loads(record_path.read_text())
    record["runtime_source_sha256"] = before
    record["source_changed_during_capture"] = before != fingerprints()
    if record["source_changed_during_capture"]: raise SystemExit("Runtime source changed; recapture before publishing")
    source_frames = record["frames"]
    # Preserve measured display duration rather than forcing a faster playback.
    durations = [max(20, round((source_frames[index+1]["wall_seconds"]-frame["wall_seconds"])*100)*10) if index+1 < len(source_frames) else 130 for index, frame in enumerate(source_frames)]
    images = []
    palette = None
    for frame in source_frames:
        path = output / frame["file"]
        frame["sha256"] = hashlib.sha256(path.read_bytes()).hexdigest()
        image = Image.open(path).convert("RGB").resize((640,360), Image.Resampling.LANCZOS)
        if palette is None: palette = image.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
        images.append(image.quantize(palette=palette,dither=Image.Dither.FLOYDSTEINBERG))
    gif = output / "cleaning-live.gif"
    images[0].save(gif, save_all=True, append_images=images[1:], duration=durations, loop=0, optimize=False, disposal=2)
    record["gif"] = {"file":gif.name,"sha256":hashlib.sha256(gif.read_bytes()).hexdigest(),"size":[640,360],"duration_ms":sum(durations),"frame_durations_ms":durations,"encoding":"Whole native frames downscaled with Lanczos and GIF palette quantization. Measured frame timing retained; no time-lapse or animation synthesis."}
    record_path.write_text(json.dumps(record, indent=2, ensure_ascii=False)+"\n")
    if args.publish_to:
        destination = args.publish_to.expanduser().resolve()
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(gif,destination/gif.name)
        shutil.copyfile(record_path,destination/"cleaning-live-provenance.json")
        (destination/"CLEANING-CLIP.md").write_text("""# Actual native cleaning motion

![Ren cleaning the visible panel during ordinary gameplay](cleaning-live.gif)

This silent clip shows approximately six seconds of the actual native game running its ordinary clock. Ren's hand and cleaning wand use the production animation, and the visible dust layer follows the mission model continuously. The clip starts from a documented fixture of 1.9 cleared sections and 16% game fatigue, after explicit Start, 60 active seconds at steady pace and 80 at the 1.25× setting. It uses no camera changes, hand-joint assignments, time-lapse or invented frames. The additional dust cleared during six seconds is deliberately modest.

The whole 960 × 540 viewport is scaled to 640 × 360 for this GIF, after a brief renderer warm-up. Playback retains the measured frame timing; a shared GIF palette changes image colour precision. This demonstrates native Linux animation, not performance on every device. See [`cleaning-live-provenance.json`](cleaning-live-provenance.json) for source hashes, frame hashes/timestamps, model start/end values and encoding details. Raw frame paths refer to the reproducible temporary capture directory, not bundled release assets.

Reproduce from the repository root:

```sh
python3 scripts/capture_cleaning_clip.py --output /tmp/komaku-cleaning-clip --publish-to docs/media/journey
```

Godot, Xvfb and Pillow are required. Use `--xvfb /path/to/Xvfb` when needed. Online requests are disabled in this capture fixture.
""")


if __name__ == "__main__":
    main()
