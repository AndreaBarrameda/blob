import SwiftUI

struct ExportMemoriesView: View {
    @ObservedObject var memory: BlobMemory
    @State private var exportedText = ""
    @State private var showExport = false

    var body: some View {
        VStack(spacing: 12) {
            if memory.memories.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.title3)
                        .foregroundColor(.gray)
                    Text("No memories yet")
                        .font(.caption)
                        .foregroundColor(.gray)
                    Text("Chat with Blob or import from ChatGPT to build memories")
                        .font(.caption2)
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .background(Color.gray.opacity(0.05))
                .cornerRadius(6)
            } else {
                Button(action: generateExport) {
                    HStack {
                        Image(systemName: "square.and.arrow.up.fill")
                            .font(.caption)
                        Text("Export for ChatGPT")
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(8)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                if showExport && !exportedText.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Copy to ChatGPT Custom Instructions:")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Spacer()
                            Button(action: copyToClipboard) {
                                HStack(spacing: 4) {
                                    Image(systemName: "doc.on.doc.fill")
                                        .font(.caption)
                                    Text("Copy")
                                }
                                .font(.caption)
                                .foregroundColor(.blue)
                            }
                            .buttonStyle(.plain)
                        }

                        TextEditor(text: $exportedText)
                            .font(.caption)
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.3))
                            .disabled(true)

                        VStack(alignment: .leading, spacing: 4) {
                            Text("📋 How to use:")
                                .font(.caption2)
                                .fontWeight(.semibold)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("1. Copy the text above")
                                    .font(.caption2)
                                Text("2. Go to ChatGPT → Custom Instructions")
                                    .font(.caption2)
                                Text("3. Paste into the 'What would you like ChatGPT to know?' box")
                                    .font(.caption2)
                            }
                            .foregroundColor(.gray)
                        }
                        .padding(8)
                        .background(Color.blue.opacity(0.05))
                        .cornerRadius(4)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("\(memory.memories.count) fact(s) in memory")
                        .font(.caption2)
                        .foregroundColor(.gray)
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 4) {
                            ForEach(memory.memories.prefix(5), id: \.timestamp) { mem in
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "circle.fill")
                                        .font(.system(size: 3))
                                        .padding(.top, 3)
                                        .foregroundColor(.gray)
                                    Text(mem.fact)
                                        .font(.caption2)
                                        .lineLimit(2)
                                }
                            }
                            if memory.memories.count > 5 {
                                Text("... and \(memory.memories.count - 5) more")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .frame(maxHeight: 100)
                    .padding(8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(4)
                }
            }
        }
        .padding(12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(6)
    }

    private func generateExport() {
        let facts = memory.memories.map { $0.fact }
        let allFacts = facts.joined(separator: ", ")

        exportedText = """
        You know the user and have context from ongoing conversations:

        Facts: \(allFacts)

        Use this information to personalize responses and show you understand their interests and preferences. Reference relevant facts when helpful, but don't be obvious about it.
        """

        showExport = true
    }

    private func copyToClipboard() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(exportedText, forType: .string)

        // Visual feedback
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSSound(named: "Glass")?.play()
        }
    }
}

#Preview {
    let memory = BlobMemory()
    memory.addMemory("User likes indie rock music", category: "preference")
    memory.addMemory("User is learning Swift programming", category: "interest")

    return ExportMemoriesView(memory: memory)
        .frame(width: 360)
}
