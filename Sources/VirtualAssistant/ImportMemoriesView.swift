import SwiftUI

struct ImportMemoriesView: View {
    @ObservedObject var memory: BlobMemory
    @State private var pastedText = ""
    @State private var isProcessing = false
    @State private var importMode: ImportMode = .instructions
    @State private var extractedMemories: [String] = []
    @State private var showResults = false

    let openAI: OpenAIClient

    enum ImportMode {
        case instructions
        case conversation
    }

    var body: some View {
        VStack(spacing: 12) {
            // Tab selection
            Picker("Import Type", selection: $importMode) {
                Text("ChatGPT Instructions").tag(ImportMode.instructions)
                Text("Conversation Export").tag(ImportMode.conversation)
            }
            .pickerStyle(.segmented)
            .font(.caption)

            // Input area
            VStack(alignment: .leading, spacing: 6) {
                Text(importMode == .instructions ? "Paste your ChatGPT custom instructions:" : "Paste ChatGPT conversation:")
                    .font(.caption)
                    .fontWeight(.semibold)

                TextEditor(text: $pastedText)
                    .font(.caption)
                    .frame(height: 100)
                    .border(Color.gray.opacity(0.3))
                    .disabled(isProcessing)
            }

            // Import button
            Button(action: processImport) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                    Text(isProcessing ? "Extracting..." : "Extract & Import")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(4)
            }
            .disabled(pastedText.trimmingCharacters(in: .whitespaces).isEmpty || isProcessing)

            // Results
            if showResults && !extractedMemories.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Imported \(extractedMemories.count) fact(s):")
                        .font(.caption)
                        .fontWeight(.semibold)

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(extractedMemories, id: \.self) { fact in
                            HStack(alignment: .top, spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text(fact)
                                    .font(.caption)
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding(8)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(4)

                    Button("Clear") {
                        showResults = false
                        extractedMemories = []
                        pastedText = ""
                    }
                    .font(.caption)
                    .foregroundColor(.gray)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }

    private func processImport() {
        isProcessing = true
        let prompt: String

        if importMode == .instructions {
            // Simple parsing for instructions
            prompt = """
            Extract 3-5 key facts or preferences from these ChatGPT custom instructions about the user.
            Format each as: "User [fact]" - keep concise.
            Instructions: \(pastedText)
            """
        } else {
            // Parse conversation to extract facts
            prompt = """
            From this ChatGPT conversation, extract 3-5 important facts about the user's preferences, interests, or background.
            Format each as: "User [fact]" - keep concise and avoid repeating facts.
            Conversation: \(pastedText)
            """
        }

        openAI.chat(message: prompt) { response, _ in
            DispatchQueue.main.async {
                self.parseExtractedFacts(response)
                self.isProcessing = false
            }
        }
    }

    private func parseExtractedFacts(_ response: String) {
        // Split by newlines and filter out empty lines
        let facts = response
            .split(separator: "\n")
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && $0.count > 5 }

        extractedMemories = facts
        showResults = true

        // Save to blob memory
        for fact in facts {
            memory.addMemory(fact, category: "chatgpt_import")
        }
    }
}

#Preview {
    ImportMemoriesView(memory: BlobMemory(), openAI: OpenAIClient())
        .frame(width: 360)
}
