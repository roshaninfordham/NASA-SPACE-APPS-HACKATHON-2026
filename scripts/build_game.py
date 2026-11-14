#!/usr/bin/env python3
"""Validate and export distributable Godot alpha packages. Never publishes implicitly."""
import argparse
import hashlib
import json
import re
from pathlib import Path
import shutil
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "releases"
DOCS = ["CREDITS.md", "CHANGELOG.md", "docs/DOWNLOADS.md", "docs/SCIENCE.md", "docs/LEARNING-DESIGN.md", "docs/TEAM-STATUS.md"]


def run(*args):
    result = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "\nERROR:" in result.stdout:
        print(result.stdout)
        raise SystemExit(result.returncode or 1)
    print(result.stdout[-1200:])


def documents(archive):
    for file in DOCS:
        archive.write(ROOT / file, Path(file).name)
    for file in (ROOT / "game/licenses").iterdir():
        archive.write(file, "licenses/" + file.name)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", default="0.3.0-alpha.1")
    options = parser.parse_args()
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-alpha\.(0|[1-9][0-9]*))?", options.version):
        raise SystemExit("Invalid release version")
    configured = re.search(r'^config/version="([^"]+)"$', (ROOT / "game/project.godot").read_text(), re.MULTILINE)
    if not configured or configured[1] != options.version:
        raise SystemExit("Release version must match game/project.godot application/config/version")
    for folder in ["web", "linux", "windows"]:
        (OUT / folder).mkdir(parents=True, exist_ok=True)
    run("godot", "--headless", "--path", "game", "--editor", "--import")
    for test in ["mission_test", "learning_test", "gameplay_test", "art_contract_test"]:
        run("godot", "--headless", "--path", "game", "--script", f"res://tests/{test}.gd")
    run("python3", "scripts/test_updater.py")
    for platform in ["Web", "macOS", "Linux", "Windows"]:
        run("godot", "--headless", "--path", "game", "--export-release", platform)
    linux = OUT / "linux/Red-Veil.x86_64"
    linux.chmod(0o755)
    run(str(linux), "--headless", "--", "--smoke-test")
    assets = []
    prefix = f"Red-Veil-{options.version}"
    mac = OUT / f"{prefix}-macOS-universal.zip"
    shutil.copyfile(OUT / "Red-Veil-macOS-universal.zip", mac)
    with zipfile.ZipFile(mac, "a", compression=zipfile.ZIP_DEFLATED) as archive:
        documents(archive)
    assets.append(mac)
    for folder, suffix in [("linux", "Linux-x64"), ("windows", "Windows-x64"), ("web", "Web")]:
        output = OUT / f"{prefix}-{suffix}.zip"
        with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for file in sorted((OUT / folder).rglob("*")):
                if file.is_file():
                    archive.write(file, str(file.relative_to(OUT / folder)))
            documents(archive)
        assets.append(output)
    manifest = {"version": options.version, "commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "engine": "Godot 4.6.3", "status": "early alpha", "signing": "macOS and Windows unsigned; macOS not notarized", "verified": ["headless numerical tests", "headless complete mission interactions", "art replacement contract", "local learning and profile recovery", "signed manifest rejection checks", "exported Linux headless startup"], "not_verified": ["physical macOS and Windows launch", "M5 performance", "mobile devices", "child playtesting", "expert scientific review"], "assets": []}
    for asset in assets:
        with asset.open("rb") as source:
            digest = hashlib.file_digest(source, "sha256").hexdigest()
        manifest["assets"].append({"name": asset.name, "bytes": asset.stat().st_size, "sha256": digest})
    (OUT / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (OUT / "SHA256SUMS.txt").write_text("".join(f"{entry['sha256']}  {entry['name']}\n" for entry in manifest["assets"]))
    print(json.dumps(manifest, indent=2))


if __name__ == "__main__":
    main()
