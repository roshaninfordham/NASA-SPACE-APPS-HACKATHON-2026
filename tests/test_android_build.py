"""Android scaffold tests do not create production keys or publish an APK."""
import io
from pathlib import Path
import stat
import sys
import tempfile
import unittest
from unittest.mock import patch
import zipfile

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import build_android
import install_android_tools


class AndroidBuildTest(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory(prefix="red-veil-android-test-")
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.preset = (build_android.ROOT / "game/export_presets.android.cfg").read_text()

    def test_internal_build_cannot_use_production_package_identity(self):
        internal = build_android.configure_preset(self.preset, "0.4.0-alpha.1", 40001, False)
        self.assertIn('package/unique_name="io.github.roshaninfordham.redveil.internal"', internal)
        self.assertIn('version/name="0.4.0-alpha.1-internal"', internal)
        release = build_android.configure_preset(self.preset, "0.4.0-alpha.1", 40002, True)
        self.assertIn('package/unique_name="io.github.roshaninfordham.redveil"', release)
        self.assertNotIn('redveil.internal', release)
        self.assertIn('version/code=40002', release)

    def test_version_and_code_must_be_valid(self):
        for version in ['0.4.0\npackage/signed=false', '../version', '']:
            with self.assertRaises(ValueError):
                build_android.configure_preset(self.preset, version, 1, True)
        for code in [0, -1, 2100000001]:
            with self.assertRaises(ValueError):
                build_android.configure_preset(self.preset, '0.4.0', code, True)

    def test_missing_or_duplicate_template_identity_fails(self):
        with self.assertRaises(ValueError):
            build_android.configure_preset(self.preset + '\nversion/code=2\n', '0.4.0', 3, True)
        with self.assertRaises(ValueError):
            build_android.configure_preset(self.preset.replace('version/code=1', ''), '0.4.0', 3, True)

    def make_zip(self, name, mode=stat.S_IFREG | 0o755):
        path = self.root / 'fixture.zip'
        with zipfile.ZipFile(path, 'w') as archive:
            entry = zipfile.ZipInfo(name)
            entry.external_attr = mode << 16
            archive.writestr(entry, b'test tool')
        return path

    def test_sdk_extraction_preserves_executable_tool(self):
        archive = self.make_zip('sdk/bin/tool')
        install_android_tools.extract_package(archive, 'sdk', self.root / 'out')
        self.assertEqual((self.root / 'out/bin/tool').read_bytes(), b'test tool')
        self.assertTrue((self.root / 'out/bin/tool').stat().st_mode & 0o100)

    def test_sdk_traversal_absolute_path_and_symlink_are_rejected(self):
        for name in ['sdk/../../outside', '/outside', 'unexpected/bin/tool']:
            with self.assertRaises(ValueError):
                install_android_tools.extract_package(self.make_zip(name), 'sdk', self.root / 'out')
        with self.assertRaises(ValueError):
            install_android_tools.extract_package(self.make_zip('sdk/link', stat.S_IFLNK | 0o777), 'sdk', self.root / 'out')
        self.assertFalse((self.root / 'outside').exists())

    def test_release_certificate_must_keep_approved_app_identity(self):
        fingerprint = "ab" * 32
        build_android.verify_certificate_identity(fingerprint, ":".join(["AB"] * 32))
        with self.assertRaises(ValueError):
            build_android.verify_certificate_identity(fingerprint, "cd" * 32)
        with self.assertRaises(ValueError):
            build_android.verify_certificate_identity(fingerprint, "")

    def test_unverified_signature_has_no_identity(self):
        with patch.object(build_android, 'run', return_value='No verified signer'):
            with self.assertRaises(ValueError):
                build_android.signed_identity('apksigner', 'game.apk', {})

    def test_source_archive_cannot_escape_isolation(self):
        data = io.BytesIO()
        with zipfile.ZipFile(data, 'w') as archive:
            archive.writestr('game/../../outside', b'no')
        with patch('subprocess.check_output', return_value=data.getvalue()):
            with self.assertRaises(ValueError):
                build_android.source_project(self.root, 'a' * 40)
        self.assertFalse((self.root / 'outside').exists())


if __name__ == '__main__':
    unittest.main()
