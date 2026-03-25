import Foundation
import AppKit

class SystemMonitor: ObservableObject {
    @Published var batteryLevel: Int = 75
    @Published var isCharging: Bool = false
    @Published var nowPlaying: String = "Nothing"
    @Published var runningApps: [String] = []
    @Published var cpuUsage: Double = 0
    @Published var memoryUsage: Double = 0

    init() {
        updateBatteryInfo()
        updateRunningApps()
        startMonitoring()
    }

    // MARK: - Battery
    private func updateBatteryInfo() {
        // Get battery info using pmset
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pmset")
        task.arguments = ["-g", "batt"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                parseAndSetBatteryInfo(output)
            }
        } catch {
            // Fallback default values
            DispatchQueue.main.async {
                self.batteryLevel = 75
                self.isCharging = false
            }
        }
    }

    private func parseAndSetBatteryInfo(_ output: String) {
        let lines = output.split(separator: "\n")

        for line in lines {
            if line.contains("%") {
                let components = line.split(separator: "\t")

                for component in components {
                    let componentStr = String(component)
                    if componentStr.contains("%") {
                        let percentStr = componentStr.dropLast().trimmingCharacters(in: .whitespaces)
                        if let percent = Int(percentStr) {
                            DispatchQueue.main.async {
                                self.batteryLevel = percent
                            }
                        }
                    }

                    if componentStr.contains("charging") || componentStr.contains("AC Power") {
                        DispatchQueue.main.async {
                            self.isCharging = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Running Apps
    private func updateRunningApps() {
        let workspace = NSWorkspace.shared
        let runningApps = workspace.runningApplications
            .filter { $0.bundleIdentifier != nil && !$0.isHidden }
            .compactMap { $0.localizedName }
            .sorted()

        DispatchQueue.main.async {
            self.runningApps = runningApps
        }
    }

    // MARK: - Volume Control
    func increaseVolume() {
        adjustVolume(by: 5)
    }

    func decreaseVolume() {
        adjustVolume(by: -5)
    }

    private func adjustVolume(by amount: Int) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        task.arguments = ["-e", "set volume output volume ((output volume of (get volume settings)) + \(amount))"]

        do {
            try task.run()
        } catch {
            print("Failed to adjust volume: \(error)")
        }
    }

    // MARK: - Monitoring
    private func startMonitoring() {
        Timer.scheduledTimer(withTimeInterval: 10, repeats: true) { [weak self] _ in
            self?.updateBatteryInfo()
            self?.updateRunningApps()
        }
    }

    // MARK: - System Info
    func getSystemInfo() -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/uname")
        process.arguments = ["-a"]

        let pipe = Pipe()
        process.standardOutput = pipe

        try? process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? "Unknown"
    }
}
