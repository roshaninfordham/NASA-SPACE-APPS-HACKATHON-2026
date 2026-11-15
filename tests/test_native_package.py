"""Native download guards can be tested without running another OS's binary."""
import hashlib
import json
from pathlib import Path
import stat
import sys
import tempfile
import unittest
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import verify_native_package as native


class NativePackageTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)

    def archive(self, names):
        path = self.folder / "fixture.zip"
        with zipfile.ZipFile(path, "w") as archive:
            for name in names:
                archive.writestr(name, b"fixture")
        return path

    def test_reject_traversal_windows_aliases_and_normalization_collisions(self):
        for names in (["../escape"], ["/absolute"], ["C:/drive"], ["a\\escape"],
                      ["directory/../escape"], ["file:stream"], ["file."], ["file "],
                      ["con.txt"], ["nested/LPT1"], ["file", "FILE"],
                      ["KŌMAKU", "KO\u0304MAKU"], ["a//b"], ["a/./b"]):
            with self.subTest(names=names), self.assertRaises(ValueError):
                native.validate_archive(self.archive(names))

    def test_reject_symlinks_before_extraction(self):
        path = self.folder / "link.zip"
        with zipfile.ZipFile(path, "w") as archive:
            entry = zipfile.ZipInfo("link")
            entry.create_system = 3
            entry.external_attr = (stat.S_IFLNK | 0o777) << 16
            archive.writestr(entry, "../../outside")
        with self.assertRaises(ValueError):
            native.validate_archive(path)

    def test_unicode_app_and_regular_docs_are_accepted(self):
        for title in ["KŌMAKU- Shield Protocol", "KŌMAKU- Dust & Radiation"]:
            with self.subTest(title=title):
                native.validate_archive(self.archive([f"{title}.app/Contents/MacOS/{title}", "DOWNLOADS.md"]))

    def distribution(self, version="0.11.0-alpha.1"):
        stem = native.archive_stem(version)
        name = f"{stem}-{version}-Windows-x64.zip"
        path = self.archive([f"{stem}.exe"])
        path.rename(self.folder / name)
        path = self.folder / name
        digest = native.digest(path)
        manifest = {"version": version, "commit": "a" * 40,
                    "assets": [{"name": name, "bytes": path.stat().st_size, "sha256": digest}]}
        manifest_path = self.folder / "release-manifest.json"
        manifest_path.write_text(json.dumps(manifest))
        (self.folder / "SHA256SUMS.txt").write_text(f"{digest}  {name}\n")
        return path, native.digest(manifest_path)

    def test_historical_and_current_download_names_select_exact_versions(self):
        for version, prefix in [("0.4.0-alpha.1", "Red-Veil"), ("0.6.1-alpha.1", "KOMAKU-Shield-Protocol"), ("0.8.0-alpha.1", "KOMAKU-Shield-Protocol"), ("0.9.0-alpha.1", "KOMAKU-Dust-and-Radiation"), ("0.10.0-alpha.1", "KOMAKU-Dust-and-Radiation"), ("0.11.0-alpha.1", "KOMAKU-Dust-and-Radiation")]:
            with self.subTest(version=version):
                path, manifest_sha = self.distribution(version)
                selected, manifest, _ = native.select_archive(self.folder, "Windows", manifest_sha)
                self.assertEqual(selected, path)
                self.assertEqual(selected.name, f"{prefix}-{version}-Windows-x64.zip")
                self.assertEqual(manifest["version"], version)

    def test_manifest_brand_metadata_cannot_rebind_current_release_to_old_archive_name(self):
        path, _ = self.distribution()
        manifest_path = self.folder / "release-manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["package_stem"] = "KOMAKU-Shield-Protocol"
        wrong_name = path.name.replace("KOMAKU-Dust-and-Radiation", "KOMAKU-Shield-Protocol")
        path.rename(self.folder / wrong_name)
        manifest["assets"][0]["name"] = wrong_name
        manifest_path.write_text(json.dumps(manifest))
        digest = manifest["assets"][0]["sha256"]
        (self.folder / "SHA256SUMS.txt").write_text(f"{digest}  {wrong_name}\n")
        with self.assertRaisesRegex(ValueError, "exactly one native archive"):
            native.select_archive(self.folder, "Windows", native.digest(manifest_path))

    def test_archive_or_manifest_tampering_fails_before_launch(self):
        path, manifest_sha = self.distribution()
        selected, _, _ = native.select_archive(self.folder, "Windows", manifest_sha)
        self.assertEqual(selected, path)
        with self.assertRaisesRegex(ValueError, "Manifest checksum"):
            native.select_archive(self.folder, "Windows", "b" * 64)
        path.write_bytes(path.read_bytes() + b"tampered")
        with self.assertRaisesRegex(ValueError, "Archive checksum"):
            native.select_archive(self.folder, "Windows", manifest_sha)

    def test_missing_or_duplicate_checksum_rejected(self):
        self.distribution()
        checksums = self.folder / "SHA256SUMS.txt"
        line = checksums.read_text()
        for contents in ("", line + line):
            checksums.write_text(contents)
            with self.assertRaisesRegex(ValueError, "Checksum list"):
                native.select_archive(self.folder, "Windows")

    def test_scene_marker_requires_exact_version_and_no_engine_errors(self):
        for version in ["0.6.1-alpha.1", "0.8.0-alpha.1", "0.9.0-alpha.1", "0.10.0-alpha.1", "0.11.0-alpha.1"]:
            with self.subTest(version=version):
                marker = f"RED_VEIL_SCENE_READY version={version} nodes=123 HUD=(960, 540)"
                self.assertTrue(native.scene_ready(marker, version))
                self.assertFalse(native.scene_ready(marker, version + "0"))
                self.assertFalse(native.scene_ready(marker + "\nSCRIPT ERROR: missing scene", version))
                self.assertFalse(native.scene_ready(marker + "\nERROR: shader failed", version))


if __name__ == "__main__":
    unittest.main()
