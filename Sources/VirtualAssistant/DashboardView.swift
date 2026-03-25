import SwiftUI

struct DashboardView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hey! I'm Blob! 🫧 What can I help you with?", isUser: false)
    ]
    @State private var inputText = ""
    @State private var isLoading = false

    private let openAI = OpenAIClient()

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
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        guard !userMessage.isEmpty else { return }

        messages.append(ChatMessage(text: userMessage, isUser: true))
        inputText = ""
        isLoading = true

        // Call OpenAI API
        openAI.chat(message: userMessage) { response in
            DispatchQueue.main.async {
                messages.append(ChatMessage(text: response, isUser: false))
                isLoading = false
            }
        }
    }
}

#Preview {
    DashboardView()
        .frame(width: 360, height: 520)
}
