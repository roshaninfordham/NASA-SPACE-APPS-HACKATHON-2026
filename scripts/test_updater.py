#!/usr/bin/env python3
"""Exercise the production Godot verifier with disposable OpenSSL signing keys."""
import hashlib
import json
import os
from pathlib import Path
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent


def run(*args):
    subprocess.run(args, check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)


def main():
    with tempfile.TemporaryDirectory(prefix="red-veil-signing-test-") as temporary:
        folder = Path(temporary)
        key = folder / "private.pem"
        run("openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", "rsa_keygen_bits:3072", "-out", str(key))
        run("openssl", "pkey", "-in", str(key), "-pubout", "-out", str(folder / "public.pem"))
        pack = b"Disposable test bytes, never a published resource pack."
        (folder / "pack.pck").write_bytes(pack)
        (folder / "altered.pck").write_bytes(b"X" + pack[1:])
        (folder / "short.pck").write_bytes(pack[:-1])
        # Exercise the real release signing command as well as the runtime verifier.
        run("python3", str(ROOT / "scripts/sign_update.py"), "--version", "0.2.0-alpha.3", "--pack", str(folder / "pack.pck"), "--private-key", str(key), "--public-key", str(folder / "public.pem"), "--output", str(folder))
        base = json.loads((folder / "update-manifest.json").read_text())
        assert base["pack_sha256"] == hashlib.sha256(pack).hexdigest()
        cases = []

        def case(name, changes=None, error=None, corrupt=False):
            raw = (json.dumps(base | (changes or {}), sort_keys=True) + "\n").encode()
            manifest = folder / f"{name}.json"
            signature = folder / f"{name}.sig"
            manifest.write_bytes(raw)
            run("openssl", "dgst", "-sha256", "-sign", str(key), "-out", str(signature), str(manifest))
            if corrupt:
                manifest.write_bytes(raw + b" ")
            cases.append({"name": name, "ok": error is None, "error": error})

        case("valid")
        case("tampered", error="signature_invalid", corrupt=True)
        for name, changes, error in [
            ("wrong-repository", {"repository": "attacker/repo"}, "wrong_repository"),
            ("wrong-engine", {"engine": "4.7.0"}, "engine_update_required"),
            ("wrong-runtime", {"runtime_contract": "red-veil-desktop-v2"}, "runtime_update_required"),
            ("newline-version", {"version": "0.4.0\n"}, "version_invalid"),
            ("schema", {"schema": 2}, "unsupported_schema"),
            ("downgrade", {"version": "0.1.0"}, "not_newer"),
            ("same-version", {"version": "0.2.0-alpha.2"}, "not_newer"),
            ("path-version", {"version": "../../evil"}, "version_invalid"),
            ("bad-type", {"version": []}, "version_invalid"),
            ("pack-name", {"pack_file": "../evil.pck"}, "pack_name_invalid"),
            ("oversize", {"pack_bytes": 128 * 1024 * 1024 + 1}, "pack_size_invalid"),
            ("fractional-size", {"pack_bytes": 1.5}, "pack_size_invalid"),
            ("negative-size", {"pack_bytes": -1}, "pack_size_invalid"),
            ("digest", {"pack_sha256": "g" * 64}, "digest_invalid"),
            ("source", {"source_commit": "z" * 40}, "source_invalid"),
        ]:
            case(name, changes, error)
        (folder / "cases.json").write_text(json.dumps(cases))
        result = subprocess.run(["godot", "--headless", "--path", "game", "--script", "res://tests/updater_test.gd"], cwd=ROOT, env=os.environ | {"RED_VEIL_TEST_FIXTURES": temporary}, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        print(result.stdout)
        if result.returncode or "SCRIPT ERROR:" in result.stdout:
            raise SystemExit(result.returncode or 1)


if __name__ == "__main__":
    main()
