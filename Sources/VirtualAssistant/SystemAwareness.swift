import AppKit
import Foundation

class SystemAwareness {
    static func getDetailedSystemInfo() -> String {
        var info = ""

        let cpuUsage = getCPUUsage()
        let memoryUsage = getMemoryUsage()
        info += "CPU: \(cpuUsage)% | Memory: \(memoryUsage)%\n"

        let diskSpace = getDiskUsage()
        info += "Disk: \(diskSpace)% full\n"

        if isNetworkActive() {
            info += "Network: Active (downloading/uploading)\n"
        }

        if let recentFiles = getRecentFiles() {
            info += "Recent file: \(recentFiles)\n"
        }

        return info
    }

    private static func getCPUUsage() -> Int {
        var loadInfo = host_cpu_load_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &loadInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let user = Double(loadInfo.cpu_ticks.0)
        let system = Double(loadInfo.cpu_ticks.1)
        let idle = Double(loadInfo.cpu_ticks.2)
        let nice = Double(loadInfo.cpu_ticks.3)
        let total = user + system + idle + nice
        guard total > 0 else { return 0 }
        return Int(((user + system + nice) / total) * 100)
    }

    private static func getMemoryUsage() -> Int {
        let totalMemory = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(
            MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size
        )
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        return Int((Double(used) / Double(totalMemory)) * 100)
    }

    static func getDiskUsagePercent() -> Int {
        return getDiskUsage()
    }

    private static func getDiskUsage() -> Int {
        guard let attrs = try? FileManager.default.attributesOfFileSystem(
            forPath: NSHomeDirectory()
        ),
        let totalSpace = attrs[.systemSize] as? Int64,
        let freeSpace = attrs[.systemFreeSize] as? Int64,
        totalSpace > 0 else { return 0 }
        let used = totalSpace - freeSpace
        return Int((Double(used) / Double(totalSpace)) * 100)
    }

    private static func isNetworkActive() -> Bool {
        let networkApps = ["Safari", "Chrome", "Firefox", "Mail", "Discord", "Slack", "Telegram"]
        if let frontApp = NSWorkspace.shared.frontmostApplication {
            let appName = frontApp.localizedName ?? ""
            return networkApps.contains(where: { appName.contains($0) })
        }
        return false
    }

    private static func getRecentFiles() -> String? {
        let fileManager = FileManager.default

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
