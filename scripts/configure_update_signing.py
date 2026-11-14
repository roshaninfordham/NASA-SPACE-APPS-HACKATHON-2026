#!/usr/bin/env python3
"""Owner-only setup on a trusted laptop. Never print or commit a private key."""
import argparse
import base64
import json
import os
from pathlib import Path
import subprocess
import tempfile

from sign_update import public_der, validate_key_pair

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
PUBLIC_PATH = "game/updater/public_key.pem"


def github_public_key():
    result = subprocess.run(
        ["gh", "api", f"repos/{REPOSITORY}/contents/{PUBLIC_PATH}?ref=main"],
        text=True, capture_output=True,
    )
    if result.returncode:
        if "HTTP 404" in result.stderr:
            return None
        raise ValueError("Cannot check the repository trust root. Use an owner login on your own laptop, outside the managed cloud environment.")
    value = json.loads(result.stdout)
    if value.get("encoding") != "base64" or value.get("type") != "file":
        raise ValueError("Unexpected repository public-key response")
    return base64.b64decode(value["content"])


def check_remote_key(candidate, existing):
    if existing is None:
        return
    with tempfile.TemporaryDirectory(prefix="red-veil-public-check-") as temporary:
        remote = Path(temporary) / "public.pem"
        remote.write_bytes(existing)
        if public_der(candidate) != public_der(remote):
            raise ValueError("A different public key is already pinned on main. Refusing to replace its signing secret; plan an explicit key-rotation installer.")


def publish_public_key(content):
    # Initial create only. Existing roots were checked before any secret write.
    # A racing create gets HTTP 409/422 rather than overwriting another root.
    payload = {"message": "Configure public trust root for signed game updates", "branch": "main", "content": base64.b64encode(content).decode()}
    result = subprocess.run(["gh", "api", "--method", "PUT", f"repos/{REPOSITORY}/contents/{PUBLIC_PATH}", "--input", "-"], input=json.dumps(payload), text=True, capture_output=True)
    if result.returncode:
        raise ValueError("The public-key commit was not created. The local public key is safe to commit manually; do not publish an updater until it matches the configured secret.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-github-secret", action="store_true", help="Upload the private key directly to the encrypted repository Actions secret")
    parser.add_argument("--publish-public-key", action="store_true", help="Commit only the public key directly to main using the GitHub API")
    parser.add_argument("--key-directory", type=Path, default=Path.home() / ".config/red-veil/signing")
    args = parser.parse_args()
    folder = args.key_directory.expanduser().resolve()
    if folder.is_relative_to(ROOT):
        raise SystemExit("Private keys must be stored outside the repository")
    os.umask(0o077)
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    private = folder / "update-private.pem"
    if private.is_symlink():
        raise SystemExit("Private-key symlinks are not supported")
    try:
        if not private.exists():
            subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072", "-out", str(private)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        private.chmod(0o600)
        public = folder / "update-public.pem"
        subprocess.run(["openssl", "pkey", "-in", str(private), "-pubout", "-out", str(public)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        validate_key_pair(private, public)
        trusted = ROOT / PUBLIC_PATH
        if trusted.exists() and public_der(trusted) != public_der(public):
            raise ValueError("A different public key is pinned in this checkout. Refusing to replace it; plan an explicit key-rotation installer.")
        existing = github_public_key() if args.install_github_secret or args.publish_public_key else None
        check_remote_key(public, existing)
        if not args.publish_public_key:
            trusted.write_bytes(public.read_bytes())
        if args.publish_public_key:
            if existing is None:
                publish_public_key(public.read_bytes())
                print("Public trust root committed to main. Pull main before the next build.")
            else:
                print("The same public trust root is already on main; no extra commit was created.")
        if args.install_github_secret:
            # Commit/verify the public root first. A racing initial creation must
            # fail before a competing setup can overwrite the signing secret.
            pinned = github_public_key()
            if pinned is None:
                raise ValueError("Publish the public root first with --publish-public-key, or commit the public file and rerun before installing its signing secret.")
            check_remote_key(public, pinned)
            with private.open("rb") as source:
                subprocess.run(["gh", "secret", "set", "RED_VEIL_UPDATE_SIGNING_KEY", "--repo", REPOSITORY], stdin=source, check=True)
            print("Signing key uploaded directly into GitHub Actions secrets.")
        print(f"Public key: {public}")
        if args.publish_public_key:
            print(f"The repository public key is at {PUBLIC_PATH}; git pull receives it without an untracked local file.")
        else:
            print(f"Public checkout file ready to commit: {trusted}")
        print(f"Keep an encrypted backup of the private key outside Git: {private}")
        if not args.install_github_secret:
            print("Add the private file through repository Settings > Secrets and variables > Actions as RED_VEIL_UPDATE_SIGNING_KEY, or rerun with --install-github-secret. Never paste it into chat or an issue.")
        if not args.publish_public_key:
            print("Review and commit the public file, or rerun with --publish-public-key. Never commit the private key.")
    except (ValueError, OSError, subprocess.CalledProcessError) as error:
        raise SystemExit(f"Signing setup did not complete: {error}") from None


if __name__ == "__main__":
    main()
