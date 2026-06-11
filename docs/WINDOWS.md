# Windows Strategy

This document records the Windows porting decision and the first production-oriented foundation.

## Recommendation

Use a native Windows tray app built with .NET 8 and WPF.

That is the best fit for ThoughtRecorder because the product is a small background utility, not a document-style app or a web UI. The Windows version needs reliable access to keyboard hooks, the clipboard, startup registration, topmost overlay UI, and installer automation. WPF plus a small amount of Win32 interop keeps those pieces direct and easy to audit.

## Alternatives Considered

- Native C++/Win32: capable, but slower to build and maintain for this app size.
- WinUI 3: modern UI stack, but adds Windows App SDK runtime and packaging complexity for a tray-first utility.
- Electron: broad ecosystem, but too heavy for a tiny background app and less transparent for low-level OS integration.
- Tauri: lighter than Electron, but still adds a webview/app shell layer around features that are mostly native OS calls.
- Qt: mature cross-platform toolkit, but adds a large C++ dependency surface without solving speech recognition or Windows installer policy.

## Windows API Mapping

| macOS feature | macOS implementation | Windows foundation |
| --- | --- | --- |
| Speech capture/transcription | `AVAudioEngine` + `Speech` | `System.Speech.Recognition` over Windows SAPI dictation |
| Global hold-to-talk shortcut | Carbon hotkey + `CGEvent` tap | `SetWindowsHookEx(WH_KEYBOARD_LL)` keyboard hook |
| Clipboard copy | `NSPasteboard` | WPF `System.Windows.Clipboard` |
| Optional paste automation | `CGEvent` sends `Cmd+V` | `SendInput` sends `Ctrl+V` |
| Launch at login | user LaunchAgent plist | HKCU `Software\Microsoft\Windows\CurrentVersion\Run` |
| Menu bar/tray UI | `NSStatusItem` | WinForms `NotifyIcon` tray menu |
| Status overlay | borderless `NSPanel` | borderless topmost WPF `Window` |
| Installer | app bundle in DMG | self-contained `.exe` in `.zip`, plus per-user WiX `.msi` |

## Product Model

The Windows version preserves the same core workflow:

1. Hold `Ctrl + Alt + Shift + Space`.
2. Speak.
3. Release the shortcut.
4. The transcript is copied to the clipboard.
5. Press normal `Ctrl+V` in the target app.

The tray menu includes `Paste Latest Transcript`, but the primary workflow is still copy-on-release followed by a normal user paste.

The default Windows shortcut intentionally avoids the Windows key because `Win+Space` is reserved for keyboard/input language switching on Windows.

## Speech Notes

The initial Windows implementation uses Windows SAPI through Microsoft `System.Speech`. This keeps the default build local, open source, and keyless. Recognition availability and quality depend on installed Windows speech components and language packs.

If a future release needs higher accuracy, add a provider boundary before introducing another backend. Good options would be a local Whisper runtime or an explicitly configured cloud API, but neither should be hidden behind the default open-source build.

## Installer and Release Flow

The Windows release script is:

```powershell
./scripts/package_windows.ps1 -Version 1.0.0 -Runtime win-x64
```

It writes:

- `dist/ThoughtRecorder-1.0.0-windows-win-x64.zip`
- `dist/ThoughtRecorder-1.0.0-windows-win-x64.zip.sha256`
- `dist/ThoughtRecorder-1.0.0-windows-win-x64.msi`
- `dist/ThoughtRecorder-1.0.0-windows-win-x64.msi.sha256`

The `.zip` contains a self-contained `ThoughtRecorder.exe`. The `.msi` is a per-user WiX installer that installs under the user's local app data programs folder and creates a Start Menu shortcut.

## Signing and SmartScreen

Windows artifacts are intentionally unsigned for now. Unsigned community builds can trigger Microsoft Defender SmartScreen warnings, especially before the project has download reputation.

Users can avoid that trust gap by inspecting the source and building locally. Later, signing can be added by:

1. Obtaining an Authenticode code-signing certificate.
2. Running `signtool sign` on `ThoughtRecorder.exe` after publish.
3. Running `signtool sign` on the generated `.msi`.
4. Adding certificate material to GitHub Actions secrets.

EV certificates usually build SmartScreen reputation faster, but the project should not require a paid certificate to remain buildable or auditable.

## Known Windows Constraints

- Low-level keyboard hooks may not observe elevated applications from a non-elevated ThoughtRecorder process.
- Some remote desktop, VM, keyboard manager, or game/anti-cheat environments may intercept the shortcut first.
- Synthetic paste is best-effort. If paste automation fails, the transcript remains on the clipboard.
- Windows speech recognition quality depends on installed recognizers and microphone/privacy settings.
