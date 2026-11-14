#!/usr/bin/env python3
"""Prepare a Pages artifact from an existing published Red Veil Web release."""
import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import urllib.parse
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
PAGES_URL = "https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/"
API_ROOT = f"https://api.github.com/repos/{REPOSITORY}"
VERSION_PATTERN = r"(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(?:-alpha\.(0|[1-9][0-9]{0,8}))?"
MAX_API_BYTES = 1024 * 1024
MAX_MANIFEST_BYTES = 64 * 1024
MAX_ZIP_BYTES = 128 * 1024 * 1024
MAX_EXPANDED_BYTES = 512 * 1024 * 1024
MAX_ZIP_ENTRIES = 5000
DOWNLOAD_HOSTS = {
    "api.github.com", "github.com", "release-assets.githubusercontent.com",
    "objects.githubusercontent.com", "github-releases.githubusercontent.com",
}


def validate_download_url(url):
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname not in DOWNLOAD_HOSTS or parts.username or parts.password or parts.port not in (None, 443):
        raise ValueError("Only HTTPS downloads from GitHub release infrastructure are allowed")


class ReleaseRedirects(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, request, file, code, message, headers, new_url):
        validate_download_url(new_url)
        redirected = super().redirect_request(request, file, code, message, headers, new_url)
        if redirected is not None and urllib.parse.urlsplit(new_url).hostname != "api.github.com":
            redirected.remove_header("Authorization")
        return redirected


def download(url, path, maximum):
    validate_download_url(url)
    headers = {"User-Agent": "Red-Veil-release-site"}
    # Actions' scoped read token avoids shared-runner anonymous API limits. It
    # never goes to a release-asset host or into the generated website.
    if urllib.parse.urlsplit(url).hostname == "api.github.com" and os.environ.get("GH_TOKEN"):
        headers["Authorization"] = "Bearer " + os.environ["GH_TOKEN"]
    request = urllib.request.Request(url, headers=headers)
    opener = urllib.request.build_opener(ReleaseRedirects())
    with opener.open(request, timeout=30) as response:
        if response.status != 200:
            raise ValueError("Release download did not return HTTP 200")
        length = response.headers.get("Content-Length")
        if length is not None and (not length.isdigit() or int(length) > maximum):
            raise ValueError("Release download exceeds the supported size")
        total = 0
        with Path(path).open("wb") as output:
            while chunk := response.read(1024 * 1024):
                total += len(chunk)
                if total > maximum:
                    raise ValueError("Release download exceeds the supported size")
                output.write(chunk)
    return total


def fetched_json(url, temporary, name, maximum):
    path = Path(temporary) / name
    download(url, path, maximum)
    value = json.loads(path.read_bytes())
    if not isinstance(value, dict):
        raise ValueError("Unexpected release metadata")
    return value, path


def version_from_tag(tag):
    if not isinstance(tag, str) or not tag.startswith("v") or not re.fullmatch(VERSION_PATTERN, tag[1:]):
        raise ValueError("Use an exact supported release tag, such as v0.4.0-alpha.1")
    return tag[1:]


def fixed_asset_url(tag, filename):
    version = version_from_tag(tag)
    allowed = {"release-manifest.json", f"Red-Veil-{version}-Web.zip"}
    if filename not in allowed:
        raise ValueError("Unexpected release asset name")
    return f"https://github.com/{REPOSITORY}/releases/download/{tag}/{filename}"


def validate_release(release, tag):
    if release.get("draft") is not False or release.get("tag_name") != tag or not release.get("published_at"):
        raise ValueError("Only an existing published release can be deployed")
    version = version_from_tag(tag)
    expected = {"release-manifest.json", f"Red-Veil-{version}-Web.zip"}
    assets = release.get("assets")
    if not isinstance(assets, list):
        raise ValueError("Published release has no asset list")
    selected = {}
    for asset in assets:
        if not isinstance(asset, dict) or asset.get("name") not in expected:
            continue
        name = asset["name"]
        if name in selected or asset.get("browser_download_url") != fixed_asset_url(tag, name):
            raise ValueError("Published release asset is duplicated or has an unexpected URL")
        size = asset.get("size")
        limit = MAX_MANIFEST_BYTES if name == "release-manifest.json" else MAX_ZIP_BYTES
        if not isinstance(size, int) or isinstance(size, bool) or not 0 < size <= limit:
            raise ValueError("Published release asset has an unsupported size")
        selected[name] = asset
    if set(selected) != expected:
        raise ValueError("Published release is missing its Web archive or source manifest")
    return selected


def web_archive_entry(manifest, version, tagged_commit):
    if manifest.get("version") != version or manifest.get("commit") != tagged_commit or not re.fullmatch(r"[0-9a-f]{40}", str(tagged_commit)):
        raise ValueError("Release manifest version/source does not match its published tag")
    if manifest.get("engine") != "Godot 4.6.3":
        raise ValueError("This web packaging adapter supports the Godot 4.6.3 export format")
    filename = f"Red-Veil-{version}-Web.zip"
    assets = manifest.get("assets")
    if not isinstance(assets, list):
        raise ValueError("Release manifest has no asset list")
    matches = [asset for asset in assets if isinstance(asset, dict) and asset.get("name") == filename]
    if len(matches) != 1:
        raise ValueError("Release manifest must contain exactly one matching Web archive")
    entry = matches[0]
    if not isinstance(entry.get("bytes"), int) or isinstance(entry["bytes"], bool) or not 0 < entry["bytes"] <= MAX_ZIP_BYTES:
        raise ValueError("Web archive size is invalid")
    if not isinstance(entry.get("sha256"), str) or not re.fullmatch(r"[0-9a-f]{64}", entry["sha256"]):
        raise ValueError("Web archive checksum is invalid")
    return entry


def verify_archive(path, entry):
    if path.stat().st_size != entry["bytes"]:
        raise ValueError("Downloaded Web archive length does not match its release manifest")
    with path.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    if digest != entry["sha256"]:
        raise ValueError("Downloaded Web archive SHA-256 does not match its release manifest")


def safe_extract(archive_path, destination):
    destination = Path(destination)
    if destination.is_symlink() or (destination.exists() and (not destination.is_dir() or any(destination.iterdir()))):
        raise ValueError("Extraction requires an empty regular directory")
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive_path) as archive:
        entries = archive.infolist()
        if not entries or len(entries) > MAX_ZIP_ENTRIES:
            raise ValueError("Web archive has an unsupported number of files")
        if sum(entry.file_size for entry in entries) > MAX_EXPANDED_BYTES:
            raise ValueError("Expanded Web archive exceeds the supported size")
        seen = set()
        for entry in entries:
            name = entry.filename
            raw_parts = name.rstrip("/").split("/")
            if not name or "\x00" in entry.orig_filename or "\\" in name or PurePosixPath(name).is_absolute() or any(part in ("", ".", "..") or ":" in part for part in raw_parts):
                raise ValueError("Web archive contains an unsafe path")
            canonical = "/".join(raw_parts).casefold()
            if canonical in seen:
                raise ValueError("Web archive contains duplicate or ambiguous paths")
            seen.add(canonical)
            file_type = stat.S_IFMT(entry.external_attr >> 16)
            if file_type not in (0, stat.S_IFREG, stat.S_IFDIR) or (file_type == stat.S_IFDIR and not entry.is_dir()):
                raise ValueError("Web archive contains a link or special file")
            if entry.flag_bits & 1:
                raise ValueError("Encrypted Web archives are unsupported")
        for entry in entries:
            target = destination.joinpath(*PurePosixPath(entry.filename).parts)
            if entry.is_dir():
                target.mkdir(parents=True, exist_ok=True)
                continue
            target.parent.mkdir(parents=True, exist_ok=True)
            copied = 0
            with archive.open(entry) as source, target.open("xb") as output:
                while chunk := source.read(1024 * 1024):
                    copied += len(chunk)
                    if copied > entry.file_size or copied > MAX_EXPANDED_BYTES:
                        raise ValueError("Web archive entry expanded beyond its declared size")
                    output.write(chunk)
            if copied != entry.file_size:
                raise ValueError("Web archive entry was truncated")
    if not (destination / "index.html").is_file():
        raise ValueError("Web archive has no index.html entry point")


def packaging_commit():
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    if not re.fullmatch(r"[0-9a-f]{40}", commit):
        raise ValueError("Web packaging source must be an exact commit")
    if subprocess.check_output(["git", "status", "--porcelain", "--untracked-files=normal"], cwd=ROOT, text=True).strip():
        raise ValueError("Deploy from a clean committed checkout so web packaging provenance is exact")
    return commit


def prepare_site(tag, output):
    version = version_from_tag(tag)
    packaged_from = packaging_commit()
    output = Path(output).expanduser()
    if output.is_symlink() or (output.exists() and (not output.is_dir() or any(output.iterdir()))):
        raise ValueError("Site output must be absent or an empty regular directory")
    output = output.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="red-veil-web-source-") as temporary:
        release, _ = fetched_json(f"{API_ROOT}/releases/tags/{tag}", temporary, "release.json", MAX_API_BYTES)
        release_assets = validate_release(release, tag)
        manifest, manifest_path = fetched_json(fixed_asset_url(tag, "release-manifest.json"), temporary, "release-manifest.json", MAX_MANIFEST_BYTES)
        if manifest_path.stat().st_size != release_assets["release-manifest.json"]["size"]:
            raise ValueError("Release manifest length differs from published asset metadata")
        tagged, _ = fetched_json(f"{API_ROOT}/commits/{tag}", temporary, "tagged-commit.json", MAX_API_BYTES)
        native_commit = tagged.get("sha")
        entry = web_archive_entry(manifest, version, native_commit)
        if entry["bytes"] != release_assets[entry["name"]]["size"]:
            raise ValueError("Published Web archive size differs from its source manifest")
        archive = Path(temporary) / "web.zip"
        download(fixed_asset_url(tag, entry["name"]), archive, entry["bytes"])
        verify_archive(archive, entry)
        with tempfile.TemporaryDirectory(prefix=".red-veil-pages-stage-", dir=output.parent) as staging:
            stage = Path(staging) / "site"
            stage.mkdir()
            safe_extract(archive, stage)
            subprocess.run([sys.executable, str(ROOT / "scripts/prepare_web_release.py"), "--directory", str(stage), "--version", version, "--commit", native_commit], cwd=ROOT, check=True, env={key: value for key, value in os.environ.items() if key not in ("GH_TOKEN", "GITHUB_TOKEN")})
            provenance = {
                "schema": 1, "native_repository": REPOSITORY, "native_release_tag": tag,
                "native_version": version, "native_source_commit": native_commit,
                "native_web_archive": entry["name"], "native_web_bytes": entry["bytes"],
                "native_web_sha256": entry["sha256"],
                "native_manifest_sha256": hashlib.sha256(manifest_path.read_bytes()).hexdigest(),
                "packaging_repository": REPOSITORY, "packaging_source_commit": packaged_from,
                "packaging_tool": "scripts/prepare_web_release.py",
                "prepared_at_utc": datetime.now(timezone.utc).isoformat(),
                "expected_pages_url": PAGES_URL,
                "note": "This website adapts the verified native Web archive for versioned assets and PWA updates. It is not byte-identical to the original release ZIP.",
            }
            (stage / "deployment-provenance.json").write_text(json.dumps(provenance, indent=2) + "\n")
            if output.exists():
                output.rmdir()
            shutil.move(str(stage), str(output))
    print(f"Prepared {tag} from native source {native_commit} using packaging source {packaged_from}.")
    print(f"Site artifact: {output}")
    print(f"Expected URL after a successful Pages deployment: {PAGES_URL}")
    return provenance


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tag", required=True, help="Existing published release tag, for example v0.4.0-alpha.1")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    try:
        prepare_site(args.tag, args.output)
    except (ValueError, OSError, zipfile.BadZipFile, subprocess.CalledProcessError) as error:
        raise SystemExit(str(error)) from None


if __name__ == "__main__":
    main()
