import Foundation

class SafariController {
    func open(url: String) {
        var urlString = url
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        let escapedURL = urlString.replacingOccurrences(of: "\"", with: "\\\"")
        runAppleScript("open location \"\(escapedURL)\"")
    }

    func openInNewTab(url: String) {
        var urlString = url
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        let escapedURL = urlString.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Safari"
            activate
            tell window 1
                set current tab to (make new tab with properties {URL:"\(escapedURL)"})
            end tell
        end tell
        """
        runAppleScript(script)
    }

    func openInNewWindow(url: String) {
        var urlString = url
        if !urlString.hasPrefix("http://") && !urlString.hasPrefix("https://") {
            urlString = "https://\(urlString)"
        }

        let escapedURL = urlString.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Safari"
            activate
            make new document with properties {URL:"\(escapedURL)"}
        end tell
        """
        runAppleScript(script)
    }

    func search(_ query: String) {
        // Focus address bar, clear it, type search query
        let cleanQuery = query.trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        tell application "Safari"
            activate
            tell application "System Events"
                keystroke "l" using command down
                delay 0.2
                keystroke "a" using command down
                delay 0.05
                keystroke "\(cleanQuery)"
                delay 0.1
                key code 36
            end tell
        end tell
        """
        print("🔍 Safari search: \(cleanQuery)")
        runAppleScript(script)
    }

    func getCurrentURL(completion: @escaping (String) -> Void) {
        let script = """
        tell application "Safari"
            try
                return URL of current tab of window 1
            on error
                return ""
            end try
        end tell
        """

        DispatchQueue.global().async {
            let result = self.runAppleScriptAndReturn(script)
            DispatchQueue.main.async {
                completion(result.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    func getTitle(completion: @escaping (String) -> Void) {
        let script = """
        tell application "Safari"
            try
                return name of current tab of window 1
            on error
                return ""
            end try
        end tell
        """

        DispatchQueue.global().async {
            let result = self.runAppleScriptAndReturn(script)
            DispatchQueue.main.async {
                completion(result.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    func activate() {
        runAppleScript("tell application \"Safari\" to activate")
    }

    func closeCurrentTab() {
        let script = """
        tell application "Safari"
            try
                close current tab of window 1
            on error
                return false
            end try
        end tell
        """
        runAppleScript(script)
    }

    func goBack() {
        let script = """
        tell application "Safari"
            try
                back of current tab of window 1
            on error
                return false
            end try
        end tell
        """
        runAppleScript(script)
    }

    func goForward() {
        let script = """
        tell application "Safari"
            try
                forward of current tab of window 1
            on error
                return false
            end try
        end tell
        """
        runAppleScript(script)
    }

    func reload() {
        let script = """
        tell application "Safari"
            try
                reload current tab of window 1
            on error
                return false
            end try
        end tell
        """
        runAppleScript(script)
    }

    private func runAppleScript(_ script: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus != 0 {
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let errorMsg = String(data: data, encoding: .utf8), !errorMsg.isEmpty {
                    print("❌ Safari Error: \(errorMsg)")
                } else {
                    print("❌ Safari command failed (status: \(task.terminationStatus))")
                }
            }
        } catch {
            print("❌ Safari Error: \(error)")
        }
    }

    private func runAppleScriptAndReturn(_ script: String) -> String {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", script]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return String(data: data, encoding: .utf8) ?? ""
        } catch {
            print("❌ Safari Error: \(error)")
            return ""
        }
    }
}
