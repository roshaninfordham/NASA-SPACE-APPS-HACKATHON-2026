#!/usr/bin/env python3
"""Owner-run setup. Generate a private key locally; never print or commit it."""
import argparse
import os
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parent.parent
REPOSITORY = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--install-github-secret", action="store_true", help="Encrypt/upload the key directly with an authenticated owner gh CLI")
    parser.add_argument("--key-directory", type=Path, default=Path.home() / ".config/red-veil/signing")
    args = parser.parse_args()
    folder = args.key_directory.expanduser().resolve()
    if folder.is_relative_to(ROOT):
        raise SystemExit("Private keys must be stored outside the repository")
    folder.mkdir(parents=True, exist_ok=True, mode=0o700)
    private = folder / "update-private.pem"
    os.umask(0o077)
    if not private.exists():
        subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072", "-out", str(private)], check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    private.chmod(0o600)
    public = folder / "update-public.pem"
    subprocess.run(["openssl", "pkey", "-in", str(private), "-pubout", "-out", str(public)], check=True)
    trusted = ROOT / "game/updater/public_key.pem"
    if trusted.exists() and trusted.read_bytes() != public.read_bytes():
        raise SystemExit("A different public key is already pinned. Plan an explicit key-rotation release; refusing to replace it.")
    trusted.write_bytes(public.read_bytes())
    if args.install_github_secret:
        with private.open("rb") as source:
            subprocess.run(["gh", "secret", "set", "RED_VEIL_UPDATE_SIGNING_KEY", "--repo", REPOSITORY], stdin=source, check=True)
        print("Signing key installed directly into GitHub Actions secrets.")
    print(f"Public key ready to review and commit: {trusted}")
    print(f"Keep the private key and its backup secure outside Git: {private}")
    if not args.install_github_secret:
        print("Owner action: add the private file contents to repository Settings > Secrets and variables > Actions as RED_VEIL_UPDATE_SIGNING_KEY. Never paste it into chat or a public issue.")


if __name__ == "__main__":
    main()
