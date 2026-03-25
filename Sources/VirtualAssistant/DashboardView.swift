import SwiftUI

struct DashboardView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hey! I'm Blob! 🫧 What can I help you with?", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var currentTrack = "Nothing playing"

    private let openAI = OpenAIClient()
    private let spotify = SpotifyController()

    var body: some View {
        VStack(spacing: 0) {
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
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "app.dashed")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text("\(systemMonitor.runningApps.count) apps")
                            .font(.caption2)
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

            // Spotify controls
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .font(.caption)
                        .foregroundColor(.green)
                    Text(currentTrack)
                        .font(.caption2)
                        .lineLimit(2)
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

                    Button(action: { spotify.playPause() }) {
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
                    .font(.caption)
                    .onSubmit {
                        sendMessage()
                    }
                    .disabled(isLoading)

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
            }
            .padding(10)
        }
        .onAppear {
            updateCurrentTrack()
        }
    }

    private func updateCurrentTrack() {
        spotify.getCurrentTrack { track in
            currentTrack = track.isEmpty ? "Nothing playing" : track
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

        // Call OpenAI API
        openAI.chat(message: userMessage) { response in
            DispatchQueue.main.async {
                messages.append(ChatMessage(text: response, isUser: false))
                isLoading = false
                updateCurrentTrack()
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
                var songName = afterKeyword
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
