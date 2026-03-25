import Foundation
import AppKit

class ScreenCapture {
    static func captureScreen() -> Data? {
        guard let screen = NSScreen.main else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-x", "-t", "jpg", "-"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            return data.isEmpty ? nil : data
        } catch {
            print("❌ Screen capture error: \(error)")
            return nil
        }
    }

    static func captureScreenAsBase64() -> String? {
        guard let imageData = captureScreen() else { return nil }
        return imageData.base64EncodedString()
    }
}
