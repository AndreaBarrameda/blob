import AppKit
import Foundation
import ApplicationServices

class SystemAwareness {
    static func getComputerIdentity() -> String {
        let username = NSUserName()
        let hostname = ProcessInfo.processInfo.hostName
        let macOSVersion = ProcessInfo.processInfo.operatingSystemVersionString
        return "You live in \(username)'s Mac — \(hostname), \(macOSVersion)"
    }

    static func getDetailedSystemInfo() -> String {
        var info = ""

        // Real memory usage
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        let memoryInGB = Double(totalMemory) / (1024 * 1024 * 1024)
        info += "💻 Memory: ~\(String(format: "%.1f", memoryInGB))GB available\n"

        // Real disk space
        if let diskUsage = getDiskUsagePercent() {
            info += "💾 Disk: \(diskUsage)% full\n"
        }

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

    private static func getDiskUsagePercent() -> Int? {
        do {
            let attributes = try FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory())
            guard let totalSize = attributes[.systemSize] as? NSNumber,
                  let freeSize = attributes[.systemFreeSize] as? NSNumber else {
                return nil
            }
            let used = totalSize.int64Value - freeSize.int64Value
            let percent = Int((Double(used) / Double(totalSize.int64Value)) * 100)
            return percent
        } catch {
            return nil
        }
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

    static func getActiveWindowTitle() -> String? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        let appRef = AXUIElementCreateApplication(app.processIdentifier)
        var windowRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(appRef, kAXFocusedWindowAttribute as CFString, &windowRef) == .success,
           let window = windowRef {
            var titleRef: CFTypeRef?
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &titleRef) == .success {
                return titleRef as? String
            }
        }
        return nil
    }

    static func getIdleSeconds() -> Double {
        return CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
    }
}
