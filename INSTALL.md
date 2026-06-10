# Install

ThoughtRecorder has two install paths.

## Option 1: Download the DMG

Use this if you want the simplest install.

1. Download the latest DMG from the GitHub Releases page or the website download page.
2. Open the DMG.
3. Drag `ThoughtRecorder.app` into `Applications`.
4. Open `ThoughtRecorder` from `Applications`.
5. Grant Microphone and Speech Recognition permissions when macOS asks.
6. Grant Accessibility permission if you want the optional menu paste action or Escape-to-cancel support.

Unsigned community builds may show a macOS warning because the app is open source and may not be notarized. If that happens, right-click `ThoughtRecorder.app`, choose `Open`, and confirm. You can also build from source using the steps below.

## Option 2: Build from Source

Use this if you prefer to inspect the code and build the app yourself.

Requirements:

- macOS 13 Ventura or later
- Xcode Command Line Tools

Install the command line tools if needed:

```bash
xcode-select --install
```

Clone and build:

```bash
git clone https://github.com/vesselsystems/Chizzler-No.git
cd Chizzler-No
./build.sh
open build/ThoughtRecorder.app
```

Package a DMG locally:

```bash
./scripts/package_dmg.sh
./scripts/checksum.sh
```

The generated DMG is written to `dist/ThoughtRecorder-1.0.0.dmg`.
