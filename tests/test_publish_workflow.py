"""Exercise the actual artifact-only workflow guards without GitHub mutations."""
from contextlib import redirect_stdout
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
WORKFLOW = ROOT / ".github/workflows/publish-downloads.yml"
sys.path.insert(0, str(ROOT / "scripts"))
import build_game


def workflow_python(step_name):
    """Extract a named inline Python block; test the code Actions will execute."""
    step = WORKFLOW.read_text().split("- name: " + step_name, 1)[1].split("\n      - ", 1)[0]
    lines = step.splitlines()
    start = next(index for index, line in enumerate(lines) if line.strip() == "python <<'PY'") + 1
    end = next(index for index in range(start, len(lines)) if lines[index].strip() == "PY")
    return compile(textwrap.dedent("\n".join(lines[start:end])), str(WORKFLOW), "exec")


class PublishWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="red-veil-publish-guard-")
        self.addCleanup(self.temporary.cleanup)
        self.folder = Path(self.temporary.name)
        self.repository = "roshaninfordham/NASA-SPACE-APPS-HACKATHON-2026"
        self.revision = "a" * 40
        self.version = "0.4.0-alpha.1"
        self.run_id = 43634324156
        self.run = {
            "id": self.run_id, "head_sha": self.revision, "status": "completed",
            "conclusion": "success", "event": "workflow_dispatch", "run_attempt": 1,
            "path": ".github/workflows/build-downloads.yml",
            "repository": {"full_name": self.repository},
            "head_repository": {"full_name": self.repository},
        }
        self.environment = {
            "RELEASE_VERSION": self.version, "SOURCE_REVISION": self.revision,
            "BUILD_RUN_ID": str(self.run_id), "GITHUB_REPOSITORY": self.repository,
            "BUILD_RUN_ATTEMPT": "1", "ACCEPTED_MANIFEST_SHA256": "a" * 64,
            "RUNNER_TEMP": str(self.folder), "GITHUB_STEP_SUMMARY": str(self.folder / "summary.md"),
        }
        self.guard = workflow_python("Verify successful source build before download")
        self.prepare = workflow_python("Verify and prepare unchanged accepted files")

    def execute(self, code, run=None, environment=None):
        result = subprocess.CompletedProcess(["gh", "api"], 0, stdout=json.dumps(self.run if run is None else run))
        original_path = list(sys.path)
        try:
            with patch.dict(os.environ, self.environment | (environment or {})), patch.object(subprocess, "run", return_value=result) as github, patch.object(Path, "cwd", return_value=self.folder), patch.object(build_game, "source_commit", return_value=self.revision), patch.object(build_game, "OUT", build_game.OUT), redirect_stdout(io.StringIO()):
                exec(code, {"__name__": "__main__"})
                return github.call_args_list
        finally:
            sys.path[:] = original_path

    def create_artifact(self):
        distribution = self.folder / "releases/distribution"
        distribution.mkdir(parents=True)
        entries = []
        for suffix in ["macOS-universal", "Windows-x64", "Linux-x64", "Web"]:
            name = f"Red-Veil-{self.version}-{suffix}.zip"
            data = ("accepted bytes for " + suffix).encode()
            (distribution / name).write_bytes(data)
            entries.append({"name": name, "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()})
        manifest = {"version": self.version, "commit": self.revision, "signed_content_updates": False, "assets": entries}
        (distribution / "release-manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
        (distribution / "SHA256SUMS.txt").write_text("".join(f"{item['sha256']}  {item['name']}\n" for item in entries))
        self.environment["ACCEPTED_MANIFEST_SHA256"] = hashlib.sha256((distribution / "release-manifest.json").read_bytes()).hexdigest()
        return distribution

    def test_successful_exact_build_is_recorded_using_read_only_api(self):
        calls = self.execute(self.guard)
        self.assertEqual(calls[0].args[0], ["gh", "api", f"repos/{self.repository}/actions/runs/{self.run_id}"])
        record = json.loads((self.folder / "red-veil-accepted-build.json").read_text())
        self.assertEqual(record["head_sha"], self.revision)
        self.assertEqual(record["run_attempt"], 1)

    def test_wrong_source_workflow_event_result_or_repository_is_rejected(self):
        changes = [
            {"head_sha": "b" * 40}, {"status": "in_progress"}, {"conclusion": "failure"},
            {"event": "pull_request"}, {"path": ".github/workflows/validate.yml"},
            {"repository": {"full_name": "other/repo"}}, {"head_repository": {"full_name": "fork/repo"}},
            {"id": self.run_id + 1}, {"run_attempt": 2},
        ]
        for changed in changes:
            with self.subTest(changed=changed), self.assertRaises(SystemExit):
                self.execute(self.guard, self.run | changed)

    def test_branch_names_and_shell_like_inputs_never_reach_github(self):
        for changed in [{"SOURCE_REVISION": "main"}, {"SOURCE_REVISION": "a" * 39}, {"BUILD_RUN_ID": "123;touch /tmp/bad"}, {"BUILD_RUN_ID": "../123"}, {"RELEASE_VERSION": "$(anything)"}]:
            with self.subTest(changed=changed), patch.object(subprocess, "run") as github, patch.dict(os.environ, self.environment | changed), self.assertRaises(SystemExit):
                exec(self.guard, {"__name__": "__main__"})
            github.assert_not_called()

    def test_accepted_file_bytes_are_copied_without_rebuilding(self):
        self.execute(self.guard)
        distribution = self.create_artifact()
        accepted = {item.name: item.read_bytes() for item in distribution.iterdir()}
        calls = self.execute(self.prepare)
        self.assertEqual(len(calls), 1)
        self.assertEqual(calls[0].args[0][:2], ["gh", "api"])
        for name, data in accepted.items():
            self.assertEqual((self.folder / "releases" / name).read_bytes(), data)
            self.assertEqual((distribution / name).read_bytes(), data)
        summary = (self.folder / "summary.md").read_text()
        self.assertIn(str(self.run_id), summary)
        self.assertIn(self.revision, summary)
        self.assertIn(hashlib.sha256(accepted["release-manifest.json"]).hexdigest(), summary)

    def test_rerun_during_download_stops_publication(self):
        self.execute(self.guard)
        self.create_artifact()
        with self.assertRaisesRegex(SystemExit, "changed during"):
            self.execute(self.prepare, self.run | {"run_attempt": 2})
        self.assertFalse((self.folder / "releases/release-manifest.json").exists())

    def test_altered_and_unexpected_artifacts_are_rejected(self):
        self.execute(self.guard)
        distribution = self.create_artifact()
        archive = next(distribution.glob("*.zip"))
        original = archive.read_bytes()
        archive.write_bytes(b"changed after acceptance")
        with self.assertRaisesRegex(ValueError, "changed"):
            self.execute(self.prepare)
        archive.write_bytes(original)
        (distribution / "unexpected.pem").write_bytes(b"must never be published")
        with self.assertRaisesRegex(SystemExit, "unexpected"):
            self.execute(self.prepare)
        self.assertFalse((self.folder / "releases/release-manifest.json").exists())

    def test_metadata_that_would_be_rewritten_is_rejected(self):
        self.execute(self.guard)
        distribution = self.create_artifact()
        manifest = distribution / "release-manifest.json"
        manifest.write_text(json.dumps(json.loads(manifest.read_text())))
        with self.assertRaisesRegex(SystemExit, "accepted manifest|exact build format"):
            self.execute(self.prepare)

    def test_a_different_canonical_manifest_cannot_replace_accepted_bytes(self):
        self.execute(self.guard)
        distribution = self.create_artifact()
        manifest_path = distribution / "release-manifest.json"
        manifest = json.loads(manifest_path.read_text())
        manifest["extra_build_metadata"] = "unaccepted rerun"
        manifest_path.write_text(json.dumps(manifest, indent=2) + "\n")
        with self.assertRaisesRegex(SystemExit, "accepted manifest"):
            self.execute(self.prepare)
        self.assertFalse((self.folder / "releases/release-manifest.json").exists())

    def test_workflow_has_no_build_or_private_signing_key_step(self):
        workflow = WORKFLOW.read_text()
        self.assertIn('run: python scripts/build_game.py --version "$RELEASE_VERSION" --publish-prepared', workflow)
        self.assertIn("actions: read", workflow)
        self.assertIn("contents: write", workflow)
        self.assertNotIn("RED_VEIL_UPDATE_SIGNING_KEY", workflow)
        self.assertNotIn("--signed-updates", workflow)
        self.assertNotIn("install_godot", workflow)


if __name__ == "__main__":
    unittest.main()
