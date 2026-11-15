"""Review builds verify their pixels and never overwrite an existing game site."""

import hashlib
import json
from pathlib import Path
import struct
import sys
import tempfile
import unittest
from unittest.mock import patch
import zlib

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import build_screen_review as review


def fixture_png():
    def chunk(kind, data):
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", 2, 1, 8, 6, 0, 0, 0)) + chunk(b"IDAT", zlib.compress(b"\x00" + b"\xff\x00\x00\xff" * 2)) + chunk(b"IEND", b"")


class ScreenReviewBuildTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="komaku-screen-review-test-")
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.root = self.folder / "checkout"
        self.root.mkdir()
        self.image = fixture_png()
        self.head = "b" * 40
        self.game = "a" * 40
        self.manifest = {
            "schema": 1, "version": "0.10.0-alpha.1", "sourceCommit": self.game,
            "gameSourceCommit": self.game, "repository": "sample/game", "displayName": "Outdated name",
            "screens": [{
                "id": "first-screen", "title": "First screen", "group": "Story", "description": "A test fixture.",
                "file": "screens/first-screen.png", "sourcePath": "docs/media/fixture.png", "width": 2, "height": 1,
                "sha256": hashlib.sha256(self.image).hexdigest(), "sourceUrl": "https://example.invalid/ignored.png",
            }],
        }
        self.write("docs/media/fixture.png", self.image)
        self.write("game/data/brand.json", json.dumps({"display_name": "KŌMAKU: Dust & Radiation", "title": "KŌMAKU", "subtitle": "DUST & RADIATION"}).encode())
        self.write("review/index.html", b"<!doctype html><title>Review</title>")
        self.write("review/review.css", b"body { color: white; }")
        self.write("review/review.js", b"'use strict';")
        self.write(review.BUILDER, b"# isolated builder input fixture\n")
        self.save_manifest()
        self.committed = {str(path.relative_to(self.root)): path.read_bytes() for path in self.root.rglob("*") if path.is_file()}
        self.head_patch = patch.object(review, "git_head", return_value=self.head)
        self.blob_patch = patch.object(review, "git_blob", side_effect=lambda root, head, path: self.committed.get(path))
        self.head_patch.start()
        self.blob_patch.start()
        self.addCleanup(self.head_patch.stop)
        self.addCleanup(self.blob_patch.stop)

    def write(self, relative, data):
        path = self.root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def save_manifest(self):
        self.write(review.MANIFEST, (json.dumps(self.manifest) + "\n").encode())

    def test_new_version_folder_preserves_game_and_reports_every_output_hash(self):
        site = self.folder / "site"
        site.mkdir()
        (site / "index.html").write_bytes(b"existing playable game")
        (site / "game.wasm").write_bytes(b"existing wasm bytes")
        before = dict(self.committed)
        output = site / "review" / "0.10.0-alpha.1"
        report = review.build_review(output, root=self.root)
        self.assertEqual((site / "index.html").read_bytes(), b"existing playable game")
        self.assertEqual((site / "game.wasm").read_bytes(), b"existing wasm bytes")
        self.assertEqual((output / "screens/first-screen.png").read_bytes(), self.image)
        built = json.loads((output / "screens.json").read_text())
        self.assertEqual(built["sourceCommit"], self.game)
        self.assertEqual(built["gameSourceCommit"], self.game)
        self.assertEqual(built["buildSourceCommit"], self.head)
        self.assertEqual(built["displayName"], "KŌMAKU: Dust & Radiation")
        self.assertTrue(built["imageSourcesPinned"])
        self.assertFalse(built["preview"])
        self.assertEqual(built["screens"][0]["sourceUrl"], f"https://raw.githubusercontent.com/sample/game/{self.head}/docs/media/fixture.png")
        inventory = {item["file"]: item for item in report["files"]}
        written = {str(path.relative_to(output)): path for path in output.rglob("*") if path.is_file()}
        self.assertEqual(set(inventory), set(written))
        for name, path in written.items():
            self.assertEqual(inventory[name]["sha256"], hashlib.sha256(path.read_bytes()).hexdigest())
            self.assertEqual(inventory[name]["bytes"], path.stat().st_size)
        self.assertEqual(before, {str(path.relative_to(self.root)): path.read_bytes() for path in self.root.rglob("*") if path.is_file()})

    def test_existing_output_even_empty_and_checkout_outputs_are_refused(self):
        existing = self.folder / "existing"
        existing.mkdir()
        with self.assertRaisesRegex(review.ReviewBuildError, "new directory"):
            review.build_review(existing, root=self.root)
        (existing / "index.html").write_text("Do not overwrite")
        with self.assertRaisesRegex(review.ReviewBuildError, "new directory"):
            review.build_review(existing, root=self.root)
        self.assertEqual((existing / "index.html").read_text(), "Do not overwrite")
        with self.assertRaisesRegex(review.ReviewBuildError, "outside the checkout"):
            review.build_review(self.root / "new-review", root=self.root)
        self.assertFalse((self.root / "new-review").exists())

    def test_hash_mismatch_is_refused_before_any_output_is_created(self):
        self.manifest["screens"][0]["sha256"] = "0" * 64
        self.save_manifest()
        output = self.folder / "not-created" / "review"
        with self.assertRaisesRegex(review.ReviewBuildError, "hash mismatch"):
            review.build_review(output, root=self.root, allow_uncommitted_preview=True)
        self.assertFalse(output.parent.exists())

    def test_dimensions_and_damaged_png_headers_are_refused(self):
        self.manifest["screens"][0]["width"] = 3
        self.save_manifest()
        with self.assertRaisesRegex(review.ReviewBuildError, "dimensions"):
            review.prepare_review(self.root, True)
        self.manifest["screens"][0]["width"] = 2
        damaged = bytearray(self.image)
        damaged[29] ^= 1
        self.write("docs/media/fixture.png", bytes(damaged))
        self.manifest["screens"][0]["sha256"] = hashlib.sha256(damaged).hexdigest()
        self.save_manifest()
        with self.assertRaisesRegex(review.ReviewBuildError, "damaged PNG header"):
            review.prepare_review(self.root, True)

    def test_destinations_and_source_paths_cannot_escape_their_directories(self):
        screen = self.manifest["screens"][0]
        screen["file"] = "../index.html"
        self.save_manifest()
        with self.assertRaisesRegex(review.ReviewBuildError, "destination"):
            review.prepare_review(self.root, True)
        screen["file"] = "screens/first-screen.png"
        for path in ("docs/media/../fixture.png", "docs/media//fixture.png", "docs/media/../../../../outside.png"):
            screen["sourcePath"] = path
            self.save_manifest()
            with self.assertRaisesRegex(review.ReviewBuildError, "Unsafe source path"):
                review.prepare_review(self.root, True)

    def test_symlink_inputs_are_refused(self):
        original = self.root / "docs/media/fixture.png"
        outside = self.folder / "outside.png"
        outside.write_bytes(self.image)
        original.unlink()
        original.symlink_to(outside)
        with self.assertRaises(review.ReviewBuildError):
            review.prepare_review(self.root, True)

    def test_uncommitted_images_require_explicit_preview_and_are_not_claimed_pinned(self):
        self.committed.pop("docs/media/fixture.png")
        output = self.folder / "preview"
        with self.assertRaisesRegex(review.ReviewBuildError, "differ from Git HEAD"):
            review.build_review(output, root=self.root)
        self.assertFalse(output.exists())
        report = review.build_review(output, root=self.root, allow_uncommitted_preview=True)
        built = json.loads((output / "screens.json").read_text())
        self.assertTrue(report["preview"])
        self.assertFalse(built["imageSourcesPinned"])
        self.assertIsNone(built["imageSourceCommit"])
        self.assertFalse(built["screens"][0]["sourcePinned"])
        self.assertEqual(built["screens"][0]["sourceUrl"], "https://raw.githubusercontent.com/sample/game/main/docs/media/fixture.png")

    def test_dirty_ui_requires_preview_but_committed_images_remain_pinned(self):
        self.write("review/review.js", b"'use strict'; // current local edit")
        with self.assertRaisesRegex(review.ReviewBuildError, "differ from Git HEAD"):
            review.prepare_review(self.root)
        report, payload = review.prepare_review(self.root, True)
        built = json.loads(payload["screens.json"])
        self.assertTrue(report["preview"])
        self.assertTrue(built["imageSourcesPinned"])
        self.assertTrue(built["screens"][0]["sourcePinned"])

    def test_duplicate_ids_and_mismatched_game_commits_are_refused(self):
        self.manifest["screens"].append(dict(self.manifest["screens"][0]))
        self.save_manifest()
        with self.assertRaisesRegex(review.ReviewBuildError, "duplicate screen id"):
            review.prepare_review(self.root, True)
        self.manifest["screens"].pop()
        self.manifest["gameSourceCommit"] = self.head
        self.save_manifest()
        with self.assertRaisesRegex(review.ReviewBuildError, "consistent Git commit"):
            review.prepare_review(self.root, True)


if __name__ == "__main__":
    unittest.main()
