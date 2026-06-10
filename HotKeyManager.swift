import Carbon

struct HotKeyShortcut {
    let keyCode: UInt32
    let modifiers: UInt32
    let label: String

    static let recordShortcut = HotKeyShortcut(
        keyCode: UInt32(kVK_Space),
        modifiers: UInt32(cmdKey | optionKey | controlKey),
        label: "Control + Option + Command + Space"
    )

    var description: String { label }
}

enum HotKeyIdentifier: UInt32 {
    case record = 1
}

final class HotKeyManager {
    enum HotKeyError: LocalizedError {
        case registrationFailed
        case eventTapFailed

        var errorDescription: String? {
            switch self {
            case .registrationFailed:
                return "Could not register the global shortcuts."
            case .eventTapFailed:
                return "Could not monitor keyboard events for cancel support."
            }
        }
    }

    enum Event {
        case keyDown(HotKeyIdentifier)
        case keyUp(HotKeyIdentifier)
        case cancel
    }

    private struct Registration {
        let identifier: HotKeyIdentifier
        let shortcut: HotKeyShortcut
    }

    private let registrations: [Registration] = [
        Registration(identifier: .record, shortcut: .recordShortcut)
    ]
    private let handler: (Event) -> Void
    private var hotKeyRefs: [HotKeyIdentifier: EventHotKeyRef] = [:]
    private var eventHandler: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private static var activeManager: HotKeyManager?
    private var pressedIdentifiers = Set<HotKeyIdentifier>()

    init(handler: @escaping (Event) -> Void) {
        self.handler = handler
    }

    func start() throws {
        HotKeyManager.activeManager = self

        var eventSpecs = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ in
                guard let event else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr,
                      let identifier = HotKeyIdentifier(rawValue: hotKeyID.id) else { return noErr }

                switch GetEventKind(event) {
                case UInt32(kEventHotKeyPressed):
                    HotKeyManager.activeManager?.handlePress(identifier)
                case UInt32(kEventHotKeyReleased):
                    HotKeyManager.activeManager?.handleRelease(identifier)
                default:
                    break
                }

                return noErr
            },
            eventSpecs.count,
            &eventSpecs,
            nil,
            &eventHandler
        )

        guard installStatus == noErr else {
            throw HotKeyError.registrationFailed
        }

        for registration in registrations {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x54525243), id: registration.identifier.rawValue)
            let registerStatus = RegisterEventHotKey(
                registration.shortcut.keyCode,
                registration.shortcut.modifiers,
                hotKeyID,
                GetApplicationEventTarget(),
                0,
                &hotKeyRef
            )

            guard registerStatus == noErr, let hotKeyRef else {
                throw HotKeyError.registrationFailed
            }

            hotKeyRefs[registration.identifier] = hotKeyRef
        }

        try installEscapeEventTap()
    }

    private func handlePress(_ identifier: HotKeyIdentifier) {
        guard !pressedIdentifiers.contains(identifier) else { return }
        pressedIdentifiers.insert(identifier)
        handler(.keyDown(identifier))
    }

    private func handleRelease(_ identifier: HotKeyIdentifier) {
        guard pressedIdentifiers.contains(identifier) else { return }
        pressedIdentifiers.remove(identifier)
        handler(.keyUp(identifier))
    }

    private func installEscapeEventTap() throws {
        let callback: CGEventTapCallBack = { _, type, event, _ in
            guard type == .keyDown else {
                return Unmanaged.passUnretained(event)
            }

            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let isAutorepeat = event.getIntegerValueField(.keyboardEventAutorepeat) == 1
            if keyCode == Int64(kVK_Escape), !isAutorepeat {
                HotKeyManager.activeManager?.handler(.cancel)
            }

            return Unmanaged.passUnretained(event)
        }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(1 << CGEventType.keyDown.rawValue),
            callback: callback,
            userInfo: nil
        ) else {
            throw HotKeyError.eventTapFailed
        }

        self.eventTap = eventTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    deinit {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }
}
