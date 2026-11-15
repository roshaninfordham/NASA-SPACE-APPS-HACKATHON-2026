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
    """Preserve both historical public ZIP prefixes across later renames.

    Never derive an allowed filename from downloaded manifest brand metadata.
    Existing update pack, runtime contract and application IDs stay unchanged.
    """
    match = VERSION.fullmatch(version) if isinstance(version, str) else None
    if match is None:
        raise ValueError("Invalid release version")
    major, minor = map(int, match.group(1, 2))
    if major == 0 and minor <= 4:
        return "Red-Veil"
    if major == 0 and minor <= 8:
        return "KOMAKU-Shield-Protocol"
    return brand()["package_stem"]


def archive_name(version, platform):
    if platform not in {"macOS-universal", "Windows-x64", "Linux-x64", "Web"}:
        raise ValueError("Unsupported archive platform")
    return f"{archive_stem(version)}-{version}-{platform}.zip"


def supplemental_asset_names(version):
    """Science guide is part of the immutable release contract from alpha 0.7."""
    stem = archive_stem(version)
    match = VERSION.fullmatch(version)
    major, minor = map(int, match.group(1, 2))
    return {f"{stem}-{version}-Science-Guide.pdf"} if (major, minor) >= (0, 7) else set()
