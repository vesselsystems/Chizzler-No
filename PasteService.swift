import AppKit
import ApplicationServices
import Foundation

final class PasteService {
    enum PasteError: LocalizedError {
        case accessibilityRequired
        case clipboardWriteFailed
        case pasteEventFailed

        var errorDescription: String? {
            switch self {
            case .accessibilityRequired:
                return "Accessibility permission is required for paste insertion."
            case .clipboardWriteFailed:
                return "Could not update the clipboard."
            case .pasteEventFailed:
                return "Could not send the paste shortcut."
            }
        }
    }

    enum Result {
        case pasted
        case copied
    }

    enum InsertionStrategy {
        case pasteFirst
        case directAXThenPaste
    }

    struct FocusSnapshot {
        let frontmostApplication: NSRunningApplication?
        let focusedElement: AXUIElement?
        let elementValue: String?
    }

    private struct PasteboardSnapshot {
        let items: [[NSPasteboard.PasteboardType: Data]]
    }

    private let logger = DebugLogger.shared
    private let strategy: InsertionStrategy = .pasteFirst

    @discardableResult
    func writeTextToSystemClipboard(_ text: String, reason: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let previousText = pasteboard.string(forType: .string)
        logger.log("clipboard", "write requested reason=\(reason)")
        logger.log("clipboard", "before write=\(preview(previousText))")
        logger.log("clipboard", "target text=\(preview(text))")

        pasteboard.clearContents()
        pasteboard.declareTypes([.string], owner: nil)

        guard pasteboard.setString(text, forType: .string) else {
            logger.log("clipboard", "setString failed reason=\(reason)")
            return false
        }

        let immediate = pasteboard.string(forType: .string)
        logger.log("clipboard", "after write immediate=\(preview(immediate))")
        let verified = immediate == text
        logger.log("clipboard", "verification result reason=\(reason) verified=\(verified)")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            let delayed = NSPasteboard.general.string(forType: .string)
            self.logger.log("clipboard", "after write 250ms reason=\(reason) value=\(self.preview(delayed))")
        }

        return verified
    }

    func pasteTranscript(_ text: String) throws -> Result {
        let focus = captureCurrentFocus()
        logger.log("paste", "paste requested using strategy=\(strategyLabel) app=\(focus.frontmostApplication?.bundleIdentifier ?? "unknown")")

        switch strategy {
        case .pasteFirst:
            return try pasteFirst(text, focus: focus)
        case .directAXThenPaste:
            if let element = focus.focusedElement, try directAXInsert(text, into: element) {
                logger.log("paste", "direct AX insertion succeeded")
                return .pasted
            }
            return try pasteFirst(text, focus: focus)
        }
    }

    func copyTranscript(_ text: String) throws {
        guard writeTextToSystemClipboard(text, reason: "copyTranscript") else {
            logger.log("paste", "clipboard write failed chars=\(text.count) reason=copyTranscript")
            throw PasteError.clipboardWriteFailed
        }
        logger.log("paste", "clipboard write succeeded chars=\(text.count) reason=copyTranscript")
    }

    private func pasteFirst(_ text: String, focus: FocusSnapshot) throws -> Result {
        let pasteboard = NSPasteboard.general
        let snapshot = capturePasteboard(from: pasteboard)
        logger.log("paste", "paste path clipboard snapshot current=\(preview(pasteboard.string(forType: .string)))")

        guard writeTextToSystemClipboard(text, reason: "pasteFirst") else {
            throw PasteError.clipboardWriteFailed
        }

        guard AXIsProcessTrusted() else {
            logger.log("paste", "paste fallback used because accessibility is unavailable")
            return .copied
        }

        guard sendPasteShortcut() else {
            logger.log("paste", "paste fallback used because synthetic paste failed")
            throw PasteError.pasteEventFailed
        }

        usleep(180_000)

        if let focusedElement = focus.focusedElement,
           let originalValue = focus.elementValue {
            if let currentValue = copyStringAttribute(kAXValueAttribute, from: focusedElement),
               currentValue != originalValue {
                restorePasteboard(snapshot, to: pasteboard)
                logger.log("paste", "paste verified via AX value change")
                return .pasted
            }

            logger.log("paste", "paste could not be verified via AX value change; leaving transcript on clipboard")
            return .copied
        }

        restorePasteboard(snapshot, to: pasteboard)
        logger.log("paste", "paste sent without AX verification; assuming success")
        return .pasted
    }

    private func directAXInsert(_ text: String, into element: AXUIElement) throws -> Bool {
        guard AXIsProcessTrusted() else {
            throw PasteError.accessibilityRequired
        }

        guard !isSecureField(element) else {
            logger.log("paste", "direct AX insertion skipped for secure field")
            return false
        }

        var settable = DarwinBoolean(false)
        let settableStatus = AXUIElementIsAttributeSettable(element, kAXValueAttribute as CFString, &settable)
        guard settableStatus == .success, settable.boolValue else {
            logger.log("paste", "direct AX insertion skipped because focused element is not writable")
            return false
        }

        guard let currentValue = copyStringAttribute(kAXValueAttribute, from: element) else {
            logger.log("paste", "direct AX insertion skipped because current value is unavailable")
            return false
        }

        let updatedValue = currentValue + text
        let status = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, updatedValue as CFTypeRef)
        if status != .success {
            logger.log("paste", "direct AX insertion failed with status=\(status.rawValue)")
        }
        return status == .success
    }

    private func captureCurrentFocus() -> FocusSnapshot {
        guard AXIsProcessTrusted() else {
            return FocusSnapshot(
                frontmostApplication: NSWorkspace.shared.frontmostApplication,
                focusedElement: nil,
                elementValue: nil
            )
        }

        let system = AXUIElementCreateSystemWide()
        var focusedValue: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focusedValue)
        let focusedElement: AXUIElement?
        if status == .success, let focusedValue {
            focusedElement = unsafeBitCast(focusedValue, to: AXUIElement.self)
        } else {
            focusedElement = nil
        }
        let elementValue = focusedElement.flatMap { copyStringAttribute(kAXValueAttribute, from: $0) }

        return FocusSnapshot(
            frontmostApplication: NSWorkspace.shared.frontmostApplication,
            focusedElement: focusedElement,
            elementValue: elementValue
        )
    }

    private func isSecureField(_ element: AXUIElement) -> Bool {
        if let protected = copyBoolAttribute("AXProtectedContent", from: element), protected {
            return true
        }

        if let subrole = copyStringAttribute(kAXSubroleAttribute, from: element),
           subrole == (kAXSecureTextFieldSubrole as String) {
            return true
        }

        return false
    }

    private func capturePasteboard(from pasteboard: NSPasteboard) -> PasteboardSnapshot {
        let items = pasteboard.pasteboardItems?.map { item in
            [NSPasteboard.PasteboardType: Data](uniqueKeysWithValues: item.types.compactMap { type in
                guard let data = item.data(forType: type) else { return nil }
                return (type, data)
            })
        } ?? []

        return PasteboardSnapshot(items: items)
    }

    private func restorePasteboard(_ snapshot: PasteboardSnapshot, to pasteboard: NSPasteboard) {
        logger.log("paste", "restoring previous clipboard contents previousString=\(preview(string(from: snapshot)))")
        pasteboard.clearContents()

        guard !snapshot.items.isEmpty else { return }

        for itemData in snapshot.items {
            let item = NSPasteboardItem()
            for (type, data) in itemData {
                item.setData(data, forType: type)
            }
            pasteboard.writeObjects([item])
        }

        logger.log("paste", "restored previous clipboard contents")
    }

    private func sendPasteShortcut() -> Bool {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)

        guard let keyDown, let keyUp else { return false }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }

    private func copyStringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let string = value as? String else { return nil }
        return string
    }

    private func copyBoolAttribute(_ attribute: String, from element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard status == .success, let number = value as? NSNumber else { return nil }
        return number.boolValue
    }

    private var strategyLabel: String {
        switch strategy {
        case .pasteFirst:
            return "pasteFirst"
        case .directAXThenPaste:
            return "directAXThenPaste"
        }
    }

    private func string(from snapshot: PasteboardSnapshot) -> String? {
        for itemData in snapshot.items {
            if let data = itemData[.string], let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return nil
    }

    private func preview(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return "<empty>" }
        let singleLine = text.replacingOccurrences(of: "\n", with: "\\n")
        if singleLine.count <= 80 {
            return "\"\(singleLine)\""
        }
        return "\"\(singleLine.prefix(80))...\""
    }
}
