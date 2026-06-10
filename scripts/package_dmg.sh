#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-ThoughtRecorder}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
DMG_NAME="${DMG_NAME:-$APP_NAME-$MARKETING_VERSION}"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"
STAGING_DIR="$BUILD_DIR/dmg-staging"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
NOTARIZE="${NOTARIZE:-0}"
NOTARY_PROFILE="${NOTARY_PROFILE:-}"

export APP_NAME MARKETING_VERSION BUILD_DIR SIGN_IDENTITY

if [[ "${SKIP_BUILD:-0}" != "1" ]]; then
  "$ROOT_DIR/build.sh"
fi

if [[ ! -d "$APP_DIR" ]]; then
  echo "Missing app bundle: $APP_DIR" >&2
  exit 1
fi

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$DIST_DIR"
cp -R "$APP_DIR" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG_PATH"
fi

if [[ "$NOTARIZE" == "1" ]]; then
  if [[ "$SIGN_IDENTITY" == "-" ]]; then
    echo "NOTARIZE=1 requires SIGN_IDENTITY to be a Developer ID Application certificate." >&2
    exit 1
  fi

  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$DMG_PATH" --keychain-profile "$NOTARY_PROFILE" --wait
  else
    : "${APPLE_ID:?APPLE_ID is required when NOTARY_PROFILE is not set}"
    : "${APPLE_TEAM_ID:?APPLE_TEAM_ID is required when NOTARY_PROFILE is not set}"
    : "${APP_SPECIFIC_PASSWORD:?APP_SPECIFIC_PASSWORD is required when NOTARY_PROFILE is not set}"
    xcrun notarytool submit "$DMG_PATH" \
      --apple-id "$APPLE_ID" \
      --team-id "$APPLE_TEAM_ID" \
      --password "$APP_SPECIFIC_PASSWORD" \
      --wait
  fi

  xcrun stapler staple "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH" >/dev/null

echo "Packaged: $DMG_PATH"
