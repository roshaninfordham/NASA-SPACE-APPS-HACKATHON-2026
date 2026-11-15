#!/usr/bin/env python3
"""Capture actual KŌMAKU journey screens with isolated user data and Xvfb.

This is a visual fixture, not a timing, hardware or release-installation test.
The JSON manifest records all direct screen intents and model advancement.
"""
import argparse
import hashlib
from html import escape
import json
import os
from pathlib import Path
import shutil
import shlex
import subprocess
import tempfile

from verify_native_update_acceptance import private_display
from branding import brand

ROOT = Path(__file__).resolve().parent.parent
SOURCE_FILES = ["game/main.tscn", "game/scripts/journey_game.gd", "game/scripts/pace_mission.gd", "game/scripts/journey_progress.gd", "game/ui/journey_shell.gd", "game/ui/training_hud.gd", "game/ui/concept_orb.gd", "game/ui/journey_style.gd", "game/data/mission-concepts.json", "game/art/red_veil/training_panel.gd", "game/art/red_veil/training_panel.gdshader", "game/art/red_veil/astronaut.gd"]


def fingerprints():
    sources = set(SOURCE_FILES) | {"game/project.godot", "game/tests/capture_journey.gd", "scripts/capture_journey.py", "game/tests/capture_cleaning_clip.gd", "scripts/capture_cleaning_clip.py", "scripts/branding.py"}
    extensions = {".gd", ".gdshader", ".tscn", ".tres", ".json", ".ttf", ".otf", ".png", ".jpg", ".svg", ".webp", ".glb", ".obj", ".ogg", ".wav", ".mp3"}
    for path in (ROOT / "game").rglob("*"):
        relative = path.relative_to(ROOT)
        if path.is_file() and path.suffix.lower() in extensions and not {".godot", "tests"}.intersection(relative.parts):
            sources.add(str(relative))
    return {name: hashlib.sha256((ROOT / name).read_bytes()).hexdigest() for name in sorted(sources)}


def publish_selected(output, destination, manifest):
    """Copy actual captures and compose a labeled, scaled review contact sheet."""
    from PIL import Image, ImageDraw, ImageFont
    if manifest["source_changed_during_capture"] or manifest["layout_failures"]:
        raise ValueError("Publish only an unchanged-source capture with no layout findings")
    destination.mkdir(parents=True, exist_ok=True)
    selection = [
        ("01-story-1280x720.png", "story-desktop.png", "Story"),
        ("04-preflight-1280x720.png", "preflight-desktop.png", "Control room · before Start"),
        ("03-concept-1280x720.png", "concept-desktop.png", "Microgray science card"),
        ("04-cleaning-1280x720.png", "mission-desktop.png", "Window frame, eight live ideas and pace"),
        ("08-debrief-1280x720.png", "debrief-desktop.png", "Immediate mission result"),
        ("04-cleaning-390x844.png", "mission-portrait.png", "Portrait mission"),
    ]
    records = []
    canvas = Image.new("RGB", (1440, 752), "#0b141b")
    draw = ImageDraw.Draw(canvas)
    face = str(ROOT / "game/assets/fonts/journey/Jost-Variable.ttf")
    title_font = ImageFont.truetype(face, 32)
    label_font = ImageFont.truetype(face, 20)
    detail_font = ImageFont.truetype(face, 17)
    draw.text((24, 14), brand()["display_name"] + " — native journey", font=title_font, fill="#fbf1ee")
    draw.text((24, 54), "Actual game captures · deterministic visual fixture · Godot / Linux compatibility renderer", font=detail_font, fill="#9cc3cc")
    for index, (source, name, caption) in enumerate(selection):
        shutil.copyfile(output / source, destination / name)
        record = next(item for item in manifest["captures"] if item["file"] == source).copy()
        record.pop("visible_controls", None)
        record["source_capture"] = source
        record["file"] = name
        record["caption"] = caption
        record["sha256"] = hashlib.sha256((destination / name).read_bytes()).hexdigest()
        records.append(record)
        x, y = 24 + index % 3 * 472, 98 + index // 3 * 300
        draw.rectangle((x, y, x + 448, y + 286), fill="#0e1b24")
        draw.text((x + 10, y + 6), caption, font=label_font, fill="#fbf1ee")
        frame = Image.open(output / source).convert("RGB")
        frame.thumbnail((448, 248), Image.Resampling.LANCZOS)
        canvas.paste(frame, (x + (448 - frame.width) // 2, y + 38 + (248 - frame.height) // 2))
    draw.text((24, 716), "Screens show a teaching simulation. Fixture actions, model values and source hashes are recorded in capture-provenance.json.", font=detail_font, fill="#9cc3cc")
    canvas.save(destination / "contact-sheet.png", optimize=True)
    for source, name, caption in [
        ("02-preparation-1280x720.png", "preparation-desktop.png", "Optional science library"),
        ("19-story-crew-1280x720.png", "story-crew-desktop.png", "Story · meet the crew"),
        ("20-story-control-1280x720.png", "story-control-desktop.png", "Story · your control room"),
        ("17-bubble-merge-1280x720.png", "bubble-merge-desktop.png", "Eight ideas combine"),
        ("14-worked-equations-1280x720.png", "science-desktop.png", "Four visual science connections"),
        ("21-opening-window-1280x720.png", "loading-desktop.png", "Cancellable scene preparation"),
        ("22-science-library-1280x720.png", "discovery-desktop.png", "Optional discovery library"),
        ("23-home-1280x720.png", "home-desktop.png", "Home"),
        ("24-more-1280x720.png", "more-desktop.png", "Optional destinations"),
        ("25-nasa-context-1280x720.png", "nasa-context-desktop.png", "NASA context · offline fixture"),
        ("27-view-menu-1280x720.png", "view-menu-desktop.png", "View and accessibility"),
        ("28-focused-window-1280x720.png", "focused-window-desktop.png", "Focused window"),
        ("30-settings-view-return-1280x720.png", "settings-view-return-desktop.png", "Settings returns to View"),
        ("31-settings-pause-return-1280x720.png", "settings-pause-return-desktop.png", "Settings returns to Pause"),
        ("33-settings-home-return-1280x720.png", "settings-home-return-desktop.png", "Settings returns to Home"),
        ("04-cleaning-320x568.png", "mission-small-phone.png", "Small phone science window"),
        ("04-cleaning-844x390.png", "mission-landscape.png", "Short landscape science window"),
        ("28-focused-window-390x844.png", "focused-window-portrait.png", "Portrait focused window"),
    ]:
        shutil.copyfile(output / source, destination / name)
        record = next(item for item in manifest["captures"] if item["file"] == source).copy()
        record.pop("visible_controls", None)
        record.update(source_capture=source, file=name, caption=caption, sha256=hashlib.sha256((destination / name).read_bytes()).hexdigest())
        records.append(record)
        selection.append((source, name, caption))

    provenance = {key: manifest[key] for key in ["kind", "engine", "method", "source_revision", "source_sha256", "source_changed_during_capture", "layout_failures"]}
    provenance["captures"] = records
    provenance["contact_sheet"] = {"file": "contact-sheet.png", "method": "Scaled copies of the six unchanged native screenshots, with labels outside the game images; no invented renders or visual retouching.", "sha256": hashlib.sha256((destination / "contact-sheet.png").read_bytes()).hexdigest()}
    (destination / "capture-provenance.json").write_text(json.dumps(provenance, indent=2, ensure_ascii=False) + "\n")
    links = "\n".join(f"| [{caption}]({name}) | {next(item for item in records if item['file']==name)['width']} × {next(item for item in records if item['file']==name)['height']} |" for _, name, caption in selection)
    (destination / "README.md").write_text("""# Native journey screenshots

These are actual Godot screenshots of the stationary-cleaning journey in `game/main.tscn`. The first scene preparation has a real cancellable loading state. Ren starts cleaning only after START MISSION. Three main readings show cleaned fraction, stored energy and remaining play time; the default Science window restores the outpost frame and all eight live scientific bubbles. View & accessibility offers a larger Focused window while retaining Science access. Reading a concept pauses the mission. The operator chooses a pace with slower/faster buttons or the stepped slider; faster work builds an authored game-fatigue indicator. The default round lasts 90 active-play seconds, compressing 30 simulated minutes; at the countdown's end Ren steps directly inside. The visible panel clears dust continuously from the mission model.

![Native game contact sheet](contact-sheet.png)

| Screen | Resolution |
| --- | --- |
""" + links + f"""

The capture fixture uses normal screen intents, then advances the actual model to repeatable points. The mission image follows explicit Start, 18 active-play seconds at steady cleaning plus 24 at 1.25×: 1.9 cleared sections and 16% game fatigue. The debrief follows 48 further active seconds at normal pace and automatic shelter entry: 3.58 cleared sections (WIN), with 10.9375 µGy accumulated model dose. There is no recall, walking mission or radio interaction in this final workflow. Results appear immediately. Selecting “See how science connects” animates the eight ideas together before revealing four clickable visual science connections; the transition screenshot holds the real shell animation at 0.35 seconds. Optional details reveal the full word equations, exact numerical equations, history graphs and transfer question. The NASA viewer capture uses its explicitly labeled bundled image with online requests disabled; it is not evidence of a fresh observation. All values come from the model; no result summary is fabricated. The scene is illustrative and does not establish physical panel dimensions or human work-rate measurements. Battery energy stored now uses kWh; power generation and habitat load use kW. The rising radiation profile and game fatigue are authored teaching assumptions, not live NASA radiation data or personal health readings.

Captured with Godot's Linux compatibility renderer under authenticated Xvfb/Mesa. This checks native composition at desktop, portrait and short-landscape sizes. It does not establish Mac/Windows installation, mobile-device performance, audio quality, live update acceptance or real-time player usability. Audio output is muted only in the capture fixture, and user data is isolated.

`capture-provenance.json` records the source SHA-256 hashes, image hashes, actual model snapshots and fixture actions. The contact sheet contains only scaled native screenshots with external labels. The full QA run also captures all three story beats, cancellable loading, preflight, steady/faster cleaning, live concepts, pause, settings, storm countdown, automatic entry, the immediate result, the eight-bubble transition, four visual science connections, optional graphs, the learning-transfer question the return to results, the discovery library, offline NASA context and expanded connection details, View & accessibility, Focused window, Settings return routes to View/Pause/Home, Home and More at 1280×720, 960×540, 390×844, 320×568 and 844×390.

Reproduce from the repository root (Godot, Xvfb and Pillow required):

```sh
python3 scripts/capture_journey.py --output /tmp/komaku-journey-capture --publish-to {shlex.quote(os.path.relpath(destination, ROOT))}
```

Use `--xvfb /path/to/Xvfb` if Xvfb is not on `PATH`. Publishing rejects any run with geometry findings or source changes during capture.
""")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, default=Path("/tmp/komaku-journey-capture"))
    parser.add_argument("--godot", default="godot")
    parser.add_argument("--xvfb", type=Path)
    parser.add_argument("--timeout", type=int, default=360)
    parser.add_argument("--publish-to", type=Path, help="Copy reviewed native screens plus contact sheet and provenance; requires Pillow")
    args = parser.parse_args()
    output = args.output.expanduser().resolve()
    output.mkdir(parents=True, exist_ok=True)
    source_before = fingerprints()
    source_revision = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    # A prior interrupted run must never supply a stale successful manifest.
    (output / "capture-manifest.json").unlink(missing_ok=True)
    with tempfile.TemporaryDirectory(prefix="komaku-journey-visual-") as temporary:
        workspace = Path(temporary)
        (workspace / "logs").mkdir()
        data = workspace / "user-data"
        data.mkdir()
        base = dict(os.environ) | {"XDG_DATA_HOME": str(data)}
        with private_display(workspace, args.xvfb, base) as env:
            with (output / "capture.log").open("w") as log:
                result = subprocess.run(
                    [args.godot, "--path", str(ROOT / "game"), "--rendering-method", "gl_compatibility", "--script", "res://tests/capture_journey.gd", "--", "--output", str(output)],
                    env=env, text=True, stdout=log, stderr=subprocess.STDOUT,
                    timeout=args.timeout,
                )
        log_text = (output / "capture.log").read_text()
    manifest_path = output / "capture-manifest.json"
    if manifest_path.exists():
        manifest = json.loads(manifest_path.read_text())
        source_after = fingerprints()
        manifest["source_sha256"] = source_before
        manifest["source_revision"] = source_revision
        manifest["source_changed_during_capture"] = source_before != source_after
        manifest_path.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n")
        cards = []
        for capture in manifest["captures"]:
            name = capture["file"]
            cards.append(f'<figure><a href="{escape(name)}"><img src="{escape(name)}" loading="lazy"></a><figcaption>{escape(name)}</figcaption></figure>')
        (output / "index.html").write_text('<!doctype html><meta charset="utf-8"><title>'+escape(brand()["display_name"])+' visual QA fixture</title><style>body{background:#0b141b;color:#fbf1ee;font:16px system-ui;margin:24px}main{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:20px}figure{margin:0}img{width:100%;max-height:600px;object-fit:contain;background:#0e1b24}p{max-width:90ch}figcaption{padding:10px}</style><h1>'+escape(brand()["display_name"])+' · actual-main visual fixture</h1><p>'+escape(manifest["method"])+"</p><main>"+"".join(cards)+"</main>")
        print(f'Captured {len(manifest["captures"])} screens; {len(manifest["layout_failures"])} layout findings. Gallery: {output / "index.html"}')
    print(log_text[-12000:])
    if result.returncode or "SCRIPT ERROR:" in log_text or "\nERROR:" in log_text:
        raise SystemExit(result.returncode or 1)
    if not manifest_path.exists():
        raise SystemExit("Capture did not produce a completion manifest")
    if manifest["source_changed_during_capture"] or manifest["layout_failures"]:
        raise SystemExit("Capture rejected: source changed or layout checks failed")
    if args.publish_to:
        publish_selected(output, args.publish_to.expanduser().resolve(), manifest)


if __name__ == "__main__":
    main()
