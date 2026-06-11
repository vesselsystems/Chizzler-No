# Contributing

Contributions are welcome.

## Development Setup

Requirements:

- macOS 13 Ventura or later and Xcode Command Line Tools for the macOS app
- Windows 10 20H1 or later and the .NET 8 SDK for the Windows app

Build macOS locally:

```bash
./build.sh
open build/ThoughtRecorder.app
```

Package a macOS DMG:

```bash
./scripts/package_dmg.sh
```

Build Windows locally:

```powershell
dotnet build windows/ThoughtRecorder.Windows.sln -c Release
```

Package Windows artifacts:

```powershell
./scripts/package_windows.ps1 -Version 1.0.0 -Runtime win-x64
```

Generate the app icon:

```bash
./scripts/generate_icon.swift build/ThoughtRecorder.app/Contents/Resources/AppIcon.icns
```

## Pull Requests

Please keep changes focused and include manual test notes for recording, clipboard copy, tray/menu actions, launch-at-login, and permission behavior when relevant.

## Debug Logging

Set `THOUGHT_RECORDER_DEBUG=1` before launching the app to enable debug logs and debug-only menu actions.
