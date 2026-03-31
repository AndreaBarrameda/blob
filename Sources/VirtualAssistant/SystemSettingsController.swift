import Foundation

class SystemSettingsController {
    private var lastWallpaper: String = ""
    func openSystemSettings() {
        runAppleScript("open location \"x-apple.systempreferences:\"")
    }

    func openWallpaperSettings() {
        // Opens System Settings > Wallpaper
        let script = """
        tell application "System Events"
            tell process "System Preferences"
                activate
                delay 0.5
            end tell
        end tell
        open location "x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"
        """
        runAppleScript(script)
    }

    func setWallpaper(imagePath: String) {
        // Set desktop wallpaper from file path using System Events
        lastWallpaper = imagePath
        let cleanPath = imagePath.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
        try
            tell application "System Events"
                tell every desktop
                    set picture to POSIX file "\(cleanPath)"
                end tell
            end tell
            return "done"
        on error errMsg
            return "error: " & errMsg
        end try
        """

        DispatchQueue.global().async {
            let result = self.runAppleScriptAndReturn(script)
            print("🖼️ Wallpaper: \(result)")
        }
    }

    func setWallpaperFromURL(_ urlString: String) {
        // Download image from URL and set as wallpaper
        guard let url = URL(string: urlString) else { return }

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tempURL, _, error in
            guard let tempURL = tempURL, error == nil else {
                print("❌ Failed to download wallpaper: \(error?.localizedDescription ?? "unknown error")")
                return
            }

            let fileManager = FileManager.default
            let wallpaperDir = NSHomeDirectory() + "/Pictures/Blob Wallpapers"

            try? fileManager.createDirectory(atPath: wallpaperDir, withIntermediateDirectories: true)

            let destPath = wallpaperDir + "/blob_wallpaper_temp.jpg"
            try? fileManager.removeItem(atPath: destPath)
            try? fileManager.copyItem(at: tempURL, to: URL(fileURLWithPath: destPath))

            self?.setWallpaper(imagePath: destPath)
        }

        task.resume()
    }

    func randomBuiltInWallpaper() {
        // Set a random macOS built-in wallpaper
        // Parse .madesktop XML files to get actual image paths
        let fileManager = FileManager.default
        let wallpaperDir = "/System/Library/Desktop Pictures"

        do {
            let files = try fileManager.contentsOfDirectory(atPath: wallpaperDir)
            var wallpaperPaths: [(name: String, path: String)] = []

            for file in files where file.hasSuffix(".madesktop") {
                let madesktopPath = wallpaperDir + "/" + file
                if let content = try? String(contentsOfFile: madesktopPath, encoding: .utf8),
                   let imagePath = extractImagePathFromMadesktop(content) {
                    wallpaperPaths.append((name: file, path: imagePath))
                }
            }

            print("📁 Available wallpapers: \(wallpaperPaths.count)")
            print("🖼️ Last wallpaper: \(lastWallpaper)")

            // Remove last wallpaper from candidates
            var candidates = wallpaperPaths.filter { $0.path != lastWallpaper }

            print("📁 After filtering: \(candidates.count)")

            if let selected = candidates.randomElement() {
                print("🎲 Selected: \(selected.name) → \(selected.path)")
                setWallpaper(imagePath: selected.path)
            } else {
                print("⚠️ No wallpapers available after filtering")
            }
        } catch {
            print("❌ Failed to list wallpapers: \(error)")
        }
    }

    private func extractImagePathFromMadesktop(_ content: String) -> String? {
        // Parse the .madesktop XML plist to find thumbnailPath or imagePath
        if let range = content.range(of: "<key>thumbnailPath</key>") {
            let afterKey = String(content[range.upperBound...])
            if let stringRange = afterKey.range(of: "<string>"),
               let endRange = afterKey[stringRange.upperBound...].range(of: "</string>") {
                let imagePath = String(afterKey[stringRange.upperBound..<endRange.lowerBound])
                return imagePath.isEmpty ? nil : imagePath
            }
        }
        return nil
    }

    func changeBrightness(_ level: Int) {
        // 0-100 brightness level — placeholder for future implementation
        let _cleanLevel = max(0, min(100, level))
        // TODO: Implement brightness control
    }

    func setDarkMode(_ enabled: Bool) {
        // TODO: Implement dark mode toggle
        let _mode = enabled ? "dark" : "light"
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
                    print("❌ Settings Error: \(errorMsg)")
                }
            }
        } catch {
            print("❌ Settings Error: \(error)")
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
            print("❌ Settings Error: \(error)")
            return ""
        }
    }
}
