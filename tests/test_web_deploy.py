"""Offline tests for published-release verification and safe Pages preparation."""
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import stat
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "scripts"))
import deploy_web_release as deploy


class WebDeployTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="red-veil-web-deploy-test-")
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.tag = "v0.4.0-alpha.1"
        self.version = "0.4.0-alpha.1"
        self.native_commit = "a" * 40
        self.packaging_commit = "b" * 40
        self.archive = self.folder / "web.zip"
        self.write_zip(self.archive, {"index.html": b"<html>native export</html>", "index.pck": b"original game bytes"})
        self.archive_bytes = self.archive.read_bytes()
        self.entry = {"name": f"Red-Veil-{self.version}-Web.zip", "bytes": len(self.archive_bytes), "sha256": hashlib.sha256(self.archive_bytes).hexdigest()}
        self.manifest = {"version": self.version, "commit": self.native_commit, "engine": "Godot 4.6.3", "assets": [self.entry]}
        self.manifest_bytes = json.dumps(self.manifest).encode()
        self.release = {
            "draft": False, "tag_name": self.tag, "published_at": "2026-11-14T00:00:00Z",
            "assets": [
                {"name": "release-manifest.json", "size": len(self.manifest_bytes), "browser_download_url": deploy.fixed_asset_url(self.tag, "release-manifest.json")},
                {"name": self.entry["name"], "size": len(self.archive_bytes), "browser_download_url": deploy.fixed_asset_url(self.tag, self.entry["name"])},
            ],
        }

    @staticmethod
    def write_zip(path, files):
        with zipfile.ZipFile(path, "w", compression=zipfile.ZIP_DEFLATED) as archive:
            for name, data in files.items():
                archive.writestr(name, data)

    def downloads(self):
        return {
            f"{deploy.API_ROOT}/releases/tags/{self.tag}": json.dumps(self.release).encode(),
            deploy.fixed_asset_url(self.tag, "release-manifest.json"): self.manifest_bytes,
            f"{deploy.API_ROOT}/commits/{self.tag}": json.dumps({"sha": self.native_commit}).encode(),
            deploy.fixed_asset_url(self.tag, self.entry["name"]): self.archive_bytes,
        }

    def test_prepare_records_native_and_packaging_sources_separately(self):
        payloads = self.downloads()
        requested = []

        def download(url, path, maximum):
            requested.append(url)
            data = payloads[url]
            self.assertLessEqual(len(data), maximum)
            Path(path).write_bytes(data)
            return len(data)

        def postprocess(arguments, **kwargs):
            self.assertEqual(arguments[-4:], ["--version", self.version, "--commit", self.native_commit])
            self.assertNotIn("GH_TOKEN", kwargs["env"])
            directory = Path(arguments[arguments.index("--directory") + 1])
            (directory / "index.html").write_text("<html>versioned web shell</html>")
            return subprocess.CompletedProcess(arguments, 0)

        output = self.folder / "site"
        with patch.object(deploy, "download", side_effect=download), patch.object(deploy, "packaging_commit", return_value=self.packaging_commit), patch.object(subprocess, "run", side_effect=postprocess), redirect_stdout(io.StringIO()):
            provenance = deploy.prepare_site(self.tag, output)
        self.assertEqual(set(requested), set(payloads))
        self.assertEqual(provenance["native_source_commit"], self.native_commit)
        self.assertEqual(provenance["packaging_source_commit"], self.packaging_commit)
        self.assertEqual(provenance["native_web_sha256"], self.entry["sha256"])
        self.assertIn("not byte-identical", provenance["note"])
        self.assertEqual(json.loads((output / "deployment-provenance.json").read_text()), provenance)
        self.assertEqual((output / "index.pck").read_bytes(), b"original game bytes")
        self.assertEqual(self.archive.read_bytes(), self.archive_bytes)

    def test_draft_or_unpublished_release_is_rejected(self):
        for changes in [{"draft": True}, {"published_at": None}, {"tag_name": "v0.1.0"}]:
            with self.subTest(changes=changes), self.assertRaisesRegex(ValueError, "published release"):
                deploy.validate_release(self.release | changes, self.tag)

    def test_only_fixed_versioned_asset_urls_are_accepted(self):
        self.release["assets"][1]["browser_download_url"] = "https://example.com/untrusted.zip"
        with self.assertRaisesRegex(ValueError, "unexpected URL"):
            deploy.validate_release(self.release, self.tag)
        for tag in ["main", "v../escape", "v0.4.0-alpha.01", "v0.4.0;echo"]:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                deploy.version_from_tag(tag)
        with self.assertRaises(ValueError):
            deploy.fixed_asset_url(self.tag, "../other.zip")

    def test_source_version_and_engine_must_match(self):
        for changes in [{"commit": "c" * 40}, {"version": "0.1.0"}, {"engine": "Godot 9.0"}]:
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                deploy.web_archive_entry(self.manifest | changes, self.version, self.native_commit)

    def test_changed_zip_bytes_and_size_are_rejected(self):
        deploy.verify_archive(self.archive, self.entry)
        self.archive.write_bytes(b"X" + self.archive_bytes[1:])
        with self.assertRaisesRegex(ValueError, "SHA-256"):
            deploy.verify_archive(self.archive, self.entry)
        self.archive.write_bytes(self.archive_bytes[:-1])
        with self.assertRaisesRegex(ValueError, "length"):
            deploy.verify_archive(self.archive, self.entry)

    def test_zip_traversal_absolute_windows_and_duplicate_paths_are_rejected(self):
        for index, name in enumerate(["../escape", "/absolute", "C:/escape", "folder\\escape", "folder/../escape", "INDEX.HTML"]):
            archive = self.folder / f"unsafe-{index}.zip"
            self.write_zip(archive, {"index.html": b"entry", name: b"unsafe"})
            with self.subTest(name=name), self.assertRaises(ValueError):
                deploy.safe_extract(archive, self.folder / f"extract-{index}")
        self.assertFalse((self.folder / "escape").exists())

    def test_zip_symlink_and_expansion_budget_are_rejected(self):
        archive = self.folder / "symlink.zip"
        with zipfile.ZipFile(archive, "w") as target:
            target.writestr("index.html", b"entry")
            link = zipfile.ZipInfo("link")
            link.create_system = 3
            link.external_attr = (stat.S_IFLNK | 0o777) << 16
            target.writestr(link, "../outside")
        with self.assertRaisesRegex(ValueError, "link or special"):
            deploy.safe_extract(archive, self.folder / "symlink-output")
        with patch.object(deploy, "MAX_EXPANDED_BYTES", 1), self.assertRaisesRegex(ValueError, "Expanded"):
            deploy.safe_extract(self.archive, self.folder / "oversized-output")

    def test_extraction_never_overwrites_an_existing_directory(self):
        output = self.folder / "existing"
        output.mkdir()
        (output / "keep.txt").write_text("keep")
        with self.assertRaisesRegex(ValueError, "empty regular"):
            deploy.safe_extract(self.archive, output)
        self.assertEqual((output / "keep.txt").read_text(), "keep")

    def test_disallowed_redirects_are_rejected_and_api_token_is_stripped(self):
        for url in ["http://github.com/file", "https://example.com/file", "https://github.com.attacker.example/file", "https://user:password@github.com/file"]:
            with self.subTest(url=url), self.assertRaises(ValueError):
                deploy.validate_download_url(url)
        request = urllib.request.Request(f"{deploy.API_ROOT}/releases", headers={"Authorization": "Bearer test-fixture-token"})
        redirected = deploy.ReleaseRedirects().redirect_request(request, None, 302, "Found", {}, "https://release-assets.githubusercontent.com/download")
        self.assertIsNone(redirected.get_header("Authorization"))

    def test_download_bounds_stream_and_does_not_send_api_token_to_asset_host(self):
        response = MagicMock()
        response.status = 200
        response.headers = {}
        response.read.side_effect = [b"too many bytes"]
        response.__enter__.return_value = response
        opener = MagicMock()
        opener.open.return_value = response
        with patch.dict(os.environ, {"GH_TOKEN": "test-fixture-token"}), patch.object(urllib.request, "build_opener", return_value=opener), self.assertRaisesRegex(ValueError, "exceeds"):
            deploy.download(deploy.fixed_asset_url(self.tag, self.entry["name"]), self.folder / "download.zip", 4)
        request = opener.open.call_args.args[0]
        self.assertIsNone(request.get_header("Authorization"))

    def test_failed_postprocessing_does_not_leave_a_deployable_output(self):
        payloads = self.downloads()

        def download(url, path, maximum):
            Path(path).write_bytes(payloads[url])
            return len(payloads[url])

        output = self.folder / "failed-site"
        with patch.object(deploy, "download", side_effect=download), patch.object(deploy, "packaging_commit", return_value=self.packaging_commit), patch.object(subprocess, "run", side_effect=subprocess.CalledProcessError(1, ["web-postprocess"])), self.assertRaises(subprocess.CalledProcessError):
            deploy.prepare_site(self.tag, output)
        self.assertFalse(output.exists())
        self.assertEqual(list(self.folder.glob(".red-veil-pages-stage-*")), [])

    def test_web_workflow_uses_published_releases_and_separate_pages_permissions(self):
        workflow = (ROOT / ".github/workflows/deploy-web.yml").read_text()
        self.assertIn("types: [published]", workflow)
        self.assertIn("ref: main", workflow)
        self.assertIn("contents: read", workflow)
        self.assertIn("pages: write", workflow)
        self.assertIn("id-token: write", workflow)
        self.assertNotIn("contents: write", workflow)
        self.assertNotIn("RED_VEIL_UPDATE_SIGNING_KEY", workflow)
        self.assertIn('--tag "$RELEASE_TAG"', workflow)


if __name__ == "__main__":
    unittest.main()
