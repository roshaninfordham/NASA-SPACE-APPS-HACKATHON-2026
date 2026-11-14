#!/usr/bin/env python3
"""Install the pinned minimal Linux SDK used by Godot's prebuilt APK exporter."""
import argparse
import hashlib
from pathlib import Path, PurePosixPath
import shutil
import stat
import sys
import urllib.request
import zipfile

BASE = "https://dl.google.com/android/repository/"
# Initial provenance: Google's repository2-3.xml, verified against its published
# SHA-1 archive checksums on 2026-11-14, then pinned here with SHA-256.
PACKAGES = [
    ("build-tools_r35.0.1_linux.zip", "5993499f3229a021b89f87088c57242aeefaa62316bf3d69da7de40bfd5350f1", "android-15", "build-tools/35.0.1"),
    ("platform-35_r02.zip", "0988cacad01b38a18a47bac14a0695f246bc76c1b06c0eeb8eb0dc825ab0c8e0", "android-35", "platforms/android-35"),
    ("platform-tools_r37.0.1-linux.zip", "d230f13842f60f782a8645f9c813f8f845bf36089ea7289f28c48f17979313f1", "platform-tools", "platform-tools"),
]


def digest(path):
    with path.open("rb") as source:
        return hashlib.file_digest(source, "sha256").hexdigest()


def extract_package(archive_path, expected_root, target):
    target = Path(target)
    target.mkdir(parents=True, exist_ok=True)
    if target.is_symlink():
        raise ValueError("SDK target cannot be a symlink")
    with zipfile.ZipFile(archive_path) as archive:
        for item in archive.infolist():
            relative = PurePosixPath(item.filename)
            mode = item.external_attr >> 16
            if relative.is_absolute() or ".." in relative.parts or not relative.parts or relative.parts[0] != expected_root or stat.S_ISLNK(mode):
                raise ValueError("Unexpected path or link in Android SDK archive")
            if len(relative.parts) == 1:
                continue
            output = target.joinpath(*relative.parts[1:])
            if not output.resolve().is_relative_to(target.resolve()):
                raise ValueError("SDK extraction would escape its target")
            if item.is_dir():
                output.mkdir(parents=True, exist_ok=True)
                continue
            output.parent.mkdir(parents=True, exist_ok=True)
            with archive.open(item) as source, output.open("wb") as destination:
                shutil.copyfileobj(source, destination)
            output.chmod((mode & 0o777) or 0o644)


def install(root):
    if sys.platform != "linux":
        raise ValueError("This pinned installer targets Linux build runners; use Android Studio for a local Mac/Windows SDK")
    root = Path(root).expanduser().resolve()
    cache = root / "downloads"
    cache.mkdir(parents=True, exist_ok=True)
    for name, checksum, source_root, destination in PACKAGES:
        path = cache / name
        if not path.exists():
            pending = path.with_suffix(".pending")
            with urllib.request.urlopen(BASE + name, timeout=90) as response, pending.open("wb") as target:
                shutil.copyfileobj(response, target)
            pending.replace(path)
        if digest(path) != checksum:
            raise ValueError(f"Android SDK archive checksum mismatch: {name}")
        extract_package(path, source_root, root / destination)
        print(f"Verified and installed {destination}")
    print(f"Minimal prebuilt-APK SDK: {root}")
    print("This does not install Gradle, command-line sdkmanager, the NDK, CMake, or an emulator.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sdk-root", required=True, type=Path)
    args = parser.parse_args()
    try:
        install(args.sdk_root)
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
