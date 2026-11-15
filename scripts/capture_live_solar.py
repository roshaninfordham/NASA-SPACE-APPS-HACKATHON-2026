#!/usr/bin/env python3
"""Opt-in native screenshot of a validated NASA SDO response. Never disables TLS."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from capture_journey import fingerprints
from verify_native_update_acceptance import live_network_environment, private_display

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("/tmp/komaku-live-solar-capture"))
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--publish-to", type=Path, help="Copy the actual desktop NASA view, response metadata and attribution")
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_before = fingerprints()
    network = live_network_environment()
    with tempfile.TemporaryDirectory(prefix="komaku-live-solar-") as temporary:
        work = Path(temporary)
        (work / "logs").mkdir()
        base = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN", "RED_VEIL_UPDATE_SIGNING_KEY"}}
        base.update({"XDG_DATA_HOME": str(work / "userdata"), "KOMAKU_SOLAR_LIVE_PROBE": "1", "KOMAKU_SOLAR_PROXY_HOST": network["RED_VEIL_PROXY_HOST"], "KOMAKU_SOLAR_PROXY_PORT": network["RED_VEIL_PROXY_PORT"], "KOMAKU_SOLAR_CA_BUNDLE": network["RED_VEIL_NETWORK_CA"]})
        with private_display(work, args.xvfb, base) as env:
            with (output / "capture.log").open("w") as log:
                result = subprocess.run([args.godot, "--path", str(ROOT / "game"), "--rendering-method", "gl_compatibility", "--script", "res://tests/capture_live_solar.gd", "--", "--output", str(output)], env=env, text=True, stdout=log, stderr=subprocess.STDOUT, timeout=50)
    log_text = (output / "capture.log").read_text()
    print(log_text[-5000:])
    if result.returncode or "SCRIPT ERROR:" in log_text or "\nERROR:" in log_text:
        raise SystemExit(result.returncode or 1)
    record_path = output / "live-sun-provenance.json"
    record = json.loads(record_path.read_text())
    record["runtime_source_sha256"] = source_before
    record["source_changed_during_capture"] = source_before != fingerprints()
    record["screenshot_sha256"] = {name: hashlib.sha256((output / name).read_bytes()).hexdigest() for name in record["screenshots"]}
    record_path.write_text(json.dumps(record, indent=2, ensure_ascii=False) + "\n")
    if record["source_changed_during_capture"]:
        raise SystemExit("Capture is valid QA, but runtime sources changed; rerun before publishing media.")
    if args.publish_to:
        destination = args.publish_to.expanduser().resolve()
        destination.mkdir(parents=True, exist_ok=True)
        name = "live-sun-desktop.png"
        shutil.copyfile(output / "live-sun-1280x720.png", destination / name)
        published = record.copy()
        published["screenshots"] = [name]
        published["screenshot_sha256"] = {name: hashlib.sha256((destination / name).read_bytes()).hexdigest()}
        published["reviewed_viewports"] = [[1280,720],[390,844],[844,390]]
        (destination / "live-sun-provenance.json").write_text(json.dumps(published, indent=2, ensure_ascii=False) + "\n")
        (destination / "LIVE-SUN.md").write_text("""# Actual NASA SDO viewer capture

![Live NASA solar image in the native viewer](live-sun-desktop.png)

Courtesy of NASA/SDO and the AIA, EVE, and HMI science teams.

This screenshot displays a validated HTTP 200 response from NASA's fixed [SDO AIA 193 Å browse-image endpoint](https://sdo.gsfc.nasa.gov/assets/img/latest/latest_512_0193.jpg), using the production native viewer. The whole source image remains visible, including its embedded timestamp. It is an extreme-ultraviolet, false-colour image of the solar corona. Its brightness is not a Mars radiation reading, storm prediction or medical risk score, and the viewer does not alter mission calculations.

[`live-sun-provenance.json`](live-sun-provenance.json) records the source-image SHA-256, received bytes, server file-update metadata, actual successful fetch time, TLS verification, viewport review and runtime source hashes. HTTP Last-Modified is file metadata, not independently verified camera exposure time. This capture demonstrates one successful NASA connection in the Linux native environment; service freshness, availability and other devices can differ.

Read [NASA's data context](https://sdo.gsfc.nasa.gov/data/) and [data-use rules](https://sdo.gsfc.nasa.gov/data/rules.php). The game also labels cached, old and bundled imagery explicitly.

To make a new real-network capture from the repository root:

```sh
python3 scripts/capture_live_solar.py --output /tmp/komaku-live-solar-capture --publish-to docs/media/journey
```

Add `--xvfb /path/to/Xvfb` when needed. The managed-network proxy adapter uses the configured certificate bundle and keeps TLS certificate verification enabled. No API key is used. General journey screenshots use a separate offline fixture so their capture does not trigger uncontrolled network requests.
""")


if __name__ == "__main__":
    main()
