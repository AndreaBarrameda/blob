import SwiftUI

struct DashboardView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hey! I'm Blob! 🫧 What can I help you with?", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentTrack = "Nothing playing"
    @State private var showImportSection = false
    @State private var showExportSection = false
    @State private var listeningMode = false
    @State private var workMode = false
    @State private var contextInfo = ""
    @State private var taskInfo = ""

    private let openAI = OpenAIClient()
    private let spotify = SpotifyController()
    private let memory = BlobMemory()

    var body: some View {
        VStack(spacing: 0) {
            // Context Status (Time, Location, Weather)
            if !contextInfo.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(contextInfo.split(separator: "\n").map(String.init), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.99, green: 0.99, blue: 0.99))
                .border(Color.gray.opacity(0.2), width: 0.5)
            }

            // System info compact view
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Image(systemName: "battery.0")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("\(systemMonitor.batteryLevel)%")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(.black)
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "app.dashed")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(systemMonitor.runningApps.count) apps")
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                }

                Spacer()

                VStack(spacing: 6) {
                    Button(action: { systemMonitor.increaseVolume() }) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { systemMonitor.decreaseVolume() }) {
                        Image(systemName: "speaker.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 28, height: 28)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color(red: 0.98, green: 0.98, blue: 0.99))
            .border(Color.gray.opacity(0.3), width: 0.5)

            // Listening Mode & Work Mode Toggles
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: listeningMode ? "ear.badge.checkmark" : "ear.slash")
                        .font(.callout)
                        .foregroundColor(listeningMode ? .blue : .gray)

                    Text("Listening Mode")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle("", isOn: $listeningMode)
                        .onChange(of: listeningMode) { newValue in
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                if newValue {
                                    appDelegate.enableListeningMode()
                                } else {
                                    appDelegate.disableListeningMode()
                                }
                            }
                        }
                }
                .padding(10)
                .background(Color(red: 0.98, green: 0.95, blue: 1.0))

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: workMode ? "briefcase.circle.fill" : "briefcase")
                        .font(.callout)
                        .foregroundColor(workMode ? .orange : .gray)

                    Text("Work Mode")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle("", isOn: $workMode)
                        .onChange(of: workMode) { newValue in
                            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                                if newValue {
                                    appDelegate.enableWorkMode()
                                    refreshTaskInfo()
                                } else {
                                    appDelegate.disableWorkMode()
                                    taskInfo = ""
                                }
                            }
                        }
                }
                .padding(10)
                .background(Color(red: 1.0, green: 0.95, blue: 0.85))
            }
            .border(Color.gray.opacity(0.3), width: 0.5)

            // Task Info Display (when Work Mode is on)
            if workMode && !taskInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(taskInfo.split(separator: "\n").map(String.init), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 1.0, green: 0.95, blue: 0.85).opacity(0.5))
                .border(Color.gray.opacity(0.2), width: 0.5)
            }

            // Import memories section
            VStack(spacing: 0) {
                Button(action: { showImportSection.toggle() }) {
                    HStack {
                        Image(systemName: showImportSection ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("Import ChatGPT Memories")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(red: 0.98, green: 0.98, blue: 1.0))
                }
                .buttonStyle(.plain)

                if showImportSection {
                    ImportMemoriesView(memory: memory, openAI: openAI)
                        .border(Color.gray.opacity(0.3), width: 0.5)
                }
            }
            .border(Color.gray.opacity(0.3), width: 0.5)

            // Export memories section
            VStack(spacing: 0) {
                Button(action: { showExportSection.toggle() }) {
                    HStack {
                        Image(systemName: showExportSection ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text("Export to ChatGPT")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(red: 0.98, green: 1.0, blue: 0.98))
                }
                .buttonStyle(.plain)

                if showExportSection {
                    ExportMemoriesView(memory: memory)
                        .border(Color.gray.opacity(0.3), width: 0.5)
                }
            }
            .border(Color.gray.opacity(0.3), width: 0.5)

            // Spotify controls
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(currentTrack)
                        .font(.caption2)
                        .lineLimit(2)
                        .foregroundColor(.black)
                    Spacer()
                }

                HStack(spacing: 6) {
                    Button(action: { spotify.previousTrack() }) {
                        Image(systemName: "backward.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: {
                        spotify.playPause()
                        print("▶️ Play/Pause clicked")
                    }) {
                        Image(systemName: "play.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { spotify.nextTrack() }) {
                        Image(systemName: "forward.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.green)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(10)
            .background(Color(red: 0.98, green: 1.0, blue: 0.98))
            .border(Color.gray.opacity(0.3), width: 0.5)

            // Chat
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(messages, id: \.id) { message in
                            ChatBubble(message: message)
                                .id(message.id)
                        }

                        if isLoading {
                            HStack {
                                ProgressView()
                                    .scaleEffect(0.8)
                                Text("Thinking...")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Spacer()
                            }
                            .padding()
                        }
                    }
                    .padding()
                    .onChange(of: messages) { _ in
                        if let lastMessage = messages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id)
                            }
                        }
                    }
                }
            }

            Divider()

            // Input
            HStack(spacing: 8) {
                TextField("Ask me...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .font(.body)
                    .foregroundColor(.black)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isLoading)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.body)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(10)
        }
        .onAppear {
            updateCurrentTrack()
            openAI.memory = memory
            refreshContextInfo()

            // Initialize toggles from AppDelegate
            if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
                listeningMode = appDelegate.listeningModeEnabled
                workMode = appDelegate.workModeEnabled
            }

            if workMode {
                refreshTaskInfo()
            }

            // Refresh context every 30 seconds
            Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                refreshContextInfo()
                if workMode {
                    refreshTaskInfo()
                }
            }
        }
    }

    private func updateCurrentTrack() {
        spotify.getCurrentTrack { track in
            currentTrack = track.isEmpty ? "Nothing playing" : track
        }
    }

    private func refreshContextInfo() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            contextInfo = appDelegate.getContextInfo()
        }
    }

    private func refreshTaskInfo() {
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            taskInfo = appDelegate.getTaskContext()
        }
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        guard !userMessage.isEmpty else { return }

        messages.append(ChatMessage(text: userMessage, isUser: true))
        inputText = ""
        isLoading = true

        // Check for Spotify commands
        handleSpotifyCommands(in: userMessage)

        // Get audio context, location/weather, and task context from AppDelegate
        var audioContext = ""
        var contextInfo = ""
        var taskContext = ""
        if let appDelegate = NSApplication.shared.delegate as? AppDelegate {
            if listeningMode {
                audioContext = appDelegate.currentAudioContext
            }
            contextInfo = appDelegate.getContextInfo()
            if workMode {
                taskContext = appDelegate.getTaskContext()
            }
        }

        // Combine all context
        let fullContext = [contextInfo, taskContext, audioContext].filter { !$0.isEmpty }.joined(separator: "\n\n")

        // Call OpenAI API with screen awareness, audio context, and all context info
        openAI.chatWithScreenAwareness(message: userMessage, audioContext: audioContext, contextInfo: fullContext) { response in
            DispatchQueue.main.async {
                messages.append(ChatMessage(text: response, isUser: false))
                isLoading = false
                updateCurrentTrack()

                // Extract memories from conversation
                let conversation = "\(userMessage) -> \(response)"
                memory.extractMemories(from: conversation, usingOpenAI: openAI) {}
            }
        }
    }

    private func handleSpotifyCommands(in message: String) {
        let lower = message.lowercased()

        if lower.contains("play") {
            // Try to extract song/artist name
            if let songName = extractSongName(from: message) {
                spotify.playSearch(query: songName)
            } else {
                spotify.play()
            }
        } else if lower.contains("pause") {
            spotify.pause()
        } else if lower.contains("next") || lower.contains("skip") {
            spotify.nextTrack()
        } else if lower.contains("previous") || lower.contains("back") {
            spotify.previousTrack()
        }
    }

    private func extractSongName(from message: String) -> String? {
        let lower = message.lowercased()

        // Keywords that precede song names
        let playKeywords = ["play", "listen to", "put on", "queue"]

        for keyword in playKeywords {
            if let range = lower.range(of: keyword) {
                let afterKeyword = String(message[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                // Clean up common ending words
                let songName = afterKeyword
                    .replacingOccurrences(of: " please", with: "")
                    .replacingOccurrences(of: " now", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if !songName.isEmpty && songName.count > 2 {
                    return songName
                }
            }
        }

        return nil
    }
}

#Preview {
    DashboardView()
        .frame(width: 360, height: 520)
}
