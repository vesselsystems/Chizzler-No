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

    private let identifier = "local.chriscasey.thoughtrecorder"

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func enable() throws {
        guard let executablePath = Bundle.main.executablePath else {
            throw LaunchAtLoginError.executablePathMissing
        }

        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0">
        <dict>
            <key>Label</key>
            <string>\(identifier)</string>
            <key>ProgramArguments</key>
            <array>
                <string>\(executablePath)</string>
            </array>
            <key>RunAtLoad</key>
            <true/>
            <key>KeepAlive</key>
            <false/>
        </dict>
        </plist>
        """

        try FileManager.default.createDirectory(at: plistURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        do {
            try plist.write(to: plistURL, atomically: true, encoding: .utf8)
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
