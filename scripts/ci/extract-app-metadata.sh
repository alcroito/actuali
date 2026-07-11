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

# Privacy usage descriptions (NS*UsageDescription) as a {key: description} map.
# AltStore blocks install unless the source declares every permission the app
# requests, so derive them from the built app to keep the source in sync.
privacy="$(plutil -convert json -o - "$PLIST" \
  | jq -c 'to_entries | map(select(.key | test("UsageDescription$"))) | from_entries')"

out="${GITHUB_OUTPUT:-/dev/stdout}"
{
  echo "version=$version"
  echo "buildVersion=$buildVersion"
  echo "bundleId=$bundleId"
  echo "minOS=$minOS"
  echo "size=$size"
  # delimiter form: privacy is JSON and may contain arbitrary description text
  echo "privacy<<PRIVACY_EOF"
  echo "$privacy"
  echo "PRIVACY_EOF"
} >> "$out"
