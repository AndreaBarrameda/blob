import SwiftUI

struct SystemControlPanel: View {
    @State private var commandInput = ""
    @State private var commandOutput = ""
    @State private var runningApps: [String] = []
    @State private var selectedPath = NSHomeDirectory()
    @State private var fileList: [String] = []
    @State private var showingOutput = false
    @State private var autonomousObservationsEnabled = true
    @State private var smartModeEnabled = false

    var body: some View {
        VStack(spacing: 12) {
            // Header
            Text("🎮 System Control")
                .font(.headline)
                .foregroundColor(.blue)

            // Command Executor
            VStack(alignment: .leading, spacing: 6) {
                Text("⌨️ Execute Command")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                HStack(spacing: 6) {
                    TextField("npm install, git status...", text: $commandInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Button(action: executeCommand) {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.body)
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                    .disabled(commandInput.isEmpty)
                }

                if showingOutput && !commandOutput.isEmpty {
                    ScrollView {
                        Text(commandOutput)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(6)
                    }
                    .frame(height: 80)
                    .background(Color.black.opacity(0.05))
                    .cornerRadius(4)
                }
            }
            .padding(8)
            .background(Color.blue.opacity(0.05))
            .cornerRadius(6)

            // App Control
            VStack(alignment: .leading, spacing: 6) {
                Text("📱 Running Apps (\(runningApps.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(runningApps.prefix(6), id: \.self) { app in
                            VStack(spacing: 4) {
                                Text(app.prefix(12).description)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(.black)

                                Button(action: { SystemControl.switchToApp(app) }) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption)
                                        .foregroundColor(.white)
                                        .frame(width: 24, height: 24)
                                        .background(Color.blue)
                                        .cornerRadius(4)
                                }
                                .buttonStyle(.plain)
                            }
                            .frame(width: 50)
                        }
                    }
                }

                Button(action: refreshApps) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
            }
            .padding(8)
            .background(Color.green.opacity(0.05))
            .cornerRadius(6)

            // File Browser
            VStack(alignment: .leading, spacing: 6) {
                Text("📁 Files")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                HStack(spacing: 4) {
                    TextField("Path...", text: $selectedPath)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)

                    Button(action: loadFiles) {
                        Image(systemName: "magnifyingglass")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(.plain)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(fileList.prefix(8), id: \.self) { file in
                            HStack(spacing: 6) {
                                Image(systemName: "doc.text")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(file)
                                    .font(.caption2)
                                    .lineLimit(1)
                                    .foregroundColor(.black)
                                Spacer()
                                Button(action: { openFile(file) }) {
                                    Image(systemName: "arrow.up.right.square")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 100)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(4)
            }
            .padding(8)
            .background(Color.orange.opacity(0.05))
            .cornerRadius(6)

            // Quick Actions
            VStack(alignment: .leading, spacing: 6) {
                Text("⚡ Quick Actions")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                HStack(spacing: 6) {
                    Button(action: { SystemControl.launchApp("Safari") }) {
                        VStack(spacing: 2) {
                            Image(systemName: "safari.fill")
                                .font(.body)
                                .foregroundColor(.black)
                            Text("Safari")
                                .font(.caption2)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { SystemControl.launchApp("Xcode") }) {
                        VStack(spacing: 2) {
                            Image(systemName: "xmark.app.fill")
                                .font(.body)
                                .foregroundColor(.black)
                            Text("Xcode")
                                .font(.caption2)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { copySystemInfo() }) {
                        VStack(spacing: 2) {
                            Image(systemName: "info.circle.fill")
                                .font(.body)
                                .foregroundColor(.black)
                            Text("Sys Info")
                                .font(.caption2)
                                .foregroundColor(.black)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color.yellow.opacity(0.05))
            .cornerRadius(6)

            // Blob Observation Settings
            VStack(alignment: .leading, spacing: 6) {
                Text("🫧 Blob Observations")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                HStack(spacing: 12) {
                    Image(systemName: autonomousObservationsEnabled ? "eye.fill" : "eye.slash.fill")
                        .font(.caption)
                        .foregroundColor(autonomousObservationsEnabled ? .blue : .gray)

                    Text("Auto Observe")
                        .font(.caption)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle("", isOn: $autonomousObservationsEnabled)
                        .onChange(of: autonomousObservationsEnabled) { newValue in
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                if newValue {
                                    appDelegate.enableAutonomousObservations()
                                } else {
                                    appDelegate.disableAutonomousObservations()
                                }
                            }
                        }
                }
                .padding(8)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(4)

                HStack(spacing: 12) {
                    Image(systemName: smartModeEnabled ? "bolt.fill" : "bolt.slash.fill")
                        .font(.caption)
                        .foregroundColor(smartModeEnabled ? .orange : .gray)

                    Text("Smart Mode")
                        .font(.caption)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle("", isOn: $smartModeEnabled)
                        .onChange(of: smartModeEnabled) { newValue in
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                if newValue {
                                    appDelegate.enableSmartMode()
                                } else {
                                    appDelegate.disableSmartMode()
                                }
                            }
                        }
                }
                .padding(8)
                .background(Color.orange.opacity(0.05))
                .cornerRadius(4)
            }
            .padding(8)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(6)

            Spacer()
        }
        .padding(10)
        .onAppear {
            refreshApps()
            loadFiles()
            refreshToggles()

            // Listen for refresh notifications
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("RefreshSystemControl"),
                object: nil,
                queue: .main
            ) { _ in
                self.refreshToggles()
            }
        }
    }

    private func refreshToggles() {
        // Initialize toggles from AppDelegate
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            autonomousObservationsEnabled = appDelegate.autonomousObservationsEnabled
            smartModeEnabled = appDelegate.smartModeEnabled
        }
    }

    private func executeCommand() {
        let result = SystemControl.executeCommand(commandInput)
        commandOutput = result.output.isEmpty ? "Command executed (no output)" : result.output
        showingOutput = true
        commandInput = ""
    }

    private func refreshApps() {
        runningApps = SystemControl.getRunningApps().sorted()
    }

    private func loadFiles() {
        fileList = SystemControl.listFiles(in: selectedPath)
    }

    private func openFile(_ fileName: String) {
        let fullPath = (selectedPath as NSString).appendingPathComponent(fileName)
        _ = SystemControl.openFile(fullPath)
    }

    private func copySystemInfo() {
        let info = SystemControl.getSystemInfo()
        NSPasteboard.general.setString(info, forType: .string)
        commandOutput = "System info copied to clipboard:\n\(info)"
        showingOutput = true
    }
}

#Preview {
    SystemControlPanel()
        .frame(height: 400)
}
