"""Site preservation checks; no network or GitHub mutations."""
import hashlib
import io
import json
from pathlib import Path
import sys
import tarfile
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import prepare_screen_review_site as deploy


class ReviewDeploymentTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.folder = Path(self.temp.name)
        self.site = self.folder / "site"
        self.site.mkdir()

    def test_archive_rejects_traversal_links_and_duplicates_before_writing(self):
        for malicious in ["../escape.html", "/absolute.html", "symlink", "duplicate"]:
            with self.subTest(malicious=malicious):
                archive = self.folder / "base.tar"
                with tarfile.open(archive, "w") as out:
                    first = tarfile.TarInfo("./index.html"); first.size = 4
                    out.addfile(first, io.BytesIO(b"game"))
                    bad = tarfile.TarInfo("./index.html" if malicious == "duplicate" else malicious)
                    if malicious == "symlink":
                        bad.type = tarfile.SYMTYPE; bad.linkname = "../escape.html"
                    out.addfile(bad)
                with self.assertRaises(ValueError):
                    deploy.extract_site(archive, self.site)
                self.assertEqual(list(self.site.iterdir()), [])
                self.assertFalse((self.folder / "escape.html").exists())

    def test_inventory_restoration_verifies_bytes_and_never_fetches_unsafe_paths(self):
        content = b"unchanged old game"
        row = {"path": "index.html", "bytes": len(content), "sha256": hashlib.sha256(content).hexdigest()}
        record = {"schema": 1, "files": [row]}
        deploy.restore_public(record, self.site, fetch=lambda path, limit: content)
        self.assertEqual((self.site / "index.html").read_bytes(), content)
        with self.assertRaisesRegex(ValueError, "changed or download"):
            deploy.restore_public(record, self.site, fetch=lambda path, limit: b"wrong bytes")
        for bad in [None, {}, {"schema": 1, "files": [row, row]}, {"schema": 1, "files": [row | {"path": "../escape"}]}]:
            with self.assertRaises(ValueError):
                deploy.validate_inventory(bad)
        self.assertEqual((self.site / "index.html").read_bytes(), content)

    def test_adding_review_preserves_game_and_older_review_versions(self):
        (self.site / "index.html").write_bytes(b"original game entry")
        (self.site / "game.wasm").write_bytes(b"original game runtime")
        old = self.site / "review/0.9.0-alpha.1/index.html"
        old.parent.mkdir(parents=True); old.write_bytes(b"previous review remains")
        current = self.site / "review/0.10.0-alpha.1/index.html"
        current.parent.mkdir(parents=True); current.write_bytes(b"previous gallery UI")
        root = self.folder / "source"
        (root / "review").mkdir(parents=True)
        (root / "review/screens.json").write_text(json.dumps({"version": "0.10.0-alpha.1", "sourceCommit": "a" * 40}))

        def build(command, **kwargs):
            output = Path(command[-1]); output.mkdir()
            (output / "index.html").write_bytes(b"new review UI")

        with patch.object(deploy, "ROOT", root), patch.object(deploy.subprocess, "run", side_effect=build), patch.object(deploy.subprocess, "check_output", return_value="b" * 40 + "\n"):
            record = deploy.add_review(self.site, {"kind": "test fixture"})
        self.assertEqual((self.site / "index.html").read_bytes(), b"original game entry")
        self.assertEqual((self.site / "game.wasm").read_bytes(), b"original game runtime")
        self.assertEqual(old.read_bytes(), b"previous review remains")
        self.assertEqual(current.read_bytes(), b"new review UI")
        self.assertEqual(record["preserved_files_checked"], 3)
        self.assertIn("0.10.0-alpha.1", (self.site / "review/index.html").read_text())
        self.assertNotIn(deploy.INVENTORY, [entry["path"] for entry in record["files"]])
        deploy.validate_inventory(record)

    def test_new_game_keeps_review_history_without_restoring_the_old_game(self):
        (self.site / "index.html").write_bytes(b"new game")
        contents = {"index.html": b"old game", "review/0.9.0-alpha.1/index.html": b"old review"}
        record = {"schema": 1, "files": [{"path": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()} for name, data in contents.items()]}
        fetched = []

        def fetch(name, limit):
            fetched.append(name)
            return contents[name]

        deploy.restore_public(record, self.site, fetch=fetch, only_review=True)
        self.assertEqual(fetched, ["review/0.9.0-alpha.1/index.html"])
        self.assertEqual((self.site / "index.html").read_bytes(), b"new game")
        self.assertEqual((self.site / "review/0.9.0-alpha.1/index.html").read_bytes(), b"old review")


if __name__ == "__main__":
    unittest.main()
