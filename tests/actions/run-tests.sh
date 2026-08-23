#!/usr/bin/env bash
#
# Tests the shell behind the composite actions in .github/actions/.
#
# These replaced the act-driven fixtures that used to exercise
# common-check-release.yml end to end. Once that workflow delegated to composite
# actions referenced as `reqstool/.github/...@main`, act resolved them against
# whatever main held -- so a PR changing the rules was tested against the *old*
# rules, and a PR adding an action failed until it was merged. Running the
# scripts directly tests the branch under test, and takes a second rather than a
# container per case.

set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ACTIONS="$ROOT/.github/actions"

pass=0
fail=0

# expect <expected-exit> <description> -- <command...>
expect() {
  local want="$1" desc="$2"
  shift 3 # want, desc, --
  local out got
  out="$("$@" 2>&1)"
  got=$?
  if [ "$got" = "$want" ]; then
    pass=$((pass + 1))
  else
    fail=$((fail + 1))
    echo "FAIL: $desc"
    echo "      expected exit $want, got $got"
    echo "      command: $*"
    [ -n "$out" ] && echo "      output: $out"
  fi
}

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

# --------------------------------------------------------------------------
# check-version.sh
# --------------------------------------------------------------------------
CV="$ACTIONS/check-version/check-version.sh"

expect 0 "empty version passes (means auto-detect)"     -- "$CV" "" pep440
expect 0 "empty version passes for semver"              -- "$CV" "" semver

expect 0 "pep440 release"                               -- "$CV" 1.2.3 pep440
expect 0 "pep440 rc"                                    -- "$CV" 1.2.3rc1 pep440
expect 0 "pep440 alpha"                                 -- "$CV" 1.2.3a1 pep440
expect 0 "pep440 post"                                  -- "$CV" 1.2.3.post1 pep440
expect 1 "pep440 rejects a v prefix"                    -- "$CV" v1.2.3 pep440
expect 1 "pep440 rejects a semver-style rc"             -- "$CV" 1.2.3-rc.1 pep440
expect 1 "pep440 rejects gibberish"                     -- "$CV" not-a-version pep440

expect 0 "semver release"                               -- "$CV" 1.2.3 semver
expect 0 "semver rc"                                    -- "$CV" 1.2.3-rc.1 semver
expect 0 "semver build metadata"                        -- "$CV" 1.2.3+build.1 semver
expect 1 "semver rejects a v prefix"                    -- "$CV" v1.2.3 semver
expect 1 "semver rejects two components"                -- "$CV" 1.2 semver
expect 1 "semver rejects a leading zero"                -- "$CV" 01.2.3 semver
expect 1 "semver rejects a pep440 rc"                   -- "$CV" 1.2.3rc1 semver

expect 0 "maven release"                                -- "$CV" 1.2.3 maven
expect 0 "maven rc"                                     -- "$CV" 1.2.3-rc1 maven
expect 0 "maven qualifier"                              -- "$CV" 1.2.3-RELEASE maven
expect 1 "maven rejects a v prefix"                     -- "$CV" v1.2.3 maven
expect 1 "maven rejects gibberish"                      -- "$CV" "not a version" maven

expect 1 "unknown format is rejected"                   -- "$CV" 1.2.3 npm

# --------------------------------------------------------------------------
# check-release-branch.sh
# --------------------------------------------------------------------------
CB="$ACTIONS/check-release-branch/check-release-branch.sh"

expect 0 "main"                                         -- "$CB" main
expect 0 "main as a full ref"                           -- "$CB" refs/heads/main
expect 0 "hotfix branch"                                -- "$CB" hotfix/urgent
expect 0 "release branch as a full ref"                 -- "$CB" refs/heads/release/1.x
expect 1 "a feature branch is rejected"                 -- "$CB" feat/whatever
expect 1 "a raw SHA is rejected"                        -- "$CB" 0123456789abcdef0123456789abcdef01234567
expect 1 "a tag ref is rejected"                        -- "$CB" refs/tags/1.2.3

# --------------------------------------------------------------------------
# next-prerelease.sh -- needs a repo with tags to count from
# --------------------------------------------------------------------------
NP="$ACTIONS/resolve-version/next-prerelease.sh"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
(
  cd "$TMP" || exit 1
  # Overridden explicitly so a contributor's global git config -- a commit
  # template, or gpg signing with no key available here -- can't fail the run.
  git -c init.templateDir= init -q .
  git -c user.email=t@t -c user.name=t -c commit.gpgsign=false \
    commit -q --allow-empty -m init
) || { echo "FAIL: could not set up the temp repo"; exit 1; }

cd "$TMP" || exit 1

expect_output "0.5.0rc1"   "pep440 first candidate"     -- "$NP" 0.5.0 rc pep440
expect_output "0.5.0-rc.1" "semver first candidate"     -- "$NP" 0.5.0 rc semver
expect_output "0.5.0-rc1"  "maven first candidate"      -- "$NP" 0.5.0 rc maven
expect_output "0.5.0b1"    "pep440 first beta"          -- "$NP" 0.5.0 b pep440

for t in 0.5.0rc1 0.5.0rc9 0.5.0-rc.1 0.5.0-rc1 0.5.0-b1 0.5.0-build2; do git tag "$t"; done

# rc9 -> rc10, not rc2: the comparison is numeric, not lexical.
expect_output "0.5.0rc10" "pep440 counts numerically"   -- "$NP" 0.5.0 rc pep440
expect_output "0.5.0-rc.2" "semver counts existing"     -- "$NP" 0.5.0 rc semver
expect_output "0.5.0-rc2"  "maven counts existing"      -- "$NP" 0.5.0 rc maven
# `0.5.0-b*` also globs `0.5.0-build2`; "uild2" is not numeric, so it is dropped.
expect_output "0.5.0-b2"   "maven beta ignores -build2" -- "$NP" 0.5.0 b maven
# A different base is unaffected by the tags above.
expect_output "0.6.0rc1"   "a fresh base starts at 1"   -- "$NP" 0.6.0 rc pep440

expect 1 "an unknown kind is rejected"                  -- "$NP" 0.5.0 x pep440
expect 1 "an unknown format is rejected"                -- "$NP" 0.5.0 rc npm

cd "$ROOT" || exit 1

# --------------------------------------------------------------------------
# publish-to-pypi/check-target.sh
# --------------------------------------------------------------------------
CT="$ACTIONS/publish-to-pypi/check-target.sh"

expect 0 "pypi is accepted"              -- "$CT" pypi
expect 0 "testpypi is accepted"          -- "$CT" testpypi
expect 1 "an unknown target is rejected" -- "$CT" prod
expect 1 "an empty target is rejected"   -- "$CT" ""

# --------------------------------------------------------------------------
echo ""
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
