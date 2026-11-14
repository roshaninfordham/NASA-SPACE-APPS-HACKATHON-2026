#!/usr/bin/env python3
"""Sign an exact content manifest and verify it against the installer trust root."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
ENGINE = "4.6.3"
RUNTIME_CONTRACT = "red-veil-desktop-v1"
MAX_PACK_BYTES = 128 * 1024 * 1024
VERSION = re.compile(r"(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})\.(0|[1-9][0-9]{0,8})(?:-alpha\.(0|[1-9][0-9]{0,8}))?")


def valid_version(value):
    return isinstance(value, str) and len(value) <= 64 and VERSION.fullmatch(value) is not None


def openssl(*arguments):
    result = subprocess.run(["openssl", *map(str, arguments)], capture_output=True)
    if result.returncode:
        # Never include key input, command output or environment in errors.
        raise ValueError("OpenSSL could not validate or sign with the supplied key")
    return result.stdout


def public_der(public_key):
    text = openssl("rsa", "-pubin", "-in", public_key, "-text", "-noout").decode()
    if not re.search(r"Public-Key:\s*\(3072 bit\)", text):
        raise ValueError("The update trust root must be a 3072-bit RSA public key")
    return openssl("rsa", "-pubin", "-in", public_key, "-pubout", "-outform", "DER")


def validate_key_pair(private_key, public_key):
    if not Path(public_key).is_file():
        raise ValueError("A committed updater public key is required before signing")
    expected = public_der(public_key)
    actual = openssl("pkey", "-in", private_key, "-pubout", "-outform", "DER")
    if actual != expected:
        raise ValueError("Signing key does not match the public key pinned in the installer")


def sign_pack(version, pack, private_key, public_key, output, source_commit):
    if not valid_version(version):
        raise ValueError("Unsupported release version")
    if not re.fullmatch(r"[0-9a-f]{40}", source_commit):
        raise ValueError("An exact source commit is required")
    pack, output = Path(pack), Path(output)
    size = pack.stat().st_size
    if not 0 < size <= MAX_PACK_BYTES:
        raise ValueError("Update pack exceeds the supported size")
    validate_key_pair(private_key, public_key)
    with pack.open("rb") as source:
        digest = hashlib.file_digest(source, "sha256").hexdigest()
    manifest = {
        "schema": 1, "repository": REPOSITORY, "version": version,
        "engine": ENGINE, "runtime_contract": RUNTIME_CONTRACT, "pack_file": "red-veil-content.pck",
        "pack_bytes": size, "pack_sha256": digest, "source_commit": source_commit,
    }
    output.mkdir(parents=True, exist_ok=True)
    path = output / "update-manifest.json"
    signature = output / "update-manifest.sig"
    path.write_bytes((json.dumps(manifest, sort_keys=True, separators=(",", ":")) + "\n").encode())
    try:
        openssl("dgst", "-sha256", "-sign", private_key, "-out", signature, path)
        openssl("dgst", "-sha256", "-verify", public_key, "-signature", signature, path)
    except ValueError:
        signature.unlink(missing_ok=True)
        raise
    return manifest


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--pack", required=True, type=Path)
    parser.add_argument("--private-key", required=True, type=Path)
    parser.add_argument("--public-key", type=Path, default=ROOT / "game/updater/public_key.pem")
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True).strip()
    try:
        sign_pack(args.version, args.pack, args.private_key, args.public_key, args.output, commit)
    except (ValueError, OSError) as error:
        raise SystemExit(str(error)) from None
    print(f"Signed and verified update manifest for {args.version}.")


if __name__ == "__main__":
    main()
