#!/usr/bin/env bash
#
# Tests the contract between two workflows that cannot see each other:
# typescript-build.yml packs a tarball, and common-release-assets.yml refuses to
# release unless some artifact filename carries the version. Nothing else checks
# that the first actually satisfies the second -- tests/typescript/build.yml is
# parsed by actionlint and never executed, and it passes no version, which is
# the only path on which the pack step runs.
#
# Run against the real fixture rather than a mocked `npm pack`: the claim being
# pinned is npm's naming, including a scoped name flattening to
# `reqstool-test-package-<version>.tgz`. A mock would assert our belief about
# npm back to us.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FIXTURE="$ROOT/tests/_resources/fake-npm-package"
VERSION="0.3.0"

pass=0
fail=0

# expect_output <expected-stdout> <description> -- <command...>
expect_output() {
  local want="$1" desc="$2"
  shift 3
  local got
  got="$("$@" 2>/dev/null)"
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc"
    echo "      expected '$want', got '$got'"
  fi
}

# The predicate from the "Assert the artifacts carry the version" step in
# .github/workflows/common-release-assets.yml. Kept in lock-step with it.
matched() {
  find "$1" -type f -name "*$2*" | wc -l | tr -d '[:space:]'
}

selected() {
  find "$1" -type f -name "$2" | wc -l | tr -d '[:space:]'
}

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

cp -r "$FIXTURE" "$WORK/pkg"
cd "$WORK/pkg" || exit 1

npm version "$VERSION" --no-git-tag-version --allow-same-version > /dev/null 2>&1
npm run build > /dev/null 2>&1

# --------------------------------------------------------------------------
# The regression this guards against
# --------------------------------------------------------------------------
# A dist/ tree on its own is index.js and friends -- the version appears in no
# filename, so the assert step refuses the release. This is what failed
# reqstool-typescript-tags 0.3.0 with everything upstream green.
expect_output 0 "a plain dist tree carries the version nowhere" \
  -- matched dist "$VERSION"

# --------------------------------------------------------------------------
# What the pack step adds
# --------------------------------------------------------------------------
npm pack --pack-destination dist > /dev/null 2>&1

expect_output 1 "a scoped package packs a tarball carrying the version" \
  -- matched dist "$VERSION"

# What the caller attaches: the tarball alone, not the .js files beside it.
expect_output 1 "the *.tgz pattern selects exactly the tarball" \
  -- selected dist "*.tgz"

# Packing into dist/ is only safe because the contents are collected before the
# tarball is written there -- otherwise each release would nest the last one.
expect_output 0 "the tarball does not contain itself" \
  -- bash -c 'tar tzf dist/*.tgz | grep -c "\.tgz$"'

cd "$ROOT" || exit 1

# --------------------------------------------------------------------------
echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
