#!/usr/bin/env python3
"""Run the exact release ZIP on a fresh native macOS/Windows CI runner.

No editor, rebuild, re-signing, quarantine removal, or security-setting changes.
Graphical startup is recorded separately from the required headless check.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import re
import shutil
import signal
import stat
import subprocess
import tempfile
import time
import unicodedata
import zipfile

MARKER = "RED_VEIL_SCENE_READY"


def digest(path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def select_archive(distribution: Path, system: str, expected_manifest: str | None = None):
    manifest_path = distribution / "release-manifest.json"
    if manifest_path.is_symlink() or not manifest_path.is_file():
        raise ValueError("Manifest must be a regular file")
    manifest_sha = digest(manifest_path)
    if expected_manifest is not None and manifest_sha != expected_manifest:
        raise ValueError("Manifest checksum differs from the accepted build")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    version = manifest.get("version", "")
    if not isinstance(version, str) or not re.fullmatch(r"\d+\.\d+\.\d+(?:-alpha\.\d+)?", version):
        raise ValueError("Unsupported release version")
    if not re.fullmatch(r"[0-9a-f]{40}", manifest.get("commit", "")):
        raise ValueError("Manifest must identify an exact source commit")
    suffix = {"Darwin": "macOS-universal", "Windows": "Windows-x64"}[system]
    name = f"KOMAKU-Shield-Protocol-{version}-{suffix}.zip"
    entries = [entry for entry in manifest.get("assets", []) if entry.get("name") == name]
    if len(entries) != 1:
        raise ValueError("Manifest must declare exactly one native archive")
    entry = entries[0]
    path = distribution / name
    if path.is_symlink() or not path.is_file():
        raise ValueError("Archive must be a regular file")
    if path.stat().st_size != entry.get("bytes") or digest(path) != entry.get("sha256"):
        raise ValueError("Archive checksum or size differs from the manifest")
    expected_line = f"{entry['sha256']}  {name}"
    checksum_path = distribution / "SHA256SUMS.txt"
    if checksum_path.is_symlink() or checksum_path.read_text(encoding="utf-8").splitlines().count(expected_line) != 1:
        raise ValueError("Checksum list does not match the selected archive")
    return path, manifest, manifest_sha


def validate_archive(path: Path) -> None:
    """Reject traversal, links, devices, collisions and Windows path aliases."""
    seen = set()
    total = 0
    with zipfile.ZipFile(path) as archive:
        if not archive.infolist() or len(archive.infolist()) > 10000:
            raise ValueError("Invalid archive entry count")
        for item in archive.infolist():
            name = item.filename
            parts = PurePosixPath(name).parts
            mode = item.external_attr >> 16
            kind = stat.S_IFMT(mode)
            normalized = unicodedata.normalize("NFC", name.rstrip("/")).casefold()
            if (not parts or name.startswith("/") or "\\" in name or ":" in name
                    or any(part in ("", ".", "..") or part.endswith((".", " ")) for part in name.rstrip("/").split("/"))
                    or normalized in seen or item.flag_bits & 1
                    or kind not in (0, stat.S_IFREG, stat.S_IFDIR)):
                raise ValueError(f"Unsafe archive entry: {name!r}")
            if any(re.fullmatch(r"(?i)(CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?", p) for p in parts):
                raise ValueError(f"Windows reserved path: {name!r}")
            seen.add(normalized)
            total += item.file_size
        if total > 2_000_000_000:
            raise ValueError("Archive exceeds native package size limit")
        if archive.testzip() is not None:
            raise ValueError("Archive CRC check failed")


def run_command(args: list[str], folder: Path, label: str, commands: list, timeout: int = 90):
    result = {"label": label, "command": args, "timeout_seconds": timeout}
    started = time.monotonic()
    log_path = folder / f"{label}.log"
    try:
        with log_path.open("w", encoding="utf-8") as log:
            process = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT,
                                       start_new_session=platform.system() != "Windows")
            try:
                result["exit_code"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                if platform.system() == "Windows":
                    subprocess.run(["taskkill", "/PID", str(process.pid), "/T", "/F"], capture_output=True)
                    if process.poll() is None:
                        process.kill()
                else:
                    os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                result.update(exit_code=process.returncode, timed_out=True)
    except OSError as error:
        result.update(exit_code=None, error=str(error))
    result["elapsed_seconds"] = round(time.monotonic() - started, 3)
    result["log"] = str(log_path)
    result["output"] = log_path.read_text(encoding="utf-8", errors="replace") if log_path.exists() else ""
    commands.append(result)
    print(f"{label}: exit={result['exit_code']}, timeout={result.get('timed_out', False)}", flush=True)
    return result


def require_success(result: dict) -> str:
    if result.get("exit_code") != 0 or result.get("timed_out"):
        raise ValueError(f"Native check failed: {result['label']}")
    return result["output"]


def scene_ready(output: str, version: str) -> bool:
    return bool(re.search(re.escape(MARKER + " version=" + version) + r"\s+nodes=", output)) and not any(
        marker in output for marker in ("SCRIPT ERROR:", "\nERROR:", "Shader compilation failed"))


def app_profile(system: str) -> Path:
    if system == "Darwin":
        return Path.home() / "Library/Application Support/Godot/app_userdata/Red Veil"
    import ctypes
    buffer = ctypes.create_unicode_buffer(32768)
    # CSIDL_APPDATA is the actual roaming folder used by Godot's Windows port.
    if ctypes.windll.shell32.SHGetFolderPathW(None, 26, None, 0, buffer) != 0:
        raise ValueError("Cannot resolve the Windows app data directory")
    return Path(buffer.value) / "Godot/app_userdata/Red Veil"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--distribution", required=True, type=Path)
    parser.add_argument("--report", required=True, type=Path)
    parser.add_argument("--manifest-sha256")
    parser.add_argument("--require-graphical", action="store_true")
    args = parser.parse_args()
    report_path = args.report.resolve()
    report_path.parent.mkdir(parents=True, exist_ok=True)
    logs = report_path.parent / (report_path.stem + "-logs")
    logs.mkdir(exist_ok=False)
    system = platform.system()
    report = {"system": system, "os": platform.platform(), "machine": platform.machine(),
              "commands": [], "passed": False,
              "scope": "Exact native release executable startup on CI; not Finder approval, physical-device playtesting, or updater acceptance.",
              "trust": "Ad-hoc Mac signature is integrity only; no Developer ID/notarization. Windows executable is unsigned."}
    profile = None
    owned_profile = False
    try:
        if system not in ("Darwin", "Windows"):
            raise ValueError("Run this check on native macOS or Windows")
        archive, manifest, manifest_sha = select_archive(args.distribution.resolve(), system, args.manifest_sha256)
        report.update(version=manifest["version"], source_commit=manifest["commit"],
                      manifest_sha256=manifest_sha, archive=archive.name, archive_sha256=digest(archive))
        validate_archive(archive)
        profile = app_profile(system)
        if profile.exists() or profile.is_symlink():
            raise ValueError("Existing player profile detected: use a fresh CI runner; it will not be overwritten")
        report["profile"] = "Fresh application-specific profile; deleted after check"
        owned_profile = True
        with tempfile.TemporaryDirectory(prefix="komaku-native-") as temporary:
            extracted = Path(temporary) / "extracted"
            extracted.mkdir()
            if system == "Darwin":
                require_success(run_command(["ditto", "-x", "-k", str(archive), str(extracted)], logs, "extract", report["commands"]))
                apps = list(extracted.glob("*.app"))
                if len(apps) != 1:
                    raise ValueError("Archive must contain one app bundle")
                app = apps[0]
                info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
                executable_name = info["CFBundleExecutable"]
                if not isinstance(executable_name, str) or PurePosixPath(executable_name).name != executable_name or "\\" in executable_name:
                    raise ValueError("Invalid bundle executable name")
                executable = app / "Contents/MacOS" / executable_name
                require_success(run_command(["codesign", "--verify", "--deep", "--strict", "--verbose=4", str(app)], logs, "signature-verify", report["commands"]))
                run_command(["codesign", "--display", "--verbose=4", str(app)], logs, "signature-details", report["commands"])
                architectures = require_success(run_command(["lipo", "-archs", str(executable)], logs, "architectures", report["commands"]))
                if set(architectures.split()) != {"x86_64", "arm64"}:
                    raise ValueError("Mac app must contain both supported universal slices")
                report["gatekeeper"] = run_command(["spctl", "--assess", "--type", "execute", "--verbose=4", str(app)], logs, "gatekeeper-assessment", report["commands"])["exit_code"]
            else:
                with zipfile.ZipFile(archive) as zipped:
                    zipped.extractall(extracted)
                executable = extracted / "KOMAKU-Shield-Protocol.exe"
            if not executable.is_file() or executable.is_symlink():
                raise ValueError("Expected native executable is missing")
            for graphical in (False, True):
                label = "graphical-startup" if graphical else "headless-startup"
                engine_log = logs / (label + "-engine.log")
                command = [str(executable)] + ([] if graphical else ["--headless"])
                command += ["--log-file", str(engine_log), "--", "--smoke-test"]
                result = run_command(command, logs, label, report["commands"])
                output = result["output"]
                if engine_log.exists():
                    output += "\n" + engine_log.read_text(encoding="utf-8", errors="replace")
                passed = result["exit_code"] == 0 and not result.get("timed_out") and scene_ready(output, manifest["version"])
                report[label] = passed
                if not passed and (not graphical or args.require_graphical):
                    raise ValueError(f"{label} failed to reach the expected game version without engine errors")
            if system == "Windows":
                for name in ("libEGL.dll", "libGLESv2.dll"):
                    if not (extracted / name).is_file():
                        raise ValueError("Missing Windows graphics fallback library: " + name)
            # macOS restart uses LaunchServices; a raw executable launch alone
            # does not establish that the complete bundle can be opened there.
            label = "launchservices-startup" if system == "Darwin" else "angle-startup"
            engine_log = logs / (label + "-engine.log")
            command = (["open", "-W", "-n", str(app), "--args"] if system == "Darwin" else
                       [str(executable), "--rendering-driver", "opengl3_angle"])
            command += ["--log-file", str(engine_log), "--", "--smoke-test"]
            result = run_command(command, logs, label, report["commands"])
            output = engine_log.read_text(encoding="utf-8", errors="replace") if engine_log.exists() else ""
            passed = result["exit_code"] == 0 and not result.get("timed_out") and scene_ready(output, manifest["version"])
            report[label] = passed
            if not passed:
                raise ValueError(label + " did not reach the game without engine errors")
            report["passed"] = True
    except Exception as error:
        report["error"] = str(error)
        print(f"Native package verification failed: {error}", flush=True)
    finally:
        if owned_profile and profile is not None and profile.exists():
            shutil.rmtree(profile)
        report_path.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
        summary_path = os.environ.get("GITHUB_STEP_SUMMARY")
        if summary_path:
            with open(summary_path, "a", encoding="utf-8") as summary:
                summary.write(f"\n### Native {system} package check\n\nPassed: **{report['passed']}**. "
                              f"Headless: {report.get('headless-startup', False)}. Graphical: {report.get('graphical-startup', False)}.\n\n"
                              f"{report['scope']}\n\n{report['trust']}\n")
    return 0 if report["passed"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
