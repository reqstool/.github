#!/usr/bin/env bash
#
# Print the next unused prerelease version for a base version, in the spelling
# the target ecosystem expects.
#
#   next-prerelease.sh 0.5.0 rc pep440   ->  0.5.0rc1,    then 0.5.0rc2, ...
#   next-prerelease.sh 0.5.0 rc semver   ->  0.5.0-rc.1,  then 0.5.0-rc.2, ...
#   next-prerelease.sh 0.5.0 rc maven    ->  0.5.0-rc1,   then 0.5.0-rc2, ...
#
# git-cliff only ever emits final versions; this is what turns its
# --bumped-version into a release candidate.
#
# The three spellings are not interchangeable. PEP 440 normalises `0.5.0-rc1` to
# `0.5.0rc1`, so a hyphenated tag would stop matching the sdist filename the
# release asserts on. semver requires the dot-separated identifier to compare
# below `0.5.0`. Maven's ComparableVersion ranks the `a`/`b`/`rc` qualifiers
# below an unqualified version only when they are hyphen-separated.

set -euo pipefail

BASE="${1:?usage: next-prerelease.sh <base-version> <a|b|rc> <semver|pep440|maven>}"
KIND="${2:?usage: next-prerelease.sh <base-version> <a|b|rc> <semver|pep440|maven>}"
FORMAT="${3:?usage: next-prerelease.sh <base-version> <a|b|rc> <semver|pep440|maven>}"

case "$KIND" in
  a|b|rc) ;;
  *) echo "next-prerelease.sh: kind must be a, b or rc (got '$KIND')" >&2; exit 1 ;;
esac

case "$FORMAT" in
  pep440) PREFIX="${BASE}${KIND}" ;;
  semver) PREFIX="${BASE}-${KIND}." ;;
  maven)  PREFIX="${BASE}-${KIND}" ;;
  *) echo "next-prerelease.sh: format must be semver, pep440 or maven (got '$FORMAT')" >&2; exit 1 ;;
esac

highest=0
while IFS= read -r tag; do
  n="${tag#"$PREFIX"}"
  # Numeric compare, so rc9 -> rc10 rather than rc9 -> rc2. The guard also drops
  # anything the glob dragged in that isn't a plain number (0.5.0rc1.post1, and
  # for maven the `b` prefix shared with a `-build2` qualifier).
  [[ "$n" =~ ^[0-9]+$ ]] || continue
  ((n > highest)) && highest="$n"
done < <(git tag --list "${PREFIX}*")

echo "${PREFIX}$((highest + 1))"
