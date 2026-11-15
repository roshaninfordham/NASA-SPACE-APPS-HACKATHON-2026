#!/usr/bin/env python3
"""Test signed content using unchanged public 0.6 through 0.10 Mac/Windows installers.

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
from branding import archive_name, archive_stem, supplemental_asset_names

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
DEFAULT_BASELINE = "0.10.0-alpha.1"
# Independent immutable identities; evidence files supply the complete asset list.
BASELINES = {
    "0.6.0-alpha.1": {
        "source_commit": "c0beba698c32741fb17f6c8e9ec44fd6bb875852",
        "manifest_sha256": "9173582180b1fbc3625dd2bda4418500cd4f64778071e837517cc10ea572dc4c",
        "macOS-universal": "4c0caf99c2d39d8c178aa8733508aab56d389bc057ea59fb402e4195f4df77b7",
        "Windows-x64": "b559fef9e6f7372e95f75cb218e9452734afb7c9e8201aa7e9ef3ea799d70029",
    },
    "0.6.1-alpha.1": {
        "source_commit": "587d6c9fc7a5cd504b1c1ea68707628572bbbe4e",
        "manifest_sha256": "1f03cb4a0b79b2a86c67e5e4da6209cedd07a2adc2bca2456c1fb66711590175",
        "macOS-universal": "ee444fc6fc11ccef7d62a6d4f151ab5b051b3d42bd7a18f17258a69108364c7d",
        "Windows-x64": "6bb0249dc616528821dc2ec2bad9901b3f643ec2783b22ca2644107ea0872761",
    },
    "0.7.0-alpha.1": {
        "source_commit": "8968859e8ffdcda7b8c0c216ff0262df633400e6",
        "manifest_sha256": "1da540b47c4f5606aed074417470ebe9c508ab0e03903d12d10f63dfa3d49abf",
        "macOS-universal": "d132433260479b984981e707f9581c613b5e4117a4e11bccbc59415a6683b353",
        "Windows-x64": "068106d04e19b605377a564b3f48a90fd26481aac10a3d254903703dfeb33828",
    },
    "0.7.1-alpha.1": {
        "source_commit": "c86ad73da7810176e437e33e192a8d8475ae72a8",
        "manifest_sha256": "fa36a81713a0a5d8e1961f108a5379052c99f4336e8eef8c2264f1d93851799d",
        "macOS-universal": "d87e1770bb8e74fa2cb81a9e4e07142aec9dceb55bdcedd61abac4517dffb2e9",
        "Windows-x64": "0bcb0dcbd3ff95655b4c9666a0d15d065398b1ffa841943e09a04445268bb949",
    },
    "0.8.0-alpha.1": {
        "source_commit": "8b13e027ce5e0fa941a6bbeb1e09c5873b11baee",
        "manifest_sha256": "17598cbdaa9ed4d028e64ed886d9c723dd0a192f7c4ea4096698336a031619cf",
        "macOS-universal": "15feed5e21cc14e12ed8176cf97b505ca71a44acca66bd0cae809a09688fe749",
        "Windows-x64": "deadf7007d6c0b0e37eed8eca4474fa2c67bf4da3d0f18cd63d1438d137ab53d"
    },
    "0.9.0-alpha.1": {
        "source_commit": "40dbea61cc1690b3f45bce397e75aa1e582cfebd",
        "manifest_sha256": "c016d1d18303881f1a814f8cffaede6e6874b815fa1a0f6609b109c73c7e9a30",
        "macOS-universal": "6912d3478cbcacb7d29939b3133d9e75cd74a701cd4220f2e0ad80203e4278c8",
        "Windows-x64": "1fdaff22a94f92d7b9ce0e8f9d7ccee95930df29614bf34c9987a4af2919857f"
    },
    "0.10.0-alpha.1": {
        "source_commit": "26f19540baf330b00b0ac4a1b470d0e1439f7382",
        "manifest_sha256": "dbf95ccd9fd266070f04e8dafa8b73b62b931244d6525fbfdc5d71d682b01657",
        "macOS-universal": "7fc1e215980aa3f30d6f9ce1e5a395f115c6901c645817ff9d1d4054fbb7df95",
        "Windows-x64": "ae018f0ce8a13ea5a7d431393b960dc1c52fa77c056584361d8753c6d0e546be",
    },
}


def download(url, path):
    with urllib.request.urlopen(url, timeout=120) as response, path.open("xb") as output:
        shutil.copyfileobj(response, output)


def baseline_evidence(version):
    if version not in BASELINES:
        raise ValueError("Unsupported historical baseline")
    pinned = BASELINES[version]
    evidence = json.loads((ROOT / f"docs/evidence/release-{version}.json").read_text(encoding="utf-8"))
    if evidence.get("version") != version or evidence.get("source_commit") != pinned["source_commit"]:
        raise ValueError("Historical evidence identity changed")
    assets = evidence.get("assets", [])
    expected_names = {archive_name(version, suffix) for suffix in ("macOS-universal", "Windows-x64", "Linux-x64", "Web")} | UPDATE_NAMES | {"release-manifest.json", "SHA256SUMS.txt"} | supplemental_asset_names(version)
    if not isinstance(assets, list) or len(assets) != len(expected_names):
        raise ValueError("Historical evidence asset set changed")
    names = set()
    for entry in assets:
        if not isinstance(entry, dict) or entry.get("name") not in expected_names or entry["name"] in names:
            raise ValueError("Historical evidence contains missing, duplicate or unexpected assets")
        names.add(entry["name"])
        if type(entry.get("bytes")) is not int or entry["bytes"] <= 0 or not isinstance(entry.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
            raise ValueError("Invalid historical asset size or checksum")
    by_name = {entry["name"]: entry for entry in assets}
    pins = {"release-manifest.json": pinned["manifest_sha256"]}
    pins.update({archive_name(version, suffix): pinned[suffix] for suffix in ("macOS-universal", "Windows-x64")})
    if any(by_name[name]["sha256"] != expected for name, expected in pins.items()):
        raise ValueError("Historical evidence differs from independently pinned release bytes")
    return evidence


def fetch_baseline(folder, version):
    evidence = baseline_evidence(version)
    folder.mkdir()
    for entry in evidence["assets"]:
        name = entry["name"]
        path = folder / name
        download(f"https://github.com/{REPOSITORY}/releases/download/v{version}/{name}", path)
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
              "baseline_version": args.baseline, "checks": [], "not_verified": ["Finder/Gatekeeper/SmartScreen approval", "HTTP update transport and notification UI", "OS.create_instance automatic relaunch", "graphics/audio or physical-device gameplay"]}
    profile = None
    owned_profile = False
    try:
        system = platform.system()
        if system not in ("Darwin", "Windows"):
            raise ValueError("Requires a native Mac or Windows runner")
        baseline_version = args.baseline
        baseline_commit = baseline_evidence(baseline_version)["source_commit"]
        candidate_dir = args.candidate_artifacts.resolve(strict=True)
        candidate = validate_artifacts(candidate_dir, args.expected_commit)
        if version_order(candidate["version"]) <= version_order(baseline_version):
            raise ValueError("Candidate must be newer than pinned baseline")
        baseline_dir = fetch_baseline(workspace / "baseline", baseline_version)
        baseline = validate_artifacts(baseline_dir, baseline_commit)
        suffix = "macOS-universal" if system == "Darwin" else "Windows-x64"
        archive = baseline_dir / archive_name(baseline_version, suffix)
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
            executable = extracted / (archive_stem(baseline_version) + ".exe")
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
        harness = write_harness(workspace, candidate_dir, baseline_version, candidate["version"])
        harness_command = [editor, "--headless", "--main-pack", str(baseline_pack), "--script", str(harness)]
        phase("inspect-original-installer", harness_command, game=True)
        evidence = bounded_json(workspace / "harness-result.json")
        if Path(evidence["user_dir"]).resolve() != profile.resolve() or evidence.get("baseline") != baseline_version:
            raise ValueError("Unexpected original profile or baseline version")
        key = workspace / "baseline-public.pem"
        verify_signature(baseline_dir, key, baseline)
        manifest = verify_signature(candidate_dir, key, candidate)
        report["checks"].append("both-signatures-match-original-shipped-key")

        def boot(name, expected_version):
            output = phase(name, [str(executable), "--headless", "--", "--smoke-test"], game=True)
            if not scene_ready(output, expected_version):
                raise ValueError("Original executable did not reach version " + expected_version)

        boot("untouched-public-baseline-start", baseline_version)
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
        boot("same-size-tampering-restores-original-baseline", baseline_version)
        expect_journal(journal, "", "healthy")
        if original_hashes != {str(path.relative_to(extracted)): digest(path) for path in extracted.rglob("*") if path.is_file()}:
            raise ValueError("Original package files changed during acceptance")
        report.update(passed=True, baseline_version=baseline_version, baseline_source_commit=baseline_commit,
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
    parser.add_argument("--baseline", choices=tuple(BASELINES), default=DEFAULT_BASELINE, help=f"Immutable published installer to test (default: {DEFAULT_BASELINE})")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_commit):
        parser.error("Exact source SHA required")
    return acceptance(args)


if __name__ == "__main__":
    raise SystemExit(main())
