import pathlib
import tempfile
import textwrap
import unittest

import check_tool_versions as ctv

REPO = pathlib.Path(__file__).resolve().parents[2]


def workflow(input_name, default):
    return textwrap.dedent(
        f"""\
        on:
          workflow_call:
            inputs:
              {input_name}:
                type: string
                default: "{default}"
        jobs:
          build:
            runs-on: ubuntu-latest
            steps:
              - run: "true"
        """
    )


def setup_node_workflow(version):
    return textwrap.dedent(
        f"""\
        on: push
        jobs:
          build:
            runs-on: ubuntu-latest
            steps:
              - uses: actions/setup-node@v7.1.0
                with:
                  node-version: "{version}"
        """
    )


def pinned_pip_workflow(version):
    return textwrap.dedent(
        f"""\
        on: push
        jobs:
          build:
            runs-on: ubuntu-latest
            steps:
              # renovate: datasource=pypi depName=hatch
              - run: pip install hatch=={version}
        """
    )


class FindProblems(unittest.TestCase):
    def check(self, files, exceptions=()):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            workflows = root / ".github" / "workflows"
            workflows.mkdir(parents=True)
            for name, text in files.items():
                (workflows / name).write_text(text)
            return ctv.find_problems(root, list(exceptions))

    def test_agreeing_defaults_pass(self):
        files = {"a.yml": workflow("node-version", "26"), "b.yml": workflow("node-version", "26")}
        self.assertEqual(self.check(files), [])

    def test_disagreeing_defaults_fail_and_name_both_files(self):
        files = {"a.yml": workflow("node-version", "26"), "b.yml": workflow("node-version", "24")}
        problems = self.check(files)
        self.assertEqual(len(problems), 1)
        self.assertIn("node", problems[0])
        self.assertIn("a.yml", problems[0])
        self.assertIn("b.yml", problems[0])

    def test_a_major_matches_a_full_version_of_the_same_major(self):
        files = {"a.yml": workflow("node-version", "26"), "b.yml": setup_node_workflow("26.13.1")}
        self.assertEqual(self.check(files), [])

    def test_a_setup_step_is_compared_with_an_input_default(self):
        files = {"a.yml": workflow("node-version", "26"), "b.yml": setup_node_workflow("24.22.3")}
        self.assertEqual(len(self.check(files)), 1)

    def test_pinned_tools_in_run_steps_are_compared(self):
        files = {"a.yml": pinned_pip_workflow("1.18.2"), "b.yml": pinned_pip_workflow("1.18.1")}
        problems = self.check(files)
        self.assertEqual(len(problems), 1)
        self.assertIn("hatch", problems[0])

    def test_an_exception_is_honoured(self):
        files = {"a.yml": workflow("node-version", "26"), "b.yml": setup_node_workflow("24.22.3")}
        exceptions = [{"file": ".github/workflows/b.yml", "tool": "node", "reason": "held"}]
        self.assertEqual(self.check(files, exceptions), [])

    def test_an_exception_that_no_longer_differs_fails(self):
        files = {"a.yml": workflow("node-version", "26"), "b.yml": setup_node_workflow("26.1.0")}
        exceptions = [{"file": ".github/workflows/b.yml", "tool": "node", "reason": "held"}]
        problems = self.check(files, exceptions)
        self.assertEqual(len(problems), 1)
        self.assertIn("no longer needed", problems[0])

    def test_an_exception_for_a_missing_entry_fails(self):
        files = {"a.yml": workflow("node-version", "26")}
        exceptions = [{"file": ".github/workflows/gone.yml", "tool": "node", "reason": "held"}]
        problems = self.check(files, exceptions)
        self.assertEqual(len(problems), 1)
        self.assertIn("no longer needed", problems[0])


class Discovery(unittest.TestCase):
    def check(self, tree):
        with tempfile.TemporaryDirectory() as tmp:
            root = pathlib.Path(tmp)
            for rel, text in tree.items():
                path = root / rel
                path.parent.mkdir(parents=True, exist_ok=True)
                path.write_text(text)
            return ctv.find_problems(root, [])

    def test_yaml_extension_workflows_are_read(self):
        tree = {
            ".github/workflows/a.yml": workflow("node-version", "26"),
            ".github/workflows/b.yaml": workflow("node-version", "24"),
        }
        self.assertEqual(len(self.check(tree)), 1)

    def test_composite_actions_are_read_with_either_extension(self):
        for name in ("action.yml", "action.yaml"):
            tree = {
                ".github/workflows/a.yml": workflow("node-version", "26"),
                f".github/actions/x/{name}": "inputs:\n  node-version:\n    default: \"24\"\n",
            }
            self.assertEqual(len(self.check(tree)), 1, name)

    def test_a_wildcard_matches_the_same_major(self):
        tree = {
            ".github/workflows/a.yml": workflow("node-version", "26.x"),
            ".github/workflows/b.yml": setup_node_workflow("26.13.1"),
        }
        self.assertEqual(self.check(tree), [])

    def test_a_wildcard_does_not_match_another_major(self):
        tree = {
            ".github/workflows/a.yml": workflow("node-version", "24.x"),
            ".github/workflows/b.yml": setup_node_workflow("26.13.1"),
        }
        self.assertEqual(len(self.check(tree)), 1)


class Repository(unittest.TestCase):
    def test_defaults_agree(self):
        exceptions = ctv.load_exceptions(REPO / "tests" / "actions" / "tool-version-exceptions.yml")
        self.assertEqual(ctv.find_problems(REPO, exceptions), [])


if __name__ == "__main__":
    unittest.main()
