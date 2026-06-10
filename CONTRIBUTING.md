# Contributing

Contributions are welcome.

## Development Setup

Requirements:

- macOS 13 Ventura or later
- Xcode Command Line Tools

Build locally:

```bash
./build.sh
open build/ThoughtRecorder.app
```

Package a DMG:

```bash
./scripts/package_dmg.sh
```

Generate the app icon:

```bash
./scripts/generate_icon.swift build/ThoughtRecorder.app/Contents/Resources/AppIcon.icns
```

## Pull Requests

Please keep changes focused and include manual test notes for recording, clipboard copy, menu actions, and permission behavior when relevant.

## Debug Logging

Set `THOUGHT_RECORDER_DEBUG=1` before launching the app to enable debug logs and debug-only menu actions.
