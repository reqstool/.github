import pathlib
import unittest

import yaml

ROOT = pathlib.Path(__file__).resolve().parents[2]
WORKFLOWS = ROOT / ".github" / "workflows"


class ApprovalPointsAtTheNotes(unittest.TestCase):
    def test_approve_job_name_points_at_the_prepare_summary(self):
        job = yaml.safe_load((WORKFLOWS / "release.yml").read_text())["jobs"]["approve"]
        self.assertIn("needs.prepare.outputs.version", job["name"])
        self.assertIn("prepare job summary", job["name"])

    def test_release_notes_heading_outranks_the_changelog_groups(self):
        text = (WORKFLOWS / "common-release-prepare.yml").read_text()
        self.assertIn('echo "## Release notes"', text)

    def test_prepare_summary_tells_the_reviewer_to_read_the_notes(self):
        text = (WORKFLOWS / "common-release-prepare.yml").read_text()
        self.assertIn("review the release notes below, then approve", text)

    def test_releasing_md_says_where_the_changelog_is(self):
        text = (ROOT / "RELEASING.md").read_text()
        self.assertIn("prepare` job summary", text)


if __name__ == "__main__":
    unittest.main()
