#!/usr/bin/env bash
# Assemble the GitHub Pages site for the AltStore source:
#   $SITE_DIR/source.json - AltStore source manifest (accumulates version history)
#   $SITE_DIR/index.html  - "Add to AltStore" landing page
#   $SITE_DIR/icon.png    - app icon referenced by the manifest
#
# The .ipa itself is NOT hosted here; downloadURL points at the GitHub release
# asset. Version history is preserved by fetching the currently published
# source.json and prepending the new version (dedup by version+build).
set -euo pipefail

SITE_DIR="${SITE_DIR:?SITE_DIR required}"
ICON_SRC="${ICON_SRC:-Actuali/Actuali/Assets.xcassets/AppIcon.appiconset/AppIcon.png}"
TEMPLATE="${TEMPLATE:-altstore/index.html}"

# Build metadata (supplied by the workflow from the built artifact).
BUNDLE_ID="${BUNDLE_ID:?}"
VERSION="${VERSION:?}"
BUILD_VERSION="${BUILD_VERSION:?}"
MIN_OS="${MIN_OS:?}"
SIZE="${SIZE:?}"
RELEASE_TAG="${RELEASE_TAG:?}"
RELEASE_DATE="${RELEASE_DATE:?}"   # ISO 8601, e.g. release published_at
LABEL="${LABEL:?}"                 # artifact label; matches the .ipa filename
REPO="${REPO:?}"                   # owner/name
SERVER_URL="${SERVER_URL:-https://github.com}"
OWNER="${OWNER:?}"

# Display strings (override via env if desired).
SOURCE_NAME="${SOURCE_NAME:-Actuali (unofficial)}"
APP_NAME="${APP_NAME:-Actuali}"
DEVELOPER_NAME="${DEVELOPER_NAME:-$OWNER}"
SUBTITLE="${SUBTITLE:-Unsigned builds of Actuali}"
DESCRIPTION="${DESCRIPTION:-Unofficial AltStore source serving unsigned Actuali builds. Each install is re-signed on-device with your own Apple ID.}"
TINT_COLOR="${TINT_COLOR:-8719E0}"          # app accent color, hex without '#'
RELEASE_BODY="${RELEASE_BODY:-}"            # release notes -> per-version changelog
PRIVACY="${PRIVACY:-{\}}"                   # {NSKey: description} the app requests
ENTITLEMENTS="${ENTITLEMENTS:-[]}"          # entitlement identifiers (none for unsigned)

owner_lc="$(printf '%s' "$OWNER" | tr '[:upper:]' '[:lower:]')"
repo_name="${REPO#*/}"
PAGES_BASE="${PAGES_BASE:-https://${owner_lc}.github.io/${repo_name}}"
SOURCE_URL="$PAGES_BASE/source.json"
ICON_URL="$PAGES_BASE/icon.png"
DOWNLOAD_URL="$SERVER_URL/$REPO/releases/download/$RELEASE_TAG/Actuali-$LABEL-unsigned.ipa"

mkdir -p "$SITE_DIR"

# Guard against malformed/empty permission inputs.
printf '%s' "$PRIVACY" | jq empty 2>/dev/null || PRIVACY='{}'
printf '%s' "$ENTITLEMENTS" | jq empty 2>/dev/null || ENTITLEMENTS='[]'

# Prior versions (best effort; empty on the first ever deploy).
prev='[]'
if curl -fsSL "$SOURCE_URL" -o "$SITE_DIR/.prev-source.json" 2>/dev/null; then
  prev="$(jq -c '.apps[0].versions // []' "$SITE_DIR/.prev-source.json" 2>/dev/null || echo '[]')"
fi
rm -f "$SITE_DIR/.prev-source.json"

new_version="$(jq -n \
  --arg version "$VERSION" \
  --arg buildVersion "$BUILD_VERSION" \
  --arg date "$RELEASE_DATE" \
  --arg localizedDescription "$RELEASE_BODY" \
  --arg downloadURL "$DOWNLOAD_URL" \
  --argjson size "$SIZE" \
  --arg minOSVersion "$MIN_OS" \
  '{version:$version, buildVersion:$buildVersion, date:$date, localizedDescription:$localizedDescription, downloadURL:$downloadURL, size:$size, minOSVersion:$minOSVersion}')"

# Prepend the new version; drop any prior entry with the same version+build.
versions="$(jq -n --argjson new "$new_version" --argjson prev "$prev" \
  '[$new] + [ $prev[] | select((.version != $new.version) or (.buildVersion != $new.buildVersion)) ]')"

jq -n \
  --arg name "$SOURCE_NAME" \
  --arg website "$PAGES_BASE" \
  --arg appName "$APP_NAME" \
  --arg bundleId "$BUNDLE_ID" \
  --arg dev "$DEVELOPER_NAME" \
  --arg subtitle "$SUBTITLE" \
  --arg desc "$DESCRIPTION" \
  --arg iconURL "$ICON_URL" \
  --arg tintColor "$TINT_COLOR" \
  --argjson privacy "$PRIVACY" \
  --argjson entitlements "$ENTITLEMENTS" \
  --argjson versions "$versions" \
  '{
    name: $name,
    subtitle: "Unofficial Actuali source",
    iconURL: $iconURL,
    tintColor: $tintColor,
    website: $website,
    apps: [ {
      name: $appName,
      bundleIdentifier: $bundleId,
      developerName: $dev,
      subtitle: $subtitle,
      localizedDescription: $desc,
      iconURL: $iconURL,
      tintColor: $tintColor,
      category: "utilities",
      appPermissions: { entitlements: $entitlements, privacy: $privacy },
      versions: $versions
    } ],
    news: []
  }' > "$SITE_DIR/source.json"

cp "$ICON_SRC" "$SITE_DIR/icon.png"

# Render the landing page from the template.
sed \
  -e "s|__SOURCE_URL__|$SOURCE_URL|g" \
  -e "s|__APP_NAME__|$APP_NAME|g" \
  -e "s|__ICON_URL__|$ICON_URL|g" \
  -e "s|__DOWNLOAD_URL__|$DOWNLOAD_URL|g" \
  -e "s|__VERSION__|$VERSION|g" \
  "$TEMPLATE" > "$SITE_DIR/index.html"

echo "Assembled AltStore Pages site in $SITE_DIR:"
ls -la "$SITE_DIR"
