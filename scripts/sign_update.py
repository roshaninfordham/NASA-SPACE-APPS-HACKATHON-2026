#!/usr/bin/env python3
"""Create a detached RSA/SHA-256 signature for a content-pack manifest."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--version", required=True)
    parser.add_argument("--pack", required=True, type=Path)
    parser.add_argument("--private-key", required=True, type=Path)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    if not re.fullmatch(r"(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(?:-alpha\.(0|[1-9][0-9]*))?", args.version):
        raise SystemExit("Invalid version")
    size = args.pack.stat().st_size
    if not 0 < size <= 128 * 1024 * 1024:
        raise SystemExit("Update pack exceeds the supported size")
    with args.pack.open("rb") as file:
        digest = hashlib.file_digest(file, "sha256").hexdigest()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    manifest = {"schema": 1, "repository": "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026", "version": args.version, "engine": "4.6.3", "pack_file": "red-veil-content.pck", "pack_bytes": size, "pack_sha256": digest, "source_commit": commit}
    args.output.mkdir(parents=True, exist_ok=True)
    path = args.output / "update-manifest.json"
    path.write_bytes((json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode())
    signature = args.output / "update-manifest.sig"
    subprocess.run(["openssl", "dgst", "-sha256", "-sign", str(args.private_key), "-out", str(signature), str(path)], check=True)
    print(f"Signed update manifest for {args.version}; private key contents were not logged.")


if __name__ == "__main__":
    main()
