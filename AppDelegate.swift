import AppKit
import ApplicationServices

final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum AppState: Equatable {
        case idle
        case recording(UUID)
        case processing(UUID)
        case readyToPaste
        case pasting
        case error

        var label: String {
            switch self {
            case .idle:
                return "idle"
            case .recording:
                return "recording"
            case .processing:
                return "processing"
            case .readyToPaste:
                return "readyToPaste"
            case .pasting:
                return "pasting"
            case .error:
                return "error"
            }
        }
    }

    private struct TranscriptBuffer {
        let text: String
        let createdAt: Date
        let sourceAppName: String?
        let sourceBundleIdentifier: String?
    }

    private struct RecordingContext {
        let id: UUID
        let sourceAppName: String?
        let sourceBundleIdentifier: String?
    }

    private let logger = DebugLogger.shared
    private let speechController = SpeechController()
    private let pasteService = PasteService()
    private let launchAtLoginManager = LaunchAtLoginManager()
    private var hotKeyManager: HotKeyManager?
    private var statusItem: NSStatusItem?
    private var overlayController: OverlayWindowController?

    private var holdToTalkMenuItem: NSMenuItem?
    private var pasteLatestMenuItem: NSMenuItem?
    private var copyTestClipboardMenuItem: NSMenuItem?
    private var showSystemClipboardMenuItem: NSMenuItem?
    private var showLatestMenuItem: NSMenuItem?
    private var copyLatestMenuItem: NSMenuItem?
    private var clearLatestMenuItem: NSMenuItem?
    private var openAtLoginMenuItem: NSMenuItem?

    private let hasShownWelcomeKey = "hasShownWelcome"
    private let maxRecentTranscriptCount = 10
    private var state: AppState = .idle
    private var activeRecordingContext: RecordingContext?
    private var latestTranscript: TranscriptBuffer?
    private var recentTranscripts: [TranscriptBuffer] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        overlayController = OverlayWindowController()
        statusItem = makeStatusItem()

        requestAccessibilityPermission()

        Task { @MainActor in
            do {
                try await speechController.requestPermissions()
                installHotKeys()
                transition(to: steadyStateAfterCycle(), reason: "permissions granted")
                showWelcomeIfNeeded()
            } catch {
                logger.log("app", "permission setup failed: \(error.localizedDescription)")
                transition(to: .error, reason: "permission setup failed")
                showOverlay(.permissionNeeded, reason: "permission setup failed")
                transition(to: steadyStateAfterCycle(), reason: "recover after permission failure")
            }
        }
    }

    private func makeStatusItem() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "Rec"

        let menu = NSMenu()

        let holdInfo = NSMenuItem(title: "Hold to Talk: \(HotKeyShortcut.recordShortcut.description)", action: nil, keyEquivalent: "")
        holdInfo.isEnabled = false
        menu.addItem(holdInfo)
        holdToTalkMenuItem = holdInfo

        let pasteInfo = NSMenuItem(title: "Paste Latest Transcript: Menu only", action: nil, keyEquivalent: "")
        pasteInfo.isEnabled = false
        menu.addItem(pasteInfo)

        menu.addItem(NSMenuItem.separator())

        let pasteItem = NSMenuItem(title: "Paste Latest Transcript (Debug)", action: #selector(pasteLastTranscriptFromMenu), keyEquivalent: "")
        pasteItem.target = self
        menu.addItem(pasteItem)
        pasteLatestMenuItem = pasteItem

        let copyTestItem = NSMenuItem(title: "Copy Test String to Clipboard", action: #selector(copyTestStringToClipboardFromMenu), keyEquivalent: "")
        copyTestItem.target = self
        menu.addItem(copyTestItem)
        copyTestClipboardMenuItem = copyTestItem

        let showClipboardItem = NSMenuItem(title: "Show System Clipboard", action: #selector(showSystemClipboardFromMenu), keyEquivalent: "")
        showClipboardItem.target = self
        menu.addItem(showClipboardItem)
        showSystemClipboardMenuItem = showClipboardItem

        let showItem = NSMenuItem(title: "Show Latest Transcript", action: #selector(showLatestTranscriptFromMenu), keyEquivalent: "")
        showItem.target = self
        menu.addItem(showItem)
        showLatestMenuItem = showItem

        let copyItem = NSMenuItem(title: "Copy Latest Transcript", action: #selector(copyLastTranscriptFromMenu), keyEquivalent: "")
        copyItem.target = self
        menu.addItem(copyItem)
        copyLatestMenuItem = copyItem

        let clearItem = NSMenuItem(title: "Clear Latest Transcript", action: #selector(clearLastTranscriptFromMenu), keyEquivalent: "")
        clearItem.target = self
        menu.addItem(clearItem)
        clearLatestMenuItem = clearItem

        let loginItem = NSMenuItem(title: "Open at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")
        loginItem.target = self
        menu.addItem(loginItem)
        openAtLoginMenuItem = loginItem

        let helpItem = NSMenuItem(title: "Show Instructions", action: #selector(showInstructions), keyEquivalent: "")
        helpItem.target = self
        menu.addItem(helpItem)

        menu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        item.menu = menu
        refreshMenuState()
        return item
    }

    private func installHotKeys() {
        hotKeyManager = HotKeyManager { [weak self] event in
            DispatchQueue.main.async {
                self?.handleHotKeyEvent(event)
            }
        }

        do {
            try hotKeyManager?.start()
            logger.log("hotkey", "registered record shortcut and cancel support")
        } catch {
            logger.log("hotkey", "failed to register shortcuts: \(error.localizedDescription)")
            showOverlay(.error(error.localizedDescription), reason: "hotkey registration failed")
        }
    }

    private func handleHotKeyEvent(_ event: HotKeyManager.Event) {
        switch event {
        case .keyDown(.record):
            logger.log("hotkey", "record keyDown state=\(state.label)")
            handleRecordKeyDown()
        case .keyUp(.record):
            logger.log("hotkey", "record keyUp state=\(state.label)")
            handleRecordKeyUp()
        case .cancel:
            logger.log("hotkey", "cancel keyDown state=\(state.label)")
            handleCancelRequest()
        }
    }

    private func handleRecordKeyDown() {
        switch state {
        case .idle, .readyToPaste:
            let frontmostApplication = NSWorkspace.shared.frontmostApplication
            let context = RecordingContext(
                id: UUID(),
                sourceAppName: frontmostApplication?.localizedName,
                sourceBundleIdentifier: frontmostApplication?.bundleIdentifier
            )

            do {
                try speechController.startRecording()
                activeRecordingContext = context
                transition(to: .recording(context.id), reason: "record keyDown")
                showOverlay(.listening, reason: "recording started")
            } catch {
                logger.log("record", "recording start failed: \(error.localizedDescription)")
                showOverlay(.error(error.localizedDescription), reason: "recording start failed")
                transition(to: steadyStateAfterCycle(), reason: "record start failed")
            }
        case .recording, .processing, .pasting, .error:
            logger.log("record", "ignored record keyDown because state=\(state.label)")
        }
    }

    private func handleRecordKeyUp() {
        guard case .recording(let sessionID) = state else {
            logger.log("record", "ignored record keyUp because no active recording session")
            return
        }

        transition(to: .processing(sessionID), reason: "record keyUp")
        showOverlay(.processing, reason: "recording stopped")
        logger.log("record", "recording stopped session=\(sessionID)")
        logger.log("record", "transcript finalization started session=\(sessionID)")

        Task { @MainActor in
            let transcript = await speechController.stopRecording().trimmingCharacters(in: .whitespacesAndNewlines)
            finishProcessing(for: sessionID, transcript: transcript)
        }
    }

    private func finishProcessing(for sessionID: UUID, transcript: String) {
        guard case .processing(let activeSessionID) = state, activeSessionID == sessionID else {
            logger.log("record", "ignored processing completion for stale session=\(sessionID)")
            return
        }

        logger.log("record", "transcript finalization completed session=\(sessionID)")
        let sourceAppName = activeRecordingContext?.sourceAppName
        let sourceBundleIdentifier = activeRecordingContext?.sourceBundleIdentifier
        activeRecordingContext = nil

        guard !transcript.isEmpty else {
            logger.log("record", "empty transcript ignored session=\(sessionID)")
            showOverlay(.noNewSpeechDetected, reason: "empty transcript ignored")
            transition(to: steadyStateAfterCycle(), reason: "empty transcript")
            return
        }

        logger.log("record", "transcript finalized session=\(sessionID) chars=\(transcript.count)")
        let buffer = TranscriptBuffer(
            text: transcript,
            createdAt: Date(),
            sourceAppName: sourceAppName,
            sourceBundleIdentifier: sourceBundleIdentifier
        )
        storeLatestTranscript(buffer, sessionID: sessionID)

        if pasteService.writeTextToSystemClipboard(transcript, reason: "release-success") {
            logger.log("record", "transcript copied to system clipboard session=\(sessionID)")
            showOverlay(.copied, reason: "clipboard write succeeded after finalization")
        } else {
            logger.log("record", "transcript copy failed session=\(sessionID)")
            showOverlay(.error("Clipboard update failed"), reason: "clipboard write failed after finalization")
        }

        transition(to: steadyStateAfterCycle(), reason: "processing completed")
    }

    private func handlePasteRequest(trigger: String) {
        logger.log("paste", "paste latest requested trigger=\(trigger)")
        switch state {
        case .recording, .processing, .pasting:
            logger.log("paste", "ignored paste request because state=\(state.label)")
        case .idle, .readyToPaste, .error:
            guard let transcript = latestTranscript else {
                logger.log("paste", "paste requested but no transcript available")
                showOverlay(.nothingToPaste, reason: "paste requested with empty buffer")
                transition(to: steadyStateAfterCycle(), reason: "paste requested with empty buffer")
                return
            }

            transition(to: .pasting, reason: "paste requested via \(trigger)")
            do {
                let result = try pasteService.pasteTranscript(transcript.text)
                switch result {
                case .pasted:
                    logger.log("paste", "paste latest succeeded")
                    showOverlay(.pasted, reason: "paste latest succeeded")
                case .copied:
                    logger.log("paste", "paste latest fell back to clipboard copy")
                    showOverlay(.copied, reason: "paste latest fell back to clipboard copy")
                }
            } catch {
                logger.log("paste", "paste latest failed: \(error.localizedDescription)")
                latestTranscript = transcript
                if pasteService.writeTextToSystemClipboard(transcript.text, reason: "paste latest fallback") {
                    logger.log("paste", "paste latest fallback copied transcript to system clipboard")
                    showOverlay(.copied, reason: "paste latest fallback copied transcript")
                } else {
                    showOverlay(.error(error.localizedDescription), reason: "paste latest fallback failed")
                    transition(to: .error, reason: "clipboard fallback failed")
                    transition(to: steadyStateAfterCycle(), reason: "recover after paste error")
                    return
                }
            }

            transition(to: steadyStateAfterCycle(), reason: "paste completed")
        }
    }

    private func handleCancelRequest() {
        switch state {
        case .recording, .processing:
            logger.log("record", "cancel accepted state=\(state.label)")
            speechController.cancelRecording()
            activeRecordingContext = nil
            showOverlay(.canceled, reason: "recording canceled")
            transition(to: steadyStateAfterCycle(), reason: "recording canceled")
        case .idle, .readyToPaste, .pasting, .error:
            logger.log("record", "cancel ignored because state=\(state.label)")
        }
    }

    private func storeLatestTranscript(_ transcript: TranscriptBuffer, sessionID: UUID) {
        latestTranscript = transcript
        recentTranscripts.insert(transcript, at: 0)
        if recentTranscripts.count > maxRecentTranscriptCount {
            recentTranscripts.removeLast(recentTranscripts.count - maxRecentTranscriptCount)
        }
        logger.log("record", "stored latestTranscript session=\(sessionID) recentCount=\(recentTranscripts.count)")
        logger.log("record", "recent history chars=[\(recentTranscripts.map { String($0.text.count) }.joined(separator: ","))]")
        logger.log("record", "latestTranscript preview=\(preview(transcript.text))")
    }

    private func showOverlay(_ status: OverlayWindowController.Status, reason: String) {
        logger.log("overlay", "show status=\(status.message) reason=\(reason)")
        overlayController?.show(status: status)
    }

    private func preview(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "<empty>" }
        let singleLine = text.replacingOccurrences(of: "\n", with: "\\n")
        if singleLine.count <= 80 {
            return "\"\(singleLine)\""
        }
        return "\"\(singleLine.prefix(80))...\""
    }

    private func transition(to newState: AppState, reason: String) {
        logger.log("state", "\(state.label) -> \(newState.label) reason=\(reason)")
        state = newState
        refreshMenuState()
        updateStatusItem()
    }

    private func steadyStateAfterCycle() -> AppState {
        latestTranscript == nil ? .idle : .readyToPaste
    }

    private func updateStatusItem() {
        let tooltip = """
        State: \(state.label)
        Record: \(HotKeyShortcut.recordShortcut.description)
        Paste: menu only
        Latest: \(latestTranscript == nil ? "empty" : "available")
        """
        statusItem?.button?.title = state.label == "recording" ? "Live" : "Rec"
        statusItem?.button?.toolTip = tooltip
    }

    private func refreshMenuState() {
        pasteLatestMenuItem?.isEnabled = latestTranscript != nil && !isBusyState
        showLatestMenuItem?.isEnabled = latestTranscript != nil
        copyLatestMenuItem?.isEnabled = latestTranscript != nil
        clearLatestMenuItem?.isEnabled = latestTranscript != nil
        openAtLoginMenuItem?.state = launchAtLoginManager.isEnabled ? .on : .off
    }

    @objc
    private func pasteLastTranscriptFromMenu() {
        logger.log("menu", "Paste Latest Transcript clicked")
        handlePasteRequest(trigger: "menu")
    }

    @objc
    private func copyTestStringToClipboardFromMenu() {
        let testString = "TR_TEST_\(Int(Date().timeIntervalSince1970))"
        logger.log("menu", "Copy Test String to Clipboard clicked value=\(preview(testString))")
        if pasteService.writeTextToSystemClipboard(testString, reason: "copy test string") {
            showOverlay(.copied, reason: "copy test string succeeded")
        } else {
            showOverlay(.error("Clipboard update failed"), reason: "copy test string failed")
        }
    }

    @objc
    private func showSystemClipboardFromMenu() {
        let alert = NSAlert()
        let clipboardText = NSPasteboard.general.string(forType: .string)
        logger.log("menu", "Show System Clipboard clicked value=\(preview(clipboardText))")
        alert.messageText = "System Clipboard"
        alert.informativeText = clipboardText ?? "No string currently on the clipboard."
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func showLatestTranscriptFromMenu() {
        let alert = NSAlert()
        alert.messageText = "Latest Transcript"
        if let transcript = latestTranscript {
            logger.log("menu", "Show Latest Transcript clicked preview=\(preview(transcript.text))")
            alert.informativeText = transcript.text
        } else {
            logger.log("menu", "Show Latest Transcript clicked with empty buffer")
            alert.informativeText = "No latest transcript stored."
        }
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc
    private func copyLastTranscriptFromMenu() {
        guard let transcript = latestTranscript else {
            logger.log("menu", "Copy Latest Transcript clicked with empty buffer")
            showOverlay(.nothingToPaste, reason: "copy latest requested with empty buffer")
            return
        }

        if pasteService.writeTextToSystemClipboard(transcript.text, reason: "copy latest from menu") {
            logger.log("menu", "copied latest transcript from menu")
            showOverlay(.copied, reason: "copy latest from menu succeeded")
        } else {
            showOverlay(.error("Clipboard update failed"), reason: "copy latest from menu failed")
        }
    }

    @objc
    private func clearLastTranscriptFromMenu() {
        logger.log("menu", "Clear Latest Transcript clicked")
        latestTranscript = nil
        transition(to: .idle, reason: "buffer cleared")
    }

    @objc
    private func toggleLaunchAtLogin() {
        do {
            if launchAtLoginManager.isEnabled {
                try launchAtLoginManager.disable()
            } else {
                try launchAtLoginManager.enable()
            }
            refreshMenuState()
        } catch {
            showOverlay(.error(error.localizedDescription), reason: "launch at login toggle failed")
        }
    }

    @objc
    private func showInstructions() {
        let alert = NSAlert()
        alert.messageText = "ThoughtRecorder"
        alert.informativeText = """
        ThoughtRecorder is a tiny voice buffer.

        1. Hold \(HotKeyShortcut.recordShortcut.description) to record.
        2. Release to finalize and copy the transcript to the clipboard.
        3. Press normal Command-V anywhere to paste it.

        The menu also includes a debug-only Paste Latest Transcript action.
        The latest transcript stays available until you replace it or clear it.
        """
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    private func showWelcomeIfNeeded() {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: hasShownWelcomeKey) else { return }
        defaults.set(true, forKey: hasShownWelcomeKey)
        showInstructions()
    }

    private func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private var isBusyState: Bool {
        switch state {
        case .recording, .processing, .pasting:
            return true
        case .idle, .readyToPaste, .error:
            return false
        }
    }

    @objc
    private func quit() {
        NSApp.terminate(nil)
    }
}
