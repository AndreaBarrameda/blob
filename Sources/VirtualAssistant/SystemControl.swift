import AppKit
import Foundation

class SystemControl {
    // MARK: - File System Access
    static func listFiles(in directory: String = NSHomeDirectory()) -> [String] {
        let fileManager = FileManager.default
        do {
            return try fileManager.contentsOfDirectory(atPath: directory)
        } catch {
            return []
        }
    }

    // MARK: - Application Control
    static func launchApp(_ appName: String) -> Bool {
        let workspace = NSWorkspace.shared
        if let appURL = workspace.urlForApplication(withBundleIdentifier: appName) ??
                        workspace.fullPath(forApplication: appName).flatMap({ URL(fileURLWithPath: $0) }) {
            do {
                try workspace.launchApplication(at: appURL, options: [], configuration: [:])
                return true
            } catch {
                return false
            }
        }
        return false
    }

    static func switchToApp(_ appName: String) -> Bool {
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.localizedName == appName }) else {
            return launchApp(appName)
        }
        return app.activate()
    }

    static func getRunningApps() -> [String] {
        NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }
    }

    // MARK: - Shell Commands
    static func executeCommand(_ command: String, args: [String] = []) -> (output: String, status: Int32) {
        let blocked = ["rm -rf /", "rm -rf ~", "mkfs", "dd if=", "> /dev/", ":(){ :|:& };:"]
        let lower = command.lowercased()
        for pattern in blocked {
            if lower.contains(pattern) {
                return ("Blocked: potentially destructive command.", -1)
            }
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/bash")
        task.arguments = ["-c", command]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (output, task.terminationStatus)
        } catch {
            return ("", -1)
        }
    }

    // MARK: - System Commands
    static func openURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString) else { return false }
        return NSWorkspace.shared.open(url)
    }

    static func openFile(_ path: String) -> Bool {
        return NSWorkspace.shared.openFile(path)
    }

    static func getSystemInfo() -> String {
        var info = ""
        info += "System: macOS \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        info += "Device: \(ProcessInfo.processInfo.hostName)\n"
        info += "Active user: \(NSUserName())\n"
        info += "Home: \(NSHomeDirectory())\n"
        return info
    }

    static func getClipboard() -> String {
        NSPasteboard.general.string(forType: .string) ?? ""
    }

    static func setClipboard(_ text: String) {
        NSPasteboard.general.setString(text, forType: .string)
    }

}
