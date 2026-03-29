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

    // MARK: - Apple Notes

    /// action: "create" | "append" | "replace"
    static func addAppleNote(title: String, body: String, action: String = "create") -> (success: Bool, message: String) {
        let safeTitle = title.replacingOccurrences(of: "\"", with: "'")
        let safeBody  = body.replacingOccurrences(of: "\"", with: "'").replacingOccurrences(of: "\n", with: "\\n")

        let script: String
        switch action {
        case "append":
            script = """
            tell application "Notes"
                set matchingNotes to notes whose name is "\(safeTitle)"
                if (count of matchingNotes) > 0 then
                    set theNote to item 1 of matchingNotes
                    set body of theNote to (body of theNote) & "\n\(safeBody)"
                else
                    make new note with properties {name:"\(safeTitle)", body:"\(safeBody)"}
                end if
            end tell
            """
        case "replace":
            script = """
            tell application "Notes"
                set matchingNotes to notes whose name is "\(safeTitle)"
                if (count of matchingNotes) > 0 then
                    set body of (item 1 of matchingNotes) to "\(safeBody)"
                else
                    make new note with properties {name:"\(safeTitle)", body:"\(safeBody)"}
                end if
            end tell
            """
        default: // create
            script = """
            tell application "Notes"
                make new note with properties {name:"\(safeTitle)", body:"\(safeBody)"}
            end tell
            """
        }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let errPipe = Pipe()
        task.standardError = errPipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                let verb = action == "append" ? "updated" : action == "replace" ? "replaced" : "added"
                return (true, "note '\(title)' \(verb) in Apple Notes")
            } else {
                let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                return (false, err.isEmpty ? "AppleScript failed" : err)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    // MARK: - Calendar

    /// Creates a macOS Calendar event via AppleScript.
    /// startISO / endISO format: "2026-03-29T15:00:00"
    static func createCalendarEvent(title: String, startISO: String, endISO: String, notes: String = "", calendarName: String = "") -> (success: Bool, message: String) {
        guard let startDate = parseISO(startISO), let endDate = parseISO(endISO) else {
            return (false, "couldn't parse dates: \(startISO) / \(endISO)")
        }

        let fmt = DateFormatter()
        fmt.dateFormat = "MMMM d, yyyy 'at' h:mm a"
        let startStr = fmt.string(from: startDate)
        let endStr   = fmt.string(from: endDate)

        // Use first writable calendar if none specified
        let calClause = calendarName.isEmpty
            ? "first calendar whose writable is true"
            : "first calendar whose name is \"\(calendarName)\""

        let safeTitle = title.replacingOccurrences(of: "\"", with: "'")
        let safeNotes = notes.replacingOccurrences(of: "\"", with: "'")

        let script = """
        tell application "Calendar"
            tell (\(calClause))
                make new event with properties {summary:"\(safeTitle)", start date:date "\(startStr)", end date:date "\(endStr)", description:"\(safeNotes)"}
            end tell
            reload calendars
        end tell
        """

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]
        let pipe = Pipe()
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            if task.terminationStatus == 0 {
                return (true, "added '\(title)' on \(startStr)")
            } else {
                let err = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                return (false, err.isEmpty ? "AppleScript failed" : err)
            }
        } catch {
            return (false, error.localizedDescription)
        }
    }

    private static func parseISO(_ iso: String) -> Date? {
        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        if let d = fmt.date(from: iso) { return d }
        // fallback without seconds
        fmt.formatOptions = [.withFullDate, .withTime]
        return fmt.date(from: iso)
    }

}
