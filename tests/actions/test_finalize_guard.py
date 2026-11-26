import os
import pathlib
import subprocess
import tempfile
import unittest

import yaml

WORKFLOWS = pathlib.Path(__file__).resolve().parents[2] / ".github" / "workflows"
WORKFLOW = WORKFLOWS / "common-release-finalize.yml"


def steps():
    (job,) = yaml.safe_load(WORKFLOW.read_text())["jobs"].values()
    return job["steps"]


def step_by_id(step_id):
    return next(s for s in steps() if s.get("id") == step_id)


def run_guard(gh_script):
    script = step_by_id("release")["run"]
    with tempfile.TemporaryDirectory() as tmp:
        tmp = pathlib.Path(tmp)
        gh = tmp / "gh"
        gh.write_text("#!/usr/bin/env bash\n" + gh_script)
        gh.chmod(0o755)
        output = tmp / "output"
        output.touch()
        env = {
            **os.environ,
            "PATH": f"{tmp}:{os.environ['PATH']}",
            "GH_TOKEN": "x",
            "VERSION": "1.2.3",
            "REPO": "reqstool/example",
            "GITHUB_OUTPUT": str(output),
            "GITHUB_STEP_SUMMARY": str(tmp / "summary"),
        }
        proc = subprocess.run(
            ["bash", "-e", "-o", "pipefail", "-c", script],
            env=env,
            capture_output=True,
            text=True,
        )
        return proc, output.read_text()


class FinalizeGuard(unittest.TestCase):
    def test_existing_release_is_finalized(self):
        proc, out = run_guard("exit 0\n")
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("exists=true", out)

    def test_missing_release_is_skipped_with_a_warning(self):
        proc, out = run_guard('echo "gh: Not Found (HTTP 404)" >&2\nexit 1\n')
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("exists=false", out)
        self.assertIn("::warning::", proc.stdout)

    def test_other_api_errors_still_fail(self):
        proc, out = run_guard('echo "gh: Bad credentials (HTTP 401)" >&2\nexit 1\n')
        self.assertNotEqual(proc.returncode, 0)
        self.assertNotIn("exists=", out)

    def test_every_later_step_waits_for_the_release(self):
        later = steps()[[s.get("id") for s in steps()].index("release") + 1 :]
        self.assertTrue(later)
        for step in later:
            self.assertIn("steps.release.outputs.exists == 'true'", step["if"], step["name"])


if __name__ == "__main__":
    unittest.main()
