# Release Guide

This project ships as a downloadable macOS DMG and Windows MSI/zip.

## Local macOS Release Build

```bash
chmod +x build.sh scripts/package_dmg.sh scripts/checksum.sh scripts/generate_icon.swift
./scripts/package_dmg.sh
./scripts/checksum.sh
```

The DMG is written to `dist/ThoughtRecorder-1.0.0.dmg`.

## Local Windows Release Build

Run this on Windows:

```powershell
./scripts/package_windows.ps1 -Version 1.0.0 -Runtime win-x64
```

The Windows script writes:

- `dist/ThoughtRecorder-1.0.0-windows-win-x64.zip`
- `dist/ThoughtRecorder-1.0.0-windows-win-x64.zip.sha256`
- `dist/ThoughtRecorder-1.0.0-windows-win-x64.msi`
- `dist/ThoughtRecorder-1.0.0-windows-win-x64.msi.sha256`

The zip contains a self-contained `ThoughtRecorder.exe`. The MSI is a per-user WiX installer.

## Automated GitHub Release

Push a version tag to trigger the GitHub Actions release workflow:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow builds the macOS DMG, Windows zip, Windows MSI, and checksum files. Tagged builds attach all artifacts to the matching GitHub Release.

## Configurable macOS Metadata

macOS release metadata can be supplied with environment variables:

```bash
APP_NAME="ThoughtRecorder" \
BUNDLE_ID="com.vesselsystems.thoughtrecorder" \
MARKETING_VERSION="1.0.0" \
BUILD_NUMBER="1" \
ARCHS="arm64 x86_64" \
./scripts/package_dmg.sh
```

Use a stable `BUNDLE_ID` before shipping publicly. Changing it later makes macOS treat the app as a different product. The default is `com.vesselsystems.thoughtrecorder`.

## macOS Signing and Notarization

Unsigned or ad-hoc signed builds are useful for local testing but are not the cleanest public website download path.

For public macOS distribution, use an Apple Developer ID Application certificate:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
BUNDLE_ID="com.vesselsystems.thoughtrecorder" \
./scripts/package_dmg.sh
```

The build script enables hardened runtime automatically when `SIGN_IDENTITY` is not `-`.

For the best macOS install experience, notarize the DMG with Apple and staple the ticket:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARIZE=1 \
NOTARY_PROFILE="your-notarytool-profile" \
./scripts/package_dmg.sh
```

You can create the notary profile once with:

```bash
xcrun notarytool store-credentials "your-notarytool-profile" \
  --apple-id "you@example.com" \
  --team-id "TEAMID" \
  --password "app-specific-password"
```

Alternatively, set `APPLE_ID`, `APPLE_TEAM_ID`, and `APP_SPECIFIC_PASSWORD` instead of `NOTARY_PROFILE`.

## Windows Signing and SmartScreen

Windows artifacts are intentionally unsigned for now. Unsigned MSI and EXE downloads can show Microsoft Defender SmartScreen warnings, especially before the project has download reputation.

Users who do not want to trust an unsigned community build can inspect the source and build locally.

Later, Authenticode signing can be added after `dotnet publish` and after MSI generation:

```powershell
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a build/windows/publish/win-x64/ThoughtRecorder.exe
signtool sign /fd SHA256 /tr http://timestamp.digicert.com /td SHA256 /a dist/ThoughtRecorder-1.0.0-windows-win-x64.msi
```

The certificate should be injected through GitHub Actions secrets. EV certificates tend to build SmartScreen reputation faster, but they are not required to build the open-source project.

## Website Download

Upload artifacts from `dist/` to GitHub Releases, your website host, or object storage and link to them from the download page:

```html
<a href="/downloads/ThoughtRecorder-1.0.0.dmg" download>
  Download for macOS
</a>

<a href="/downloads/ThoughtRecorder-1.0.0-windows-win-x64.msi" download>
  Download for Windows
</a>
```

For transparency, include a second link to the public source code:

```html
<a href="https://github.com/vesselsystems/Chizzler-No">
  View source on GitHub
</a>
```

Recommended extras for a production download page:

- Show the current version and release date.
- Include minimum supported OS versions.
- Mention required permissions: microphone and speech recognition on macOS; microphone access and installed speech recognition components on Windows.
- Publish SHA-256 checksums next to each download link.
- Mention unsigned Windows SmartScreen warnings until Authenticode signing is enabled.

## Release Checklist

1. Set the final version.
2. Build the macOS DMG.
3. Build the Windows zip and MSI.
4. Verify checksums.
5. Install the DMG on a clean Mac user account.
6. Install the MSI on a clean Windows user account.
7. Confirm microphone, speech recognition, shortcut, clipboard, launch-at-login, and optional paste flows on both platforms.
8. Upload artifacts and checksum files to GitHub Releases or the website.
