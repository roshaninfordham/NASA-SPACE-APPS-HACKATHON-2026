"""Release security tests use only temporary files/keys and mocked GitHub reads."""
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
import re
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import build_game
import configure_update_signing
import sign_update
import branding
import verify_native_update_acceptance as acceptance
import zipfile


class ReleaseToolsTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.keys = tempfile.TemporaryDirectory(prefix="red-veil-release-tests-")
        cls.folder = Path(cls.keys.name)
        for name, bits in [("first", 3072), ("second", 3072), ("weak", 2048)]:
            subprocess.run(["openssl", "genpkey", "-algorithm", "RSA", "-pkeyopt", f"rsa_keygen_bits:{bits}", "-out", str(cls.folder / f"{name}-private.pem")], check=True, capture_output=True)
            subprocess.run(["openssl", "pkey", "-in", str(cls.folder / f"{name}-private.pem"), "-pubout", "-out", str(cls.folder / f"{name}-public.pem")], check=True, capture_output=True)

    @classmethod
    def tearDownClass(cls):
        cls.keys.cleanup()

    def setUp(self):
        self.work = tempfile.TemporaryDirectory(prefix="red-veil-release-output-")
        self.output = Path(self.work.name)
        self.addCleanup(self.work.cleanup)
        self.pack = self.output / "red-veil-content.pck"
        self.pack.write_bytes(b"isolated signing test fixture")
        self.version = "0.4.0-alpha.1"
        self.commit = "a" * 40
        self.private = self.folder / "first-private.pem"
        self.public = self.folder / "first-public.pem"

    def unsigned_manifest(self):
        entries = []
        for name in sorted(build_game.expected_names(self.version, False)):
            file = self.output / name
            file.write_bytes(name.encode())
            entries.append(build_game.describe_asset(file))
        return {"version": self.version, "commit": self.commit, "signed_content_updates": False, "assets": entries}

    def test_brand_archive_boundary_and_manifest_cannot_override_names(self):
        for version in ["0.1.0", "0.4.0-alpha.1", "0.4.99"]:
            self.assertEqual(branding.archive_name(version, "Web"), f"Red-Veil-{version}-Web.zip")
        for version in ["0.5.0-alpha.1", "0.5.0", "0.8.0-alpha.1", "0.8.99"]:
            self.assertEqual(branding.archive_name(version, "Web"), f"KOMAKU-Shield-Protocol-{version}-Web.zip")
        for version in ["0.9.0-alpha.1", "0.9.0", "0.10.0", "1.0.0"]:
            self.assertEqual(branding.archive_name(version, "Web"), f"KOMAKU-Dust-and-Radiation-{version}-Web.zip")
        for version in ["../0.4.0", "0.04.0", "0.4.0-beta.1"]:
            with self.assertRaises(ValueError):
                branding.archive_name(version, "Web")
        for version, wrong_stem in [("0.5.0-alpha.1", "Red-Veil"), ("0.8.0-alpha.1", "KOMAKU-Dust-and-Radiation"), ("0.9.0-alpha.1", "KOMAKU-Shield-Protocol")]:
            with self.subTest(version=version):
                self.version = version
                manifest = self.unsigned_manifest()
                with patch.object(build_game, "OUT", self.output):
                    build_game.stage_distribution(manifest)
                    manifest["package_stem"] = wrong_stem
                    manifest["assets"][0]["name"] = manifest["assets"][0]["name"].replace(branding.archive_stem(version), wrong_stem)
                    with self.assertRaisesRegex(ValueError, "exact declared"):
                        build_game.validate_release_manifest(manifest, self.version, self.commit)

    def test_native_acceptance_reads_historical_and_renamed_artifact_sets(self):
        for version in ["0.4.0-alpha.1", "0.5.0-alpha.1", "0.7.0-alpha.1", "0.8.0-alpha.1", "0.9.0-alpha.1"]:
            entries = []
            for name in sorted(build_game.expected_names(version, True)):
                path = self.output / name
                if name.endswith(".zip"):
                    with zipfile.ZipFile(path, "w") as archive:
                        archive.writestr("fixture.txt", version)
                else:
                    path.write_bytes(b"independent signature verification follows artifact validation")
                entries.append(build_game.describe_asset(path))
            manifest = {"version": version, "commit": self.commit, "engine": "Godot 4.6.3", "signed_content_updates": True, "assets": entries}
            (self.output / "release-manifest.json").write_text(json.dumps(manifest))
            (self.output / "SHA256SUMS.txt").write_text("".join(f"{entry['sha256']}  {entry['name']}\n" for entry in entries))
            self.assertEqual(acceptance.validate_artifacts(self.output, self.commit)["version"], version)

    def test_science_guide_is_required_only_from_its_first_release(self):
        self.assertFalse(branding.supplemental_asset_names("0.6.1-alpha.1"))
        self.assertEqual(branding.supplemental_asset_names("0.7.0-alpha.1"), {"KOMAKU-Shield-Protocol-0.7.0-alpha.1-Science-Guide.pdf"})
        self.assertEqual(branding.supplemental_asset_names("0.8.0-alpha.1"), {"KOMAKU-Shield-Protocol-0.8.0-alpha.1-Science-Guide.pdf"})
        self.assertEqual(branding.supplemental_asset_names("0.9.0-alpha.1"), {"KOMAKU-Dust-and-Radiation-0.9.0-alpha.1-Science-Guide.pdf"})
        for version in ["0.7.0-alpha.1", "0.8.0-alpha.1", "0.9.0-alpha.1"]:
            with self.subTest(version=version):
                self.version = version
                manifest = self.unsigned_manifest()
                manifest["assets"] = [a for a in manifest["assets"] if not a["name"].endswith(".pdf")]
                with patch.object(build_game, "OUT", self.output), self.assertRaisesRegex(ValueError, "exact declared"):
                    build_game.validate_release_manifest(manifest, self.version, self.commit)

    def test_signed_manifest_verifies_and_binds_exact_bytes(self):
        manifest = sign_update.sign_pack(self.version, self.pack, self.private, self.public, self.output, self.commit)
        self.assertEqual(manifest["source_commit"], self.commit)
        self.assertEqual(manifest["pack_sha256"], hashlib.sha256(self.pack.read_bytes()).hexdigest())
        self.assertEqual(manifest["pack_bytes"], self.pack.stat().st_size)
        sign_update.openssl("dgst", "-sha256", "-verify", self.public, "-signature", self.output / "update-manifest.sig", self.output / "update-manifest.json")
        with (self.output / "update-manifest.json").open("ab") as target:
            target.write(b" ")
        with self.assertRaises(ValueError):
            sign_update.openssl("dgst", "-sha256", "-verify", self.public, "-signature", self.output / "update-manifest.sig", self.output / "update-manifest.json")

    def test_mismatched_key_fails_before_creating_signature(self):
        with self.assertRaisesRegex(ValueError, "does not match"):
            sign_update.sign_pack(self.version, self.pack, self.private, self.folder / "second-public.pem", self.output, self.commit)
        self.assertFalse((self.output / "update-manifest.sig").exists())

    def test_weak_or_missing_trust_root_rejected(self):
        with self.assertRaisesRegex(ValueError, "3072-bit"):
            sign_update.validate_key_pair(self.folder / "weak-private.pem", self.folder / "weak-public.pem")
        with self.assertRaisesRegex(ValueError, "public key is required"):
            sign_update.validate_key_pair(self.private, self.output / "missing.pem")

    def test_signer_and_baseline_verifier_runtime_contract_match(self):
        verifier = (build_game.ROOT / "game/updater/verifier.gd").read_text()
        declared = re.search(r'const RUNTIME_CONTRACT\s*(?::=|=)\s*"([^"]+)"', verifier)
        self.assertIsNotNone(declared, "Baseline verifier must pin an explicit runtime contract")
        self.assertEqual(declared[1], sign_update.RUNTIME_CONTRACT)

    def test_runtime_version_bounds_match_signer(self):
        for value in ["999999999.0.0", "0.4.0-alpha.999999999", "0.4.0"]:
            self.assertTrue(sign_update.valid_version(value), value)
        for value in ["1000000000.0.0", "0.4.0-alpha.1000000000", "0.04.0", "0.4.0-alpha.01", "../bad", "0.4.0-beta.1"]:
            self.assertFalse(sign_update.valid_version(value), value)

    def test_private_key_temp_file_cleanup_after_failure(self):
        with self.assertRaises(RuntimeError):
            with build_game.signing_key(None, self.private.read_text()) as private:
                self.assertFalse(private.is_relative_to(build_game.ROOT))
                self.assertEqual(private.stat().st_mode & 0o777, 0o600)
                self.assertEqual(private.read_bytes(), self.private.read_bytes())
                raise RuntimeError("simulated export failure")
        self.assertFalse(private.exists())
        with self.assertRaisesRegex(ValueError, "missing"):
            with build_game.signing_key(None, ""):
                self.fail("Missing signing secret must fail closed")

    def test_private_key_cannot_live_in_checkout(self):
        with self.assertRaisesRegex(ValueError, "outside"):
            with build_game.signing_key(build_game.ROOT / "secret.pem", ""):
                self.fail("Repository key path must be rejected")

    def test_owner_setup_refuses_remote_trust_root_rotation(self):
        configure_update_signing.check_remote_key(self.public, self.public.read_bytes())
        with self.assertRaisesRegex(ValueError, "different public key"):
            configure_update_signing.check_remote_key(self.public, (self.folder / "second-public.pem").read_bytes())

    def test_owner_creates_and_rechecks_public_root_before_secret_upload(self):
        checkout = self.output / "checkout"
        (checkout / "game/updater").mkdir(parents=True)
        key_dir = self.output / "owner-keys"
        key_dir.mkdir()
        (key_dir / "update-private.pem").write_bytes(self.private.read_bytes())
        calls = []
        real_run = subprocess.run

        def execute(command, **kwargs):
            if command[:3] == ["gh", "secret", "set"]:
                calls.append("secret")
                return subprocess.CompletedProcess(command, 0)
            return real_run(command, **kwargs)

        def publish(content):
            self.assertEqual(content, self.public.read_bytes())
            calls.append("public")

        def remote():
            calls.append("read")
            return None if calls.count("read") == 1 else self.public.read_bytes()

        arguments = ["setup", "--key-directory", str(key_dir), "--publish-public-key", "--install-github-secret"]
        old_umask = os.umask(0o077)
        try:
            with patch.object(configure_update_signing, "ROOT", checkout), patch.object(sys, "argv", arguments), patch.object(configure_update_signing, "github_public_key", side_effect=remote), patch.object(configure_update_signing, "publish_public_key", side_effect=publish), patch.object(subprocess, "run", side_effect=execute), redirect_stdout(io.StringIO()) as output:
                configure_update_signing.main()
            self.assertEqual(calls, ["read", "public", "read", "secret"])
            self.assertFalse((checkout / "game/updater/public_key.pem").exists(), "API publication must not leave an untracked file blocking git pull")
            self.assertNotIn("BEGIN PRIVATE KEY", output.getvalue())
            calls.clear()
            with patch.object(configure_update_signing, "ROOT", checkout), patch.object(sys, "argv", arguments), patch.object(configure_update_signing, "github_public_key", return_value=None), patch.object(configure_update_signing, "publish_public_key", side_effect=ValueError("Racing initial public key creation")), patch.object(subprocess, "run", side_effect=execute), redirect_stdout(io.StringIO()):
                with self.assertRaises(SystemExit):
                    configure_update_signing.main()
            self.assertNotIn("secret", calls)
        finally:
            os.umask(old_umask)

    def test_unsigned_distribution_excludes_stale_signed_files_and_private_keys(self):
        manifest = self.unsigned_manifest()
        for name in ["update-manifest.json", "update-manifest.sig", "private.pem"]:
            (self.output / name).write_bytes(b"stale output never distributed")
        distribution = self.output / "distribution"
        distribution.mkdir()
        (distribution / "private.pem").write_bytes(b"stale private fixture")
        with patch.object(build_game, "OUT", self.output):
            build_game.stage_distribution(manifest)
        expected = build_game.expected_names(self.version, False) | build_game.METADATA_ASSETS
        self.assertEqual({p.name for p in distribution.iterdir()}, expected)
        self.assertNotIn("red-veil-content.pck", (distribution / "SHA256SUMS.txt").read_text())

    def test_signed_distribution_checksums_include_all_update_assets(self):
        manifest = self.unsigned_manifest()
        sign_update.sign_pack(self.version, self.pack, self.private, self.public, self.output, self.commit)
        manifest["signed_content_updates"] = True
        manifest["assets"].extend(build_game.describe_asset(self.output / name) for name in sorted(build_game.UPDATE_ASSETS))
        with patch.object(build_game, "OUT", self.output):
            build_game.stage_distribution(manifest)
        distribution = self.output / "distribution"
        self.assertEqual(len(list(distribution.iterdir())), 9)
        checksums = (distribution / "SHA256SUMS.txt").read_text()
        for entry in manifest["assets"]:
            self.assertIn(f"{entry['sha256']}  {entry['name']}\n", checksums)

    def test_changed_asset_and_arbitrary_names_are_rejected(self):
        manifest = self.unsigned_manifest()
        with patch.object(build_game, "OUT", self.output):
            file = self.output / manifest["assets"][0]["name"]
            file.write_bytes(b"changed after verification")
            with self.assertRaisesRegex(ValueError, "changed"):
                build_game.validate_release_manifest(manifest, self.version, self.commit)
            manifest["assets"][0]["name"] = "../private.pem"
            with self.assertRaisesRegex(ValueError, "exact declared"):
                build_game.validate_release_manifest(manifest, self.version, self.commit)

    def test_source_mismatch_rejected(self):
        with patch.object(build_game, "OUT", self.output):
            with self.assertRaisesRegex(ValueError, "version/source"):
                build_game.validate_release_manifest(self.unsigned_manifest(), self.version, "b" * 40)

    def test_draft_lookup_uses_validated_numeric_release_api_id(self):
        release = {"id": 12345, "draft": True, "tag_name": "v" + self.version}
        result = subprocess.CompletedProcess([], 0, stdout=f"https://api.github.com/repos/{build_game.REPOSITORY}/releases/12345\n")
        with patch.object(subprocess, "run", return_value=result) as command, patch.object(build_game, "gh_api", return_value=release) as github:
            self.assertEqual(build_game.read_release(self.version), release)
        self.assertEqual(command.call_args.args[0][:4], ["gh", "release", "view", "v" + self.version])
        github.assert_called_once_with(f"repos/{build_game.REPOSITORY}/releases/12345")

    def test_draft_lookup_rejects_arbitrary_api_urls_before_querying_them(self):
        urls = ["https://example.com/releases/12345", "https://api.github.com/repos/other/repo/releases/12345", f"https://api.github.com/repos/{build_game.REPOSITORY}/releases/tags/v{self.version}", f"https://api.github.com/repos/{build_game.REPOSITORY}/releases/12345?redirect=1"]
        for url in urls:
            with self.subTest(url=url), patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 0, stdout=url)), patch.object(build_game, "gh_api") as github, self.assertRaisesRegex(ValueError, "unexpected API URL"):
                build_game.read_release(self.version)
            github.assert_not_called()

    def test_failed_draft_lookup_does_not_try_an_api_mutation(self):
        with patch.object(subprocess, "run", return_value=subprocess.CompletedProcess([], 1, stdout="", stderr="not found")) as command, patch.object(build_game, "gh_api") as github, self.assertRaisesRegex(ValueError, "no publication attempted"):
            build_game.read_release(self.version)
        self.assertEqual(command.call_args.args[0][:3], ["gh", "release", "view"])
        github.assert_not_called()

    def test_draft_lookup_checks_api_response_identity(self):
        result = subprocess.CompletedProcess([], 0, stdout=f"https://api.github.com/repos/{build_game.REPOSITORY}/releases/12345")
        with patch.object(subprocess, "run", return_value=result), patch.object(build_game, "gh_api", return_value={"id": 99999}), self.assertRaisesRegex(ValueError, "numeric ID"):
            build_game.read_release(self.version)

    def test_published_release_and_wrong_tag_cannot_be_modified(self):
        with patch.object(build_game, "gh_api") as github:
            for release in [{"draft": False, "tag_name": "v" + self.version}, {"draft": True, "tag_name": "v0.1.0"}]:
                with self.assertRaisesRegex(ValueError, "matching existing draft"):
                    build_game.validate_release_binding(release, self.version, self.commit)
            github.assert_not_called()

    def test_draft_target_and_existing_tag_must_match_build_commit(self):
        release = {"draft": True, "tag_name": "v" + self.version, "target_commitish": self.commit}
        with patch.object(build_game, "gh_api", side_effect=[{"sha": self.commit}, None]):
            build_game.validate_release_binding(release, self.version, self.commit)
        with patch.object(build_game, "gh_api", return_value={"sha": "b" * 40}):
            with self.assertRaisesRegex(ValueError, "target differs"):
                build_game.validate_release_binding(release, self.version, self.commit)
        with patch.object(build_game, "gh_api", side_effect=[{"sha": self.commit}, {"object": {"type": "tag"}}, {"sha": "b" * 40}]):
            with self.assertRaisesRegex(ValueError, "tag differs"):
                build_game.validate_release_binding(release, self.version, self.commit)

    def test_output_directory_symlink_is_not_followed(self):
        link = self.output / "distribution"
        link.symlink_to(self.folder, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlinks"):
            build_game.clean_generated_folder(link)
        self.assertTrue(self.private.exists())


if __name__ == "__main__":
    unittest.main()
