#!/usr/bin/env python3
"""Test signed content using unchanged public 0.6 Mac/Windows installers.

Runs only on a fresh native CI runner, refuses an existing player profile, and
cleans its newly created profile. Staging uses the matching editor with the
baseline's original resource pack/store/verifier/key; normal headless boots use
the original executable. This is not Finder/SmartScreen approval, networking,
graphical interaction, or OS.create_instance automatic-restart acceptance.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import plistlib
import re
import shutil
import subprocess
import urllib.request
import zipfile

from verify_baseline_update import bounded_json, expect_journal, version_order, write_harness
from verify_native_package import app_profile, scene_ready, validate_archive
from verify_native_update_acceptance import ENGINE, UPDATE_NAMES, digest, validate_artifacts, verify_signature

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
BASELINE = "0.6.0-alpha.1"
BASELINE_COMMIT = "c0beba698c32741fb17f6c8e9ec44fd6bb875852"


def download(url, path):
    with urllib.request.urlopen(url, timeout=120) as response, path.open("xb") as output:
        shutil.copyfileobj(response, output)


def fetch_baseline(folder):
    folder.mkdir()
    evidence = json.loads((ROOT / "docs/evidence/release-0.6.0-alpha.1.json").read_text(encoding="utf-8"))
    if evidence["version"] != BASELINE or evidence["source_commit"] != BASELINE_COMMIT:
        raise ValueError("Historical evidence identity changed")
    for entry in evidence["assets"]:
        name = entry["name"]
        if Path(name).name != name or "/" in name or "\\" in name:
            raise ValueError("Invalid pinned asset name")
        path = folder / name
        download(f"https://github.com/{REPOSITORY}/releases/download/v{BASELINE}/{name}", path)
        if path.stat().st_size != entry["bytes"] or digest(path) != entry["sha256"]:
            raise ValueError("Historical public asset differs from independently pinned evidence: " + name)
    return folder


def install_editor(workspace, system):
    name = f"Godot_v{ENGINE}-stable_" + ("macos.universal.zip" if system == "Darwin" else "win64.exe.zip")
    base = f"https://github.com/godotengine/godot-builds/releases/download/{ENGINE}-stable/"
    checksums = workspace / "godot-SHA512-SUMS.txt"
    download(base + "SHA512-SUMS.txt", checksums)
    expected = dict((parts[1].lstrip("*"), parts[0]) for line in checksums.read_text().splitlines() if len(parts := line.split()) == 2)
    archive = workspace / name
    download(base + name, archive)
    with archive.open("rb") as source:
        actual = hashlib.file_digest(source, "sha512").hexdigest()
    if actual != expected.get(name):
        raise ValueError("Godot editor checksum mismatch")
    extracted = workspace / "editor"
    extracted.mkdir()
    # Official macOS editor ZIP contains symlinks; ditto preserves its signed layout.
    if system == "Darwin":
        subprocess.run(["ditto", "-x", "-k", str(archive), str(extracted)], check=True)
        editor = extracted / "Godot.app/Contents/MacOS/Godot"
    else:
        validate_archive(archive)
        with zipfile.ZipFile(archive) as zipped:
            zipped.extractall(extracted)
        editor = extracted / f"Godot_v{ENGINE}-stable_win64_console.exe"
        if not editor.is_file():
            editor = extracted / f"Godot_v{ENGINE}-stable_win64.exe"
    if not editor.is_file():
        raise ValueError("Expected matching editor missing")
    return str(editor), {"archive": name, "sha512": actual, "source": base}


def acceptance(args):
    workspace = args.workspace.absolute()
    workspace.mkdir(parents=True, exist_ok=False)
    logs = workspace / "logs"
    logs.mkdir()
    report = {"passed": False, "system": platform.system(), "os": platform.platform(), "machine": platform.machine(),
              "checks": [], "not_verified": ["Finder/Gatekeeper/SmartScreen approval", "HTTP update transport and notification UI", "OS.create_instance automatic relaunch", "graphics/audio or physical-device gameplay"]}
    profile = None
    owned_profile = False
    try:
        system = platform.system()
        if system not in ("Darwin", "Windows"):
            raise ValueError("Requires a native Mac or Windows runner")
        candidate_dir = args.candidate_artifacts.resolve(strict=True)
        candidate = validate_artifacts(candidate_dir, args.expected_commit)
        if version_order(candidate["version"]) <= version_order(BASELINE):
            raise ValueError("Candidate must be newer than pinned baseline")
        baseline_dir = fetch_baseline(workspace / "baseline")
        baseline = validate_artifacts(baseline_dir, BASELINE_COMMIT)
        suffix = "macOS-universal" if system == "Darwin" else "Windows-x64"
        archive = baseline_dir / f"KOMAKU-Shield-Protocol-{BASELINE}-{suffix}.zip"
        validate_archive(archive)
        extracted = workspace / "original"
        extracted.mkdir()
        if system == "Darwin":
            subprocess.run(["ditto", "-x", "-k", str(archive), str(extracted)], check=True)
            apps = list(extracted.glob("*.app"))
            if len(apps) != 1:
                raise ValueError("Expected one original app")
            app = apps[0]
            info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
            name = info["CFBundleExecutable"]
            if Path(name).name != name or "/" in name or "\\" in name:
                raise ValueError("Invalid baseline executable name")
            executable = app / "Contents/MacOS" / name
            packs = list((app / "Contents/Resources").glob("*.pck"))
            if len(packs) != 1:
                raise ValueError("Expected one original resource pack")
            baseline_pack = packs[0]
        else:
            with zipfile.ZipFile(archive) as zipped:
                zipped.extractall(extracted)
            executable = extracted / "KOMAKU-Shield-Protocol.exe"
            baseline_pack = executable
        original_hashes = {str(path.relative_to(extracted)): digest(path) for path in extracted.rglob("*") if path.is_file()}
        profile = app_profile(system)
        if profile.exists() or profile.is_symlink():
            raise ValueError("Existing player profile: use a fresh runner; it will not be overwritten")
        owned_profile = True
        env = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN", "RED_VEIL_UPDATE_SIGNING_KEY"}}

        def phase(name, command, game=False):
            engine_log = logs / (name + "-engine.log")
            if game:
                command = command[:1] + ["--log-file", str(engine_log)] + command[1:]
            result = subprocess.run(command, cwd=workspace, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, encoding="utf-8", errors="replace", timeout=120)
            output = result.stdout
            if engine_log.exists():
                output += "\n" + engine_log.read_text(encoding="utf-8", errors="replace")
            (logs / (name + ".log")).write_text(output, encoding="utf-8")
            if result.returncode or any(marker in output for marker in ["SCRIPT ERROR:", "\nERROR:", "BASELINE_ACCEPTANCE_ERROR="]):
                raise ValueError("Failed " + name + ":\n" + output[-8000:])
            report["checks"].append(name)
            print("PASS: " + name, flush=True)
            return output

        editor, editor_evidence = install_editor(workspace, system)
        if not phase("matching-staging-engine", [editor, "--version"]).strip().startswith(ENGINE + ".stable."):
            raise ValueError("Wrong staging editor version")
        harness = write_harness(workspace, candidate_dir, BASELINE, candidate["version"])
        harness_command = [editor, "--headless", "--main-pack", str(baseline_pack), "--script", str(harness)]
        phase("inspect-original-installer", harness_command, game=True)
        evidence = bounded_json(workspace / "harness-result.json")
        if Path(evidence["user_dir"]).resolve() != profile.resolve() or evidence.get("baseline") != BASELINE:
            raise ValueError("Unexpected original profile or baseline version")
        key = workspace / "baseline-public.pem"
        verify_signature(baseline_dir, key, baseline)
        manifest = verify_signature(candidate_dir, key, candidate)
        report["checks"].append("both-signatures-match-original-shipped-key")

        def boot(name, expected_version):
            output = phase(name, [str(executable), "--headless", "--", "--smoke-test"], game=True)
            if not scene_ready(output, expected_version):
                raise ValueError("Original executable did not reach version " + expected_version)

        boot("untouched-public-baseline-start", BASELINE)
        phase("original-store-stage-and-activate", harness_command + ["--", "--stage-candidate"], game=True)
        journal = profile / "updates/state.json"
        expect_journal(journal, candidate["version"], "ready")
        installed = profile / "updates/slots" / candidate["version"] / "red-veil-content.pck"
        for name in UPDATE_NAMES:
            if digest(installed.parent / name) != digest(candidate_dir / name):
                raise ValueError("Changed staged bytes: " + name)
        for name in ("original-installer-mounts-candidate", "original-installer-repeats-healthy-start"):
            boot(name, candidate["version"])
            expect_journal(journal, candidate["version"], "healthy")
        length = installed.stat().st_size
        with installed.open("r+b") as pack:
            pack.seek(-1, os.SEEK_END)
            byte = pack.read(1)
            pack.seek(-1, os.SEEK_END)
            pack.write(bytes([byte[0] ^ 1]))
            pack.flush()
            os.fsync(pack.fileno())
        if installed.stat().st_size != length or digest(installed) == manifest["pack_sha256"]:
            raise ValueError("Corruption fixture failed")
        boot("same-size-tampering-restores-original-baseline", BASELINE)
        expect_journal(journal, "", "healthy")
        if original_hashes != {str(path.relative_to(extracted)): digest(path) for path in extracted.rglob("*") if path.is_file()}:
            raise ValueError("Original package files changed during acceptance")
        report.update(passed=True, baseline_version=BASELINE, baseline_source_commit=BASELINE_COMMIT,
                      baseline_archive_sha256=digest(archive), baseline_executable_sha256=digest(executable),
                      target_version=candidate["version"], source_commit=candidate["commit"],
                      pack_sha256=manifest["pack_sha256"], runtime_contract=manifest["runtime_contract"], editor=editor_evidence,
                      staging="Matching editor runs original packaged store/verifier/key; no source re-export or altered trust root",
                      scope="Unchanged public baseline executable; local signed artifacts; native headless mounting, healthy repeat startup and corruption fallback; fresh application profile")
    except Exception as error:
        report["error"] = str(error)
        print("Native content update acceptance failed: " + str(error), flush=True)
    finally:
        if owned_profile and profile is not None and profile.exists():
            shutil.rmtree(profile)
        (workspace / "acceptance-result.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    return 0 if report["passed"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--candidate-artifacts", required=True, type=Path)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--workspace", required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_commit):
        parser.error("Exact source SHA required")
    return acceptance(args)


if __name__ == "__main__":
    raise SystemExit(main())
