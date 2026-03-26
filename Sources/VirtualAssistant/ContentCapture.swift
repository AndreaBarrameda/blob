import AppKit
import Foundation

class ContentCapture {
    static func getClipboardContent() -> String {
        let pasteboard = NSPasteboard.general
        if let clipboardContent = pasteboard.string(forType: .string) {
            return clipboardContent
        }
        return ""
    }

    static func getFocusedTextFieldContent() -> String {
        guard let focusedApp = NSWorkspace.shared.frontmostApplication else {
            return ""
        }

        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: false]
        let isTrusted = AXIsProcessTrustedWithOptions(options)

        guard isTrusted else {
            return ""
        }

        guard let pid = focusedApp.processIdentifier as pid_t? else {
            return ""
        }

        let app = AXUIElementCreateApplication(pid)
        var focusedElement: AnyObject?
        let result = AXUIElementCopyAttributeValue(app, kAXFocusedUIElementAttribute as CFString, &focusedElement)

        guard result == .success, let element = focusedElement else {
            return ""
        }

        // Try to get the value (text content)
        var value: AnyObject?
        AXUIElementCopyAttributeValue(element as! AXUIElement, kAXValueAttribute as CFString, &value)

        if let textValue = value as? String {
            // Limit to last 500 characters to avoid too much text
            return String(textValue.suffix(500))
        }

        return ""
    }

    static func getRecentTypedText() -> String {
        let clipboard = getClipboardContent()
        let focused = getFocusedTextFieldContent()

        var combined = ""
        if !clipboard.isEmpty {
            combined += "Recently copied: \(clipboard.prefix(200))\n"
        }
        if !focused.isEmpty {
            combined += "Currently typing: \(focused.prefix(200))"
        }

        return combined
    }
}
