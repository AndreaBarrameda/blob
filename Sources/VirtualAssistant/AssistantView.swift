import SwiftUI

struct AssistantView: View {
    @StateObject private var systemMonitor = SystemMonitor()
    @State private var messages: [ChatMessage] = [
        ChatMessage(text: "Hi! I'm your virtual assistant. I can help you with anything!", isUser: false)
    ]
    @State private var inputText = ""
    @State private var showSystemInfo = true

    var body: some View {
        VStack(spacing: 0) {
            // Header with assistant
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    Text("🤖 Assistant")
                        .font(.headline)
                    Text("Online")
                        .font(.caption)
                        .foregroundColor(.green)
                }
                Spacer()
                Button(action: { showSystemInfo.toggle() }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(red: 0.9, green: 0.93, blue: 0.97))

            // System Info Section
            if showSystemInfo {
                SystemInfoView(monitor: systemMonitor)
                    .padding()
                    .background(Color(red: 0.98, green: 0.98, blue: 0.99))
                    .border(Color.gray.opacity(0.3), width: 0.5)
            }

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(messages, id: \.id) { message in
                            ChatBubble(message: message)
                                .id(message.id)
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

            // Input area
            HStack(spacing: 10) {
                TextField("Ask me anything...", text: $inputText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage()
                    }

                Button(action: sendMessage) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(.blue)
                }
                .buttonStyle(.plain)
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
    }

    private func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        guard !userMessage.isEmpty else { return }

        messages.append(ChatMessage(text: userMessage, isUser: true))
        inputText = ""

        // Simulate assistant response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            let response = generateResponse(for: userMessage)
            messages.append(ChatMessage(text: response, isUser: false))
        }
    }

    private func generateResponse(for userMessage: String) -> String {
        let lowerMessage = userMessage.lowercased()

        if lowerMessage.contains("battery") {
            return "Your battery is at \(systemMonitor.batteryLevel)% and is \(systemMonitor.isCharging ? "charging" : "not charging")."
        } else if lowerMessage.contains("volume") {
            if lowerMessage.contains("up") {
                systemMonitor.increaseVolume()
                return "I've increased the volume for you!"
            } else if lowerMessage.contains("down") {
                systemMonitor.decreaseVolume()
                return "I've decreased the volume."
            }
        } else if lowerMessage.contains("music") || lowerMessage.contains("playing") {
            return "Current playing: \(systemMonitor.nowPlaying)"
        } else if lowerMessage.contains("apps") {
            return "You have \(systemMonitor.runningApps.count) apps open."
        } else if lowerMessage.contains("remind") {
            return "I can set reminders for you. What would you like to be reminded about?"
        }

        return "I understand you said: \(userMessage). I'm learning more about how to help you! How can I assist?"
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
    AssistantView()
}
