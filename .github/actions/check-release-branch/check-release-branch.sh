#!/usr/bin/env bash
#
# Fail unless $1 names a branch releases may be cut from.
#
#   check-release-branch.sh refs/heads/main
#   check-release-branch.sh hotfix/urgent
#
# Kept as a script rather than inline in action.yml so tests/actions/ can run it
# directly -- see check-version.sh for why.

set -euo pipefail

REF="${1:?usage: check-release-branch.sh <branch-or-ref>}"
BRANCH="${REF#refs/heads/}"

if [[ "$BRANCH" != "main" && "$BRANCH" != hotfix/* && "$BRANCH" != release/* ]]; then
  echo "::error::Releases must come from main, hotfix/*, or release/* (got: '$BRANCH')."
  echo "::error::If you passed a raw commit SHA, release from the branch containing it instead."
  exit 1
fi
