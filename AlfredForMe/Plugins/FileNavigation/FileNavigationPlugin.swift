import AppKit
import Foundation

// MARK: - File Navigation Plugin

final class FileNavigationPlugin: SearchPlugin {
    let id = "com.alfredForMe.fileNavigation"
    let name = "File Navigation"
    var isEnabled = true
    let priority = 90

    func canHandle(query: SearchQuery) -> Bool {
        let text = query.raw
        return text.hasPrefix("/") || text.hasPrefix("~") || text.hasPrefix(".")
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        var path = query.raw

        // Expand ~
        if path.hasPrefix("~") {
            path = NSHomeDirectory() + path.dropFirst()
        }

        // Resolve the path
        let url = URL(fileURLWithPath: path)
        let resolvedPath = url.path

        var results: [SearchResult] = []

        // Check if path exists
        var isDir: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: resolvedPath, isDirectory: &isDir)

        if exists && isDir.boolValue {
            // List directory contents
            results = listDirectory(at: resolvedPath)
        } else if exists {
            // Show the file itself
            let icon = NSWorkspace.shared.icon(forFile: resolvedPath)
            icon.size = NSSize(width: 32, height: 32)

            results.append(
                SearchResult(
                    id: "nav:\(resolvedPath)",
                    title: url.lastPathComponent,
                    subtitle: abbreviatePath(resolvedPath),
                    icon: icon,
                    category: .file,
                    relevanceScore: 0.95,
                    plugin: id,
                    userData: ["path": resolvedPath]
                ))
        } else {
            // Try to list the parent directory with prefix matching
            let parentPath = url.deletingLastPathComponent().path
            let prefix = url.lastPathComponent.lowercased()

            if FileManager.default.fileExists(atPath: parentPath, isDirectory: &isDir)
                && isDir.boolValue
            {
                results = listDirectory(at: parentPath, filterPrefix: prefix)
            }
        }

        return results
    }

    func execute(result: SearchResult) async {
        guard let path = result.userData["path"] else { return }

        var isDir: ObjCBool = false
        FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

        if isDir.boolValue {
            // Open in Finder
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: path)
        } else {
            NSWorkspace.shared.open(URL(fileURLWithPath: path))
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let path = result.userData["path"] else { return [] }
        let l10n = LocalizationManager.shared

        return [
            ResultAction(title: l10n.t("action.open"), shortcut: "⏎") {
                NSWorkspace.shared.open(URL(fileURLWithPath: path))
            },
            ResultAction(title: l10n.t("action.openInFinder"), shortcut: "⌘⏎") {
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            },
            ResultAction(title: l10n.t("action.openInTerminal")) {
                var dir = path
                var isDir: ObjCBool = false
                if FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
                    && !isDir.boolValue
                {
                    dir = URL(fileURLWithPath: path).deletingLastPathComponent().path
                }
                let escapedDir = dir.replacingOccurrences(of: "\"", with: "\\\"")
                let script =
                    "tell application \"Terminal\" to do script \"cd \\\"\(escapedDir)\\\"\""
                NSAppleScript(source: script)?.executeAndReturnError(nil)
            },
            ResultAction(title: l10n.t("action.copyPath")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(path, forType: .string)
            },
            ResultAction(title: l10n.t("action.moveToTrash")) {
                do {
                    try FileManager.default.trashItem(
                        at: URL(fileURLWithPath: path), resultingItemURL: nil)
                } catch {
                    print("Failed to trash: \(error)")
                }
            },
        ]
    }

    // MARK: - Directory Listing

    private func listDirectory(at path: String, filterPrefix: String? = nil) -> [SearchResult] {
        guard let contents = try? FileManager.default.contentsOfDirectory(atPath: path) else {
            return []
        }

        let filtered: [String]
        if let prefix = filterPrefix, !prefix.isEmpty {
            filtered = contents.filter { $0.lowercased().hasPrefix(prefix) }
        } else {
            filtered = contents.filter { !$0.hasPrefix(".") }  // Hide hidden files by default
        }

        return filtered.sorted().prefix(20).enumerated().map { index, name in
            let fullPath = (path as NSString).appendingPathComponent(name)
            var isDir: ObjCBool = false
            FileManager.default.fileExists(atPath: fullPath, isDirectory: &isDir)

            let icon = NSWorkspace.shared.icon(forFile: fullPath)
            icon.size = NSSize(width: 32, height: 32)

            let category: ResultCategory = isDir.boolValue ? .navigation : .file

            return SearchResult(
                id: "nav:\(fullPath)",
                title: name + (isDir.boolValue ? "/" : ""),
                subtitle: abbreviatePath(fullPath),
                icon: icon,
                category: category,
                relevanceScore: 0.9 - Double(index) * 0.01,
                plugin: id,
                userData: ["path": fullPath]
            )
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
