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
    @State private var screenWatchEnabled = true
    @State private var ambientAwarenessEnabled = true
    @State private var autonomousSpeechEnabled = true
    @State private var voiceEnabled = true
    @State private var contextInfo = ""
    @State private var taskInfo = ""
    @State private var mindStateInfo = ""
    @State private var showSystemControl = false
    @State private var chatTimeoutTimer: Timer?

    private var openAI: OpenAIClient {
        AppDelegate.shared?.openAI ?? OpenAIClient()
    }
    private var spotify: SpotifyController {
        AppDelegate.shared?.spotify ?? SpotifyController()
    }
    private var memory: BlobMemory {
        AppDelegate.shared?.memory ?? BlobMemory()
    }
    private var conversationLog: ConversationLog {
        AppDelegate.shared?.conversationLog ?? ConversationLog()
    }

    var body: some View {
        VStack(spacing: 0) {
          ScrollView {
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

                    Toggle(isOn: $listeningMode) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: listeningMode) { newValue in
                            print("🎙️ Toggle changed to: \(newValue)")
                            if let appDelegate = AppDelegate.shared {
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

                    Toggle(isOn: $workMode) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: workMode) { newValue in
                            if let appDelegate = AppDelegate.shared {
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

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: screenWatchEnabled ? "eye.fill" : "eye.slash.fill")
                        .font(.callout)
                        .foregroundColor(screenWatchEnabled ? .purple : .gray)

                    Text("Screen Watch")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle(isOn: $screenWatchEnabled) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: screenWatchEnabled) { newValue in
                            UserDefaults.standard.set(newValue, forKey: "autonomousObservationsEnabled")
                            NotificationCenter.default.post(
                                name: .autonomousObservationsChanged,
                                object: nil,
                                userInfo: ["enabled": newValue]
                            )

                            if let appDelegate = AppDelegate.shared {
                                if newValue {
                                    appDelegate.enableAutonomousObservations()
                                } else {
                                    appDelegate.disableAutonomousObservations()
                                }
                            }
                        }
                }
                .padding(10)
                .background(Color(red: 0.95, green: 0.9, blue: 1.0))

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: ambientAwarenessEnabled ? "waveform.path.ecg" : "waveform.path.ecg.rectangle")
                        .font(.callout)
                        .foregroundColor(ambientAwarenessEnabled ? .green : .gray)

                    Text("Ambient Awareness")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle(isOn: $ambientAwarenessEnabled) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: ambientAwarenessEnabled) { newValue in
                            if let appDelegate = AppDelegate.shared {
                                appDelegate.setAmbientAwarenessEnabled(newValue)
                            }
                        }
                }
                .padding(10)
                .background(Color(red: 0.92, green: 0.98, blue: 0.94))

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: autonomousSpeechEnabled ? "bubble.left.and.bubble.right.fill" : "bubble.left.and.bubble.right")
                        .font(.callout)
                        .foregroundColor(autonomousSpeechEnabled ? .orange : .gray)

                    Text("Autonomous Speech")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle(isOn: $autonomousSpeechEnabled) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: autonomousSpeechEnabled) { newValue in
                            if let appDelegate = AppDelegate.shared {
                                appDelegate.setAutonomousSpeechEnabled(newValue)
                            }
                        }
                }
                .padding(10)
                .background(Color(red: 1.0, green: 0.95, blue: 0.9))

                Divider()

                HStack(spacing: 12) {
                    Image(systemName: voiceEnabled ? "speaker.wave.3.fill" : "speaker.slash.fill")
                        .font(.callout)
                        .foregroundColor(voiceEnabled ? .pink : .gray)

                    Text("Voice (ElevenLabs)")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle(isOn: $voiceEnabled) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: voiceEnabled) { newValue in
                            if let appDelegate = AppDelegate.shared {
                                appDelegate.elevenLabs.isEnabled = newValue
                            }
                        }
                }
                .padding(10)
                .background(Color(red: 1.0, green: 0.92, blue: 0.95))
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

            if !mindStateInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Blob Mind")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    ForEach(mindStateInfo.split(separator: "\n").map(String.init), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 1.0, green: 0.97, blue: 0.9))
                .border(Color.gray.opacity(0.2), width: 0.5)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Mood Colors")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.black)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 5), spacing: 6) {
                    moodDot(color: Color(red: 0.62, green: 0.9, blue: 1.0), label: "Curious")
                    moodDot(color: Color(red: 0.78, green: 0.75, blue: 0.98), label: "Thoughtful")
                    moodDot(color: Color(red: 1.0, green: 0.78, blue: 0.9), label: "Playful")
                    moodDot(color: Color(red: 1.0, green: 0.66, blue: 0.5), label: "Alert")
                    moodDot(color: Color(red: 0.93, green: 0.34, blue: 0.3), label: "Angry")
                    moodDot(color: Color(red: 1.0, green: 0.84, blue: 0.52), label: "Annoyed")
                    moodDot(color: Color(red: 1.0, green: 0.7, blue: 0.82), label: "Offended")
                    moodDot(color: Color(red: 0.9, green: 0.97, blue: 1.0), label: "Afraid")
                    moodDot(color: Color(red: 1.0, green: 0.94, blue: 0.56), label: "Delighted")
                    moodDot(color: Color(red: 0.72, green: 0.95, blue: 0.84), label: "Content")
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(red: 0.96, green: 0.98, blue: 0.95))
            .border(Color.gray.opacity(0.2), width: 0.5)

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

            // System Control section
            VStack(spacing: 0) {
                Button(action: { showSystemControl.toggle() }) {
                    HStack {
                        Image(systemName: showSystemControl ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.orange)
                        Text("System Control")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                    .padding(10)
                    .background(Color(red: 1.0, green: 0.95, blue: 0.9))
                }
                .buttonStyle(.plain)

                if showSystemControl {
                    ScrollView {
                        SystemControlPanel()
                            .padding(8)
                    }
                    .frame(height: 300)
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

            } // end controls VStack
          } // end controls ScrollView
          .frame(maxHeight: 350)

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
        .frame(minWidth: 420, minHeight: 600)
        .onAppear {
            print("📋 Dashboard appeared")
            updateCurrentTrack()
            refreshContextInfo()
            refreshMindState()
            publishDashboardState()

            // Initialize toggles from AppDelegate
            if let appDelegate = AppDelegate.shared {
                print("📋 AppDelegate connected — syncing toggles")
                listeningMode = appDelegate.listeningModeEnabled
                workMode = appDelegate.workModeEnabled
                screenWatchEnabled = appDelegate.autonomousObservationsEnabled
                ambientAwarenessEnabled = appDelegate.ambientAwarenessEnabled
                autonomousSpeechEnabled = appDelegate.autonomousSpeechEnabled
                voiceEnabled = appDelegate.elevenLabs.isEnabled
            }

            if workMode {
                refreshTaskInfo()
            }

            // Refresh context every 30 seconds
            Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                refreshContextInfo()
                refreshMindState()
                if workMode {
                    refreshTaskInfo()
                }
            }

            NotificationCenter.default.addObserver(
                forName: .blobSpoke,
                object: nil,
                queue: .main
            ) { notification in
                guard let text = notification.userInfo?["text"] as? String else { return }
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

                if let last = messages.last, !last.isUser, last.text == text {
                    return
                }

                messages.append(ChatMessage(text: text, isUser: false))
                publishDashboardState()
            }
        }
        .onChange(of: inputText) { _ in
            publishDashboardState()
        }
        .onChange(of: showImportSection) { _ in
            publishDashboardState()
        }
        .onChange(of: showExportSection) { _ in
            publishDashboardState()
        }
        .onChange(of: showSystemControl) { _ in
            publishDashboardState()
        }
        .onChange(of: messages) { _ in
            publishDashboardState()
        }
    }

    private func updateCurrentTrack() {
        spotify.getCurrentTrack { track in
            currentTrack = track.isEmpty ? "Nothing playing" : track
        }
    }

    private func refreshContextInfo() {
        if let appDelegate = AppDelegate.shared {
            contextInfo = appDelegate.getContextInfo()
        }
    }

    private func refreshTaskInfo() {
        if let appDelegate = AppDelegate.shared {
            taskInfo = appDelegate.getTaskContext()
        }
    }

    private func refreshMindState() {
        if let appDelegate = AppDelegate.shared {
            mindStateInfo = appDelegate.getMindStateSummary()
        }
    }

    @ViewBuilder
    private func moodDot(color: Color, label: String) -> some View {
        VStack(spacing: 3) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        guard !userMessage.isEmpty else { return }

        messages.append(ChatMessage(text: userMessage, isUser: true))
        inputText = ""
        isLoading = true
        publishDashboardState()

        // Check for Spotify commands
        handleSpotifyCommands(in: userMessage)

        // Get audio context, location/weather, and task context from AppDelegate
        var audioContext = ""
        var contextInfo = ""
        var taskContext = ""
        var ambientContext = ""
        if let appDelegate = AppDelegate.shared {
            appDelegate.registerUserInteraction(userMessage)
            if listeningMode {
                audioContext = appDelegate.currentAudioContext
            }
            contextInfo = appDelegate.getContextInfo()
            if workMode {
                taskContext = appDelegate.getTaskContext()
            }
            if ambientAwarenessEnabled {
                ambientContext = appDelegate.getAmbientContextSummary()
            }
            mindStateInfo = appDelegate.getMindStateSummary()
        }

        // Combine all context
        let fullContext = [contextInfo, taskContext, ambientContext, mindStateInfo, audioContext]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        // Cancel any previous timeout
        chatTimeoutTimer?.invalidate()

        let completion: (String, BlobMood) -> Void = { response, mood in
            DispatchQueue.main.async {
                chatTimeoutTimer?.invalidate()
                chatTimeoutTimer = nil

                guard isLoading else { return } // timeout already fired

                messages.append(ChatMessage(text: response, isUser: false))
                isLoading = false
                updateCurrentTrack()
                publishDashboardState()

                // Update blob mood from LLM response
                if let blobView = AppDelegate.shared?.blobWindow?.contentView as? BlobNativeView {
                    blobView.setMood(mood, animated: true)
                }

                // Log to conversation history
                conversationLog.logChat(userMessage: userMessage, blobResponse: response, mood: mood.rawValue)

                // Extract memories from conversation
                let conversation = "\(userMessage) -> \(response)"
                memory.extractMemories(from: conversation, usingOpenAI: openAI) {}
            }
        }

        // 30-second timeout — recover UI if API never responds
        chatTimeoutTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: false) { _ in
            DispatchQueue.main.async {
                guard isLoading else { return }
                messages.append(ChatMessage(text: "...brain went offline. try again?", isUser: false))
                isLoading = false
                publishDashboardState()
            }
        }

        if screenWatchEnabled {
            openAI.chatWithScreenAwareness(message: userMessage, audioContext: audioContext, contextInfo: fullContext, completion: completion)
        } else {
            openAI.chat(message: userMessage, audioContext: audioContext, contextInfo: fullContext, completion: completion)
        }
    }

    private func publishDashboardState() {
        let lastLines = messages.suffix(4).map { message in
            let speaker = message.isUser ? "User" : "Blob"
            return "\(speaker): \(message.text)"
        }.joined(separator: " | ")

        let sections = [
            showImportSection ? "import open" : nil,
            showExportSection ? "export open" : nil,
            showSystemControl ? "system control open" : nil,
            workMode ? "work mode on" : nil,
            listeningMode ? "listening on" : nil
        ].compactMap { $0 }.joined(separator: ", ")

        let summary = """
        dashboard open; input: \(inputText.isEmpty ? "empty" : inputText); sections: \(sections.isEmpty ? "none" : sections); recent chat: \(lastLines.isEmpty ? "none" : lastLines)
        """

        NotificationCenter.default.post(
            name: .dashboardStateChanged,
            object: nil,
            userInfo: ["summary": summary]
        )
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

struct ChatMessage: Identifiable, Equatable {
    let id: UUID
    let text: String
    let isUser: Bool

    init(text: String, isUser: Bool) {
        self.id = UUID()
        self.text = text
        self.isUser = isUser
    }

    static func == (lhs: ChatMessage, rhs: ChatMessage) -> Bool {
        lhs.id == rhs.id
    }
}

struct ChatBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.isUser { Spacer() }

            Text(message.text)
                .padding(12)
                .background(message.isUser ? Color.blue : Color(red: 0.9, green: 0.93, blue: 0.97))
                .foregroundColor(message.isUser ? .white : .black)
                .cornerRadius(10)
                .frame(maxWidth: 300, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser { Spacer() }
        }
        .padding(.horizontal)
    }
}

#Preview {
    DashboardView()
        .frame(width: 360, height: 520)
}
