import AppKit
import Foundation

final class InputAwarenessManager {
    static let shared = InputAwarenessManager()

    private struct ClickEvent {
        let timestamp: Date
        let appName: String
        let location: CGPoint
        let button: String
    }

    private struct KeyEvent {
        let timestamp: Date
        let appName: String
        let text: String
    }

    private var globalKeyMonitor: Any?
    private var globalMouseMonitor: Any?
    private let queue = DispatchQueue(label: "InputAwarenessManager.queue")
    private var recentClicks: [ClickEvent] = []
    private var recentKeys: [KeyEvent] = []
    private let maxEvents = 40
    private let retentionWindow: TimeInterval = 90

    private init() {}

    func start() {
        guard globalKeyMonitor == nil, globalMouseMonitor == nil else { return }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            self?.recordKeyEvent(event)
        }

        globalMouseMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]) { [weak self] event in
            self?.recordMouseEvent(event)
        }
    }

    func recentInputSummary() -> String {
        queue.sync {
            pruneOldEvents()

            var sections: [String] = []

            let typedSnippet = recentKeys
                .map(\.text)
                .joined()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !typedSnippet.isEmpty {
                sections.append("Recent keys: \(typedSnippet.suffix(120))")
            }

            if let lastClick = recentClicks.last {
                let repeatedClicks = recentClicks.filter { click in
                    click.appName == lastClick.appName &&
                    abs(click.location.x - lastClick.location.x) < 30 &&
                    abs(click.location.y - lastClick.location.y) < 30
                }.count

                let clickSummary = "\(lastClick.button) click in \(lastClick.appName) near (\(Int(lastClick.location.x)), \(Int(lastClick.location.y)))"
                if repeatedClicks >= 3 {
                    sections.append("Recent clicks: \(clickSummary), repeated \(repeatedClicks)x in the same area")
                } else {
                    sections.append("Recent clicks: \(clickSummary)")
                }
            }

            return sections.joined(separator: "\n")
        }
    }

    private func recordKeyEvent(_ event: NSEvent) {
        let characters = sanitizedCharacters(from: event)
        guard !characters.isEmpty else { return }

        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown App"

        queue.async {
            self.recentKeys.append(KeyEvent(timestamp: Date(), appName: appName, text: characters))
            self.pruneOldEvents()
            if self.recentKeys.count > self.maxEvents {
                self.recentKeys.removeFirst(self.recentKeys.count - self.maxEvents)
            }
        }
    }

    private func recordMouseEvent(_ event: NSEvent) {
        let appName = NSWorkspace.shared.frontmostApplication?.localizedName ?? "Unknown App"
        let button: String

        switch event.type {
        case .leftMouseDown:
            button = "Left"
        case .rightMouseDown:
            button = "Right"
        default:
            button = "Other"
        }

        queue.async {
            self.recentClicks.append(
                ClickEvent(
                    timestamp: Date(),
                    appName: appName,
                    location: event.locationInWindow,
                    button: button
                )
            )
            self.pruneOldEvents()
            if self.recentClicks.count > self.maxEvents {
                self.recentClicks.removeFirst(self.recentClicks.count - self.maxEvents)
            }
        }
    }

    private func sanitizedCharacters(from event: NSEvent) -> String {
        guard let characters = event.characters else { return "" }

        let filteredScalars = characters.unicodeScalars.filter { scalar in
            if CharacterSet.alphanumerics.contains(scalar) { return true }
            if CharacterSet.whitespaces.contains(scalar) { return true }
            return "-_./:".unicodeScalars.contains(scalar)
        }

        return String(String.UnicodeScalarView(filteredScalars))
    }

    private func pruneOldEvents() {
        let cutoff = Date().addingTimeInterval(-retentionWindow)
        recentClicks.removeAll { $0.timestamp < cutoff }
        recentKeys.removeAll { $0.timestamp < cutoff }
    }
}
