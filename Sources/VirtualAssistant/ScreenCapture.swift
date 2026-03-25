import Foundation
import AppKit

class ScreenCapture {
    static func captureScreen() -> Data? {
        guard let screen = NSScreen.main else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        // Capture entire screen as JPEG
        let tempFile = "/tmp/blob_screen.jpg"
        task.arguments = ["-x", "-t", "jpg", tempFile]

        do {
            try task.run()
            task.waitUntilExit()

            // Read the file
            let fileData = try Data(contentsOf: URL(fileURLWithPath: tempFile))

            // Clean up temp file
            try? FileManager.default.removeItem(atPath: tempFile)

            return fileData.isEmpty ? nil : fileData
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
