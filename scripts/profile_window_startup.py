#!/usr/bin/env python3
"""Fresh-process Linux window-startup evidence, never a target-device benchmark.

Runs the same external GDScript against either checkout. Memory checkpoints
precede all image/geometry readbacks; inventory and captures use other processes.
One warmup per backend is recorded but excluded from the repeated-run summary.
"""
import argparse
from contextlib import nullcontext
import datetime
import hashlib
import json
import os
from pathlib import Path
import platform
import re
import shutil
import statistics
import subprocess
import tempfile
import time

from verify_native_update_acceptance import private_display

ROOT = Path(__file__).resolve().parent.parent
HARNESS = ROOT / "game/tests/profile_window_startup.gd"


def digest(path):
    with Path(path).open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def rss(pid):
    result = {}
    try:
        lines = Path(f"/proc/{pid}/status").read_text().splitlines()
    except (FileNotFoundError, ProcessLookupError):
        return result
    for line in lines:
        match = re.match(r"^(VmRSS|VmHWM|RssAnon|RssFile|RssShmem):\s+(\d+) kB", line)
        if match:
            result[match[1] + "_bytes"] = int(match[2]) * 1024
    return result


def source_fingerprint(project):
    files = {}
    for path in sorted((project / "game").rglob("*")):
        if not path.is_file() or ".godot" in path.parts or "tests" in path.parts:
            continue
        files[str(path.relative_to(project))] = digest(path)
    tree = hashlib.sha256(json.dumps(files, sort_keys=True).encode()).hexdigest()
    return {"tree_sha256": tree, "files": files}


def run_process(project, directory, purpose, backend, executable, environment):
    directory.mkdir(parents=True)
    profile = tempfile.TemporaryDirectory(prefix="komaku-window-profile-")
    environment = environment | {"XDG_DATA_HOME": profile.name}
    command = [str(executable)]
    if backend == "headless":
        command.append("--headless")
    command += ["--path", str(project / "game"), "--script", str(HARNESS), "--", "--purpose", purpose, "--output", str(directory)]
    start = time.monotonic()
    peak = 0
    checkpoints = {}
    samples = 0
    host_load = os.getloadavg()
    with (directory / "process.log").open("w") as log:
        process = subprocess.Popen(command, env=environment, cwd=project, stdout=log, stderr=subprocess.STDOUT)
        try:
            while process.poll() is None:
                status = rss(process.pid)
                peak = max(peak, status.get("VmRSS_bytes", 0))
                samples += 1
                if purpose == "memory":
                    for phase in ["window", "full_world", "window_return"]:
                        marker = directory / f"checkpoint_{phase}.json"
                        if phase in checkpoints or not marker.exists():
                            continue
                        readings = []
                        for _ in range(5):
                            readings.append(rss(process.pid))
                            time.sleep(0.01)
                        checkpoint = json.loads(marker.read_text())
                        checkpoint["proc_samples"] = readings
                        checkpoint["rss_median_bytes"] = statistics.median(r["VmRSS_bytes"] for r in readings)
                        checkpoint["proc_hwm_bytes"] = max(r.get("VmHWM_bytes", 0) for r in readings)
                        checkpoint["process_wall_seconds_at_checkpoint"] = time.monotonic() - start
                        checkpoints[phase] = checkpoint
                        (directory / f"ack_{phase}").touch()
                if time.monotonic() - start > 180:
                    raise TimeoutError(f"Profile process timed out: {directory}")
                time.sleep(0.01)
        finally:
            if process.poll() is None:
                process.terminate()
                try:
                    process.wait(timeout=5)
                except subprocess.TimeoutExpired:
                    process.kill()
                    process.wait(timeout=5)
            profile.cleanup()
    text = (directory / "process.log").read_text()
    if process.returncode or "SCRIPT ERROR:" in text or "\nERROR:" in text:
        raise RuntimeError(f"Profile failed: {directory}\n{text[-8000:]}")
    if purpose == "memory" and len(checkpoints) != 3:
        raise RuntimeError("Missing memory checkpoints: " + str(directory))
    result = {"purpose": purpose, "backend": backend, "wall_seconds": time.monotonic() - start,
              "rss_poll_peak_bytes": peak, "rss_poll_samples": samples,
              "host_load_start": host_load, "checkpoints": checkpoints}
    (directory / "process.json").write_text(json.dumps(result, indent=2) + "\n")
    return result


def distribution(values):
    return {"n": len(values), "median": statistics.median(values), "min": min(values), "max": max(values), "values": values}


def summarize(runs):
    result = {}
    for backend in sorted({r["backend"] for r in runs}):
        group = [r for r in runs if r["backend"] == backend and not r["warmup"]]
        result[backend] = {}
        for phase in ["window", "full_world", "window_return"]:
            phases = [r["checkpoints"][phase] for r in group]
            measures = {"rss_bytes": distribution([p["rss_median_bytes"] for p in phases]),
                        "tree_nodes": distribution([p["tree_nodes"] for p in phases])}
            for key in ["construction_us", "ready_us", "reveal_us"]:
                if key in phases[0]:
                    measures[key] = distribution([p[key] for p in phases])
            result[backend][phase] = measures
    return result


def compare_evidence(report, baseline_file, output):
    # Pixel comparisons are numerical only; no modified/difference image is saved.
    from PIL import Image, ImageChops, ImageStat, __version__ as pillow_version
    baseline = json.loads(baseline_file.read_text())
    comparison = {"baseline": str(baseline_file), "candidate_label": report["label"],
                  "same_engine_binary": baseline["executable_sha256"] == report["executable_sha256"],
                  "same_harness": baseline["harness_sha256"] == report["harness_sha256"],
                  "same_runner": baseline["runner_sha256"] == report["runner_sha256"],
                  "same_driver_files": baseline["driver_files_sha256"] == report["driver_files_sha256"],
                  "pillow_version": pillow_version, "metrics": {}, "images": {},
                  "route_exactly_equal": baseline.get("route") == report.get("route"),
                  "field_notes_before": baseline.get("field_notes"), "field_notes_after": report.get("field_notes")}
    for backend, phases in report["summary"].items():
        comparison["metrics"][backend] = {}
        for phase, metrics in phases.items():
            result = {}
            for metric, values in metrics.items():
                before = baseline["summary"][backend][phase][metric]["median"]
                after = values["median"]
                result[metric] = {"before_median": before, "after_median": after,
                                  "change_percent": (after / before - 1) * 100 if before else None}
            comparison["metrics"][backend][phase] = result
    for name in ["window_initial", "full_world", "window_return", "field_notes_return"]:
        left = baseline_file.parent / "visual" / (name + ".png")
        right = output / "visual" / (name + ".png")
        if not left.exists() or not right.exists():
            continue
        with Image.open(left) as original, Image.open(right) as candidate:
            a, b = original.convert("RGB"), candidate.convert("RGB")
            if a.size != b.size:
                raise ValueError("Comparison captures have different viewport sizes")
            difference = ImageChops.difference(a, b)
            changed = sum(1 for pixel in difference.get_flattened_data() if pixel != (0, 0, 0))
            comparison["images"][name] = {"baseline_sha256": digest(left), "candidate_sha256": digest(right),
                "size": a.size, "changed_pixels": changed, "total_pixels": a.width * a.height,
                "changed_fraction": changed / (a.width * a.height),
                "mean_absolute_channel_difference_0_to_255": statistics.mean(ImageStat.Stat(difference).mean),
                "max_channel_difference": max(maximum for _, maximum in difference.getextrema())}
    (output / "comparison.json").write_text(json.dumps(comparison, indent=2) + "\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True)
    parser.add_argument("--label", required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--runs", type=int, default=3)
    parser.add_argument("--backends", default="headless,native")
    parser.add_argument("--godot", type=Path, default=Path(shutil.which("godot") or "godot"))
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--baseline", type=Path, help="Optional baseline report.json for numerical comparison; requires Pillow")
    args = parser.parse_args()
    if platform.system() != "Linux" or args.runs < 2:
        parser.error("Linux /proc and at least two measured runs are required")
    backends = args.backends.split(",")
    if any(b not in ["headless", "native"] for b in backends):
        parser.error("Backends must be headless,native")
    project = args.project.resolve()
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    executable = args.godot.resolve()
    source = source_fingerprint(project)
    libraries = {}
    for path in [Path("/usr/lib/x86_64-linux-gnu/libGLX_mesa.so.0"), Path("/usr/lib/x86_64-linux-gnu/dri/swrast_dri.so")]:
        if path.exists():
            libraries[str(path.resolve())] = digest(path.resolve())
    report = {"label": args.label, "utc": datetime.datetime.now(datetime.timezone.utc).isoformat(),
              "scope": "Linux warm-cache fresh processes. Not cold-disk, target-device FPS, Apple Silicon, total-system/GPU memory or child-playtest evidence.",
              "project": str(project), "executable": str(executable), "executable_sha256": digest(executable),
              "engine": subprocess.check_output([str(executable), "--version"], text=True).strip(),
              "harness_sha256": digest(HARNESS), "runner_sha256": digest(__file__), "source": source,
              "platform": platform.platform(), "driver_files_sha256": libraries,
              "cpu_affinity_count": len(os.sched_getaffinity(0)),
              "cpu_model": next((line.split(":", 1)[1].strip() for line in Path("/proc/cpuinfo").read_text().splitlines() if line.startswith("model name")), "unknown"),
              "cpu_quota": Path("/sys/fs/cgroup/cpu.max").read_text().strip() if Path("/sys/fs/cgroup/cpu.max").exists() else "unavailable",
              "viewport": [1280, 720], "runs": [],
              "measurement_notes": ["RSS sampled directly from /proc before any mesh-array or image readback.",
                  "Checkpoints use five RSS samples separated by 10ms. Startup readiness is eight process frames; construction is synchronous scene load/instantiate/add-child.",
                  "One excluded warmup per backend; repeated fresh processes share warm OS/import/shader caches.",
                  "External update query suppressed while its client node remains allocated. RNG fixed and ambient time scale zero for comparable scenes.",
                  "Optional geometry builds on first reveal and may remain cached when returning to window. Inventory and captures run in separate fresh processes.",
                  "Geometry channel bytes are estimates, not RSS. No headless MultiMesh transform or bounds readback."]}
    with tempfile.TemporaryDirectory(prefix="komaku-window-display-") as temp:
        display_root = Path(temp)
        (display_root / "logs").mkdir()
        context = private_display(display_root, args.xvfb, os.environ.copy()) if "native" in backends else nullcontext(os.environ.copy())
        with context as environment:
            for backend in backends:
                for index in range(args.runs + 1):
                    name = f"{backend}-{'warmup' if index == 0 else str(index)}"
                    print("PROFILE", args.label, name, flush=True)
                    result = run_process(project, output / name, "memory", backend, executable, environment)
                    result["warmup"] = index == 0
                    report["runs"].append(result)
            print("PROFILE", args.label, "inventory", flush=True)
            run_process(project, output / "inventory", "inventory", "headless", executable, environment)
            if "native" in backends:
                print("PROFILE", args.label, "visual", flush=True)
                run_process(project, output / "visual", "visual", "native", executable, environment)
        if (display_root / "logs/xvfb.log").exists():
            shutil.copyfile(display_root / "logs/xvfb.log", output / "xvfb.log")
    if digest(HARNESS) != report["harness_sha256"] or digest(__file__) != report["runner_sha256"]:
        raise RuntimeError("Measurement harness changed during profiling; discard and repeat")
    if source_fingerprint(project) != source:
        raise RuntimeError("Runtime source changed during profiling; discard and repeat after freeze")
    report["summary"] = summarize(report["runs"])
    report["inventory"] = json.loads((output / "inventory/inventory.json").read_text())
    if (output / "visual/route.json").exists():
        report["route"] = json.loads((output / "visual/route.json").read_text())
        report["field_notes"] = json.loads((output / "visual/field_notes.json").read_text())
    (output / "report.json").write_text(json.dumps(report, indent=2) + "\n")
    if args.baseline:
        compare_evidence(report, args.baseline.resolve(), output)
    print(json.dumps(report["summary"], indent=2), flush=True)


if __name__ == "__main__":
    main()
