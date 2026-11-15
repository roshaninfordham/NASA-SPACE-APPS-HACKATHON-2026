#!/usr/bin/env python3
"""Build the screenshot review app without changing or replacing a game site.

The destination must be a new directory outside this checkout. Every build
input must match Git HEAD unless --allow-uncommitted-preview is explicitly used.
Screenshot bytes and PNG dimensions are verified before any output is created.
"""

from __future__ import annotations

import argparse
from copy import deepcopy
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import struct
import subprocess
import sys
from urllib.parse import quote
import zlib


ROOT = Path(__file__).resolve().parents[1]
MANIFEST = "review/screens.json"
BUILDER = "scripts/build_screen_review.py"
BRAND = "game/data/brand.json"
UI_FILES = ("index.html", "review.css", "review.js")
SHA256 = re.compile(r"[0-9a-f]{64}")
COMMIT = re.compile(r"[0-9a-f]{40}")
SCREEN_ID = re.compile(r"[a-z0-9]+(?:-[a-z0-9]+)*")
VERSION = re.compile(r"\d{1,9}\.\d{1,9}\.\d{1,9}(?:-alpha\.\d{1,9})?")
REPOSITORY = re.compile(r"[A-Za-z0-9_-][A-Za-z0-9_.-]{0,99}/[A-Za-z0-9_-][A-Za-z0-9_.-]{0,99}")


class ReviewBuildError(ValueError):
    """A review build refused an unsafe path or unverified input."""


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def read_repo_file(root: Path, relative: str) -> bytes:
    """Only ordinary files contained by the checkout are build inputs."""
    path = PurePosixPath(relative)
    if not relative or "\\" in relative or path.is_absolute() or any(part in ("", ".", "..") for part in relative.split("/")):
        raise ReviewBuildError(f"Unsafe source path: {relative!r}")
    target = root.joinpath(*path.parts)
    if not target.resolve().is_relative_to(root):
        raise ReviewBuildError(f"Source escapes the checkout: {relative}")
    current = root
    for part in path.parts:
        current /= part
        if current.is_symlink():
            raise ReviewBuildError(f"Symlink build inputs are not supported: {relative}")
    if not target.is_file():
        raise ReviewBuildError(f"Missing build input: {relative}")
    return target.read_bytes()


def png_dimensions(data: bytes) -> tuple[int, int]:
    """Read and validate the PNG IHDR using only the standard library."""
    if len(data) < 33 or data[:8] != b"\x89PNG\r\n\x1a\n" or data[8:16] != b"\0\0\0\rIHDR":
        raise ReviewBuildError("A screenshot is not a PNG with a complete IHDR")
    expected_crc = struct.unpack(">I", data[29:33])[0]
    if zlib.crc32(data[12:29]) & 0xFFFFFFFF != expected_crc:
        raise ReviewBuildError("A screenshot has a damaged PNG header")
    width, height = struct.unpack(">II", data[16:24])
    if not 1 <= width <= 16384 or not 1 <= height <= 16384 or width * height > 32_000_000:
        raise ReviewBuildError("A screenshot has unsupported dimensions")
    return width, height


def git_head(root: Path) -> str:
    result = subprocess.run(
        ["git", "-C", str(root), "rev-parse", "--verify", "HEAD"],
        capture_output=True, text=True, timeout=15,
    )
    value = result.stdout.strip()
    if result.returncode or not COMMIT.fullmatch(value):
        raise ReviewBuildError("A committed Git checkout is required for review source links")
    return value


def git_blob(root: Path, commit: str, relative: str) -> bytes | None:
    result = subprocess.run(
        ["git", "-C", str(root), "cat-file", "blob", f"{commit}:{relative}"],
        capture_output=True, timeout=15,
    )
    return result.stdout if result.returncode == 0 else None


def _text(value: object, label: str, limit: int) -> str:
    if not isinstance(value, str) or not value.strip() or len(value) > limit:
        raise ReviewBuildError(f"Invalid {label}")
    return value


def prepare_review(root: Path, allow_uncommitted_preview: bool = False) -> tuple[dict, dict[str, bytes]]:
    """Validate the manifest and return the complete, immutable output payload."""
    root = root.resolve()
    manifest_bytes = read_repo_file(root, MANIFEST)
    if len(manifest_bytes) > 512_000:
        raise ReviewBuildError("Review manifest is too large")
    try:
        source = json.loads(manifest_bytes)
    except (ValueError, UnicodeDecodeError) as error:
        raise ReviewBuildError("Review manifest is not valid UTF-8 JSON") from error
    if not isinstance(source, dict) or type(source.get("schema")) is not int or source["schema"] != 1:
        raise ReviewBuildError("Unsupported review manifest schema")
    version = _text(source.get("version"), "version", 64)
    if not VERSION.fullmatch(version):
        raise ReviewBuildError("Invalid release version")
    game_commit = _text(source.get("sourceCommit"), "game source commit", 40)
    if not COMMIT.fullmatch(game_commit) or source.get("gameSourceCommit", game_commit) != game_commit:
        raise ReviewBuildError("Game source commit must be a full, consistent Git commit")
    repository = _text(source.get("repository"), "repository", 201)
    if not REPOSITORY.fullmatch(repository):
        raise ReviewBuildError("Invalid GitHub repository")
    screens = source.get("screens")
    if not isinstance(screens, list) or not 1 <= len(screens) <= 200:
        raise ReviewBuildError("Review requires between 1 and 200 screenshots")

    brand_bytes = read_repo_file(root, BRAND)
    try:
        brand = json.loads(brand_bytes)
    except (ValueError, UnicodeDecodeError) as error:
        raise ReviewBuildError("Canonical game brand is not valid UTF-8 JSON") from error
    if not isinstance(brand, dict):
        raise ReviewBuildError("Canonical game brand must be an object")
    display_name = _text(brand.get("display_name"), "canonical display name", 160)
    title = _text(brand.get("title"), "canonical title", 100)
    subtitle = _text(brand.get("subtitle"), "canonical subtitle", 100)
    inputs = {MANIFEST: manifest_bytes, BUILDER: read_repo_file(root, BUILDER), BRAND: brand_bytes}
    payload: dict[str, bytes] = {}
    for name in UI_FILES:
        data = read_repo_file(root, "review/" + name)
        if not data or len(data) > 512_000:
            raise ReviewBuildError(f"Invalid review UI input: {name}")
        try:
            data.decode("utf-8")
        except UnicodeDecodeError as error:
            raise ReviewBuildError(f"Review UI input is not UTF-8: {name}") from error
        inputs["review/" + name] = data
        payload[name] = data

    ids: set[str] = set()
    checked_screens: list[dict] = []
    for screen in screens:
        if not isinstance(screen, dict):
            raise ReviewBuildError("Each screenshot must be an object")
        identifier = _text(screen.get("id"), "screen id", 64)
        if not SCREEN_ID.fullmatch(identifier) or identifier in ids:
            raise ReviewBuildError(f"Invalid or duplicate screen id: {identifier}")
        ids.add(identifier)
        for name, limit in (("title", 160), ("group", 64), ("description", 1600)):
            _text(screen.get(name), "screen " + name, limit)
        if screen.get("file") != f"screens/{identifier}.png":
            raise ReviewBuildError(f"Unexpected screenshot destination for {identifier}")
        source_path = _text(screen.get("sourcePath"), "screenshot source path", 240)
        if not source_path.startswith("docs/media/") or not source_path.endswith(".png"):
            raise ReviewBuildError("Screenshots must come from PNG files in docs/media")
        digest = _text(screen.get("sha256"), "screenshot SHA-256", 64)
        if not SHA256.fullmatch(digest):
            raise ReviewBuildError(f"Invalid screenshot SHA-256: {identifier}")
        data = read_repo_file(root, source_path)
        if sha256(data) != digest:
            raise ReviewBuildError(f"Screenshot hash mismatch: {identifier}")
        width, height = png_dimensions(data)
        if type(screen.get("width")) is not int or type(screen.get("height")) is not int or (width, height) != (screen["width"], screen["height"]):
            raise ReviewBuildError(f"Screenshot dimensions do not match the manifest: {identifier}")
        inputs[source_path] = data
        payload[screen["file"]] = data
        checked_screens.append(deepcopy(screen))

    head = git_head(root)
    changed = sorted(path for path, data in inputs.items() if git_blob(root, head, path) != data)
    if changed and not allow_uncommitted_preview:
        raise ReviewBuildError(
            "Build inputs differ from Git HEAD: " + ", ".join(changed)
            + ". Commit them before publishing, or use --allow-uncommitted-preview for local review."
        )
    image_sources_pinned = True
    for screen in checked_screens:
        pinned = screen["sourcePath"] not in changed
        image_sources_pinned = image_sources_pinned and pinned
        ref = head if pinned else "main"
        screen["sourceUrl"] = f"https://raw.githubusercontent.com/{repository}/{ref}/{quote(screen['sourcePath'], safe='/')}"
        screen["sourcePinned"] = pinned

    built = deepcopy(source)
    built.update(
        displayName=display_name,
        title=title,
        subtitle=subtitle,
        gameSourceCommit=game_commit,
        buildSourceCommit=head,
        imageSourceCommit=head if image_sources_pinned else None,
        imageSourcesPinned=image_sources_pinned,
        preview=bool(changed),
        screens=checked_screens,
    )
    payload["screens.json"] = (json.dumps(built, indent=2, ensure_ascii=False) + "\n").encode("utf-8")
    report = {
        "schema": 1,
        "version": version,
        "gameSourceCommit": game_commit,
        "buildSourceCommit": head,
        "imageSourceCommit": built["imageSourceCommit"],
        "imageSourcesPinned": image_sources_pinned,
        "preview": bool(changed),
        "uncommittedInputs": changed,
        "screenCount": len(checked_screens),
        "files": [
            {"file": name, "bytes": len(data), "sha256": sha256(data)}
            for name, data in sorted(payload.items())
        ],
    }
    return report, payload


def build_review(output: Path, *, root: Path = ROOT, allow_uncommitted_preview: bool = False) -> dict:
    """Create a new app folder; never merge into or replace an existing site."""
    root = root.resolve()
    output = output.expanduser()
    if output.exists() or output.is_symlink():
        raise ReviewBuildError("Output must be a new directory; existing files will not be replaced")
    output = output.resolve()
    if output.is_relative_to(root) or output == Path(output.anchor):
        raise ReviewBuildError("Output must be a new directory outside the checkout")
    report, payload = prepare_review(root, allow_uncommitted_preview)
    # Validate every byte and source link before creating any output. Existing
    # parent directories (including the game site) are never modified or removed.
    output.parent.mkdir(parents=True, exist_ok=True)
    created_files: list[Path] = []
    created_dirs: list[Path] = []
    try:
        output.mkdir()  # Exclusive: refuse a directory that appeared meanwhile.
        created_dirs.append(output)
        (output / "screens").mkdir()
        created_dirs.append(output / "screens")
        for relative, data in sorted(payload.items()):
            target = output / relative
            with target.open("xb") as stream:
                created_files.append(target)
                stream.write(data)
    except OSError:
        # Remove only files this invocation created. Do not recursively delete
        # a site or an unexpected file added by another process.
        for path in reversed(created_files):
            try:
                path.unlink()
            except OSError:
                pass
        for path in reversed(created_dirs):
            try:
                path.rmdir()
            except OSError:
                pass
        raise
    report["output"] = str(output)
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True, help="New app directory outside the checkout; no version wrapper is added")
    parser.add_argument("--allow-uncommitted-preview", action="store_true", help="Permit local previews before commit; unpinned image links and the preview status are labeled explicitly")
    args = parser.parse_args()
    try:
        report = build_review(args.output, allow_uncommitted_preview=args.allow_uncommitted_preview)
    except (ReviewBuildError, OSError, subprocess.SubprocessError) as error:
        print(f"Screen review build refused: {error}", file=sys.stderr)
        raise SystemExit(1) from error
    print(json.dumps(report, indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
