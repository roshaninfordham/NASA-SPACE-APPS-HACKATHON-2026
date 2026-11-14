#!/usr/bin/env python3
"""Diagnose the immutable public 0.6 Mac artifact; never publish or modify it.

Run on macOS with Python 3 and GitHub CLI. Diagnostic command failures are
recorded, not treated as infrastructure failures. Download/hash/archive failures
stop before extraction or execution. This is not a notarization or Finder test.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import platform
import plistlib
import shlex
import signal
import stat
import subprocess
import sys
import time
import zipfile


REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
VERSION = "0.6.0-alpha.1"
ASSET = f"KOMAKU-Shield-Protocol-{VERSION}-macOS-universal.zip"
SHA256 = "4c0caf99c2d39d8c178aa8733508aab56d389bc057ea59fb402e4195f4df77b7"
ASSET_BYTES = 62416350
APP_NAME = "KŌMAKU- Shield Protocol.app"
EXECUTABLE = "KŌMAKU- Shield Protocol"
MARKER = "RED_VEIL_SCENE_READY"
ALLOWED_PATHS = {
    f"{APP_NAME}/Contents/{path}"
    for path in (
        "Resources/icon.icns",
        "Resources/PrivacyInfo.xcprivacy",
        f"Resources/{EXECUTABLE}.pck",
        "PkgInfo",
        "Info.plist",
        f"MacOS/{EXECUTABLE}",
    )
} | {
    "CREDITS.md", "CHANGELOG.md", "DOWNLOADS.md", "SCIENCE.md",
    "LEARNING-DESIGN.md", "TEAM-STATUS.md", "UPDATES.md",
    "SPEC-IMPLEMENTATION.md", "licenses/Godot-MIT.txt",
    "licenses/Godot-THIRDPARTY.txt", "licenses/Kenney-MIT.txt",
    "licenses/Lilita-OFL.txt", "licenses/Kenney-ASSETS.md",
}


def validate_archive(archive: Path) -> list[dict]:
    """Require this known release's complete regular-file allowlist before ditto."""
    entries = []
    names: set[str] = set()
    with zipfile.ZipFile(archive) as zipped:
        for entry in zipped.infolist():
            path = PurePosixPath(entry.filename)
            mode = entry.external_attr >> 16
            if (
                path.is_absolute() or ".." in path.parts
                or "\\" in entry.filename or entry.filename not in ALLOWED_PATHS
                or entry.filename in names or not stat.S_ISREG(mode)
                or entry.flag_bits & 1
            ):
                raise ValueError(f"Unexpected or unsafe archive entry: {entry.filename!r}")
            names.add(entry.filename)
            entries.append({"path": entry.filename, "bytes": entry.file_size, "mode": oct(mode)})
        if names != ALLOWED_PATHS or sum(e["bytes"] for e in entries) > 250_000_000:
            raise ValueError("Archive contents differ from the pinned 0.6 allowlist")
        corrupt = zipped.testzip()
        if corrupt:
            raise ValueError(f"ZIP CRC failed: {corrupt!r}")
    return entries


def run_command(output: Path, report: dict, label: str, args: list[str], timeout: int = 60) -> dict:
    started = time.monotonic()
    result = {"label": label, "command": args, "timeout_seconds": timeout}
    log_path = output / "logs" / f"{label}.log"
    with log_path.open("w", encoding="utf-8") as log:
        log.write(f"$ {shlex.join(args)}\n")
        log.flush()
        try:
            process = subprocess.Popen(args, stdout=log, stderr=subprocess.STDOUT, start_new_session=True)
            try:
                result["exit_code"] = process.wait(timeout=timeout)
            except subprocess.TimeoutExpired:
                os.killpg(process.pid, signal.SIGKILL)
                process.wait()
                result.update(exit_code=process.returncode, timed_out=True)
        except OSError as error:
            result.update(exit_code=None, error=str(error))
            log.write(f"{error}\n")
    result["elapsed_seconds"] = round(time.monotonic() - started, 3)
    result["log"] = f"logs/{label}.log"
    result["scene_ready_marker"] = MARKER in log_path.read_text(encoding="utf-8", errors="replace")
    report["commands"].append(result)
    print(f"{label}: exit={result['exit_code']}, scene_ready={result['scene_ready_marker']}", flush=True)
    return result


def inspect_app(output: Path, report: dict, label: str, app: Path, launch: bool = True) -> None:
    commands = [
        ("codesign-display", ["codesign", "--display", "--verbose=4", str(app)]),
        ("codesign-verify", ["codesign", "--verify", "--deep", "--strict", "--verbose=4", str(app)]),
        ("gatekeeper-assess", ["spctl", "--assess", "--type", "execute", "--verbose=4", str(app)]),
        ("quarantine", ["xattr", "-lr", str(app)]),
    ]
    if launch:
        commands.append(("direct-smoke", [str(app / "Contents/MacOS" / EXECUTABLE), "--headless", "--", "--smoke-test"]))
    for suffix, args in commands:
        run_command(output, report, f"{label}-{suffix}", args)


def write_reports(output: Path, report: dict) -> None:
    (output / "report.json").write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    lines = [
        "# Published 0.6 macOS launch diagnosis", "",
        f"Artifact: `{ASSET}`", f"SHA-256: `{SHA256}`", "",
        "The original public archive is unchanged. Signing and quarantine experiments use copies.",
        "Direct headless execution tests engine startup, not Finder approval, graphics, or playability.",
        "Ad-hoc signing supplies bundle integrity; it does not establish Developer ID trust or notarization.",
        "This runner is not the user's M5/Tahoe machine. OS and architecture are captured in logs.", "",
        "| Check | Exit code | Scene ready | Timeout |", "| --- | --- | --- | --- |",
    ]
    for result in report["commands"]:
        lines.append(f"| {result['label']} | {result['exit_code']} | {result['scene_ready_marker']} | {result.get('timed_out', False)} |")
    if "fatal_error" in report:
        lines.extend(["", f"Fatal infrastructure error: {report['fatal_error']}"])
    summary = "\n".join(lines) + "\n"
    (output / "summary.md").write_text(summary, encoding="utf-8")
    if os.environ.get("GITHUB_STEP_SUMMARY"):
        with open(os.environ["GITHUB_STEP_SUMMARY"], "a", encoding="utf-8") as handle:
            handle.write(summary)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", required=True, type=Path)
    arguments = parser.parse_args()
    output = arguments.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    (output / "logs").mkdir()
    report: dict = {"repository": REPOSITORY, "version": VERSION, "asset": ASSET,
                    "expected_sha256": SHA256, "expected_bytes": ASSET_BYTES,
                    "python_platform": platform.platform(), "machine": platform.machine(), "commands": []}
    try:
        if sys.platform != "darwin":
            raise RuntimeError("Native macOS is required; Linux cannot validate macOS signatures or launch")
        evidence_path = Path(__file__).resolve().parents[1] / "docs/evidence/release-0.6.0-alpha.1.json"
        evidence = json.loads(evidence_path.read_text(encoding="utf-8"))
        asset = next(item for item in evidence["assets"] if item["name"] == ASSET)
        if evidence["version"] != VERSION or asset["sha256"] != SHA256 or asset["bytes"] != ASSET_BYTES:
            raise ValueError("Committed release evidence does not match immutable diagnostic pins")
        for label, command in (("os", ["sw_vers"]), ("architecture", ["uname", "-a"]),
                               ("hardware", ["system_profiler", "SPHardwareDataType"]),
                               ("gatekeeper-status", ["spctl", "--status"])):
            run_command(output, report, label, command)
        download = run_command(output, report, "download", ["gh", "release", "download", f"v{VERSION}",
                               "--repo", REPOSITORY, "--pattern", ASSET, "--dir", str(output)], timeout=180)
        if download["exit_code"] != 0:
            raise RuntimeError("Could not download the exact public release asset")
        archive = output / ASSET
        hasher = hashlib.sha256()
        with archive.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                hasher.update(chunk)
        digest = hasher.hexdigest()
        report["actual_sha256"] = digest
        report["actual_bytes"] = archive.stat().st_size
        if digest != SHA256 or archive.stat().st_size != ASSET_BYTES:
            raise ValueError("Public archive SHA-256/size mismatch; refusing to extract or execute")
        report["archive_entries"] = validate_archive(archive)
        original = output / "original"
        original.mkdir()
        extraction = run_command(output, report, "extract", ["ditto", "-x", "-k", str(archive), str(original)])
        if extraction["exit_code"] != 0:
            raise RuntimeError("ditto extraction failed")
        app = original / APP_NAME
        with (app / "Contents/Info.plist").open("rb") as handle:
            report["info_plist"] = plistlib.load(handle)
        executable = app / "Contents/MacOS" / EXECUTABLE
        if report["info_plist"].get("CFBundleExecutable") != EXECUTABLE or not os.access(executable, os.X_OK):
            raise ValueError("App executable name or executable permission is invalid")
        run_command(output, report, "executable-format", ["file", str(executable)])
        run_command(output, report, "executable-architectures", ["lipo", "-archs", str(executable)])
        inspect_app(output, report, "original", app)
        signed = output / "adhoc" / APP_NAME
        signed.parent.mkdir()
        copied = run_command(output, report, "copy-for-signing", ["ditto", str(app), str(signed)])
        if copied["exit_code"] != 0:
            raise RuntimeError("Could not create isolated signing copy")
        run_command(output, report, "adhoc-sign", ["codesign", "--force", "--deep", "--sign", "-", str(signed)])
        inspect_app(output, report, "adhoc", signed)
        # Apply quarantine only to the disposable signed copy, never to the
        # original archive and never by changing system-wide Gatekeeper policy.
        run_command(output, report, "adhoc-set-quarantine", ["xattr", "-r", "-w", "com.apple.quarantine",
                    f"0083;{int(time.time()):x};KOMAKUReleaseProbe;", str(signed)])
        inspect_app(output, report, "adhoc-quarantined", signed, launch=False)
        report["diagnostic_complete"] = True
        return 0
    except Exception as error:
        report["fatal_error"] = f"{type(error).__name__}: {error}"
        print(report["fatal_error"], file=sys.stderr)
        return 1
    finally:
        write_reports(output, report)


if __name__ == "__main__":
    raise SystemExit(main())
