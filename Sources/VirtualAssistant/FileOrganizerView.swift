import SwiftUI

struct FileOrganizerView: View {
    @ObservedObject var organizer: FileOrganizerManager

    private var openAI: OpenAIClient {
        AppDelegate.shared?.openAI ?? OpenAIClient()
    }

    private var groupedActions: [String: [FileMoveAction]] {
        Dictionary(grouping: organizer.moveActions, by: { $0.category })
    }

    private var displayPath: String {
        organizer.currentDirectory.replacingOccurrences(
            of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {

            // Directory row
            HStack(spacing: 6) {
                Image(systemName: "folder")
                    .font(.caption2)
                    .foregroundColor(.orange)
                Text(displayPath)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Button("Change") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = false
                    panel.canChooseDirectories = true
                    panel.allowsMultipleSelection = false
                    panel.directoryURL = URL(fileURLWithPath: organizer.currentDirectory)
                    if panel.runModal() == .OK, let url = panel.url {
                        organizer.currentDirectory = url.path
                        organizer.moveActions = []
                        organizer.statusMessage = ""
                        organizer.undoLog = []
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)
                .foregroundColor(.blue)
            }

            // Status line
            if organizer.isScanning {
                HStack(spacing: 6) {
                    ProgressView().scaleEffect(0.6)
                    Text("Scanning and categorizing...")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
            } else if !organizer.statusMessage.isEmpty {
                Text(organizer.statusMessage)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }

            // Scan button (idle state)
            if organizer.moveActions.isEmpty && !organizer.isScanning {
                Button(action: {
                    organizer.scan(directory: organizer.currentDirectory, openAI: openAI)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkle.magnifyingglass")
                        Text("Scan & Categorize")
                    }
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.orange)
                    .cornerRadius(5)
                }
                .buttonStyle(.plain)
            }

            // File plan
            if !organizer.moveActions.isEmpty {
                ScrollView {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(groupedActions.keys.sorted(), id: \.self) { category in
                            let items = groupedActions[category] ?? []

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "folder.fill")
                                        .font(.caption2)
                                        .foregroundColor(.orange)
                                    Text(category)
                                        .font(.caption2)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.black)
                                    Text("(\(items.count))")
                                        .font(.caption2)
                                        .foregroundColor(Color(white: 0.4))
                                }

                                ForEach(items) { action in
                                    HStack(spacing: 4) {
                                        Toggle("", isOn: Binding(
                                            get: { action.selected },
                                            set: { newVal in
                                                if let idx = organizer.moveActions.firstIndex(where: { $0.id == action.id }) {
                                                    organizer.moveActions[idx].selected = newVal
                                                }
                                            }
                                        ))
                                        .toggleStyle(.checkbox)
                                        .scaleEffect(0.75)
                                        .frame(width: 14)

                                        Text(action.fileName)
                                            .font(.caption2)
                                            .foregroundColor(action.selected ? .black : Color(white: 0.6))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                        Spacer()
                                    }
                                    .padding(.leading, 12)
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 200)
                .background(Color.white)

                // Action row
                HStack(spacing: 8) {
                    let selectedCount = organizer.moveActions.filter { $0.selected }.count

                    Button(action: {
                        organizer.execute(directory: organizer.currentDirectory)
                    }) {
                        HStack(spacing: 4) {
                            if organizer.isExecuting {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Image(systemName: "arrow.right.circle.fill")
                            }
                            Text("Move \(selectedCount) files")
                        }
                        .font(.caption)
                        .foregroundColor(.white)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(selectedCount > 0 ? Color.green : Color.gray)
                        .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .disabled(selectedCount == 0 || organizer.isExecuting)

                    Button("Rescan") {
                        organizer.scan(directory: organizer.currentDirectory, openAI: openAI)
                    }
                    .font(.caption2)
                    .buttonStyle(.plain)
                    .foregroundColor(.blue)
                }
            }

            // Undo row
            if !organizer.undoLog.isEmpty {
                Button(action: { organizer.undo() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.uturn.backward")
                        Text("Undo last move")
                    }
                    .font(.caption2)
                    .foregroundColor(.orange)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
    }
}
