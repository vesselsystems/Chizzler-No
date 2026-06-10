# Release Guide

This project ships as a downloadable macOS DMG containing `ThoughtRecorder.app`.

## Local Release Build

```bash
chmod +x build.sh scripts/package_dmg.sh scripts/checksum.sh scripts/generate_icon.swift
./scripts/package_dmg.sh
./scripts/checksum.sh
```

The DMG is written to `dist/ThoughtRecorder-1.0.0.dmg`.

## Automated GitHub Release

Push a version tag to trigger the GitHub Actions release workflow:

```bash
git tag v1.0.1
git push origin v1.0.1
```

The workflow builds the DMG, generates the checksum, uploads both as workflow artifacts, and attaches them to the matching GitHub Release.

## Configurable Metadata

All release metadata can be supplied with environment variables:

```bash
APP_NAME="ThoughtRecorder" \
BUNDLE_ID="com.vesselsystems.thoughtrecorder" \
MARKETING_VERSION="1.0.0" \
BUILD_NUMBER="1" \
ARCHS="arm64 x86_64" \
./scripts/package_dmg.sh
```

Use a stable `BUNDLE_ID` before shipping publicly. Changing it later makes macOS treat the app as a different product. The default is `com.vesselsystems.thoughtrecorder`.

## Signing

Unsigned or ad-hoc signed builds are useful for local testing but not appropriate for public website downloads.

For public distribution, use an Apple Developer ID Application certificate:

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
BUNDLE_ID="com.vesselsystems.thoughtrecorder" \
./scripts/package_dmg.sh
```

The build script enables hardened runtime automatically when `SIGN_IDENTITY` is not `-`.

## Notarization

For the best install experience, notarize the DMG with Apple and staple the ticket:

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

## Website Download

Upload the DMG from `dist/` to GitHub Releases, your website host, or object storage and link to it from the new tab/page:

```html
<a href="/downloads/ThoughtRecorder-1.0.0.dmg" download>
  Download for macOS
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
- Include the minimum macOS version: macOS 13 Ventura or later.
- Mention required permissions: Microphone, Speech Recognition, and Accessibility for paste automation.
- Publish a SHA-256 checksum next to the download link.

Generate the checksum with:

```bash
./scripts/checksum.sh
```

## Release Checklist

1. Set the final `APP_NAME`, `BUNDLE_ID`, `MARKETING_VERSION`, and `BUILD_NUMBER`.
2. Build with a Developer ID certificate.
3. Notarize and staple the DMG.
4. Install the DMG on a clean Mac user account.
5. Confirm microphone, speech recognition, and accessibility permission flows.
6. Upload the DMG and checksum to the website.
