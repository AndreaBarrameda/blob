import AppKit
import Foundation

class TaskContextManager {
    private static var hasLoggedAccessibilityWarning = false
    var currentApp: String = ""
    var currentTask: String = ""
    var windowTitle: String = ""
    var fileType: String = ""
    var projectContext: String = ""
    var terminalContext: String = ""

    func updateContext() {
        // Get active application
        if let activeApp = NSWorkspace.shared.frontmostApplication {
            currentApp = activeApp.localizedName ?? "Unknown"
        }

        // Get window title from active app
        updateWindowTitle()

        // Parse context based on app type
        parseAppSpecificContext()
    }

    private func updateWindowTitle() {
        guard let activeApp = NSWorkspace.shared.frontmostApplication else {
            windowTitle = ""
            return
        }

        // Use AXUIElement to get window title (accessibility API)
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        if isTrusted {
            if let pid = activeApp.processIdentifier as pid_t? {
                let app = AXUIElementCreateApplication(pid)
                var windowValue: AnyObject?
                let result = AXUIElementCopyAttributeValue(app, kAXFocusedWindowAttribute as CFString, &windowValue)

                if result == .success, let window = windowValue {
                    var titleValue: AnyObject?
                    AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleValue)
                    if let title = titleValue as? String {
                        windowTitle = title
                    }
                }
            }
        } else {
            if !Self.hasLoggedAccessibilityWarning {
                print("📋 Accessibility permission needed for full task awareness. Check System Settings → Privacy & Security → Accessibility")
                Self.hasLoggedAccessibilityWarning = true
            }
            windowTitle = "(Accessibility disabled - enable for full task details)"
        }
    }

    private func parseAppSpecificContext() {
        let lower = currentApp.lowercased()

        if lower.contains("xcode") || lower.contains("code") || lower.contains("sublime") {
            fileType = "code editor"
            extractFileName()
        } else if lower.contains("figma") {
            fileType = "design tool"
            extractFileName()
        } else if lower.contains("chrome") || lower.contains("safari") || lower.contains("firefox") {
            fileType = "browser"
            extractBrowserContext()
        } else if lower.contains("notion") || lower.contains("obsidian") {
            fileType = "notes"
            extractFileName()
        } else if lower.contains("slack") || lower.contains("discord") {
            fileType = "chat"
        } else if lower.contains("terminal") || lower.contains("iterm") {
            fileType = "terminal"
            extractFileName()
            terminalContext = getTerminalSessionContext()
        } else if lower.contains("spotify") || lower.contains("apple music") {
            fileType = "music"
        } else if lower.contains("finder") {
            fileType = "file browser"
        } else {
            fileType = "unknown"
            terminalContext = ""
        }
    }

    private func extractFileName() {
        // Extract filename from window title
        // Format: "filename - App" or just filename
        let parts = windowTitle.split(separator: "-").map(String.init)
        if !parts.isEmpty {
            let filename = parts[0].trimmingCharacters(in: .whitespaces)
            currentTask = filename
            projectContext = "Working on: \(filename)"
        } else {
            currentTask = windowTitle
            projectContext = "Working on: \(windowTitle)"
        }
    }

    private func extractBrowserContext() {
        // For browser: try to extract meaningful context from title
        // Usually it's "Page Title - Site Name"
        let parts = windowTitle.split(separator: "-").map(String.init)
        if parts.count >= 2 {
            let site = parts.last?.trimmingCharacters(in: .whitespaces) ?? ""
            currentTask = site
            projectContext = "Browsing: \(site)"
        } else {
            currentTask = windowTitle
            projectContext = "Browsing: \(windowTitle)"
        }
    }

    func getTaskContext() -> String {
        updateContext()

        var context = "Active Task Information:\n"
        context += "📱 App: \(currentApp)\n"
        context += "📄 Type: \(fileType)\n"

        if !currentTask.isEmpty {
            context += "📝 Task: \(currentTask)\n"
        }

        if !projectContext.isEmpty {
            context += "🎯 Context: \(projectContext)\n"
        }

        if !windowTitle.isEmpty && windowTitle != currentTask {
            context += "🪟 Window: \(windowTitle)\n"
        }

        if !terminalContext.isEmpty {
            context += "💻 Terminal Context:\n\(terminalContext)\n"
        }

        return context
    }

    func getDetailedTaskSummary() -> String {
        updateContext()
        return projectContext.isEmpty ? currentApp : projectContext
    }

    private func getTerminalSessionContext() -> String {
        let lower = currentApp.lowercased()
        let terminalOutput: String

        if lower.contains("iterm") {
            terminalOutput = runAppleScriptAndReturn("""
            tell application "iTerm2"
                if not (exists current window) then return ""
                try
                    return contents of current session of current tab of current window
                on error
                    return ""
                end try
            end tell
            """)
        } else if lower.contains("terminal") {
            terminalOutput = runAppleScriptAndReturn("""
            tell application "Terminal"
                if not (exists front window) then return ""
                try
                    return contents of selected tab of front window
                on error
                    return ""
                end try
            end tell
            """)
        } else {
            return ""
        }

        let trimmed = terminalOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let lines = trimmed.split(separator: "\n").suffix(12).map { String($0).trimmingCharacters(in: .whitespaces) }
        let cleaned = lines
            .filter { !$0.isEmpty }
            .joined(separator: "\n")

        if cleaned.isEmpty {
            return ""
        }

        return String(cleaned.suffix(700))
    }

    private func runAppleScriptAndReturn(_ script: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else { return "" }
            let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        } catch {
            return ""
        }
    }
}
