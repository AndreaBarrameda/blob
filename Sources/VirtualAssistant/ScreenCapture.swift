import Foundation
import AppKit
import CoreGraphics

class ScreenCapture {
    static func captureScreen() -> Data? {
        // Try native CGWindowListCreateImage first (doesn't require screencapture TCC)
        if let nativeData = captureScreenNative() {
            print("📸 Screen captured via CGWindowListCreateImage (\(nativeData.count / 1024)KB)")
            return nativeData
        }

        // Fallback to screencapture CLI
        if let cliData = captureScreenCLI() {
            print("📸 Screen captured via screencapture CLI (\(cliData.count / 1024)KB)")
            return cliData
        }

        print("📸 All screen capture methods failed")
        return nil
    }

    static func captureScreenAsBase64() -> String? {
        guard let imageData = captureScreen() else { return nil }
        return imageData.base64EncodedString()
    }

    // MARK: - Native capture via CoreGraphics

    private static func captureScreenNative() -> Data? {
        guard CGMainDisplayID() != kCGNullDirectDisplay,
              let image = CGWindowListCreateImage(
                  CGRect.null, // entire display
                  .optionOnScreenOnly,
                  kCGNullWindowID,
                  [.bestResolution]
              ) else {
            return nil
        }

        let bitmapRep = NSBitmapImageRep(cgImage: image)
        // Compress to JPEG at 40% quality to keep payload small for API
        guard let jpegData = bitmapRep.representation(
            using: .jpeg,
            properties: [.compressionFactor: 0.4]
        ), !jpegData.isEmpty else {
            return nil
        }

        return jpegData
    }

    // MARK: - CLI capture via /usr/sbin/screencapture

    private static func captureScreenCLI() -> Data? {
        guard NSScreen.main != nil else { return nil }

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        let tempFile = NSTemporaryDirectory() + "blob_screen_\(UUID().uuidString).jpg"
        task.arguments = ["-x", "-t", "jpg", tempFile]

        do {
            try task.run()
            task.waitUntilExit()

            guard task.terminationStatus == 0 else {
                print("📸 screencapture exited with status \(task.terminationStatus)")
                return nil
            }

            let fileData = try Data(contentsOf: URL(fileURLWithPath: tempFile))
            try? FileManager.default.removeItem(atPath: tempFile)
            return fileData.isEmpty ? nil : fileData
        } catch {
            print("📸 screencapture error: \(error.localizedDescription)")
            return nil
        }
    }
}
