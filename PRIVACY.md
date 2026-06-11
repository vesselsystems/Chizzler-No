# Privacy

ThoughtRecorder is designed as a local voice buffer for macOS and Windows.

## What the App Does

- Records audio only while you hold the record shortcut.
- Sends that audio through Apple's built-in Speech framework on macOS.
- Sends that audio through Windows speech recognition through SAPI on Windows.
- Copies the resulting transcript to your system clipboard.
- Keeps the latest transcript in memory while the app is running.

## What the App Does Not Do

- It does not include analytics.
- It does not include advertising SDKs.
- It does not create user accounts.
- It does not send transcripts to this project, the maintainer, or a custom server.
- It does not save transcript history to disk.

## Permissions

macOS may ask for:

- Microphone: required to capture speech.
- Speech Recognition: required for Apple's speech transcription service.
- Accessibility: used only for the optional menu paste action and Escape-to-cancel support.

If you do not grant Accessibility permission, the main record-copy-then-Command-V workflow still works.

Windows may require:

- Microphone access for desktop apps: required to capture speech.
- Installed Windows speech recognition components: required for local dictation.

The main Windows workflow is record, copy, then normal `Ctrl+V`.

## Clipboard

Successful transcripts are copied to the system clipboard. Other apps can read clipboard contents according to normal operating system clipboard behavior.

## Open Source Verification

The source code is public at:

https://github.com/vesselsystems/Chizzler-No
