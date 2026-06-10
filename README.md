# ThoughtRecorder

ThoughtRecorder is a tiny macOS menu bar app for fast voice capture.

Its Phase 1 workflow is intentionally simple:

1. Hold the record shortcut and talk
2. Release to finalize the transcript
3. The transcript is automatically copied to the clipboard
4. Press normal `Command + V` anywhere

That design is deliberate. ThoughtRecorder is a voice buffer, not a universal auto-insert system. It optimizes for repeatable speed instead: record, auto-copy, then paste wherever you want.

## Default Shortcuts

- Hold to talk: `Control + Option + Command + Space`
- Paste last transcript: `Control + Option + Command + V`

You can change them in [HotKeyManager.swift](/Users/chriscasey/Desktop/recorder/HotKeyManager.swift).

## Product Model

ThoughtRecorder keeps a single `latestTranscript` buffer.

- Record shortcut starts and stops speech capture
- Releasing the record shortcut finalizes the transcript and automatically copies it to the clipboard
- A separate paste shortcut can still try to paste the latest transcript into the current field
- If direct paste cannot be confirmed, the transcript is kept on the clipboard instead
- Empty capture and canceled capture do not overwrite the latest transcript

This keeps the mental model simple:

- one shortcut means record and copy
- normal `Command + V` pastes the captured text
- optional paste shortcut is only a convenience

## Status Overlay

The app shows a tiny non-activating overlay for:

- `Listening...`
- `Processing...`
- `Copied`
- `Pasted`
- `Nothing to paste`
- `No new speech detected - latest unchanged`
- `Canceled`
- `Permission needed`
- short error text

## Menu Bar

The menu bar app exposes:

- shortcut reminders
- `Paste Latest Transcript`
- `Copy Latest Transcript`
- `Clear Latest Transcript`
- `Open at Login`
- `Show Instructions`
- `Quit`

## Build

```bash
chmod +x build.sh
./build.sh
open build/ThoughtRecorder.app
```

## Permissions

macOS will ask for:

- Microphone
- Speech Recognition
- Accessibility

Accessibility is required for the optional synthetic paste shortcut.

## Paste Strategy

The primary Phase 1 flow is auto-copy on release.

The optional paste shortcut uses a simple best-effort paste path:

1. capture the currently focused field if Accessibility metadata is available
2. place `latestTranscript` on the clipboard
3. send a normal `Cmd+V`
4. restore the previous clipboard when paste can be reasonably verified
5. otherwise keep the transcript on the clipboard and show `Copied`

This means the transcript is still available even when direct paste cannot be trusted.

## Debug Mode

Set:

```bash
THOUGHT_RECORDER_DEBUG=1
```

before launching the app to print:

- shortcut events
- state transitions
- transcript lifecycle milestones
- clipboard copy on successful capture
- paste attempts and fallbacks

This is useful for diagnosing “why didn’t the next transcription start?” problems.

## Known macOS Constraints

- Some apps expose poor Accessibility metadata, so paste verification is imperfect.
- Some secure or custom fields may ignore synthetic paste events.
- The app keeps `latestTranscript` in memory even when paste fails so you can retry immediately.
- The app also keeps a small in-memory recent history of successful captures for debugging only.

## Testing

1. Hold the record shortcut, speak, release, and confirm the overlay says `Copied`.
2. Press normal `Command + V` and confirm the captured text pastes.
3. Optionally press the paste shortcut and confirm it inserts the latest transcript or falls back to `Copied`.
4. Immediately start another recording cycle and confirm it works without getting stuck.
5. Release after silence and confirm `No new speech detected - latest unchanged`.
6. Press `Escape` while recording and confirm the app resets cleanly without replacing the latest transcript.

## Files

- [AppDelegate.swift](/Users/chriscasey/Desktop/recorder/AppDelegate.swift): state machine and menu bar orchestration
- [HotKeyManager.swift](/Users/chriscasey/Desktop/recorder/HotKeyManager.swift): separate record and paste shortcuts
- [SpeechController.swift](/Users/chriscasey/Desktop/recorder/SpeechController.swift): speech capture lifecycle
- [PasteService.swift](/Users/chriscasey/Desktop/recorder/PasteService.swift): clipboard copy and optional paste-latest behavior
- [OverlayWindowController.swift](/Users/chriscasey/Desktop/recorder/OverlayWindowController.swift): tiny non-activating status overlay
