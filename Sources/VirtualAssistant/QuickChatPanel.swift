import Cocoa
import SwiftUI

/// Shared state for the reusable Quick Chat panel.
final class QuickChatViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var isLoading = false
    @Published private(set) var focusToken = UUID()

    func prepareForDisplay() {
        isLoading = false
        inputText = ""
        requestFocus()
    }

    func requestFocus() {
        focusToken = UUID()
    }
}

/// Manages the Quick Chat popup panel lifecycle and global hotkey monitoring.
final class QuickChatManager {
    private let viewModel = QuickChatViewModel()
    private var panel: QuickChatNSPanel?
    private var globalHotkeyMonitor: Any?
    private var localHotkeyMonitor: Any?

    func setup() {
        // Global monitor: fires when Blob is not the frontmost app.
        globalHotkeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyEvent(event)
        }

        // Local monitor: fires when Blob is frontmost, including when the panel is key.
        localHotkeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }

    /// Returns true if the event was consumed.
    @discardableResult
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard event.keyCode == 49,
              event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [.command, .shift]
        else { return false }

        DispatchQueue.main.async { [weak self] in
            self?.togglePanel()
        }
        return true
    }

    func togglePanel() {
        if let panel, panel.isVisible {
            hidePanel()
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        let existingPanel = panel ?? makePanel()
        panel = existingPanel

        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) ?? NSScreen.main
        let targetScreen = screen ?? NSScreen.screens.first
        let panelWidth: CGFloat = 528
        let panelHeight: CGFloat = 56
        let margin: CGFloat = 16

        guard let targetScreen else { return }

        var x = mouseLocation.x - panelWidth / 2
        var y = mouseLocation.y + margin

        x = max(targetScreen.visibleFrame.minX + margin, min(x, targetScreen.visibleFrame.maxX - panelWidth - margin))
        if y + panelHeight > targetScreen.visibleFrame.maxY - margin {
            y = mouseLocation.y - panelHeight - margin
        }

        viewModel.prepareForDisplay()
        existingPanel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        existingPanel.makeKeyAndOrderFront(nil)
        existingPanel.orderFrontRegardless()
    }

    private func hidePanel() {
        viewModel.prepareForDisplay()
        panel?.orderOut(nil)
    }

    private func makePanel() -> QuickChatNSPanel {
        let contentView = QuickChatView(
            viewModel: viewModel,
            onSubmit: { [weak self] text in
                self?.hidePanel()
                NotificationCenter.default.post(
                    name: .quickChatSend,
                    object: nil,
                    userInfo: ["message": text]
                )
            }
        )

        return QuickChatNSPanel(
            rootView: contentView
        ) { [weak self] in
            self?.hidePanel()
        }
    }
}

/// NSPanel subclass for the Quick Chat popup.
final class QuickChatNSPanel: NSPanel {
    private let onEscape: () -> Void

    init(rootView: QuickChatView, onEscape: @escaping () -> Void) {
        self.onEscape = onEscape

        let hostingController = NSHostingController(rootView: rootView)
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 528, height: 56),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        contentViewController = hostingController
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        isReleasedWhenClosed = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        hasShadow = true
        isMovableByWindowBackground = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape()
            return
        }
        super.keyDown(with: event)
    }

    override func cancelOperation(_ sender: Any?) {
        onEscape()
    }

    required init?(coder: NSCoder) {
        fatalError()
    }
}

/// SwiftUI view for the Quick Chat popup.
struct QuickChatView: View {
    @ObservedObject var viewModel: QuickChatViewModel
    @FocusState private var isInputFocused: Bool

    let onSubmit: (String) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color(red: 0.58, green: 0.82, blue: 0.94))
                .frame(width: 10, height: 10)

            TextField("Ask Blob...", text: $viewModel.inputText)
                .textFieldStyle(.plain)
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white.opacity(0.95))
                .focused($isInputFocused)
                .onSubmit(submit)
                .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView()
                    .scaleEffect(0.72)
                    .progressViewStyle(.circular)
                    .tint(.white.opacity(0.8))
            } else if !viewModel.inputText.isEmpty {
                Button(action: submit) {
                    Image(systemName: "paperplane.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.white.opacity(0.65))
                }
                .buttonStyle(.plain)
            }
        }
        .frame(width: 528, height: 56)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(red: 0.13, green: 0.13, blue: 0.15).opacity(0.98))
                .shadow(color: .black.opacity(0.24), radius: 9, x: 0, y: 3)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.05), lineWidth: 0.75)
        )
        .onAppear {
            requestFocusSoon()
        }
        .onChange(of: viewModel.focusToken) { _ in
            requestFocusSoon()
        }
    }

    private func requestFocusSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            isInputFocused = true
        }
    }

    private func submit() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        viewModel.isLoading = true
        viewModel.inputText = ""

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            viewModel.isLoading = false
            onSubmit(text)
        }
    }
}
