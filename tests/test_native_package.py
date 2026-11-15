"""Native download guards can be tested without running another OS's binary."""
import hashlib
from contextlib import ExitStack, contextmanager
import io
import json
import os
from pathlib import Path
import stat
import sys
import tempfile
import unittest
import zipfile
from unittest.mock import Mock, patch

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

    @staticmethod
    def sharing_error():
        error = PermissionError("The test executable is still in use")
        error.winerror = 32
        return error

    def native_main_fixture(self, workspace_cleanup_error=None, profile_cleanup_error=None,
                            context_exit_error=None, startup_error=None,
                            existing_profile=False, report_write_error=None):
        """Run the real verifier flow; only native process/OS calls are fixtures."""
        self.distribution("0.11.0-alpha.1")
        report_path = self.folder / "native-launch.json"
        profile = self.folder / "owned-test-profile"
        if existing_profile:
            profile.mkdir()
            (profile / "player-data.json").write_text("existing player data must remain")
        temporary_path = self.folder / "owned-workspace"
        temporary_path.mkdir()
        real_rmtree = native.shutil.rmtree
        real_write_text = Path.write_text

        def write_text(path, *args, **kwargs):
            if path == report_path and report_write_error is not None:
                raise report_write_error
            return real_write_text(path, *args, **kwargs)

        def clean_workspace():
            if workspace_cleanup_error is not None:
                raise workspace_cleanup_error
            real_rmtree(temporary_path)

        def clean_profile(path, *args, **kwargs):
            if Path(path) == profile and profile_cleanup_error is not None:
                raise profile_cleanup_error
            return real_rmtree(path, *args, **kwargs)

        temporary = Mock(name=str(temporary_path), cleanup=Mock(side_effect=clean_workspace))
        temporary.name = str(temporary_path)

        def run_command(args, _logs, label, commands, timeout=90):
            if startup_error is not None:
                raise startup_error
            profile.mkdir(exist_ok=True)
            marker = "RED_VEIL_SCENE_READY version=0.11.0-alpha.1 nodes=235 journey=mission\n"
            Path(args[args.index("--log-file") + 1]).write_text(marker)
            result = {"label": label, "command": args, "exit_code": 0, "output": marker}
            commands.append(result)
            return result

        @contextmanager
        def broken_exit(_system, _report):
            yield str(temporary_path)
            raise context_exit_error

        with ExitStack() as stack:
            stack.enter_context(patch("sys.argv", ["verify_native_package.py", "--distribution", str(self.folder), "--report", str(report_path), "--require-graphical"]))
            stack.enter_context(patch.dict(os.environ, {}, clear=True))
            stack.enter_context(patch.object(native.platform, "system", return_value="Windows"))
            stack.enter_context(patch.object(native, "app_profile", return_value=profile))
            stack.enter_context(patch.object(native, "run_command", side_effect=run_command))
            stack.enter_context(patch.object(native.tempfile, "TemporaryDirectory", return_value=temporary))
            stack.enter_context(patch.object(native.shutil, "rmtree", side_effect=clean_profile))
            stack.enter_context(patch.object(Path, "write_text", new=write_text))
            sleep = stack.enter_context(patch.object(native.time, "sleep"))
            stack.enter_context(patch("sys.stdout", new=io.StringIO()))
            if context_exit_error is not None:
                stack.enter_context(patch.object(native, "native_workspace", side_effect=broken_exit))
            result = native.main()
        report = json.loads(report_path.read_text()) if report_path.exists() else None
        return result, report, profile, temporary, sleep

    def test_success_requires_startups_and_both_owned_cleanups(self):
        code, report, profile, temporary, sleep = self.native_main_fixture()
        self.assertEqual(code, 0)
        self.assertTrue(report["passed"])
        self.assertTrue(report["startup_passed"])
        self.assertTrue(report["workspace_cleanup_passed"])
        self.assertTrue(report["profile_cleanup_passed"])
        self.assertNotIn("cleanup_error", report)
        self.assertFalse(profile.exists())
        self.assertFalse(Path(temporary.name).exists())
        sleep.assert_not_called()

    def test_workspace_cleanup_failure_cannot_leave_successful_gate(self):
        code, report, profile, temporary, sleep = self.native_main_fixture(workspace_cleanup_error=self.sharing_error())
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertTrue(report["startup_passed"])
        self.assertTrue(all(report[label] for label in ["headless-startup", "graphical-startup", "angle-startup"]))
        self.assertFalse(report["workspace_cleanup_passed"])
        self.assertTrue(report["profile_cleanup_passed"])
        self.assertIn("workspace", report["cleanup_error"])
        self.assertEqual(temporary.cleanup.call_count, 5)
        self.assertEqual(sleep.call_count, 4)
        self.assertFalse(profile.exists())
        self.assertTrue(Path(temporary.name).exists())

    def test_profile_cleanup_failure_preserves_report_and_truthful_status(self):
        code, report, profile, _temporary, sleep = self.native_main_fixture(profile_cleanup_error=PermissionError("Profile cleanup denied"))
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertTrue(report["startup_passed"])
        self.assertTrue(report["workspace_cleanup_passed"])
        self.assertFalse(report["profile_cleanup_passed"])
        self.assertIn("profile", report["cleanup_error"])
        self.assertIn("cleanup failed", report["profile"])
        self.assertNotIn("absent after cleanup", report["profile"])
        self.assertTrue(profile.exists())
        sleep.assert_not_called()

    def test_unhandled_context_exit_error_resets_gate_after_successful_startups(self):
        code, report, profile, _temporary, _sleep = self.native_main_fixture(context_exit_error=RuntimeError("Unexpected workspace exit failure"))
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertTrue(report["startup_passed"])
        self.assertIn("Unexpected workspace exit failure", report["error"])
        self.assertFalse(profile.exists())

    def test_startup_exception_is_not_converted_to_success_by_clean_cleanup(self):
        code, report, _profile, _temporary, _sleep = self.native_main_fixture(startup_error=RuntimeError("Native launch failed"))
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertFalse(report["startup_passed"])
        self.assertIn("Native launch failed", report["error"])
        self.assertTrue(report["workspace_cleanup_passed"])
        self.assertTrue(report["profile_cleanup_passed"])

    def test_cleanup_never_touches_a_preexisting_player_profile(self):
        code, report, profile, temporary, sleep = self.native_main_fixture(existing_profile=True)
        self.assertEqual(code, 1)
        self.assertFalse(report["passed"])
        self.assertFalse(report["startup_passed"])
        self.assertIsNone(report["profile_cleanup_passed"])
        self.assertIn("Existing player profile", report["error"])
        self.assertEqual((profile / "player-data.json").read_text(), "existing player data must remain")
        temporary.cleanup.assert_not_called()
        sleep.assert_not_called()

    def test_missing_report_cannot_return_success_after_checks_and_cleanup(self):
        code, report, profile, temporary, _sleep = self.native_main_fixture(report_write_error=PermissionError("Report cannot be written"))
        self.assertEqual(code, 1)
        self.assertIsNone(report)
        self.assertFalse(profile.exists())
        self.assertFalse(Path(temporary.name).exists())

    def test_only_windows_sharing_violations_get_bounded_cleanup_retries(self):
        report = {}
        cleanup = Mock(side_effect=[self.sharing_error(), self.sharing_error(), None])
        with patch.object(native.time, "sleep") as sleep:
            self.assertTrue(native.cleanup_owned_resource(cleanup, "Windows", "workspace", report))
        self.assertEqual(cleanup.call_count, 3)
        self.assertEqual([call.args[0] for call in sleep.call_args_list], [0.2, 0.4])
        self.assertEqual(report["cleanup_attempts"]["workspace"], 3)
        self.assertNotIn("cleanup_error", report)
        for system, error in [("Darwin", self.sharing_error()), ("Windows", PermissionError("Unrelated permission denial"))]:
            with self.subTest(system=system, error=str(error)):
                report = {}
                cleanup = Mock(side_effect=error)
                with patch.object(native.time, "sleep") as sleep, patch("sys.stdout", new=io.StringIO()):
                    self.assertFalse(native.cleanup_owned_resource(cleanup, system, "workspace", report))
                cleanup.assert_called_once()
                sleep.assert_not_called()
                self.assertFalse(report["workspace_cleanup_passed"])


if __name__ == "__main__":
    unittest.main()
