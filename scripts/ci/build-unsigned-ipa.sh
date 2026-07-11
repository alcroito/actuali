#!/usr/bin/env bash
# Archive the app without signing, then package the .app into an unsigned .ipa.
# The .ipa installs only via re-signing tools (AltStore/Sideloadly).
set -euo pipefail

PROJECT="${PROJECT:-Actuali/Actuali.xcodeproj}"
SCHEME="${SCHEME:-Actuali}"
CONFIGURATION="${CONFIGURATION:-Release}"
LABEL="${LABEL:?LABEL required}"
OUT_DIR="${OUT_DIR:-${RUNNER_TEMP:-./build}}"

mkdir -p "$OUT_DIR"
OUT_DIR="$(cd "$OUT_DIR" && pwd)"   # absolute; the zip step cds into it

ARCHIVE="$OUT_DIR/Actuali.xcarchive"
IPA="$OUT_DIR/Actuali-$LABEL-unsigned.ipa"

xcodebuild archive \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -destination 'generic/platform=iOS' \
  -archivePath "$ARCHIVE" \
  -skipPackagePluginValidation \
  CODE_SIGN_IDENTITY="" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=NO

rm -rf "$OUT_DIR/Payload"
mkdir -p "$OUT_DIR/Payload"
cp -R "$ARCHIVE/Products/Applications/Actuali.app" "$OUT_DIR/Payload/"
( cd "$OUT_DIR" && rm -f "$IPA" && zip -qr "$IPA" Payload )

echo "ipa=$IPA" >> "${GITHUB_OUTPUT:-/dev/stdout}"
