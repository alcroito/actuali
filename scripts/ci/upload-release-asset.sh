#!/usr/bin/env bash
# Attach the built .ipa to an existing GitHub release. Needs GH_TOKEN in env.
set -euo pipefail

gh release upload "${RELEASE_TAG:?RELEASE_TAG required}" "${IPA:?IPA required}" --clobber
