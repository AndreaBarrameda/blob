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
    @State private var taskGoal = ""
    @State private var mindStateInfo = ""
    @State private var codexBridgeInfo = ""
    @State private var showSystemControl = false
    @State private var chatTimeoutTimer: Timer?
    @State private var panelPinned = true
    @State private var panelOpacity: Double = 1.0

    private var openAI: OpenAIClient {
        AppDelegate.shared?.openAI ?? OpenAIClient()
    }
    private var spotify: SpotifyController {
        AppDelegate.shared?.spotify ?? SpotifyController()
    }
    private var safari: SafariController {
        AppDelegate.shared?.safari ?? SafariController()
    }
    private var systemSettings: SystemSettingsController {
        AppDelegate.shared?.systemSettings ?? SystemSettingsController()
    }
    private var notifications: NotificationController {
        AppDelegate.shared?.notifications ?? NotificationController()
    }
    private var camera: CameraCapture {
        AppDelegate.shared?.camera ?? CameraCapture()
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

            // Panel settings — pin + transparency
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    Image(systemName: panelPinned ? "pin.fill" : "pin.slash")
                        .font(.callout)
                        .foregroundColor(panelPinned ? .blue : .gray)

                    Text("Keep on Screen")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Spacer()

                    Toggle(isOn: $panelPinned) { EmptyView() }
                        .labelsHidden()
                        .onChange(of: panelPinned) { newValue in
                            AppDelegate.shared?.setDashboardPinned(newValue)
                        }
                }
                .padding(10)
                .background(Color(red: 0.93, green: 0.95, blue: 0.98))

                HStack(spacing: 12) {
                    Image(systemName: "circle.lefthalf.striped.horizontal")
                        .font(.callout)
                        .foregroundColor(.gray)

                    Text("Opacity")
                        .font(.callout)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    Slider(value: $panelOpacity, in: 0.3...1.0, step: 0.05)
                        .onChange(of: panelOpacity) { newValue in
                            AppDelegate.shared?.setDashboardOpacity(newValue)
                        }
                }
                .padding(10)
                .background(Color(red: 0.93, green: 0.95, blue: 0.98))
            }
            .border(Color.gray.opacity(0.3), width: 0.5)

            // Work Mode task goal + info
            if workMode {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        TextField("what are you working on?", text: $taskGoal)
                            .font(.caption)
                            .textFieldStyle(PlainTextFieldStyle())
                            .onSubmit {
                                AppDelegate.shared?.currentTaskGoal = taskGoal
                            }
                            .onChange(of: taskGoal) { _ in
                                AppDelegate.shared?.currentTaskGoal = taskGoal
                            }
                        if !taskGoal.isEmpty {
                            Button("clear") {
                                taskGoal = ""
                                AppDelegate.shared?.currentTaskGoal = ""
                            }
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color.white.opacity(0.6))
                    .cornerRadius(6)

                    if !taskInfo.isEmpty {
                        ForEach(taskInfo.split(separator: "\n").map(String.init), id: \.self) { line in
                            Text(line)
                                .font(.caption2)
                                .foregroundColor(.black)
                        }
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

            if !codexBridgeInfo.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Codex Bridge")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)

                    ForEach(codexBridgeInfo.split(separator: "\n").map(String.init), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.93, green: 0.97, blue: 1.0))
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

            // Safari controls
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "safari")
                        .font(.caption)
                        .foregroundColor(.blue)
                    Text("Safari")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Spacer()
                }

                HStack(spacing: 6) {
                    Button(action: { safari.goBack() }) {
                        Image(systemName: "arrow.left")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { safari.goForward() }) {
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { safari.reload() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { safari.activate() }) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(10)
            .background(Color(red: 0.98, green: 0.99, blue: 1.0))
            .border(Color.gray.opacity(0.3), width: 0.5)

            // System Settings controls
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "gear")
                        .font(.caption)
                        .foregroundColor(.purple)
                    Text("System")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.black)
                    Spacer()
                }

                HStack(spacing: 6) {
                    Button(action: { systemSettings.openSystemSettings() }) {
                        Image(systemName: "gearshape.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { systemSettings.openWallpaperSettings() }) {
                        Image(systemName: "photo.fill")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Button(action: { systemSettings.randomBuiltInWallpaper() }) {
                        Image(systemName: "shuffle")
                            .font(.caption)
                            .foregroundColor(.white)
                            .frame(width: 24, height: 24)
                            .background(Color.purple)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
            }
            .padding(10)
            .background(Color(red: 1.0, green: 0.98, blue: 1.0))
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
            refreshCodexBridge()
            publishDashboardState()

            // Initialize task goal from AppDelegate
            taskGoal = AppDelegate.shared?.currentTaskGoal ?? ""

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
                refreshCodexBridge()
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

            NotificationCenter.default.addObserver(
                forName: .quickChatUserMessage,
                object: nil,
                queue: .main
            ) { notification in
                guard let text = notification.userInfo?["message"] as? String else { return }
                messages.append(ChatMessage(text: text, isUser: true))
                publishDashboardState()
            }

            NotificationCenter.default.addObserver(
                forName: .codexBridgeUpdated,
                object: nil,
                queue: .main
            ) { _ in
                refreshCodexBridge()
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

    private func refreshCodexBridge() {
        if let appDelegate = AppDelegate.shared {
            codexBridgeInfo = appDelegate.getCodexBridgeTranscript()
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

        // Check for Safari commands
        handleSafariCommands(in: userMessage)

        // Check for System Settings commands
        handleSystemSettingsCommands(in: userMessage)

        // Check for notification/reminder commands
        handleNotificationCommands(in: userMessage)

        // Check for camera commands
        let lower = userMessage.lowercased()
        if lower.contains("stop camera") || lower.contains("stop watching") || lower.contains("turn off camera") {
            camera.stopCapture()
            messages.append(ChatMessage(text: userMessage, isUser: true))
            messages.append(ChatMessage(text: "camera off 📷", isUser: false))
            inputText = ""
            isLoading = false
            publishDashboardState()
            return
        }

        if lower.contains("look at") || lower.contains("see me") || lower.contains("see my") ||
           lower.contains("can you see") || lower.contains("camera") || lower.contains("face") && lower.contains("see") {
            handleCameraRequest()
            return
        }

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

                // Show thinking if present
                if let thinking = openAI.lastThinking, !thinking.isEmpty {
                    messages.append(ChatMessage(text: "💭 \(thinking)", isUser: false))
                    openAI.lastThinking = nil  // Clear so we don't repeat it
                }

                messages.append(ChatMessage(text: response, isUser: false))
                isLoading = false
                updateCurrentTrack()
                publishDashboardState()

                // Update blob mood and show speech bubble
                if let appDelegate = AppDelegate.shared {
                    if let blobView = appDelegate.blobWindow?.contentView as? BlobNativeView {
                        blobView.setMood(mood, animated: true)
                    }
                    appDelegate.showSpeechBubbleFromChat(text: response, mood: mood)
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

        // Wrap completion to intercept tags ([note: ...] always, other tags in work mode)
        let runPattern      = #"\[run:\s*(.+?)\]"#
        let notePattern     = #"\[note:\s*([\s\S]+?)\]"#
        let calendarPattern = #"\[calendar:\s*(\{[\s\S]+?\})\]"#
        let appNotePattern  = #"\[appnote:\s*(\{[\s\S]+?\})\]"#
        let wrappedCompletion: (String, BlobMood) -> Void = { response, mood in
            var cleaned = response
            var didHandle = false

            // ALWAYS process [note: ...] tags (all modes)
            if let noteRegex = try? NSRegularExpression(pattern: notePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let ns = cleaned as NSString
                let matches = noteRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
                if !matches.isEmpty {
                    didHandle = true
                    for match in matches {
                        let noteContent = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        AppDelegate.shared?.appendNote(noteContent)
                    }
                    cleaned = noteRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: ns.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Work mode only: [run:], [calendar:], [appnote:] tags
            if workMode {
            // Handle [run: <command>] tags
            if let runRegex = try? NSRegularExpression(pattern: runPattern, options: .caseInsensitive) {
                let ns = cleaned as NSString
                let matches = runRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
                if !matches.isEmpty {
                    didHandle = true
                    for match in matches {
                        let command = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        DispatchQueue.main.async {
                            messages.append(ChatMessage(text: "$ \(command)", isUser: false))
                        }
                        DispatchQueue.global().async {
                            let result = SystemControl.executeCommand(command)
                            let output = result.output.trimmingCharacters(in: .whitespacesAndNewlines)
                            let display = output.isEmpty ? "(no output)" : String(output.prefix(1500))
                            DispatchQueue.main.async {
                                messages.append(ChatMessage(text: display, isUser: false))
                                publishDashboardState()
                            }
                        }
                    }
                    cleaned = runRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: ns.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // Handle [calendar: {...}] tags (work mode only)
            if let calRegex = try? NSRegularExpression(pattern: calendarPattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let ns = cleaned as NSString
                let matches = calRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
                if !matches.isEmpty {
                    didHandle = true
                    for match in matches {
                        let json = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        let msg = AppDelegate.shared?.handleCalendarTag(json) ?? "calendar error"
                        DispatchQueue.main.async {
                            messages.append(ChatMessage(text: "📅 \(msg)", isUser: false))
                        }
                    }
                    cleaned = calRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: ns.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
            } // End workMode block

            // Handle [appnote: {...}] Apple Notes (ALL MODES)
            if let appNoteRegex = try? NSRegularExpression(pattern: appNotePattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) {
                let ns = cleaned as NSString
                let matches = appNoteRegex.matches(in: cleaned, range: NSRange(location: 0, length: ns.length))
                if !matches.isEmpty {
                    didHandle = true
                    for match in matches {
                        let json = ns.substring(with: match.range(at: 1)).trimmingCharacters(in: .whitespacesAndNewlines)
                        let msg = AppDelegate.shared?.handleAppNoteTag(json) ?? "notes error"
                        DispatchQueue.main.async {
                            messages.append(ChatMessage(text: "📝 \(msg)", isUser: false))
                        }
                    }
                    cleaned = appNoteRegex.stringByReplacingMatches(in: cleaned, range: NSRange(location: 0, length: ns.length), withTemplate: "").trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }

            // SAFETY FALLBACK: If user asked for notes but Blob forgot the tag, inject it
            let userAskedForNotes = userMessage.lowercased().contains("note") ||
                                   userMessage.lowercased().contains("Notes") ||
                                   userMessage.lowercased().contains("apple notes")
            let responseHasAppNote = response.contains("[appnote:")

            if userAskedForNotes && !responseHasAppNote && !cleaned.isEmpty {
                // Extract what Blob said (cleaned response) and automatically save it
                let noteBody = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
                if !noteBody.isEmpty {
                    didHandle = true
                    let noteJSON = "{\"title\": \"blob notes\", \"body\": \"\(noteBody.replacingOccurrences(of: "\"", with: "\\\""))\", \"action\": \"append\"}"
                    let msg = AppDelegate.shared?.handleAppNoteTag(noteJSON) ?? "notes saved"
                    DispatchQueue.main.async {
                        messages.append(ChatMessage(text: "📝 \(msg)", isUser: false))
                    }
                    cleaned = ""
                }
            }

            // Handle [play:], [volume:], [brightness:] via AppDelegate (all modes)
            if let appDelegate = AppDelegate.shared {
                let afterMedia = appDelegate.handleMediaTags(in: cleaned)
                if afterMedia != cleaned { didHandle = true }
                cleaned = afterMedia
            }

            // Show the cleaned response (without tags)
            let finalResponse = cleaned.isEmpty && didHandle ? "done." : cleaned
            if !finalResponse.isEmpty {
                completion(finalResponse, mood)
            }
        }

        if screenWatchEnabled {
            openAI.chatWithScreenAwareness(message: userMessage, audioContext: audioContext, contextInfo: fullContext, workMode: workMode, completion: wrappedCompletion)
        } else {
            openAI.chat(message: userMessage, audioContext: audioContext, contextInfo: fullContext, workMode: workMode, completion: wrappedCompletion)
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

    private func handleSafariCommands(in message: String) {
        let lower = message.lowercased()

        if lower.contains("open") || lower.contains("go to") || lower.contains("visit") {
            if let url = extractURL(from: message) {
                safari.open(url: url)
            }
        } else if lower.contains("search") || lower.contains("look up") || lower.contains("google") {
            if let query = extractSearchQuery(from: message) {
                safari.search(query)
            }
        } else if lower.contains("back") && lower.contains("safari") {
            safari.goBack()
        } else if lower.contains("forward") && lower.contains("safari") {
            safari.goForward()
        } else if lower.contains("reload") || lower.contains("refresh") {
            safari.reload()
        }
    }

    private func extractURL(from message: String) -> String? {
        // Look for common URL patterns or quoted text
        let lower = message.lowercased()
        let openKeywords = ["open", "go to", "visit", "navigate to"]

        for keyword in openKeywords {
            if let range = lower.range(of: keyword) {
                let afterKeyword = String(message[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)
                    .trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))

                let url = afterKeyword
                    .replacingOccurrences(of: " please", with: "")
                    .replacingOccurrences(of: " now", with: "")
                    .trimmingCharacters(in: .whitespaces)

                if !url.isEmpty && url.count > 2 {
                    return url
                }
            }
        }

        // Check for URLs like "example.com" or "http://..."
        if message.contains(".com") || message.contains(".org") || message.contains("http") {
            // Simple extraction - get the domain/URL from message
            let words = message.split(separator: " ")
            for word in words {
                let wordStr = String(word).trimmingCharacters(in: CharacterSet(charactersIn: "\"',.!?"))
                if wordStr.contains(".") && !wordStr.contains(" ") {
                    return wordStr
                }
            }
        }

        return nil
    }

    private func extractSearchQuery(from message: String) -> String? {
        let lower = message.lowercased()
        let searchKeywords = ["search", "look up", "google", "find", "check"]

        for keyword in searchKeywords {
            if let range = lower.range(of: keyword) {
                let afterKeyword = String(message[range.upperBound...])
                    .trimmingCharacters(in: .whitespaces)

                // Handle quoted strings: extract text between quotes
                if (afterKeyword.hasPrefix("\"") || afterKeyword.hasPrefix("'")) {
                    let quote = String(afterKeyword.first!)
                    let withoutFirst = String(afterKeyword.dropFirst())
                    if let endQuoteRange = withoutFirst.range(of: quote) {
                        let query = String(withoutFirst[..<endQuoteRange.lowerBound])
                        if !query.isEmpty {
                            return query
                        }
                    }
                }

                // Stop at "in safari" or other boundary words
                let boundaryWords = [" in safari", " on safari", " please", " now"]
                var query = afterKeyword
                for boundary in boundaryWords {
                    if let boundaryRange = query.lowercased().range(of: boundary) {
                        query = String(query[..<boundaryRange.lowerBound])
                    }
                }

                query = query.trimmingCharacters(in: .whitespaces)
                if !query.isEmpty && query.count > 2 {
                    return query
                }
            }
        }

        return nil
    }

    private func handleSystemSettingsCommands(in message: String) {
        let lower = message.lowercased()

        if lower.contains("wallpaper") || lower.contains("background") {
            if lower.contains("random") || lower.contains("change") {
                systemSettings.randomBuiltInWallpaper()
            } else if lower.contains("settings") {
                systemSettings.openWallpaperSettings()
            }
        } else if lower.contains("system settings") {
            systemSettings.openSystemSettings()
        }
    }

    private func handleNotificationCommands(in message: String) {
        let lower = message.lowercased()

        if lower.contains("remind") {
            // Parse "remind me in 5 minutes to do X" or "remind me at 3pm to do X"
            if lower.contains(" in ") {
                // Match: 30 sec, 5 min, 10 seconds, 2 minutes, etc.
                let pattern = #"(\d+)\s*(?:seconds?|secs?|s|minutes?|mins?|m)"#
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
                   let match = regex.firstMatch(in: lower, range: NSRange(lower.startIndex..., in: lower)) {
                    if let numberRange = Range(match.range(at: 1), in: lower),
                       let fullMatch = Range(match.range, in: lower) {
                        let number = Int(String(lower[numberRange])) ?? 0
                        let unit = String(lower[fullMatch.lowerBound..<fullMatch.upperBound]).lowercased()

                        let seconds: TimeInterval
                        if unit.contains("s") && !unit.contains("m") {
                            // seconds
                            seconds = TimeInterval(number)
                        } else {
                            // minutes
                            seconds = TimeInterval(number * 60)
                        }

                        if let messageStart = lower.range(of: " to ") ?? lower.range(of: " about ") {
                            let reminder = String(message[messageStart.upperBound...]).trimmingCharacters(in: .whitespaces)
                            if !reminder.isEmpty {
                                notifications.remind(message: reminder, after: seconds)
                            }
                        }
                    }
                }
            } else if lower.contains(" at ") {
                // "remind me at 3:30pm to do X"
                if let timeMatch = extractTime(from: message) {
                    if let messageStart = lower.range(of: " to ") ?? lower.range(of: " about ") {
                        let reminder = String(message[messageStart.upperBound...]).trimmingCharacters(in: .whitespaces)
                        notifications.remindAt(message: reminder, hour: timeMatch.hour, minute: timeMatch.minute)
                    }
                }
            }
        }
    }

    private func extractTime(from message: String) -> (hour: Int, minute: Int)? {
        let pattern = #"(\d{1,2}):(\d{2})\s*(am|pm|AM|PM)"#
        if let regex = try? NSRegularExpression(pattern: pattern),
           let match = regex.firstMatch(in: message, range: NSRange(message.startIndex..., in: message)) {
            let nsString = message as NSString
            if let hourRange = Range(match.range(at: 1), in: message),
               let minRange = Range(match.range(at: 2), in: message),
               let ampmRange = Range(match.range(at: 3), in: message),
               let hour = Int(String(message[hourRange])),
               let minute = Int(String(message[minRange])) {
                let ampm = String(message[ampmRange]).lowercased()
                var finalHour = hour
                if ampm == "pm" && hour != 12 {
                    finalHour += 12
                } else if ampm == "am" && hour == 12 {
                    finalHour = 0
                }
                return (hour: finalHour, minute: minute)
            }
        }
        return nil
    }

    private func handleCameraRequest() {
        print("📷 Camera request from user")

        isLoading = true

        // First request permission
        camera.requestCameraPermission { granted in
            print("📷 Permission granted: \(granted)")

            if !granted {
                DispatchQueue.main.async {
                    self.isLoading = false
                    self.messages.append(ChatMessage(text: "you didn't give me camera access 😢", isUser: false))
                }
                return
            }

            // Start capture
            self.camera.startCapture()

            // Wait for camera to warm up and capture first frame
            print("📷 Waiting for first frame...")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.camera.captureFrameAsBase64 { base64 in
                    print("📷 Captured frame, base64 length: \(base64?.count ?? 0)")

                    guard let base64 = base64, !base64.isEmpty else {
                        DispatchQueue.main.async {
                            self.isLoading = false
                            self.messages.append(ChatMessage(text: "camera's not working right now... 📷", isUser: false))
                        }
                        return
                    }

                    // Got a frame!
                    let cameraPrompt = """
                    The user asked you to look at them or see them. You have a camera image of them.
                    React naturally to what you see. Keep it brief (1-2 sentences max).
                    Comment on their expression, what they're doing, their appearance, or just react emotionally.
                    """

                    self.openAI.chatWithImage(
                        image: base64,
                        message: cameraPrompt,
                        completion: { response, mood in
                            DispatchQueue.main.async {
                                self.isLoading = false
                                self.messages.append(ChatMessage(text: response, isUser: false))
                                if let appDelegate = AppDelegate.shared {
                                    appDelegate.showSpeechBubbleFromChat(text: response, mood: mood)
                                    // Speak the camera observation out loud
                                    appDelegate.elevenLabs.speak(response)
                                }
                            }
                        }
                    )
                }
            }
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
