#!/usr/bin/env python3
"""Prepare a complete Godot Web export for explicit, atomic browser updates."""
import argparse
import hashlib
import html
import json
from pathlib import Path, PurePosixPath
import re
import shutil
from urllib.parse import quote, unquote

from branding import brand

ROOT = Path(__file__).resolve().parent.parent
TEMPLATES = ROOT / "game/web"
MAX_FILE_BYTES = 256 * 1024 * 1024
MAX_TOTAL_BYTES = 384 * 1024 * 1024
MAX_ASSETS = 2048
VERSION = re.compile(r"(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-alpha\.(?:0|[1-9][0-9]*))?")
BUILD_FOLDER = "red-veil-builds"


def digest(data):
    return hashlib.sha256(data).hexdigest()


def prepare(directory, version, commit):
    identity = brand()
    folder = directory.resolve()
    if not VERSION.fullmatch(version) or len(version) > 64:
        raise ValueError("Invalid release version")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("An exact 40-character source commit is required")
    entry = folder / "index.html"
    source = entry.read_text(encoding="utf-8")
    metadata = folder / "web-release.json"
    if "<!-- RED_VEIL_WEB_BUILD " in source:
        if not metadata.is_file():
            raise ValueError("Prepared page has no release inventory; export again into a clean directory")
        existing = json.loads(metadata.read_text())
        if existing.get("version") != version or existing.get("commit") != commit:
            raise ValueError("Export again before preparing a different version")
        for asset in existing["assets"]:
            relative = PurePosixPath(unquote(asset["path"]))
            if relative.is_absolute() or ".." in relative.parts:
                raise ValueError("Invalid saved inventory path")
            candidate = folder / relative
            if candidate.is_symlink() or digest(candidate.read_bytes()) != asset["sha256"]:
                raise ValueError("Prepared export changed; export again into a clean directory")
        worker_path = folder / existing["worker"]
        if worker_path.is_symlink() or digest(worker_path.read_bytes()) != existing.get("worker_sha256"):
            raise ValueError("Prepared worker changed; export again into a clean directory")
        return existing
    match = re.search(r"const GODOT_CONFIG = (\{[^\n]+\});", source)
    if not match or "const GODOT_THREADS_ENABLED = false;" not in source:
        raise ValueError("Expected a single-threaded Godot export with index.html")
    if re.search(r'''\b(?:src|href)\s*=\s*["'](?:https?:)?//''', source, flags=re.IGNORECASE):
        raise ValueError("Export HTML must use local assets, not external resource URLs")
    config = json.loads(match[1])
    executable = config.get("executable")
    if not isinstance(executable, str) or not re.fullmatch(r"[A-Za-z0-9_-]+", executable):
        raise ValueError("Unsupported Godot executable filename")
    worker = config.get("serviceWorker") or executable + ".service.worker.js"
    if not isinstance(worker, str) or not re.fullmatch(r"[A-Za-z0-9_.-]+\.js", worker):
        raise ValueError("Expected a root-level Godot service worker")
    for required in [executable + ".js", executable + ".pck", executable + ".wasm"]:
        if not (folder / required).is_file():
            raise ValueError(f"Missing required game asset: {required}")
    generated = {"web-release.json", worker}
    assets = {}
    for path in sorted(folder.rglob("*")):
        relative = path.relative_to(folder)
        if relative.parts[0] == BUILD_FOLDER or relative.as_posix() in generated:
            continue
        if path.is_symlink():
            raise ValueError("Export assets must not be symbolic links")
        if path.is_file():
            data = path.read_bytes()
            if len(data) > MAX_FILE_BYTES:
                raise ValueError(f"Asset is larger than the supported offline budget: {relative}")
            assets[relative.as_posix()] = data
    templates = {name: (TEMPLATES / name).read_bytes() for name in ["service-worker.js", "browser-updates.js", "browser-updates.css"]}
    seed = json.dumps({"brand": identity, "version": version, "commit": commit, "assets": {name: digest(data) for name, data in assets.items()}, "templates": {name: digest(data) for name, data in templates.items()}}, sort_keys=True).encode()
    build_id = digest(seed)[:24]
    prefix = f"{BUILD_FOLDER}/{build_id}/"
    config["serviceWorker"] = ""  # Do not allow Godot's built-in updater to claim/reload clients.
    config["ensureCrossOriginIsolationHeaders"] = False
    source = source[:match.start(1)] + json.dumps(config, separators=(",", ":")) + source[match.end(1):]
    source = re.sub(r"<title>.*?</title>", lambda _: "<title>" + html.escape(identity["display_name"]) + "</title>", source, count=1, flags=re.IGNORECASE | re.DOTALL)
    source = re.sub(r'<link\b[^>]*\brel=["\']manifest["\'][^>]*>', "", source, flags=re.IGNORECASE)
    head = f'''<!-- RED_VEIL_WEB_BUILD {build_id} -->
<base href="./{prefix}">
<meta name="theme-color" content="#142a35">
<meta name="mobile-web-app-capable" content="yes">
<meta name="apple-mobile-web-app-title" content="{html.escape(identity["title"], quote=True)}">
<link rel="manifest" href="../../{executable}.manifest.json">
<link rel="stylesheet" href="browser-updates.css">
<script defer src="browser-updates.js" data-brand="{html.escape(identity["display_name"], quote=True)}" data-build="{build_id}" data-version="{html.escape(version, quote=True)}" data-root="../../" data-worker="{html.escape(worker, quote=True)}"></script>
'''
    source = source.replace("<head>", "<head>\n" + head, 1)
    assets["index.html"] = source.encode()
    assets["browser-updates.js"] = templates["browser-updates.js"]
    assets["browser-updates.css"] = templates["browser-updates.css"]
    icons = []
    for size in [144, 180, 512]:
        name = f"{executable}.{size}x{size}.png"
        if name in assets:
            icons.append({"src": prefix + name, "sizes": f"{size}x{size}", "type": "image/png", "purpose": "any"})
    if not icons:
        raise ValueError("Godot PWA icons are missing; enable PWA export before packaging")
    manifest = {"id": "./", "name": identity["display_name"], "short_name": identity["title"], "description": "A first-person Mars learning adventure for young explorers.", "start_url": "./", "scope": "./", "display": "standalone", "orientation": "landscape", "background_color": "#0d1b29", "theme_color": "#142a35", "icons": icons}
    output = {prefix + name: data for name, data in assets.items()}
    output["index.html"] = source.encode()
    output[f"{executable}.manifest.json"] = (json.dumps(manifest, indent=2) + "\n").encode()
    inventory = [{"path": quote(name, safe="/-._~"), "bytes": len(data), "sha256": digest(data)} for name, data in sorted(output.items())]
    if len(inventory) > MAX_ASSETS:
        raise ValueError("The export has too many individual files for this offline cache policy")
    total = sum(asset["bytes"] for asset in inventory)
    if total > MAX_TOTAL_BYTES:
        raise ValueError("The whole export exceeds the supported offline cache budget")
    release = {"schema": 1, "display_name": identity["display_name"], "version": version, "commit": commit, "build_id": build_id, "worker": worker, "total_bytes": total, "assets": inventory}
    worker_source = templates["service-worker.js"].decode().replace("/* RED_VEIL_RELEASE */ null", json.dumps(release, separators=(",", ":")))
    if "/* RED_VEIL_RELEASE */" in worker_source:
        raise ValueError("Worker inventory substitution failed")
    release["worker_sha256"] = digest(worker_source.encode())
    # All validation precedes output mutation. The caller publishes this directory atomically.
    old_builds = folder / BUILD_FOLDER
    if old_builds.exists():
        if not metadata.is_file():
            raise ValueError("Refusing to replace an unrecognized build directory")
        shutil.rmtree(old_builds)
    for name in assets:
        path = folder / name
        if path.is_file(): path.unlink()
    for name, data in output.items():
        path = folder / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    (folder / worker).write_text(worker_source)
    metadata.write_text(json.dumps(release, indent=2) + "\n")
    return release


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--directory", required=True, type=Path)
    parser.add_argument("--version", required=True)
    parser.add_argument("--commit", required=True)
    args = parser.parse_args()
    release = prepare(args.directory, args.version, args.commit)
    print(json.dumps({"directory": str(args.directory.resolve()), "version": release["version"], "build_id": release["build_id"], "asset_count": len(release["assets"]), "bytes": release["total_bytes"]}))


if __name__ == "__main__":
    main()
