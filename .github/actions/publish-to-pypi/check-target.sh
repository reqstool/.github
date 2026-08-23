#!/usr/bin/env bash
#
# Fail unless $1 is 'pypi' or 'testpypi'.
#
#   check-target.sh pypi
#
# Kept as a script rather than inline in action.yml so tests/actions/ can run it
# directly -- see check-version.sh for why.

set -euo pipefail

TARGET="${1:?usage: check-target.sh <pypi|testpypi>}"

case "$TARGET" in
  pypi|testpypi) ;;
  *)
    echo "::error::target must be 'pypi' or 'testpypi' (got: '$TARGET')"
    exit 1
    ;;
esac
