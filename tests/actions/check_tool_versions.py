#!/usr/bin/env python3
"""Fail when the same tool carries different versions in different files.

A shared workflow cannot read a central version file at runtime, so each file
carries its own default and Renovate bumps them. A bump that lands in one file
and not another is caught here, in the PR, instead of by a consumer.

Versions are compared at the coarsest granularity present for a tool, so `26`
matches `26.13.1`. Deliberate differences are listed in
tool-version-exceptions.yml; an exception that no longer differs fails too.
"""
import os
import pathlib
import re
import sys

import yaml

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
EXCEPTIONS = HERE / "tool-version-exceptions.yml"

ANNOTATIONS = [
    re.compile(r'# renovate: datasource=[a-z-]+? depName=(?P<tool>\S+)\s+default: "(?P<version>[^"]+)"'),
    re.compile(r'# renovate: datasource=[a-z-]+? depName=(?P<tool>\S+)\s+VERSION="(?P<version>[^"]+)"'),
    re.compile(r"# renovate: datasource=[a-z-]+? depName=(?P<tool>\S+)\s+[^\n]*?(?:==|@)(?P<version>[0-9][^\s\"']*)"),
]
SETUP_ACTIONS = {
    "actions/setup-node": ("node", "node-version"),
    "actions/setup-python": ("python", "python-version"),
    "actions/setup-java": ("java", "java-version"),
}
INPUT_NAME = re.compile(r"^(?P<tool>.+)-version$")


def files(root):
    for pattern in (".github/workflows/*.y*ml", ".github/actions/*/action.y*ml"):
        yield from sorted(root.glob(pattern))


def literal(value):
    return isinstance(value, (str, int, float)) and "${{" not in str(value)


def records(root):
    for path in files(root):
        rel = path.relative_to(root).as_posix()
        text = path.read_text()
        for pattern in ANNOTATIONS:
            for match in pattern.finditer(text):
                yield rel, match["tool"], match["version"]

        doc = yaml.safe_load(text)
        if not isinstance(doc, dict):
            continue
        trigger = doc.get("on", doc.get(True))
        inputs = (trigger.get("workflow_call") or {}).get("inputs") if isinstance(trigger, dict) else None
        inputs = inputs or doc.get("inputs") or {}
        for name, spec in inputs.items():
            match = INPUT_NAME.match(name)
            if match and isinstance(spec, dict) and literal(spec.get("default")):
                yield rel, match["tool"], str(spec["default"])

        jobs = doc.get("jobs") or {}
        steps = [s for job in jobs.values() for s in job.get("steps", [])]
        steps += (doc.get("runs") or {}).get("steps", [])
        for step in steps:
            action = str(step.get("uses", "")).split("@")[0]
            if action in SETUP_ACTIONS:
                tool, key = SETUP_ACTIONS[action]
                value = (step.get("with") or {}).get(key)
                if literal(value):
                    yield rel, tool, str(value)


def normalise(version):
    parts = version.lstrip("v").split(".")
    while len(parts) > 1 and parts[-1] in ("x", "X", "*"):
        parts.pop()
    return parts


def keys(entries):
    width = min(len(normalise(v)) for _, v in entries)
    return {".".join(normalise(v)[:width]) for _, v in entries}


def find_problems(root, exceptions):
    by_tool = {}
    for rel, tool, version in sorted(set(records(root))):
        by_tool.setdefault(tool, []).append((rel, version))

    problems = []
    excepted = {(e["file"], e["tool"]) for e in exceptions}
    for tool, entries in sorted(by_tool.items()):
        checked = [(f, v) for f, v in entries if (f, tool) not in excepted]
        if checked and len(keys(checked)) > 1:
            lines = "\n".join(f"    {f}: {v}" for f, v in checked)
            problems.append(f"{tool} has different versions:\n{lines}")

    for exception in exceptions:
        tool, rel = exception["tool"], exception["file"]
        held = [(f, v) for f, v in by_tool.get(tool, []) if f == rel]
        others = [(f, v) for f, v in by_tool.get(tool, []) if (f, tool) not in excepted]
        if not held or not others or len(keys(held + others)) == 1:
            problems.append(f"exception for {tool} in {rel} is no longer needed: remove it from {EXCEPTIONS.name}")
    return problems


def load_exceptions(path):
    return yaml.safe_load(path.read_text()) or []


def main():
    problems = find_problems(ROOT, load_exceptions(EXCEPTIONS))
    for problem in problems:
        print(f"::error::{problem}" if "GITHUB_ACTIONS" in os.environ else problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
