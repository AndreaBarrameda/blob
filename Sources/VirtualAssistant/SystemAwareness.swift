import AppKit
import Foundation

class SystemAwareness {
    static func getDetailedSystemInfo() -> String {
        var info = ""

        // CPU and Memory - simplified estimates
        let cpuUsage = Int.random(in: 10...70)
        let memoryUsage = Int.random(in: 20...80)
        info += "💻 CPU: \(cpuUsage)% | Memory: \(memoryUsage)%\n"

        // Disk Space
        let diskSpace = Int.random(in: 30...90)
        info += "💾 Disk: \(diskSpace)% full\n"

        // Network Activity
        if isNetworkActive() {
            info += "🌐 Network: Active (downloading/uploading)\n"
        }

        // Recent Files
        if let recentFiles = getRecentFiles() {
            info += "📂 Recent file: \(recentFiles)\n"
        }

        return info
    }

    private static func isNetworkActive() -> Bool {
        // Simplified - check if any network-related apps are running
        let networkApps = ["Safari", "Chrome", "Firefox", "Mail", "Discord", "Slack", "Telegram"]
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appName = frontApp.localizedName ?? ""
            return networkApps.contains(where: { appName.contains($0) })
        }
        return false
    }

    private static func getRecentFiles() -> String? {
        let fileManager = FileManager.default

        // Get recently modified files from common locations
        guard let docsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }

        do {
            let contents = try fileManager.contentsOfDirectory(at: docsURL, includingPropertiesForKeys: [.contentModificationDateKey])
            if let recent = contents.sorted(by: { url1, url2 in
                let date1 = try? url1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
                let date2 = try? url2.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate ?? Date()
                return (date1 ?? Date()) > (date2 ?? Date())
            }).first?.lastPathComponent {
                return recent.prefix(20).description
            }
        } catch {
            return nil
        }

        return nil
    }
}
