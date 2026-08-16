#!/usr/bin/env bash
#
# Fail unless $1 is a valid version in the $2 format, with no v prefix.
# An empty version passes: it means the caller auto-detects instead.
#
#   check-version.sh 1.2.3rc1 pep440
#
# Kept as a script rather than inline in action.yml so tests/actions/ can run it
# directly -- a PR that changes these rules is then tested by the PR, not by
# whatever `@main` happens to hold.

set -euo pipefail

VERSION="${1-}"
FORMAT="${2:?usage: check-version.sh <version> <semver|pep440|maven>}"

[ -z "$VERSION" ] && exit 0

case "$FORMAT" in
  semver)
    # semver.org's own grammar, transcribed to POSIX ERE: (?: -> ( and \d -> [0-9].
    # Replaces an `npx --yes semver` call, which installed a package from the
    # network on every validation.
    RE='^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-((0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*)(\.(0|[1-9][0-9]*|[0-9]*[a-zA-Z-][0-9a-zA-Z-]*))*))?(\+([0-9a-zA-Z-]+(\.[0-9a-zA-Z-]+)*))?$'
    EXAMPLE='1.2.3, 1.2.3-rc.1'
    ;;
  pep440)
    RE='^[0-9]+(\.[0-9]+)*(a[0-9]+|b[0-9]+|rc[0-9]+)?(\.post[0-9]+)?(\.dev[0-9]+)?$'
    EXAMPLE='1.2.3, 1.2.3rc1, 1.2.3.post1'
    ;;
  maven)
    RE='^[0-9]+(\.[0-9]+)*(-[A-Za-z0-9._-]+)?$'
    EXAMPLE='1.2.3, 1.2.3-rc1, 1.2.3-RELEASE'
    ;;
  *)
    echo "::error::Unknown version-format '$FORMAT'. Must be semver, pep440, or maven."
    exit 1
    ;;
esac

if ! echo "$VERSION" | grep -qE "$RE"; then
  echo "::error::'$VERSION' is not a valid $FORMAT version (e.g. $EXAMPLE -- no v prefix)"
  exit 1
fi
