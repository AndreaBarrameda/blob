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

    static func readFile(_ path: String) -> String? {
        try? String(contentsOfFile: path, encoding: .utf8)
    }

    static func writeFile(_ content: String, to path: String) -> Bool {
        do {
            try content.write(toFile: path, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    static func deleteFile(_ path: String) -> Bool {
        try? FileManager.default.removeItem(atPath: path)
        return !FileManager.default.fileExists(atPath: path)
    }

    static func getFileInfo(_ path: String) -> [FileAttributeKey: Any]? {
        try? FileManager.default.attributesOfItem(atPath: path)
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

    static func closeApp(_ appName: String) -> Bool {
        let workspace = NSWorkspace.shared
        guard let app = workspace.runningApplications.first(where: { $0.localizedName == appName }) else {
            return false
        }
        return app.terminate()
    }

    static func getRunningApps() -> [String] {
        NSWorkspace.shared.runningApplications.compactMap { $0.localizedName }
    }

    // MARK: - Shell Commands
    static func executeCommand(_ command: String, args: [String] = []) -> (output: String, status: Int32) {
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

    // MARK: - Keyboard & Mouse Control (via AppleScript)
    static func typeText(_ text: String) -> Bool {
        let escaped = text.replacingOccurrences(of: "\"", with: "\\\"")
        let script = "tell application \"System Events\" to keystroke \"\(escaped)\""
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func pressKey(_ key: String) -> Bool {
        let script = "tell application \"System Events\" to key code \(keyNameToCode(key))"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    static func click(at point: NSPoint) -> Bool {
        let script = "tell application \"System Events\" to click at {\(Int(point.x)), \(Int(point.y))}"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
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

    // MARK: - Helper Functions
    private static func keyNameToCode(_ name: String) -> Int {
        let codes: [String: Int] = [
            "return": 36, "enter": 36,
            "tab": 48,
            "space": 49,
            "delete": 51,
            "escape": 53,
            "left": 123, "right": 124, "down": 125, "up": 126,
            "home": 115, "end": 119, "pageup": 116, "pagedown": 121,
            "f1": 122, "f2": 120, "f3": 99, "f4": 118
        ]
        return codes[name.lowercased()] ?? 0
    }
}
