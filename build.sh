#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="${APP_NAME:-ThoughtRecorder}"
EXECUTABLE_NAME="${EXECUTABLE_NAME:-$APP_NAME}"
BUNDLE_ID="${BUNDLE_ID:-local.chriscasey.thoughtrecorder}"
MARKETING_VERSION="${MARKETING_VERSION:-1.0.0}"
BUILD_NUMBER="${BUILD_NUMBER:-$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || echo 1)}"
MIN_MACOS_VERSION="${MIN_MACOS_VERSION:-13.0}"
ARCHS="${ARCHS:-arm64 x86_64}"
SIGN_IDENTITY="${SIGN_IDENTITY:--}"
ENTITLEMENTS="${ENTITLEMENTS:-}"
BUILD_DIR="${BUILD_DIR:-$ROOT_DIR/build}"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"
INTERMEDIATES_DIR="$BUILD_DIR/intermediates"

export APP_NAME EXECUTABLE_NAME BUNDLE_ID MARKETING_VERSION BUILD_NUMBER MIN_MACOS_VERSION

rm -rf "$APP_DIR" "$INTERMEDIATES_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$INTERMEDIATES_DIR"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>__APP_NAME__</string>
    <key>CFBundleExecutable</key>
    <string>__EXECUTABLE_NAME__</string>
    <key>CFBundleIdentifier</key>
    <string>__BUNDLE_ID__</string>
    <key>CFBundleName</key>
    <string>__APP_NAME__</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>__MARKETING_VERSION__</string>
    <key>CFBundleVersion</key>
    <string>__BUILD_NUMBER__</string>
    <key>LSMinimumSystemVersion</key>
    <string>__MIN_MACOS_VERSION__</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>__APP_NAME__ transcribes spoken notes into the currently focused text field.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>__APP_NAME__ records your voice so it can transcribe and paste your thoughts.</string>
</dict>
</plist>
PLIST

perl -0pi -e '
  s/__APP_NAME__/$ENV{APP_NAME}/g;
  s/__EXECUTABLE_NAME__/$ENV{EXECUTABLE_NAME}/g;
  s/__BUNDLE_ID__/$ENV{BUNDLE_ID}/g;
  s/__MARKETING_VERSION__/$ENV{MARKETING_VERSION}/g;
  s/__BUILD_NUMBER__/$ENV{BUILD_NUMBER}/g;
  s/__MIN_MACOS_VERSION__/$ENV{MIN_MACOS_VERSION}/g;
' "$APP_DIR/Contents/Info.plist"

SOURCES=(
  "$ROOT_DIR/RecorderApp.swift"
  "$ROOT_DIR/DebugLogger.swift"
  "$ROOT_DIR/AppDelegate.swift"
  "$ROOT_DIR/HotKeyManager.swift"
  "$ROOT_DIR/LaunchAtLoginManager.swift"
  "$ROOT_DIR/SpeechController.swift"
  "$ROOT_DIR/PasteService.swift"
  "$ROOT_DIR/OverlayWindowController.swift"
)

BUILT_BINARIES=()
for ARCH in ${(z)ARCHS}; do
  OUTPUT="$INTERMEDIATES_DIR/$EXECUTABLE_NAME-$ARCH"
  echo "Compiling $APP_NAME for $ARCH..."
  swiftc \
  -target "$ARCH-apple-macos$MIN_MACOS_VERSION" \
  -framework AppKit \
  -framework SwiftUI \
  -framework AVFoundation \
  -framework Speech \
  -framework ApplicationServices \
  "${SOURCES[@]}" \
  -o "$OUTPUT"
  BUILT_BINARIES+=("$OUTPUT")
done

if [[ "${#BUILT_BINARIES[@]}" -gt 1 ]]; then
  lipo -create "${BUILT_BINARIES[@]}" -output "$MACOS_DIR/$EXECUTABLE_NAME"
else
  cp "$BUILT_BINARIES[1]" "$MACOS_DIR/$EXECUTABLE_NAME"
fi

chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

CODE_SIGN_ARGS=(--force --deep --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  CODE_SIGN_ARGS+=(--options runtime --timestamp)
fi
if [[ -n "$ENTITLEMENTS" ]]; then
  CODE_SIGN_ARGS+=(--entitlements "$ENTITLEMENTS")
fi

codesign "${CODE_SIGN_ARGS[@]}" "$APP_DIR" >/dev/null
codesign --verify --deep --strict "$APP_DIR"

echo "Built: $APP_DIR"
echo "Version: $MARKETING_VERSION ($BUILD_NUMBER)"
echo "Bundle ID: $BUNDLE_ID"
echo "Architectures: $(lipo -archs "$MACOS_DIR/$EXECUTABLE_NAME")"
