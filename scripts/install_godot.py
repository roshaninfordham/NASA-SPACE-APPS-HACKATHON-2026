#!/usr/bin/env python3
"""Install the pinned Linux editor and optional templates after SHA-512 verification."""
import argparse
import hashlib
import os
from pathlib import Path
import shutil
import urllib.request
import zipfile

VERSION = "4.6.3"
BASE = f"https://github.com/godotengine/godot-builds/releases/download/{VERSION}-stable/"
CACHE = Path(os.environ.get("RED_VEIL_GODOT_CACHE", Path.home() / ".cache/red-veil/godot" / VERSION))


def download(name):
    path = CACHE / name
    if not path.exists():
        temporary = path.with_suffix(path.suffix + ".part")
        with urllib.request.urlopen(BASE + name, timeout=90) as response, temporary.open("wb") as output:
            shutil.copyfileobj(response, output)
        temporary.replace(path)
    return path


def verified(name, checksums):
    path = download(name)
    with path.open("rb") as source:
        actual = hashlib.file_digest(source, "sha512").hexdigest()
    if actual != checksums[name]:
        raise RuntimeError(f"SHA-512 mismatch: {name}; refusing to install")
    return path


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--templates", action="store_true")
    options = parser.parse_args()
    CACHE.mkdir(parents=True, exist_ok=True)
    checksums = {}
    for line in download("SHA512-SUMS.txt").read_text().splitlines():
        parts = line.split()
        if len(parts) == 2:
            checksums[parts[1].lstrip("*")] = parts[0]
    name = f"Godot_v{VERSION}-stable_linux.x86_64.zip"
    with zipfile.ZipFile(verified(name, checksums)) as archive:
        member = f"Godot_v{VERSION}-stable_linux.x86_64"
        target = CACHE / "bin/godot"
        target.parent.mkdir(exist_ok=True)
        target.write_bytes(archive.read(member))
        target.chmod(0o755)
    if options.templates:
        name = f"Godot_v{VERSION}-stable_export_templates.tpz"
        directory = Path.home() / ".local/share/godot/export_templates" / f"{VERSION}.stable"
        directory.mkdir(parents=True, exist_ok=True)
        with zipfile.ZipFile(verified(name, checksums)) as archive:
            for member in archive.namelist():
                if member.startswith("templates/") and not member.endswith("/"):
                    (directory / Path(member).name).write_bytes(archive.read(member))
    print(f"Verified Godot {VERSION}: {target}")


if __name__ == "__main__":
    main()
