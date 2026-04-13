import AppKit
import Foundation

// MARK: - File Search Plugin

final class FileSearchPlugin: SearchPlugin {
    let id = "com.alfredForMe.fileSearch"
    let name = "File Search"
    var isEnabled = true
    let priority = 80

    private let fileKeywords = ["open", "find", "file"]
    private let inKeyword = "in"

    func canHandle(query: SearchQuery) -> Bool {
        if query.isKeywordTrigger, let kw = query.keyword {
            return fileKeywords.contains(kw.lowercased())
        }
        // Also handle general queries (with lower relevance)
        return !query.raw.isEmpty && !query.isKeywordTrigger && query.raw.count >= 2
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let searchText: String
        if query.isKeywordTrigger {
            searchText = query.argument ?? ""
        } else {
            searchText = query.raw
        }

        guard !searchText.isEmpty else { return [] }

        return await spotlightSearch(query: searchText)
    }

    func execute(result: SearchResult) async {
        if let path = result.userData["path"] {
            let url = URL(fileURLWithPath: path)
            NSWorkspace.shared.open(url)
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let path = result.userData["path"] else { return [] }
        let url = URL(fileURLWithPath: path)

        return [
            ResultAction(title: "打开", shortcut: "⏎") {
                NSWorkspace.shared.open(url)
            },
            ResultAction(title: "在 Finder 中显示", shortcut: "⌘⏎") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            },
            ResultAction(title: "复制路径") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            },
            ResultAction(title: "复制文件名") {
                let name = url.lastPathComponent
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(name, forType: .string)
            },
            ResultAction(title: "在终端中打开") {
                let dir = url.hasDirectoryPath ? path : url.deletingLastPathComponent().path
                let script = "tell application \"Terminal\" to do script \"cd \(dir.shellEscaped)\""
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            },
            ResultAction(title: "移到废纸篓") {
                do {
                    try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                } catch {
                    print("Failed to trash: \(error)")
                }
            },
        ]
    }

    // MARK: - Spotlight Search

    private func spotlightSearch(query: String) async -> [SearchResult] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: [])
                    return
                }

                // Use mdfind (command-line Spotlight) for reliability
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/mdfind")
                process.arguments = ["-limit", "20", "-name", query]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = Pipe()

                do {
                    try process.run()
                    process.waitUntilExit()
                } catch {
                    continuation.resume(returning: [])
                    return
                }

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                guard let output = String(data: data, encoding: .utf8) else {
                    continuation.resume(returning: [])
                    return
                }

                let paths = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                let results = paths.prefix(15).enumerated().map { index, path -> SearchResult in
                    let url = URL(fileURLWithPath: path)
                    let isDir = (try? url.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    icon.size = NSSize(width: 32, height: 32)

                    let category: ResultCategory = isDir ? .folder : .file
                    let score = 0.7 - Double(index) * 0.03

                    return SearchResult(
                        id: "file:\(path)",
                        title: url.lastPathComponent,
                        subtitle: self.abbreviatePath(path),
                        icon: icon,
                        category: category,
                        relevanceScore: score,
                        plugin: self.id,
                        userData: ["path": path]
                    )
                }

                continuation.resume(returning: results)
            }
        }
    }

    private func abbreviatePath(_ path: String) -> String {
        let home = NSHomeDirectory()
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }
}

// MARK: - String Extension

extension String {
    var shellEscaped: String {
        return self.replacingOccurrences(of: "'", with: "'\\''")
            .wrapping(with: "'")
    }

    func wrapping(with character: String) -> String {
        return character + self + character
    }
}
