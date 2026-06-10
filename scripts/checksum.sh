#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="${APP_NAME:-ThoughtRecorder}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
DIST_DIR="${DIST_DIR:-$ROOT_DIR/dist}"
DMG_NAME="${DMG_NAME:-$APP_NAME-$MARKETING_VERSION}"
DMG_PATH="$DIST_DIR/$DMG_NAME.dmg"

if [[ ! -f "$DMG_PATH" ]]; then
  echo "Missing DMG: $DMG_PATH" >&2
  exit 1
fi

shasum -a 256 "$DMG_PATH" | tee "$DMG_PATH.sha256"
