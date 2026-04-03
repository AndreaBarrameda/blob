import Foundation
import AppKit

struct FileMoveAction: Identifiable {
    let id = UUID()
    let fileName: String
    let sourcePath: String
    let category: String
    var selected: Bool = true
}

class FileOrganizerManager: ObservableObject {
    @Published var moveActions: [FileMoveAction] = []
    @Published var isScanning = false
    @Published var isExecuting = false
    @Published var statusMessage = ""
    @Published var undoLog: [(from: String, to: String)] = []
    @Published var currentDirectory: String = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads").path

    func scan(directory: String, openAI: OpenAIClient) {
        isScanning = true
        statusMessage = ""
        moveActions = []
        undoLog = []
        currentDirectory = directory

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            guard let contents = try? fm.contentsOfDirectory(atPath: directory) else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.statusMessage = "Couldn't read directory."
                }
                return
            }

            let files = contents.filter { !$0.hasPrefix(".") }.filter {
                var isDir: ObjCBool = false
                fm.fileExists(atPath: (directory as NSString).appendingPathComponent($0), isDirectory: &isDir)
                return !isDir.boolValue
            }

            guard !files.isEmpty else {
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.statusMessage = "No files found."
                }
                return
            }

            openAI.categorizeFiles(files) { categorized in
                // Build a case-insensitive lookup so GPT name variants still match
                let lowercasedMap: [String: String] = Dictionary(
                    uniqueKeysWithValues: files.map { ($0.lowercased(), $0) }
                )
                var categorizedNames = Set<String>()
                var actions: [FileMoveAction] = categorized.compactMap { (gptName, category) in
                    let trimmed = gptName.trimmingCharacters(in: .whitespacesAndNewlines)
                    let realName = files.contains(trimmed)
                        ? trimmed
                        : lowercasedMap[trimmed.lowercased()]
                    guard let fileName = realName else { return nil }
                    categorizedNames.insert(fileName)
                    return FileMoveAction(
                        fileName: fileName,
                        sourcePath: (directory as NSString).appendingPathComponent(fileName),
                        category: category
                    )
                }

                // Fallback: files GPT missed get extension-based category
                let missed = files.filter { !categorizedNames.contains($0) }
                for fileName in missed {
                    let category = FileOrganizerManager.categoryByExtension(fileName)
                    actions.append(FileMoveAction(
                        fileName: fileName,
                        sourcePath: (directory as NSString).appendingPathComponent(fileName),
                        category: category
                    ))
                }

                DispatchQueue.main.async {
                    self.moveActions = actions
                    self.isScanning = false
                    self.statusMessage = actions.isEmpty
                        ? "No files found."
                        : "\(actions.count) files ready to organize."
                }
            }
        }
    }

    func execute(directory: String) {
        let selected = moveActions.filter { $0.selected }
        guard !selected.isEmpty else { return }

        isExecuting = true
        undoLog = []

        DispatchQueue.global(qos: .userInitiated).async {
            let fm = FileManager.default
            var moved = 0
            var errors = 0
            var log: [(from: String, to: String)] = []

            for action in selected {
                let categoryDir = (directory as NSString).appendingPathComponent(action.category)

                if !fm.fileExists(atPath: categoryDir) {
                    do {
                        try fm.createDirectory(atPath: categoryDir, withIntermediateDirectories: true)
                    } catch {
                        errors += 1
                        continue
                    }
                }

                var dest = (categoryDir as NSString).appendingPathComponent(action.fileName)

                // Avoid collisions
                if fm.fileExists(atPath: dest) {
                    let ext = (action.fileName as NSString).pathExtension
                    let base = (action.fileName as NSString).deletingPathExtension
                    let name = ext.isEmpty ? "\(base)_1" : "\(base)_1.\(ext)"
                    dest = (categoryDir as NSString).appendingPathComponent(name)
                }

                do {
                    try fm.moveItem(atPath: action.sourcePath, toPath: dest)
                    log.append((from: action.sourcePath, to: dest))
                    moved += 1
                } catch {
                    errors += 1
                }
            }

            DispatchQueue.main.async {
                self.undoLog = log
                self.isExecuting = false
                self.moveActions = self.moveActions.filter { !$0.selected }
                self.statusMessage = errors == 0
                    ? "Moved \(moved) files."
                    : "Moved \(moved), \(errors) failed."
            }
        }
    }

    static func categoryByExtension(_ fileName: String) -> String {
        let ext = (fileName as NSString).pathExtension.lowercased()
        let name = fileName.lowercased()

        // Screenshot detection by name pattern
        if name.hasPrefix("screenshot") { return "Screenshots" }
        if name.hasPrefix("simulator screenshot") || name.hasPrefix("screens") && name.contains("simulator") {
            return "Simulator Screenshots"
        }

        switch ext {
        case "png", "jpg", "jpeg", "heic", "webp", "gif", "bmp", "tiff":
            return "Images"
        case "mp4", "mov", "avi", "mkv", "m4v":
            return "Videos"
        case "mp3", "m4a", "wav", "flac", "aac":
            return "Music"
        case "pdf":
            return "PDFs"
        case "doc", "docx", "pages", "rtf", "odt":
            return "Documents"
        case "xls", "xlsx", "numbers", "csv":
            return "Spreadsheets"
        case "ppt", "pptx", "key":
            return "Presentations"
        case "zip", "tar", "gz", "rar", "7z", "dmg", "pkg":
            return "Archives"
        case "swift", "py", "js", "ts", "html", "css", "json", "sh", "rb", "go", "rs":
            return "Code"
        case "sketch", "fig", "xd", "ai", "psd":
            return "Design"
        default:
            return "Misc"
        }
    }

    func undo() {
        guard !undoLog.isEmpty else { return }

        let fm = FileManager.default
        var restored = 0

        for entry in undoLog {
            do {
                try fm.moveItem(atPath: entry.to, toPath: entry.from)
                restored += 1
            } catch {}
        }

        undoLog = []
        statusMessage = "Restored \(restored) files."
    }
}
