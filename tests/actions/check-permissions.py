#!/usr/bin/env python3
"""Fail if a reusable workflow requests a permission none of its jobs can use.

A called workflow may not request more than its caller granted; asking for more
is rejected before any job runs, and that rejection produces no check run -- so
it does not show up in `gh pr checks` or a PR's checks rollup, and the PR looks
green. That has bitten five times in this org.

The specific shape caught here: a workflow-level `permissions:` block listing a
scope that *every* job overrides away with its own block. A job without its own
block inherits the workflow-level one, which is normal and not flagged -- but a
scope no job can reach is still counted as part of what the workflow requests,
so a caller granting exactly what the jobs need is refused. That is what broke
python-publish-to-pypi.yml, whose jobs declare `id-token: write` while the
workflow asked for a `contents: read` it has no checkout to use.
"""
import pathlib
import sys

import yaml

RANK = {"none": 0, "read": 1, "write": 2}
root = pathlib.Path(__file__).resolve().parents[2] / ".github" / "workflows"
problems = []

for path in sorted(root.glob("*.yml")):
    doc = yaml.safe_load(path.read_text())
    if not isinstance(doc, dict):
        continue
    # PyYAML parses the `on:` key as the boolean True.
    triggers = doc.get(True) or doc.get("on") or {}
    if "workflow_call" not in (triggers or {}):
        continue
    top = doc.get("permissions")
    if not isinstance(top, dict) or not top:
        continue

    jobs = doc.get("jobs") or {}
    if not jobs:
        continue

    # Effective permissions per job: its own block if it has one, else inherited.
    reachable = {}
    for job in jobs.values():
        eff = job.get("permissions") if isinstance(job.get("permissions"), dict) else top
        for scope, level in (eff or {}).items():
            if RANK.get(str(level), 0) > RANK.get(str(reachable.get(scope, "none")), 0):
                reachable[scope] = level

    for scope, level in top.items():
        if RANK.get(str(level), 0) > RANK.get(str(reachable.get(scope, "none")), 0):
            problems.append(
                f"{path.name}: workflow-level `{scope}: {level}` is overridden away by "
                f"every job, but is still part of what this workflow requests. A caller "
                f"granting only what the jobs need will be rejected before any job runs."
            )

if problems:
    print("Reusable workflows requesting a permission no job can use:\n")
    for p in problems:
        print(f"  - {p}")
    sys.exit(1)
print(f"OK: no reusable workflow requests a permission its jobs cannot use.")
