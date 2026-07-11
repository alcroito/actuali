#!/usr/bin/env bash
# Emit a filename-safe version label for the build artifact.
# Release events use the tag; everything else uses PR number + short SHA.
set -euo pipefail

if [ "${GITHUB_EVENT_NAME:-}" = "release" ]; then
  label="${RELEASE_TAG:?RELEASE_TAG required for release event}"
else
  sha="${GITHUB_SHA:-unknown}"
  label="pr${PR_NUMBER:-local}-${sha:0:7}"
fi

echo "label=$label" >> "${GITHUB_OUTPUT:-/dev/stdout}"
