#!/usr/bin/env python3
"""Synchronize current presentation metadata from game/data/brand.json.

Only the explicit targets below are generated. Historical releases, update feed
filenames, package signatures, application IDs and npm scripts remain unchanged.
Run without arguments to synchronize, or --check to reject metadata drift in CI.
Markdown updates are limited to explicit <!-- brand:FIELD -->...<!-- /brand -->
markers in root Markdown files, game/README.md and docs/**/*.md.
"""
from __future__ import annotations

import argparse
import html
import json
from pathlib import Path
import re
import sys

ROOT = Path(__file__).resolve().parents[1]
FIELDS = {"display_name", "title", "subtitle", "package_stem", "package_slug", "legacy_product_name"}


def load_brand(root: Path = ROOT) -> dict[str, str]:
    brand = json.loads((root / "game/data/brand.json").read_text(encoding="utf-8"))
    if not isinstance(brand, dict) or set(brand) != FIELDS:
        raise ValueError("brand.json must contain exactly the six documented brand fields")
    if any(not isinstance(value, str) or not value.strip() or value != value.strip() for value in brand.values()):
        raise ValueError("Every brand field must be a nonempty trimmed string")
    if not re.fullmatch(r"[A-Za-z0-9]+(?:-[A-Za-z0-9]+)*", brand["package_stem"]):
        raise ValueError("package_stem must be a portable ASCII filename stem")
    if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", brand["package_slug"]):
        raise ValueError("package_slug must be a lowercase package identifier")
    if any(char in brand["legacy_product_name"] for char in '/\\:*?"<>|'):
        raise ValueError("legacy_product_name must remain a safe single directory name")
    return brand


def setting(text: str, section: str, key: str, value: str | bool) -> str:
    pattern = rf"(?ms)^\[{re.escape(section)}\]\n(.*?)(?=^\[|\Z)"
    match = re.search(pattern, text)
    if match is None:
        raise ValueError(f"Missing required config section [{section}]")
    body = match.group(1)
    encoded = str(value).lower() if isinstance(value, bool) else json.dumps(value, ensure_ascii=False)
    line = f"{key}={encoded}\n"
    key_pattern = rf"(?m)^{re.escape(key)}=.*(?:\n|$)"
    count = len(re.findall(key_pattern, body))
    if count > 1:
        raise ValueError(f"Duplicate [{section}] setting {key}")
    body = re.sub(key_pattern, lambda _: line, body) if count else line + body
    return text[:match.start(1)] + body + text[match.end(1):]


def replace_once(text: str, pattern: str, replacement: str, label: str) -> str:
    result, count = re.subn(pattern, lambda _: replacement, text, flags=re.DOTALL)
    if count != 1:
        raise ValueError(f"Expected exactly one {label}; found {count}")
    return result


def icon(brand: dict[str, str]) -> str:
    # A generated K monogram within a protective membrane; no external font needed.
    title = html.escape(brand["display_name"])
    return f'''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 192 192" role="img" aria-labelledby="brand-title">
  <title id="brand-title">{title}</title>
  <rect width="192" height="192" rx="42" fill="#32141e" />
  <path d="M96 25 153 46v47c0 35-23 58-57 76-34-18-57-41-57-76V46Z" fill="#f1e2ce" />
  <path d="M96 34 144 52v41c0 29-19 49-48 65-29-16-48-36-48-65V52Z" fill="none" stroke="#b98947" stroke-width="3" />
  <path d="M73 60v73m45-73-44 39 47 34" fill="none" stroke="#741b32" stroke-width="12" stroke-linecap="round" stroke-linejoin="round" />
  <path d="M73 46h45" stroke="#b98947" stroke-width="4" stroke-linecap="round" />
</svg>
'''


def expected_files(root: Path = ROOT) -> dict[Path, str]:
    brand = load_brand(root)
    result: dict[Path, str] = {}
    read = lambda name: (root / name).read_text(encoding="utf-8")
    description = f'{brand["display_name"]} — a first-person Mars learning adventure for young explorers.'
    project = read("game/project.godot")
    for key, value in {
        "config/name": brand["display_name"],
        "config/description": description,
        "config/use_custom_user_dir": True,
        # Godot core/os/os.cpp get_user_data_dir joins these to platform data roots.
        # Windows/macOS override get_godot_dir_name() to "Godot"; Linux uses "godot".
        "config/custom_user_dir_name": "Godot/app_userdata/" + brand["legacy_product_name"],
        "config/custom_user_dir_name.linux": "godot/app_userdata/" + brand["legacy_product_name"],
    }.items():
        project = setting(project, "application", key, value)
    result[root / "game/project.godot"] = project
    exports = read("game/export_presets.cfg")
    for section, key, value in [
        ("preset.1", "export_path", f'../releases/{brand["package_stem"]}-macOS-universal.zip'),
        ("preset.2", "export_path", f'../releases/linux/{brand["package_stem"]}.x86_64'),
        ("preset.3", "export_path", f'../releases/windows/{brand["package_stem"]}.exe'),
        ("preset.3.options", "application/product_name", brand["display_name"]),
        ("preset.3.options", "application/file_description", description),
    ]:
        exports = setting(exports, section, key, value)
    result[root / "game/export_presets.cfg"] = exports
    package = json.loads(read("package.json"))
    package["name"] = brand["package_slug"]
    result[root / "package.json"] = json.dumps(package, ensure_ascii=False, indent=2) + "\n"
    lock = json.loads(read("package-lock.json"))
    lock["name"] = brand["package_slug"]
    if not isinstance(lock.get("packages", {}).get(""), dict):
        raise ValueError("package-lock.json must contain its root package entry")
    lock["packages"][""]["name"] = brand["package_slug"]
    result[root / "package-lock.json"] = json.dumps(lock, ensure_ascii=False, indent=2) + "\n"
    manifest = json.loads(read("public/manifest.webmanifest"))
    manifest["name"] = brand["display_name"]
    manifest["short_name"] = brand["title"]
    result[root / "public/manifest.webmanifest"] = json.dumps(manifest, ensure_ascii=False, indent=2) + "\n"
    index = replace_once(read("index.html"), r"<title>.*?</title>", "<title>" + html.escape(brand["display_name"]) + "</title>", "document title")
    index = replace_once(index, r'<meta\s+name="description"\s+content="[^"]*"\s*/>', '<meta\n      name="description"\n      content="' + html.escape(description, quote=True) + '"\n    />', "description metadata")
    result[root / "index.html"] = index
    result[root / "public/icon.svg"] = icon(brand)
    result[root / "game/icon.svg"] = icon(brand)
    marker = re.compile(r"(?P<open><!--\s*brand:(?P<field>[a-z_]+)\s*-->)(?P<value>.*?)(?P<close><!--\s*/brand\s*-->)", re.DOTALL)
    documents = set(root.glob("*.md")) | set((root / "docs").rglob("*.md"))
    if (root / "game/README.md").exists():
        documents.add(root / "game/README.md")
    for path in sorted(documents):
        original = path.read_text(encoding="utf-8")
        if not re.search(r"<!--\s*brand:", original):
            continue
        def expand(match: re.Match[str]) -> str:
            field = match.group("field")
            if field not in brand:
                raise ValueError(f"Unknown brand marker {field} in {path.relative_to(root)}")
            return match.group("open") + brand[field] + match.group("close")
        rendered = marker.sub(expand, original)
        if len(marker.findall(original)) != len(re.findall(r"<!--\s*brand:", original)):
            raise ValueError(f"Malformed brand marker in {path.relative_to(root)}")
        result[path] = rendered
    return result


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Report stale targets without changing files")
    args = parser.parse_args()
    try:
        targets = expected_files()
        changed = [path for path, text in targets.items() if path.read_text(encoding="utf-8") != text]
        if args.check:
            if changed:
                print("Brand metadata is stale; run python3 scripts/sync_brand.py:", file=sys.stderr)
                for path in changed:
                    print("  " + str(path.relative_to(ROOT)), file=sys.stderr)
                return 1
            print(f"Canonical brand metadata is synchronized ({len(targets)} explicit targets).")
            return 0
        for path in changed:
            path.write_text(targets[path], encoding="utf-8")
            print("Updated " + str(path.relative_to(ROOT)))
        return 0
    except (OSError, ValueError) as exc:
        print(f"Brand synchronization failed: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
