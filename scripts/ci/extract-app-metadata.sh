#!/usr/bin/env bash
# Extract AltStore-relevant metadata from the built .app and .ipa.
# Reads the app's Info.plist so the values match what AltStore validates at
# install time (bundle id, version, build), plus the exact .ipa byte size.
set -euo pipefail

APP="${APP:?APP required (path to built .app)}"
IPA="${IPA:?IPA required (path to built .ipa)}"
PLIST="$APP/Info.plist"

pb() { /usr/libexec/PlistBuddy -c "Print :$1" "$PLIST"; }

version="$(pb CFBundleShortVersionString)"
buildVersion="$(pb CFBundleVersion)"
bundleId="$(pb CFBundleIdentifier)"
minOS="$(pb MinimumOSVersion)"
size="$(stat -f%z "$IPA")"

{
  echo "version=$version"
  echo "buildVersion=$buildVersion"
  echo "bundleId=$bundleId"
  echo "minOS=$minOS"
  echo "size=$size"
} >> "${GITHUB_OUTPUT:-/dev/stdout}"
