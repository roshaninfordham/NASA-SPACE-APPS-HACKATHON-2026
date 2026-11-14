#!/usr/bin/env python3
"""Gate signed content against the actual previously published Linux installer.

The baseline ELF, its embedded PCK, class/UID registry and project configuration
are never modified. The Godot release template does not support --script, so an
installed matching Godot editor runs an external staging harness with --main-pack
pointing at the unchanged baseline ELF. That harness uses the ORIGINAL embedded
store/verifier/key, with an explicit production updates directory in isolated XDG
data. Normal boot, startup acknowledgment, repeated boot and corruption recovery
then run the actual old exported executable. No source re-export, substituted
trust key, private key, fake signature or production test hook is involved.

This tests resource compatibility on Linux, not updater networking, notification
UI, OS.create_instance, graphics/audio, Windows/macOS, or full gameplay health.
The startup acknowledgment is a narrow checkpoint, not a correctness guarantee.
The known previously published baseline archive is pinned below; adding another
historical baseline requires an independently reviewed archive hash and commit.

Requires Python 3.11+, OpenSSL, Godot 4.6.3, and complete downloaded release assets.
Example:
  python3 scripts/verify_baseline_update.py \
    --baseline-artifacts /tmp/red-veil-0.4.0-alpha.1 \
    --candidate-artifacts /tmp/red-veil-candidate \
    --expected-commit <40-hex-candidate-source-commit> \
    --keep-workspace /tmp/red-veil-previous-installer-acceptance
"""
import argparse
from contextlib import nullcontext
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import zipfile

from verify_native_update_acceptance import (
    ENGINE, UPDATE_NAMES, VERSION, digest, validate_artifacts, verify_signature,
)

PUBLISHED_BASELINE = {
    "version": "0.4.0-alpha.1",
    "commit": "48901d0bce68e72974b36377c3a060f90403ebe9",
    "linux_zip_sha256": "1aa8ccdf01d33e90cf4ae7c3d29abbabeff6e41083852d763a5d18b5a6d5cb30",
}


def version_order(value):
    match = VERSION.fullmatch(value)
    if match is None:
        raise ValueError("Invalid version")
    major, minor, patch, alpha = match.groups()
    return (int(major), int(minor), int(patch), alpha is None, int(alpha or 0))


def bounded_json(path, limit=8192):
    if path.is_symlink() or not path.is_file() or not 0 < path.stat().st_size <= limit:
        raise ValueError("Missing, linked or oversized state: " + str(path))
    value = json.loads(path.read_text())
    if not isinstance(value, dict):
        raise ValueError("Expected a JSON object: " + str(path))
    return value


def expect_journal(path, version, status):
    state = bounded_json(path)
    expected = {"schema": 1, "active": version, "previous": "", "status": status, "pid": 0, "token": ""}
    if state != expected:
        raise ValueError(f"Unexpected activation journal: {state!r}; expected {expected!r}")


def write_harness(workspace, candidate, baseline_version, target_version):
    script = workspace / "original-store-harness.gd"
    script.write_text('''extends SceneTree
# External test script: never embedded in either production artifact.
const Store = preload("res://updater/store.gd")
const EXPECTED_BASELINE = __BASELINE__
const EXPECTED_TARGET = __TARGET__
const ARTIFACTS = __ARTIFACTS__
const RESULT_PATH = __RESULT__
const KEY_PATH = __KEY__
func _initialize(): call_deferred("run")
func fail(reason: String) -> void:
    printerr("BASELINE_ACCEPTANCE_ERROR=", reason)
    quit(1)
func run() -> void:
    var baseline := str(ProjectSettings.get_setting("application/config/version", ""))
    if baseline != EXPECTED_BASELINE:
        fail("wrong embedded baseline version")
        return
    var key := CryptoKey.new()
    if key.load("res://updater/public_key.pem", true) != OK:
        fail("original installer key unavailable")
        return
    var output := FileAccess.open(KEY_PATH, FileAccess.WRITE)
    if output == null:
        fail("cannot write public-key evidence")
        return
    output.store_buffer(FileAccess.get_file_as_bytes("res://updater/public_key.pem"))
    output.close()
    var result := {"baseline": baseline, "user_dir": OS.get_user_data_dir(), "engine": Engine.get_version_info().string, "editor_staging_interpreter": OS.has_feature("editor")}
    if "--stage-candidate" in OS.get_cmdline_user_args():
        var store := Store.new("user://updates", baseline, key)
        var staged: Dictionary = store.stage(FileAccess.get_file_as_bytes(ARTIFACTS.path_join("update-manifest.json")), FileAccess.get_file_as_bytes(ARTIFACTS.path_join("update-manifest.sig")), ARTIFACTS.path_join("red-veil-content.pck"), baseline)
        if not staged.get("ok", false) or staged.get("version", "") != EXPECTED_TARGET:
            fail("original installer stage rejected: " + JSON.stringify(staged))
            return
        var activated: Dictionary = store.activate(EXPECTED_TARGET)
        if not activated.get("ok", false):
            fail("original installer activation rejected: " + JSON.stringify(activated))
            return
        result["staged"] = staged
        result["activated"] = activated
    output = FileAccess.open(RESULT_PATH, FileAccess.WRITE)
    if output == null:
        fail("cannot write acceptance evidence")
        return
    output.store_string(JSON.stringify(result))
    output.close()
    print("BASELINE_ACCEPTANCE_RESULT=", JSON.stringify(result))
    quit()
'''.replace("__BASELINE__", json.dumps(baseline_version))
     .replace("__TARGET__", json.dumps(target_version))
     .replace("__ARTIFACTS__", json.dumps(str(candidate)))
     .replace("__RESULT__", json.dumps(str(workspace / "harness-result.json")))
     .replace("__KEY__", json.dumps(str(workspace / "baseline-public.pem"))))
    return script


def acceptance(args):
    baseline_dir = args.baseline_artifacts.resolve(strict=True)
    candidate_dir = args.candidate_artifacts.resolve(strict=True)
    baseline = validate_artifacts(baseline_dir, PUBLISHED_BASELINE["commit"])
    candidate = validate_artifacts(candidate_dir, args.expected_commit)
    if baseline["version"] != PUBLISHED_BASELINE["version"]:
        raise ValueError("The baseline is not the independently pinned published version")
    archive_path = baseline_dir / f"Red-Veil-{baseline['version']}-Linux-x64.zip"
    if digest(archive_path) != PUBLISHED_BASELINE["linux_zip_sha256"]:
        raise ValueError("The baseline Linux installer differs from the pinned published bytes")
    if version_order(candidate["version"]) <= version_order(baseline["version"]):
        raise ValueError("Candidate must be strictly newer than the actual published baseline")
    if args.keep_workspace:
        workspace = args.keep_workspace.absolute()
        # Never merge into an existing profile, including through a symlink.
        workspace.mkdir(parents=True, exist_ok=False)
        context = nullcontext(str(workspace))
    else:
        context = tempfile.TemporaryDirectory(prefix="red-veil-published-baseline-")
    with context as location:
        workspace = Path(location).resolve()
        (workspace / "logs").mkdir()
        userdata = workspace / "userdata"
        userdata.mkdir()
        env = {key: value for key, value in os.environ.items() if key not in {"GH_TOKEN", "GITHUB_TOKEN", "RED_VEIL_UPDATE_SIGNING_KEY"}}
        env.update({"XDG_DATA_HOME": str(userdata), "XDG_CONFIG_HOME": str(workspace / "config"), "XDG_CACHE_HOME": str(workspace / "cache")})

        def phase(name, *command, timeout=180):
            log_path = workspace / "logs" / (name + ".log")
            try:
                result = subprocess.run(command, cwd=workspace, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, timeout=timeout)
            except subprocess.TimeoutExpired as error:
                output = error.stdout or b""
                log_path.write_text(output.decode(errors="replace") if isinstance(output, bytes) else output)
                raise ValueError("Timed out in " + name + "; see " + str(log_path)) from error
            log_path.write_text(result.stdout)
            if result.returncode or any(marker in result.stdout for marker in ["SCRIPT ERROR:", "\nERROR:", "BASELINE_ACCEPTANCE_ERROR="]):
                raise ValueError("Failed " + name + ":\n" + result.stdout[-12000:])
            print("PASS:", name, flush=True)
            return result.stdout

        executable = workspace / "Red-Veil.x86_64"
        with zipfile.ZipFile(archive_path) as archive:
            entries = [entry for entry in archive.infolist() if entry.filename == executable.name]
            if len(entries) != 1 or not 0 < entries[0].file_size <= 256 * 1024 * 1024:
                raise ValueError("Unexpected baseline executable archive entry")
            # Extract only a fixed filename: never trust archive paths or permissions.
            with archive.open(entries[0]) as source, executable.open("xb") as target:
                shutil.copyfileobj(source, target)
        executable.chmod(0o700)
        original_executable_hash = digest(executable)
        engine = phase("matching-staging-engine", args.godot, "--version").strip()
        if not engine.startswith(ENGINE + ".stable."):
            raise ValueError("Staging requires the baseline's exact Godot release series")
        harness = write_harness(workspace, candidate_dir, baseline["version"], candidate["version"])
        harness_command = (args.godot, "--headless", "--main-pack", str(executable), "--script", str(harness))
        phase("inspect-original-embedded-installer", *harness_command)
        evidence = bounded_json(workspace / "harness-result.json")
        profile = Path(evidence["user_dir"]).resolve()
        if evidence.get("baseline") != baseline["version"] or not profile.is_relative_to(userdata) or profile == userdata:
            raise ValueError("Embedded installer probe escaped isolation or changed baseline")
        key = workspace / "baseline-public.pem"
        verify_signature(baseline_dir, key, baseline)
        manifest = verify_signature(candidate_dir, key, candidate)
        print("PASS: both signatures match the original shipped installer key", flush=True)
        output = phase("untouched-published-baseline-start", str(executable), "--headless", "--", "--smoke-test")
        if f"RED_VEIL_SCENE_READY version={baseline['version']} " not in output:
            raise ValueError("Actual shipped installer did not start at its baseline version")
        phase("original-embedded-store-stage-and-activate", *harness_command, "--", "--stage-candidate")
        evidence = bounded_json(workspace / "harness-result.json")
        if evidence.get("staged", {}).get("version") != candidate["version"] or evidence.get("activated", {}).get("version") != candidate["version"]:
            raise ValueError("Original store did not stage and activate the exact candidate")
        journal = profile / "updates/state.json"
        expect_journal(journal, candidate["version"], "ready")
        installed = profile / "updates/slots" / candidate["version"] / "red-veil-content.pck"
        for name in UPDATE_NAMES:
            if digest(installed.parent / name) != digest(candidate_dir / name):
                raise ValueError("Staging changed signed candidate bytes: " + name)
        for name in ["published-installer-mounts-new-content", "published-installer-repeats-healthy-start"]:
            output = phase(name, str(executable), "--headless", "--", "--smoke-test")
            if f"RED_VEIL_SCENE_READY version={candidate['version']} " not in output:
                raise ValueError("Old shipped executable did not run the candidate main scene")
            expect_journal(journal, candidate["version"], "healthy")
        original_size = installed.stat().st_size
        with installed.open("r+b") as pack:
            pack.seek(-1, os.SEEK_END)
            byte = pack.read(1)
            pack.seek(-1, os.SEEK_END)
            pack.write(bytes([byte[0] ^ 1]))
            pack.flush()
            os.fsync(pack.fileno())
        if installed.stat().st_size != original_size or digest(installed) == manifest["pack_sha256"]:
            raise ValueError("Same-size corruption fixture was not applied")
        output = phase("corruption-restores-actual-published-baseline", str(executable), "--headless", "--", "--smoke-test")
        if f"RED_VEIL_SCENE_READY version={baseline['version']} " not in output:
            raise ValueError("Corrupted candidate did not restore the real published baseline")
        expect_journal(journal, "", "healthy")
        if digest(executable) != original_executable_hash:
            raise ValueError("Published baseline executable was modified during acceptance")
        result = {
            "status": "passed", "platform": "Linux x64, headless",
            "baseline_kind": "actual previously published installer; ELF and embedded PCK unchanged",
            "baseline_version": baseline["version"], "baseline_source_commit": baseline["commit"],
            "baseline_linux_zip_sha256": digest(archive_path), "baseline_executable_sha256": original_executable_hash,
            "target_version": candidate["version"], "source_commit": candidate["commit"],
            "pack_sha256": manifest["pack_sha256"], "runtime_contract": manifest["runtime_contract"],
            "staging": "matching Godot editor executes original embedded store/verifier/key via --main-pack; no modified resources",
            "checks": ["all release hashes and ZIP integrity", "independently pinned historical Linux installer archive", "both signatures verified against original embedded installer public key", "original embedded store stages exact signed candidate", "actual old installer mounts candidate and acknowledges startup", "actual old installer repeats healthy candidate start", "same-size tampering recovers actual published baseline", "original executable hash remains unchanged"],
            "not_verified": ["network transfer and update notification UI", "OS.create_instance automatic restart", "graphics/audio", "Windows/macOS/mobile", "full gameplay correctness or physical power-loss durability"],
        }
        (workspace / "acceptance-result.json").write_text(json.dumps(result, indent=2) + "\n")
        print(json.dumps(result, indent=2), flush=True)
        return result


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--baseline-artifacts", required=True, type=Path)
    parser.add_argument("--candidate-artifacts", required=True, type=Path)
    parser.add_argument("--expected-commit", required=True)
    parser.add_argument("--keep-workspace", type=Path, help="New directory only; preserves logs and isolated userdata")
    parser.add_argument("--godot", default="godot")
    args = parser.parse_args()
    try:
        acceptance(args)
    except (ValueError, OSError, KeyError, TypeError, zipfile.BadZipFile) as error:
        parser.exit(1, "Baseline update acceptance failed: " + str(error) + "\n")


if __name__ == "__main__":
    main()
