import Cocoa
import SwiftUI

/// Manages the Quick Chat popup panel lifecycle and global hotkey monitoring.
final class QuickChatManager {
    private var panel: QuickChatNSPanel?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?

    func setup() {
        // Global monitor: fires when Blob is NOT the frontmost app
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }
        // Local monitor: fires when Blob IS the frontmost app
        // (allows toggle-hide when panel is key)
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil  // consume the event
            }
            return event
        }
    }

    /// Returns true if the event was consumed (Cmd+Shift+Space)
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Cmd+Shift+Space: keyCode 49, modifierFlags contains .command and .shift
        guard event.keyCode == 49,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift]
        else { return false }

        DispatchQueue.main.async { [weak self] in
            self?.togglePanel()
        }
        return true
    }

    func togglePanel() {
        if let panel = panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let existingPanel = panel ?? makePanel()
        self.panel = existingPanel

        // Position near mouse cursor, clamped to screen
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main!
        let panelWidth: CGFloat = 550
        let panelHeight: CGFloat = 68
        let margin: CGFloat = 16

        var x = mouseLocation.x - panelWidth / 2
        var y = mouseLocation.y + margin

        // Clamp to screen bounds
        x = max(screen.visibleFrame.minX + margin, min(x, screen.visibleFrame.maxX - panelWidth - margin))
        if y + panelHeight > screen.visibleFrame.maxY - margin {
            y = mouseLocation.y - panelHeight - margin  // flip below cursor
        }

        existingPanel.setFrameOrigin(NSPoint(x: x, y: y))
        existingPanel.makeKeyAndOrderFront(nil)
    }

    private func hidePanel() {
        panel?.orderOut(nil)
        panel?.resetInputText()
    }

    private func makePanel() -> QuickChatNSPanel {
        let contentView = QuickChatView(
            onSubmit: { [weak self] text in
                self?.hidePanel()
                NotificationCenter.default.post(
                    name: .quickChatSend,
                    object: nil,
                    userInfo: ["message": text]
                )
            },
            onDismiss: { [weak self] in
                self?.hidePanel()
            }
        )
        return QuickChatNSPanel(contentView: contentView)
    }
}

/// NSPanel subclass for the Quick Chat popup.
final class QuickChatNSPanel: NSPanel {
    var quickChatTextField: NSTextField? {
        findTextField(in: contentView)
    }

    func resetInputText() {
        quickChatTextField?.stringValue = ""
    }

    init(contentView: QuickChatView) {
        let hostingController = NSHostingController(rootView: contentView)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 550, height: 68),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.contentViewController = hostingController
        self.isOpaque = false
        self.backgroundColor = NSColor.clear
        self.level = .floating
        self.isReleasedWhenClosed = false
        self.hidesOnDeactivate = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.hasShadow = true
        self.isMovableByWindowBackground = true
    }

    // Required for text input to work in a borderless panel
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    required init?(coder: NSCoder) { fatalError() }

    private func findTextField(in view: NSView?) -> NSTextField? {
        guard let view = view else { return nil }
        if let tf = view as? NSTextField { return tf }
        for sub in view.subviews {
            if let found = findTextField(in: sub) { return found }
        }
        return nil
    }
}

/// SwiftUI view for the Quick Chat popup.
struct QuickChatView: View {
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    @State private var isLoading = false

    let onSubmit: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Blob indicator dot
            Circle()
                .fill(Color(red: 0.62, green: 0.9, blue: 1.0))
                .frame(width: 14, height: 14)

            TextField("Ask Blob...", text: $inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.white)
                .focused($isInputFocused)
                .onSubmit {
                    submit()
                }
                .disabled(isLoading)

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
            } else if !inputText.isEmpty {
                Button(action: submit) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 550, height: 68)
        .padding(.horizontal, 20)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(red: 0.12, green: 0.12, blue: 0.14))
                .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            // Small delay ensures the panel is key before focusing
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isInputFocused = true
            }
        }
        .background(KeyEventHandlerView(onEscape: onDismiss))
    }

    private func submit() {
        let text = inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        inputText = ""
        isLoading = true
        // Brief spinner, then dismiss; actual response arrives via .blobSpoke
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            isLoading = false
            onSubmit(text)
        }
    }
}

/// NSViewRepresentable for handling Escape key in the Quick Chat panel.
struct KeyEventHandlerView: NSViewRepresentable {
    let onEscape: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = EscapeListenerNSView()
        view.onEscape = onEscape
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// NSView subclass that listens for Escape key (keyCode 53).
class EscapeListenerNSView: NSView {
    var onEscape: (() -> Void)?

    override var acceptsFirstResponder: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {   // Escape
            onEscape?()
        } else {
            super.keyDown(with: event)
        }
    }
}
