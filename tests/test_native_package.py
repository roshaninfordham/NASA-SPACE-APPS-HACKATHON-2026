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
        native.validate_archive(self.archive(["KŌMAKU- Shield Protocol.app/Contents/MacOS/KŌMAKU- Shield Protocol", "DOWNLOADS.md"]))

    def distribution(self):
        name = "KOMAKU-Shield-Protocol-0.6.1-alpha.1-Windows-x64.zip"
        path = self.archive(["KOMAKU-Shield-Protocol.exe"])
        path.rename(self.folder / name)
        path = self.folder / name
        digest = native.digest(path)
        manifest = {"version": "0.6.1-alpha.1", "commit": "a" * 40,
                    "assets": [{"name": name, "bytes": path.stat().st_size, "sha256": digest}]}
        manifest_path = self.folder / "release-manifest.json"
        manifest_path.write_text(json.dumps(manifest))
        (self.folder / "SHA256SUMS.txt").write_text(f"{digest}  {name}\n")
        return path, native.digest(manifest_path)

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
        version = "0.6.1-alpha.1"
        marker = f"RED_VEIL_SCENE_READY version={version} nodes=123 HUD=(960, 540)"
        self.assertTrue(native.scene_ready(marker, version))
        self.assertFalse(native.scene_ready(marker, "0.6.1-alpha.10"))
        self.assertFalse(native.scene_ready(marker + "\nSCRIPT ERROR: missing scene", version))
        self.assertFalse(native.scene_ready(marker + "\nERROR: shader failed", version))


if __name__ == "__main__":
    unittest.main()
