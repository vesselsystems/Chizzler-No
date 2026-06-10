import Foundation

final class DebugLogger {
    static let shared = DebugLogger()

    static let defaultEnabled = false
    let isEnabled: Bool

    private init() {
        let environmentEnabled = ProcessInfo.processInfo.environment["THOUGHT_RECORDER_DEBUG"] == "1"
        isEnabled = Self.defaultEnabled || environmentEnabled
    }

    func log(_ category: String, _ message: String) {
        guard isEnabled else { return }
        print("[ThoughtRecorder][\(category)] \(message)")
    }
}
