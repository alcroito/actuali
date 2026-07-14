#!/usr/bin/env bash
# Publish a fork GitHub release. The release workflow then builds the IPA and
# publishes the AltStore source.
#
# Default tag: v<MARKETING_VERSION>-<CURRENT_PROJECT_VERSION>-<DD.MM.YYYY>-fork
#   e.g. v1.0.6-76-14.07.2026-fork
# The build-number segment is dropped when CURRENT_PROJECT_VERSION is empty:
#   v<MARKETING_VERSION>-<DD.MM.YYYY>-fork
# Both versions are parsed from the app target's build settings in project.pbxproj.
#
# Inputs (all optional):
#   TAG         full tag to use verbatim; skips version/date construction
#   VERSION     override the parsed MARKETING_VERSION
#   BUILD       override the parsed CURRENT_PROJECT_VERSION
#   BUNDLE_ID   app bundle id used to locate the target's config (default: com.mfazz.ActualiOS)
#   TARGET      commit-ish the tag points at (default: main)
#   TITLE       release title (default: the tag)
#   NOTES       release body (default: auto-generated from commits)
#   PRERELEASE  non-empty to mark the release as a prerelease
# Repo is inferred from the git remote.
set -euo pipefail

# Echo the inputs this script was called with (mise passes them as env vars).
{
  echo "create-release.sh inputs:"
  echo "  TAG=${TAG:-} VERSION=${VERSION:-} BUILD=${BUILD:-} BUNDLE_ID=${BUNDLE_ID:-}"
  echo "  TARGET=${TARGET:-} TITLE=${TITLE:-} PRERELEASE=${PRERELEASE:-}"
  echo "  NOTES=${NOTES:-}"
  [ "$#" -gt 0 ] && echo "  positional args: $*"
} >&2

PROJECT="${PROJECT:-Actuali/Actuali.xcodeproj}"
BUNDLE_ID="${BUNDLE_ID:-com.mfazz.ActualiOS}"

if [ -z "${TAG:-}" ]; then
  version="${VERSION:-}"
  build="${BUILD:-}"
  if [ -z "$version" ] || [ -z "$build" ]; then
    # Parse the app target's config block: track MARKETING_VERSION and
    # CURRENT_PROJECT_VERSION, emit them when its PRODUCT_BUNDLE_IDENTIFIER is hit.
    pbxproj="$PROJECT/project.pbxproj"
    parsed="$(awk -v bid="$BUNDLE_ID" '
      /isa = XCBuildConfiguration/                       { mv=""; cpv="" }
      /^[[:space:]]*MARKETING_VERSION = /                { mv=$NF; sub(/;/,"",mv) }
      /^[[:space:]]*CURRENT_PROJECT_VERSION = /          { cpv=$NF; sub(/;/,"",cpv) }
      $0 ~ "PRODUCT_BUNDLE_IDENTIFIER = " bid ";"        { print mv "|" cpv; exit }
    ' "$pbxproj")"
    [ -z "$version" ] && version="${parsed%%|*}"
    [ -z "$build" ] && build="${parsed##*|}"
  fi
  version="${version//[[:space:]]/}"
  build="${build//[[:space:]]/}"
  : "${version:?could not determine MARKETING_VERSION; pass VERSION= or TAG=}"

  date_str="$(date +%d.%m.%Y)"
  if [ -n "$build" ]; then
    TAG="v${version}-${build}-${date_str}-fork"
  else
    TAG="v${version}-${date_str}-fork"
  fi
fi

echo "Creating release $TAG (target ${TARGET:-main})" >&2
args=(release create "$TAG" --target "${TARGET:-main}" --title "${TITLE:-$TAG}")
if [ -n "${NOTES:-}" ]; then args+=(--notes "$NOTES"); else args+=(--generate-notes); fi
case "${PRERELEASE:-}" in 1 | true | yes) args+=(--prerelease) ;; esac

{ printf '+ gh'; printf ' %q' "${args[@]}"; printf '\n'; } >&2
gh "${args[@]}"
