# Install

ThoughtRecorder has download and source-build paths for macOS and Windows.

## Download for macOS

Use this if you want the simplest Mac install.

1. Download the latest `.dmg` from the [GitHub Releases page](https://github.com/vesselsystems/Chizzler-No/releases) or the website download page.
2. Open the DMG.
3. Drag `ThoughtRecorder.app` into `Applications`.
4. Open `ThoughtRecorder` from `Applications`.
5. Grant Microphone and Speech Recognition permissions when macOS asks.
6. Grant Accessibility permission if you want the optional menu paste action or Escape-to-cancel support.

Unsigned community builds may show a macOS warning because the app is open source and may not be notarized. If that happens, right-click `ThoughtRecorder.app`, choose `Open`, and confirm.

## Download for Windows

Use this if you want the simplest Windows install.

1. Download the latest `ThoughtRecorder-<version>-windows-win-x64.msi` from the [GitHub Releases page](https://github.com/vesselsystems/Chizzler-No/releases) or the website download page.
2. Run the MSI. It installs for the current user and creates a Start Menu shortcut.
3. Open `ThoughtRecorder` from the Start Menu.
4. Make sure Windows allows microphone access for desktop apps.
5. Hold `Ctrl + Alt + Shift + Space`, speak, release, then press `Ctrl+V`.

The release also includes `ThoughtRecorder-<version>-windows-win-x64.zip`. Use the zip if you prefer a portable self-contained `ThoughtRecorder.exe`.

Unsigned Windows community builds may show a Microsoft Defender SmartScreen warning. That is expected until the project uses Authenticode signing and builds reputation. You can inspect the source and build locally instead.

## Build from Source on macOS

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

## Build from Source on Windows

Requirements:

- Windows 10 20H1 or later
- .NET 8 SDK

Clone and build:

```powershell
git clone https://github.com/vesselsystems/Chizzler-No.git
cd Chizzler-No
dotnet build windows/ThoughtRecorder.Windows.sln -c Release
```

Package Windows artifacts locally:

```powershell
./scripts/package_windows.ps1 -Version 1.0.0 -Runtime win-x64
```

The generated zip, MSI, and checksum files are written to `dist/`.
