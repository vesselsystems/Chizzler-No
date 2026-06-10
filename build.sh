#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
APP_NAME="ThoughtRecorder"
BUILD_DIR="$ROOT_DIR/build"
APP_DIR="$BUILD_DIR/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RESOURCES_DIR="$APP_DIR/Contents/Resources"

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

cat > "$APP_DIR/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDisplayName</key>
    <string>ThoughtRecorder</string>
    <key>CFBundleExecutable</key>
    <string>ThoughtRecorder</string>
    <key>CFBundleIdentifier</key>
    <string>local.chriscasey.thoughtrecorder</string>
    <key>CFBundleName</key>
    <string>ThoughtRecorder</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSSpeechRecognitionUsageDescription</key>
    <string>ThoughtRecorder transcribes spoken notes into the currently focused text field.</string>
    <key>NSMicrophoneUsageDescription</key>
    <string>ThoughtRecorder records your voice so it can transcribe and paste your thoughts.</string>
</dict>
</plist>
PLIST

swiftc \
  -target arm64-apple-macos13.0 \
  -framework AppKit \
  -framework SwiftUI \
  -framework AVFoundation \
  -framework Speech \
  -framework ApplicationServices \
  "$ROOT_DIR/RecorderApp.swift" \
  "$ROOT_DIR/DebugLogger.swift" \
  "$ROOT_DIR/AppDelegate.swift" \
  "$ROOT_DIR/HotKeyManager.swift" \
  "$ROOT_DIR/LaunchAtLoginManager.swift" \
  "$ROOT_DIR/SpeechController.swift" \
  "$ROOT_DIR/PasteService.swift" \
  "$ROOT_DIR/OverlayWindowController.swift" \
  -o "$MACOS_DIR/$APP_NAME"

codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "Built: $APP_DIR"
