#!/usr/bin/env python3
"""Validate/export exact-source game packages; publication is an explicit separate mode."""
import argparse
from contextlib import contextmanager
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile
from urllib.parse import quote

from branding import archive_name, archive_stem, brand, supplemental_asset_names
from sign_update import REPOSITORY, RUNTIME_CONTRACT, sign_pack, valid_version, validate_key_pair

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "releases"
DOCS = ["CREDITS.md", "CHANGELOG.md", "docs/DOWNLOADS.md", "docs/MACOS-LAUNCH-REPAIR.md", "docs/TRAINING-MODEL.md", "docs/SCIENCE-JOURNEY-SOURCES.md", "docs/AUDIO-CREDITS.md", "docs/LIVE-DATA.md", "docs/SOURCE-INDEX.md", "docs/VIDEO-PITCH.md", "docs/VIDEO-EQUATIONS.md", "docs/media/KOMAKU-Video-Equations.pdf", "docs/NAVIGATION.md", "docs/MISSION-PLANNER.md", "docs/PERFORMANCE.md", "docs/SCIENCE.md", "docs/LEARNING-DESIGN.md", "docs/TEAM-STATUS.md", "docs/UPDATES.md", "docs/SPEC-IMPLEMENTATION.md"]
UPDATE_ASSETS = {"red-veil-content.pck", "update-manifest.json", "update-manifest.sig"}
METADATA_ASSETS = {"release-manifest.json", "SHA256SUMS.txt"}


def run(*args, env=None):
    result = subprocess.run(args, cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, env=env)
    if result.returncode or "SCRIPT ERROR:" in result.stdout or "\nERROR:" in result.stdout:
        print(result.stdout)
        raise ValueError("Build or validation command failed")
    print(result.stdout[-1200:])


def source_commit():
    return subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()


def require_clean_source():
    changes = subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=ROOT, text=True)
    if changes.strip():
        raise ValueError("Release builds require a clean committed checkout so the source manifest is exact")


def documents(archive, version):
    archive.writestr("START-HERE.txt", f"""{brand()['display_name']} — {version}

PLAY
Extract this entire ZIP first. No game editor or development tools are required.
Mac: open the .app. If blocked, read DOWNLOADS.md and use the included
     Install KŌMAKU.command only after deciding you trust this download.
Windows: open KOMAKU-Shield-Protocol.exe.
Linux: run KOMAKU-Shield-Protocol.x86_64.
Web archive: serve index.html over HTTP(S), as explained in DOWNLOADS.md.

FIRST MISSION
Follow the short Mars story into the control-room window.
Set a starting pace, then press START MISSION (or Enter).
1: SLOWER. 3: FASTER. The slider selects the same cleaning effort.
High effort builds game tiredness; gentler effort restores it.
Ren steps inside automatically when the countdown ends. There is no walk.
All controls also work by click/touch. No microphone is required.
Science cards and Pause stop the mission clock. Escape leaves fullscreen
first and pauses; another Escape closes one panel or offers Resume.
Settings has music, sound effects, reduced motion and relaxed/quick pacing.
Debrief connects your actual run to four equations and an optional quiz.
Home > Advanced lab retains the earlier Mira/EVA mission separately.

UPDATES AND SCIENCE
Compatible desktop updates appear at a safe menu on a fresh launch:
Update available → Install → Restart. Engine changes need a new installer.
Read KOMAKU-Science-Guide.pdf for equations, data and teaching assumptions.
Live Sun shows NASA SDO imagery with timestamps; cached imagery works offline.
Its latest image is educational context, not a Mars radiation prediction.
This is a learning-game alpha, not certified astronaut training.

VERSION AND SUPPORT
The release manifest records the exact source and file checksums.
https://github.com/roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026/releases/tag/v{version}
Documentation on main may be newer than this packaged snapshot.

made with love by Team Roshan Xingbo at the NASA Space App Hackathon 2026, NYC
""")
    archive.write(ROOT / "docs/media/KOMAKU-Science-Guide.pdf", "KOMAKU-Science-Guide.pdf")
    for file in DOCS:
        archive.write(ROOT / file, Path(file).name)
        if Path(file).parent != Path("."):
            # Retain the original docs hierarchy as well as convenient root copies.
            archive.write(ROOT / file, file)
    for file in (ROOT / "game/licenses").iterdir():
        archive.write(file, "licenses/" + file.name)


def clean_generated_folder(path):
    if path.is_symlink():
        raise ValueError("Generated output directories must not be symlinks")
    if path.exists():
        shutil.rmtree(path)
    path.mkdir(parents=True)


@contextmanager
def signing_key(private_path, secret):
    """A workflow key exists only outside the checkout and is deleted even on failure."""
    if private_path:
        path = Path(private_path).expanduser().resolve()
        if path.is_relative_to(ROOT):
            raise ValueError("Signing private keys must live outside the repository")
        yield path
        return
    if not secret:
        raise ValueError("Signed updates requested, but RED_VEIL_UPDATE_SIGNING_KEY is missing")
    with tempfile.TemporaryDirectory(prefix="red-veil-release-key-", dir=os.environ.get("RUNNER_TEMP")) as temporary:
        path = Path(temporary) / "private.pem"
        if path.resolve().is_relative_to(ROOT):
            raise ValueError("Runner temporary directory must be outside the repository")
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
        with os.fdopen(descriptor, "w") as output:
            output.write(secret)
        yield path


def describe_asset(path):
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    return {"name": path.name, "bytes": path.stat().st_size, "sha256": digest}


def expected_names(version, signed):
    names = {archive_name(version, suffix) for suffix in ["macOS-universal", "Windows-x64", "Linux-x64", "Web"]}
    names |= supplemental_asset_names(version)
    return names | UPDATE_ASSETS if signed else names


def validate_release_manifest(manifest, version, commit):
    if not valid_version(version) or manifest.get("version") != version or manifest.get("commit") != commit:
        raise ValueError("Release version/source does not match the exact checkout")
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Release source must be an exact commit")
    signed = manifest.get("signed_content_updates")
    if not isinstance(signed, bool):
        raise ValueError("Release must declare whether content updates are signed")
    entries = manifest.get("assets")
    if not isinstance(entries, list):
        raise ValueError("Release asset list is missing")
    names = [entry.get("name") for entry in entries if isinstance(entry, dict)]
    expected = expected_names(version, signed)
    if len(names) != len(expected) or set(names) != expected:
        raise ValueError("Release assets must match the exact declared platform/update set")
    for entry in entries:
        path = OUT / entry["name"]
        if path.is_symlink() or not path.is_file() or describe_asset(path) != entry:
            raise ValueError("A release asset changed after its checksum was recorded")
    return expected


def stage_distribution(manifest):
    """Only declared files enter the artifact directory; stale packs are never inherited."""
    names = validate_release_manifest(manifest, manifest["version"], manifest["commit"])
    checksum_text = "".join(f"{entry['sha256']}  {entry['name']}\n" for entry in manifest["assets"])
    if any((OUT / name).is_symlink() for name in METADATA_ASSETS):
        raise ValueError("Release metadata outputs must not be symlinks")
    (OUT / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    (OUT / "SHA256SUMS.txt").write_text(checksum_text)
    distribution = OUT / "distribution"
    clean_generated_folder(distribution)
    for name in sorted(names | METADATA_ASSETS):
        shutil.copyfile(OUT / name, distribution / name)


def export_game(version, private_key=None):
    require_clean_source()
    configured = re.search(r'^config/version="([^"]+)"$', (ROOT / "game/project.godot").read_text(), re.MULTILINE)
    if not configured or configured[1] != version:
        raise ValueError("Release version must match game/project.godot application/config/version")
    public_key = ROOT / "game/updater/public_key.pem"
    if private_key:
        validate_key_pair(private_key, public_key)
        subprocess.run(["git", "ls-files", "--error-unmatch", "game/updater/public_key.pem"], cwd=ROOT, check=True, stdout=subprocess.DEVNULL)
    for folder in ["web", "linux", "windows"]:
        clean_generated_folder(OUT / folder)
    run("python3", "scripts/test_game.py")
    for platform in ["Web", "macOS", "Linux", "Windows"]:
        run("godot", "--headless", "--path", "game", "--export-release", platform)
    linux = OUT / "linux" / (brand()["package_stem"] + ".x86_64")
    linux.chmod(0o755)
    with tempfile.TemporaryDirectory(prefix="red-veil-export-smoke-") as isolated:
        run(str(linux), "--headless", "--", "--smoke-test", env=os.environ | {"XDG_DATA_HOME": isolated})
    assets = []
    prefix = f"{archive_stem(version)}-{version}"
    mac = OUT / f"{prefix}-macOS-universal.zip"
    shutil.copyfile(OUT / (brand()["package_stem"] + "-macOS-universal.zip"), mac)
    with zipfile.ZipFile(mac, "a", compression=zipfile.ZIP_DEFLATED) as archive:
        documents(archive, version)
        installer = zipfile.ZipInfo("Install KŌMAKU.command")
        installer.create_system = 3
        installer.external_attr = 0o100755 << 16
        installer.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(installer, (ROOT / "scripts/macos-install.command").read_bytes())
    assets.append(mac)
    for folder, suffix in [("linux", "Linux-x64"), ("windows", "Windows-x64"), ("web", "Web")]:
        output = OUT / f"{prefix}-{suffix}.zip"
        with zipfile.ZipFile(output, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for file in sorted((OUT / folder).rglob("*")):
                if file.is_file():
                    archive.write(file, str(file.relative_to(OUT / folder)))
            documents(archive, version)
        assets.append(output)
    for name in supplemental_asset_names(version):
        guide = OUT / name
        shutil.copyfile(ROOT / "docs/media/KOMAKU-Science-Guide.pdf", guide)
        assets.append(guide)
    commit = source_commit()
    if private_key:
        pack = OUT / "red-veil-content.pck"
        run("godot", "--headless", "--path", "game", "--export-pack", "Linux", str(pack))
        sign_pack(version, pack, private_key, public_key, OUT, commit)
        assets.extend(OUT / name for name in sorted(UPDATE_ASSETS))
    require_clean_source()
    manifest = {
        "display_name": brand()["display_name"], "package_stem": archive_stem(version),
        "version": version, "commit": commit, "engine": "Godot 4.6.3", "status": "early alpha",
        "signing": "macOS ad-hoc signed (no Developer ID/notarization); Windows unsigned",
        "signed_content_updates": private_key is not None,
        "verified": ["headless numerical tests", "headless complete mission interactions", "art replacement contract", "local learning and profile recovery", "signed manifest rejection checks", "update client/UI integration", "real-PCK baseline boot and rollback fixtures", "release signing/publication tests", "exported Linux headless startup"],
        "not_verified": ["physical macOS and Windows launch", "M5 performance", "mobile devices", "child playtesting", "expert scientific review"],
        "assets": [describe_asset(asset) for asset in assets],
    }
    if private_key:
        manifest["verified"].append("PCK manifest signature matches committed installer public key")
    stage_distribution(manifest)
    print(json.dumps(manifest, indent=2))


def gh_api(endpoint, allow_missing=False):
    result = subprocess.run(["gh", "api", endpoint], cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        if allow_missing and "HTTP 404" in result.stderr:
            return None
        raise ValueError("GitHub could not verify the release or source binding")
    return json.loads(result.stdout)


def read_release(version):
    """Resolve drafts through gh, then read only the fixed repository's numeric API ID."""
    if not valid_version(version):
        raise ValueError("Invalid release version")
    result = subprocess.run(["gh", "release", "view", "v" + version, "--repo", REPOSITORY, "--json", "apiUrl", "--jq", ".apiUrl"], cwd=ROOT, capture_output=True, text=True)
    if result.returncode:
        raise ValueError("GitHub could not resolve the existing release; no publication attempted")
    match = re.fullmatch(r"https://api\.github\.com/repos/" + re.escape(REPOSITORY) + r"/releases/([1-9][0-9]{0,19})", result.stdout.strip())
    if match is None:
        raise ValueError("Release lookup returned an unexpected API URL")
    release_id = int(match[1])
    release = gh_api(f"repos/{REPOSITORY}/releases/{release_id}")
    if not isinstance(release, dict) or type(release.get("id")) is not int or release["id"] != release_id:
        raise ValueError("Release API response does not match the resolved numeric ID")
    return release


def validate_release_binding(release, version, commit):
    if release.get("draft") is not True or release.get("tag_name") != "v" + version:
        raise ValueError("Publication requires the matching existing draft; published assets are immutable")
    target = release.get("target_commitish", "")
    if not isinstance(target, str) or not target:
        raise ValueError("Draft release target is missing")
    target_commit = gh_api(f"repos/{REPOSITORY}/commits/{quote(target, safe='')}").get("sha")
    if target_commit != commit:
        raise ValueError("Draft release target differs from the exact built source")
    tag = gh_api(f"repos/{REPOSITORY}/git/ref/tags/v{version}", allow_missing=True)
    if tag is not None:
        tagged_commit = gh_api(f"repos/{REPOSITORY}/commits/v{version}").get("sha")
        if tagged_commit != commit:
            raise ValueError("Existing release tag differs from the built source")


def publish_prepared(version):
    require_clean_source()
    manifest = json.loads((OUT / "release-manifest.json").read_text())
    expected = validate_release_manifest(manifest, version, source_commit()) | METADATA_ASSETS
    release = read_release(version)
    validate_release_binding(release, version, manifest["commit"])
    existing = {asset["name"] for asset in release.get("assets", [])}
    if not existing.issubset(expected):
        raise ValueError("Draft contains unexpected assets; review them before publishing")
    # Rebuild the artifact directory from exact validated files, excluding stale output.
    stage_distribution(manifest)
    if manifest["signed_content_updates"]:
        public_key = ROOT / "game/updater/public_key.pem"
        from sign_update import openssl
        openssl("dgst", "-sha256", "-verify", public_key, "-signature", OUT / "update-manifest.sig", OUT / "update-manifest.json")
        update = json.loads((OUT / "update-manifest.json").read_text())
        pack = describe_asset(OUT / "red-veil-content.pck")
        expected_update = {"schema": 1, "repository": REPOSITORY, "version": version, "engine": "4.6.3", "runtime_contract": RUNTIME_CONTRACT, "pack_file": "red-veil-content.pck", "pack_bytes": pack["bytes"], "pack_sha256": pack["sha256"], "source_commit": manifest["commit"]}
        if update != expected_update:
            raise ValueError("Signed content manifest does not match the prepared release")
    subprocess.run(["gh", "release", "upload", "v" + version, *[str(OUT / name) for name in sorted(expected)], "--clobber", "--repo", REPOSITORY], cwd=ROOT, check=True)
    uploaded = gh_api(f"repos/{REPOSITORY}/releases/{release['id']}")
    validate_release_binding(uploaded, version, manifest["commit"])
    if {asset["name"] for asset in uploaded.get("assets", [])} != expected:
        raise ValueError("Uploaded asset set is incomplete or unexpected")
    for asset in uploaded["assets"]:
        local = describe_asset(OUT / asset["name"])
        if asset.get("size") != local["bytes"] or (asset.get("digest") and asset["digest"] != "sha256:" + local["sha256"]):
            raise ValueError("GitHub asset size/digest does not match the verified local file")
    subprocess.run(["gh", "release", "edit", "v" + version, "--draft=false", "--prerelease", "--repo", REPOSITORY], cwd=ROOT, check=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", help="Defaults to the version committed in game/project.godot")
    parser.add_argument("--signed-updates", action="store_true", help="Export/sign a same-engine desktop content pack; requires the pinned key and signing secret")
    parser.add_argument("--private-key", type=Path, help="Local signing key outside the checkout; otherwise use the Actions secret")
    parser.add_argument("--publish-prepared", action="store_true", help="Upload exact prepared files to the matching draft and publish it")
    args = parser.parse_args()
    secret = os.environ.pop("RED_VEIL_UPDATE_SIGNING_KEY", "")
    try:
        if args.version is None:
            configured = re.search(r'^config/version="([^"]+)"$', (ROOT / "game/project.godot").read_text(), re.MULTILINE)
            if configured is None:
                raise ValueError("Game application version is missing")
            args.version = configured[1]
        if not valid_version(args.version):
            raise ValueError("Invalid release version")
        if args.publish_prepared:
            if args.signed_updates or args.private_key:
                raise ValueError("Publishing uses prepared signatures; it never needs the private key")
            publish_prepared(args.version)
        elif args.signed_updates:
            with signing_key(args.private_key, secret) as private:
                export_game(args.version, private)
        elif args.private_key:
            raise ValueError("A private key is only used with --signed-updates")
        else:
            export_game(args.version)
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
