"""Canonical player-facing brand and version-bound public archive naming."""
import json
from pathlib import Path
import re

BRAND_FILE = Path(__file__).resolve().parents[1] / "game/data/brand.json"
VERSION = re.compile(r"(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(?:-alpha\.(0|[1-9][0-9]{0,8}))?")


def brand():
    value = json.loads(BRAND_FILE.read_text(encoding="utf-8"))
    for field in ("display_name", "title", "subtitle", "package_stem", "package_slug"):
        if not isinstance(value.get(field), str) or not value[field].strip():
            raise ValueError("Canonical game brand is missing " + field)
    if not re.fullmatch(r"[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*", value["package_stem"]):
        raise ValueError("Brand package stem must be a safe ASCII filename component")
    return value


def archive_stem(version):
    """Only historical 0.0–0.4 releases use the former public ZIP prefix.

    Never derive an allowed filename from downloaded manifest brand metadata.
    Existing update pack, runtime contract and application IDs stay unchanged.
    """
    match = VERSION.fullmatch(version) if isinstance(version, str) else None
    if match is None:
        raise ValueError("Invalid release version")
    major, minor = map(int, match.group(1, 2))
    return "Red-Veil" if major == 0 and minor <= 4 else brand()["package_stem"]


def archive_name(version, platform):
    if platform not in {"macOS-universal", "Windows-x64", "Linux-x64", "Web"}:
        raise ValueError("Unsupported archive platform")
    return f"{archive_stem(version)}-{version}-{platform}.zip"
