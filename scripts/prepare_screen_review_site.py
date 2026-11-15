#!/usr/bin/env python3
"""Add a versioned screen-review gallery while preserving the existing Pages site.

Initial deployment recovers the exact successful Pages artifact. Later deployments
can reconstruct the public site from its bounded, hash-checked inventory, even
when Actions artifacts have expired. No game release or hosting settings change.
"""
import argparse
import datetime
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
from concurrent.futures import ThreadPoolExecutor
from urllib.error import HTTPError
from urllib.parse import quote
from urllib.request import urlopen
import zipfile

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
PUBLIC_ROOT = "https://roshaninfordham.github.io/NASA-SPACE-APPS-HACKATHON-2026/"
INVENTORY = "screen-review-deployment.json"
MAX_FILE = 128 * 1024 * 1024
MAX_TOTAL = 512 * 1024 * 1024
MAX_FILES = 4096
VERSION = re.compile(r"[0-9]+\.[0-9]+\.[0-9]+(?:-alpha\.[0-9]+)?")


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safe_path(value):
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        raise ValueError("Invalid site path")
    path = PurePosixPath(value)
    if path.is_absolute() or any(part in {"", ".", ".."} for part in value.split("/")):
        raise ValueError("Site path must remain inside the deployment")
    return path


def public_bytes(path, limit):
    url = PUBLIC_ROOT + quote(str(safe_path(path)), safe="/")
    with urlopen(url, timeout=45) as response:
        if response.status != 200 or response.geturl() != url:
            raise ValueError("Pages address redirected or changed; verify hosting before deployment")
        data = response.read(limit + 1)
        if len(data) > limit:
            raise ValueError("Public site file exceeds its declared limit")
        return data


def validate_inventory(data):
    entries = data.get("files") if isinstance(data, dict) else None
    if not isinstance(data, dict) or data.get("schema") != 1 or not isinstance(entries, list) or not 0 < len(entries) <= MAX_FILES:
        raise ValueError("Invalid site inventory")
    names = set()
    total = 0
    for entry in entries:
        if not isinstance(entry, dict):
            raise ValueError("Invalid site inventory entry")
        path = str(safe_path(entry.get("path")))
        size = entry.get("bytes")
        if path == INVENTORY or path in names or type(size) is not int or not 0 <= size <= MAX_FILE:
            raise ValueError("Duplicate, recursive or oversized site inventory entry")
        if not re.fullmatch(r"[0-9a-f]{64}", str(entry.get("sha256", ""))):
            raise ValueError("Invalid site file digest")
        names.add(path)
        total += size
    if total > MAX_TOTAL or "index.html" not in names:
        raise ValueError("Site inventory is too large or lacks its entry page")
    return entries


def restore_public(data, destination, fetch=public_bytes, only_review=False):
    entries = validate_inventory(data)
    if only_review:
        entries = [entry for entry in entries if entry["path"].startswith("review/")]

    def restore(entry):
        content = fetch(entry["path"], entry["bytes"])
        if len(content) != entry["bytes"] or digest(content) != entry["sha256"]:
            raise ValueError("Public site changed or download was damaged: " + entry["path"])
        path = destination / safe_path(entry["path"])
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(content)

    with ThreadPoolExecutor(max_workers=6) as executor:
        list(executor.map(restore, entries))


def extract_site(archive_path, destination):
    with tarfile.open(archive_path) as archive:
        members = archive.getmembers()
        if len(members) > MAX_FILES * 2:
            raise ValueError("Pages archive has too many entries")
        names = set()
        total = 0
        approved = []
        for member in members:
            name = member.name.removeprefix("./").rstrip("/")
            if name in {"", "."} and member.isdir():
                continue
            path = safe_path(name)
            if name in names or not (member.isfile() or member.isdir()):
                raise ValueError("Pages archive has duplicate paths or nonregular entries")
            names.add(name)
            if member.isfile():
                total += member.size
                if member.size > MAX_FILE or total > MAX_TOTAL:
                    raise ValueError("Pages archive is too large")
            approved.append((member, path))
        # Validate every member before creating any files; never follow archive links.
        for member, relative in approved:
            path = destination / relative
            if member.isdir():
                path.mkdir(parents=True, exist_ok=True)
            else:
                path.parent.mkdir(parents=True, exist_ok=True)
                if path.exists():
                    raise ValueError("Refusing to overwrite an existing extracted file")
                with archive.extractfile(member) as source, path.open("xb") as target:
                    shutil.copyfileobj(source, target)
    if not (destination / "index.html").is_file():
        raise ValueError("Pages artifact has no entry page")


def api(endpoint):
    result = subprocess.run(["gh", "api", f"repos/{REPOSITORY}/" + endpoint], check=True, capture_output=True, text=True)
    return json.loads(result.stdout)


def bootstrap_site(run_id, destination):
    if not re.fullmatch(r"[1-9][0-9]*", str(run_id)):
        raise ValueError("A numeric successful Pages run is required")
    run = api(f"actions/runs/{run_id}")
    if run.get("conclusion") != "success" or run.get("repository", {}).get("full_name") != REPOSITORY:
        raise ValueError("Bootstrap Pages run must be successful and belong to this repository")
    artifacts = [a for a in api(f"actions/runs/{run_id}/artifacts?per_page=100")["artifacts"] if a["name"] == "github-pages"]
    if len(artifacts) != 1 or artifacts[0].get("expired"):
        raise ValueError("Bootstrap Pages artifact is unavailable; choose its current successful deployment run")
    artifact = artifacts[0]
    if not 0 < artifact.get("size_in_bytes", 0) <= MAX_TOTAL:
        raise ValueError("Unexpected Pages artifact size")
    expected = str(artifact.get("digest", "")).removeprefix("sha256:")
    if not re.fullmatch(r"[0-9a-f]{64}", expected):
        raise ValueError("Pages artifact lacks a trustworthy digest")
    with tempfile.TemporaryDirectory(prefix="komaku-pages-base-") as temporary:
        folder = Path(temporary)
        archive = folder / "artifact.zip"
        with archive.open("wb") as output:
            subprocess.run(["gh", "api", f"repos/{REPOSITORY}/actions/artifacts/{artifact['id']}/zip"], stdout=output, check=True)
        if digest(archive.read_bytes()) != expected:
            raise ValueError("Downloaded Pages artifact does not match GitHub's digest")
        with zipfile.ZipFile(archive) as zipped:
            if zipped.namelist() != ["artifact.tar"] or zipped.getinfo("artifact.tar").file_size > MAX_TOTAL:
                raise ValueError("Unexpected Pages artifact wrapper")
            with zipped.open("artifact.tar") as source, (folder / "artifact.tar").open("wb") as target:
                shutil.copyfileobj(source, target)
        extract_site(folder / "artifact.tar", destination)
    # Never replace a site that moved on since this bootstrap artifact was created.
    for name in ["index.html", "web-release.json", "index.service.worker.js"]:
        path = destination / name
        if path.is_file() and public_bytes(name, path.stat().st_size) != path.read_bytes():
            raise ValueError("Bootstrap artifact is not the currently served site: " + name)
    return {"kind": "successful Pages artifact", "run_id": int(run_id), "artifact_id": artifact["id"], "artifact_sha256": expected}


def file_records(site):
    records = []
    for path in sorted(site.rglob("*")):
        if path.is_symlink():
            raise ValueError("A deployment cannot contain symlinks")
        if path.is_file() and path.relative_to(site).as_posix() != INVENTORY:
            records.append({"path": path.relative_to(site).as_posix(), "bytes": path.stat().st_size, "sha256": digest(path.read_bytes())})
    validate_inventory({"schema": 1, "files": records})
    return records


def add_review(site, preserved_from):
    manifest = json.loads((ROOT / "review/screens.json").read_text())
    version = manifest["version"]
    if not isinstance(version, str) or not VERSION.fullmatch(version):
        raise ValueError("Unsupported review version")
    before = {p["path"]: p["sha256"] for p in file_records(site) if not p["path"].startswith(f"review/{version}/") and p["path"] != "review/index.html"}
    with tempfile.TemporaryDirectory(prefix="komaku-review-build-") as temporary:
        built = Path(temporary) / "app"
        subprocess.run([sys.executable, str(ROOT / "scripts/build_screen_review.py"), "--output", str(built)], cwd=ROOT, check=True)
        target = site / "review" / version
        if target.exists():
            shutil.rmtree(target)
        shutil.copytree(built, target)
    redirect = site / "review/index.html"
    redirect.write_text(f'<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><meta http-equiv="refresh" content="0;url=./{version}/"><title>KŌMAKU screen review</title><p><a href="./{version}/">Open the KŌMAKU {version} screen review</a></p></html>\n')
    after = file_records(site)
    hashes = {p["path"]: p["sha256"] for p in after}
    if any(hashes.get(name) != value for name, value in before.items()):
        raise ValueError("Review deployment changed an existing game or older review file")
    record = {"schema": 1, "review_version": version, "review_path": f"review/{version}/", "review_source_commit": subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip(), "game_source_commit": manifest["sourceCommit"], "created_utc": datetime.datetime.now(datetime.timezone.utc).isoformat(), "preserved_from": preserved_from, "preserved_files_checked": len(before), "files": after}
    (site / INVENTORY).write_text(json.dumps(record, indent=2) + "\n")
    return record


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--output", type=Path, help="NEW site output directory; preserves the current public site")
    group.add_argument("--existing-site", type=Path, help="Add review to an intentionally prepared new game website")
    parser.add_argument("--bootstrap-run-id", default="43638541666")
    args = parser.parse_args()
    if args.output:
        site = args.output.resolve()
        site.mkdir(parents=True, exist_ok=False)
        try:
            data = json.loads(public_bytes(INVENTORY, 2 * 1024 * 1024))
        except HTTPError as error:
            if error.code != 404:
                raise
            preserved = bootstrap_site(args.bootstrap_run_id, site)
        else:
            restore_public(data, site)
            preserved = {"kind": "hash-verified public site inventory", "previous_review_commit": data.get("review_source_commit")}
    else:
        site = args.existing_site.resolve()
        if not site.is_dir() or not (site / "index.html").is_file():
            raise ValueError("The prepared game website is missing")
        preserved = {"kind": "explicitly prepared new game website"}
        # A later intentional game deployment must not break old annotated links.
        try:
            previous = json.loads(public_bytes(INVENTORY, 2 * 1024 * 1024))
        except HTTPError as error:
            if error.code != 404:
                raise
        else:
            restore_public(previous, site, only_review=True)
            preserved["review_inventory_commit"] = previous.get("review_source_commit")
    result = add_review(site, preserved)
    print(json.dumps({"review_url": PUBLIC_ROOT + result["review_path"], "preserved_files": result["preserved_files_checked"], "site_files": len(result["files"]), "source_commit": result["review_source_commit"]}, indent=2))


if __name__ == "__main__":
    main()
