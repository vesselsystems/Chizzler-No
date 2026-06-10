import AppKit

final class OverlayWindowController: NSWindowController {
    enum Status {
        case listening
        case processing
        case pasted
        case copied
        case nothingToPaste
        case noNewSpeechDetected
        case canceled
        case permissionNeeded
        case error(String)

        var message: String {
            switch self {
            case .listening:
                return "Listening..."
            case .processing:
                return "Processing..."
            case .pasted:
                return "Pasted"
            case .copied:
                return "Copied"
            case .nothingToPaste:
                return "Nothing to paste"
            case .noNewSpeechDetected:
                return "No new speech detected - latest unchanged"
            case .canceled:
                return "Canceled"
            case .permissionNeeded:
                return "Permission needed"
            case .error(let text):
                return text
            }
        }

        var duration: TimeInterval {
            switch self {
            case .listening, .processing:
                return 60
            case .pasted, .copied, .nothingToPaste, .noNewSpeechDetected, .canceled:
                return 1.1
            case .permissionNeeded, .error:
                return 1.6
            }
        }
    }

    private let label = NSTextField(labelWithString: "")
    private var hideTask: DispatchWorkItem?

    init() {
        let contentRect = NSRect(x: 0, y: 0, width: 240, height: 56)
        let window = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        window.isReleasedWhenClosed = false
        window.level = .statusBar
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.84)
        window.hasShadow = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.ignoresMouseEvents = true

        super.init(window: window)

        label.font = .systemFont(ofSize: 16, weight: .semibold)
        label.textColor = .white
        label.alignment = .center
        label.lineBreakMode = .byTruncatingTail
        label.frame = NSRect(x: 16, y: 16, width: 208, height: 24)

        let contentView = NSView(frame: contentRect)
        contentView.wantsLayer = true
        contentView.layer?.cornerRadius = 14
        contentView.addSubview(label)
        window.contentView = contentView
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(status: Status) {
        hideTask?.cancel()
        label.stringValue = status.message

        if let screenFrame = NSScreen.main?.visibleFrame, let window {
            let x = screenFrame.midX - (window.frame.width / 2)
            let y = screenFrame.maxY - 104
            window.setFrameOrigin(NSPoint(x: x, y: y))
            window.orderFrontRegardless()
        }

        let task = DispatchWorkItem { [weak self] in
            self?.window?.orderOut(nil)
        }
        hideTask = task
        DispatchQueue.main.asyncAfter(deadline: .now() + status.duration, execute: task)
    }
}
