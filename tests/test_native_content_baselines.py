"""Historical update gates must fail before trusting substituted baseline bytes."""
import copy
import json
import re
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "scripts"))
import verify_native_content_update as native

EXPECTED_STEMS = {
    "0.6.0-alpha.1": "KOMAKU-Shield-Protocol",
    "0.6.1-alpha.1": "KOMAKU-Shield-Protocol",
    "0.7.0-alpha.1": "KOMAKU-Shield-Protocol",
    "0.7.1-alpha.1": "KOMAKU-Shield-Protocol",
    "0.8.0-alpha.1": "KOMAKU-Shield-Protocol",
    "0.9.0-alpha.1": "KOMAKU-Dust-and-Radiation",
    "0.10.0-alpha.1": "KOMAKU-Dust-and-Radiation",
}
BASELINES_WITH_GUIDES = {"0.7.0-alpha.1", "0.7.1-alpha.1", "0.8.0-alpha.1", "0.9.0-alpha.1", "0.10.0-alpha.1"}


class NativeContentBaselinesTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        (self.root / "docs/evidence").mkdir(parents=True)
        self.records = {version: native.baseline_evidence(version) for version in native.BASELINES}

    def write_record(self, version, record):
        (self.root / f"docs/evidence/release-{version}.json").write_text(json.dumps(record), encoding="utf-8")

    def test_all_immutable_records_match_independent_pins(self):
        self.assertEqual(native.DEFAULT_BASELINE, "0.10.0-alpha.1")
        self.assertEqual(set(native.BASELINES), set(EXPECTED_STEMS))
        for version, record in self.records.items():
            self.assertEqual(record["version"], version)
            self.assertEqual(record["source_commit"], native.BASELINES[version]["source_commit"])
            self.assertEqual(len(record["assets"]), 10 if version in BASELINES_WITH_GUIDES else 9)
            self.assertEqual({asset["name"] for asset in record["assets"] if asset["name"].endswith(".zip")}, {
                f"{EXPECTED_STEMS[version]}-{version}-{platform}.zip"
                for platform in ["macOS-universal", "Windows-x64", "Linux-x64", "Web"]
            })

    def test_hosted_matrix_covers_every_pinned_baseline_on_both_platforms(self):
        workflow = (native.ROOT / ".github/workflows/probe-native-update.yml").read_text()
        baseline_section = re.search(r"(?ms)^        baseline:\s*\[(.*?)\]", workflow)
        self.assertIsNotNone(baseline_section, "The baseline matrix must be explicit and reviewable")
        versions = re.findall(r'"([0-9.]+-alpha\.[0-9]+)"', baseline_section[1])
        self.assertEqual(len(versions), len(set(versions)), "Duplicate baselines must not disguise a missing job")
        self.assertEqual(set(versions), set(native.BASELINES))
        operating_systems = re.search(r"(?m)^        os:\s*\[([^\]]+)\]", workflow)
        self.assertIsNotNone(operating_systems)
        platforms = [value.strip() for value in operating_systems[1].split(",")]
        self.assertEqual(set(platforms), {"macos-latest", "windows-latest"})
        self.assertEqual(len(versions) * len(platforms), 14)
        self.assertIn('BASELINE_VERSION: ${{ matrix.baseline }}', workflow)
        self.assertIn('--baseline "$BASELINE_VERSION"', workflow)

    def test_science_guide_required_only_for_baselines_that_shipped_it(self):
        for version, original in self.records.items():
            with self.subTest(version=version):
                record = copy.deepcopy(original)
                filename = f"{EXPECTED_STEMS[version]}-{version}-Science-Guide.pdf"
                if version in BASELINES_WITH_GUIDES:
                    record["assets"] = [asset for asset in record["assets"] if asset["name"] != filename]
                else:
                    record["assets"].append({"name": filename, "bytes": 1, "sha256": "0" * 64})
                self.write_record(version, record)
                with patch.object(native, "ROOT", self.root), self.assertRaisesRegex(ValueError, "asset set changed"):
                    native.baseline_evidence(version)

    def test_unknown_baseline_rejected_before_download_or_directory_creation(self):
        folder = self.root / "download"
        with patch.object(native, "download") as download, self.assertRaisesRegex(ValueError, "Unsupported"):
            native.fetch_baseline(folder, "../../untrusted")
        download.assert_not_called()
        self.assertFalse(folder.exists())

    def test_changed_version_or_source_identity_rejected(self):
        for version, original in self.records.items():
            for key, replacement in (("version", "99.0.0"), ("source_commit", "0" * 40)):
                with self.subTest(version=version, key=key):
                    record = copy.deepcopy(original)
                    record[key] = replacement
                    self.write_record(version, record)
                    with patch.object(native, "ROOT", self.root), self.assertRaisesRegex(ValueError, "identity"):
                        native.baseline_evidence(version)

    def test_changed_manifest_or_native_archive_pin_rejected(self):
        for version, original in self.records.items():
            for filename in ("release-manifest.json", f"{EXPECTED_STEMS[version]}-{version}-macOS-universal.zip", f"{EXPECTED_STEMS[version]}-{version}-Windows-x64.zip"):
                with self.subTest(version=version, filename=filename):
                    record = copy.deepcopy(original)
                    next(asset for asset in record["assets"] if asset["name"] == filename)["sha256"] = "0" * 64
                    self.write_record(version, record)
                    with patch.object(native, "ROOT", self.root), self.assertRaisesRegex(ValueError, "independently pinned"):
                        native.baseline_evidence(version)

    def test_renamed_baseline_cannot_substitute_historical_archive_names(self):
        for version in ["0.9.0-alpha.1", "0.10.0-alpha.1"]:
            with self.subTest(version=version):
                record = copy.deepcopy(self.records[version])
                for asset in record["assets"]:
                    asset["name"] = asset["name"].replace("KOMAKU-Dust-and-Radiation", "KOMAKU-Shield-Protocol")
                self.write_record(version, record)
                with patch.object(native, "ROOT", self.root), self.assertRaisesRegex(ValueError, "unexpected assets"):
                    native.baseline_evidence(version)

    def test_missing_duplicate_and_unexpected_assets_rejected(self):
        version = native.DEFAULT_BASELINE
        for kind in ("missing", "duplicate", "unexpected"):
            with self.subTest(kind=kind):
                record = copy.deepcopy(self.records[version])
                if kind == "missing":
                    record["assets"].pop()
                elif kind == "duplicate":
                    record["assets"][-1] = copy.deepcopy(record["assets"][0])
                else:
                    record["assets"][0]["name"] = "../outside.zip"
                self.write_record(version, record)
                with patch.object(native, "ROOT", self.root), self.assertRaises(ValueError):
                    native.baseline_evidence(version)

    def test_downloaded_bytes_must_match_evidence_before_execution(self):
        folder = self.root / "download"
        def wrong_download(_url, target):
            target.write_bytes(b"substituted historical artifact")
        with patch.object(native, "download", side_effect=wrong_download) as download:
            with self.assertRaisesRegex(ValueError, "Historical public asset differs"):
                native.fetch_baseline(folder, native.DEFAULT_BASELINE)
            self.assertEqual(download.call_count, 1)


if __name__ == "__main__":
    unittest.main()
