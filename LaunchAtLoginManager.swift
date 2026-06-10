import Foundation

final class LaunchAtLoginManager {
    enum LaunchAtLoginError: LocalizedError {
        case executablePathMissing
        case writeFailed
        case shellCommandFailed

        var errorDescription: String? {
            switch self {
            case .executablePathMissing:
                return "Could not determine the app location for launch at login."
            case .writeFailed:
                return "Could not write the launch-at-login configuration."
            case .shellCommandFailed:
                return "macOS refused the launch-at-login change."
            }
        }
    }

    private var identifier: String {
        Bundle.main.bundleIdentifier ?? "com.vesselsystems.thoughtrecorder"
    }

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func enable() throws {
        guard let executablePath = Bundle.main.executablePath else {
            throw LaunchAtLoginError.executablePathMissing
        }

        let plist: [String: Any] = [
            "Label": identifier,
            "ProgramArguments": [executablePath],
            "RunAtLoad": true,
            "KeepAlive": false
        ]

        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: plistURL, options: .atomic)
        } catch {
            throw LaunchAtLoginError.writeFailed
        }

        try runLaunchCtl(arguments: ["bootstrap", "gui/\(getuid())", plistURL.path])
    }

    func disable() throws {
        if isEnabled {
            _ = try? runLaunchCtl(arguments: ["bootout", "gui/\(getuid())", plistURL.path])
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private var plistURL: URL {
        let libraryDirectory = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        return libraryDirectory.appendingPathComponent("\(identifier).plist")
    }

    @discardableResult
    private func runLaunchCtl(arguments: [String]) throws -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/launchctl")
        process.arguments = arguments
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            throw LaunchAtLoginError.shellCommandFailed
        }
        return process.terminationStatus
    }
}
