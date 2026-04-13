import AppKit
import Foundation

// MARK: - Bookmark Plugin

final class BookmarkPlugin: SearchPlugin {
    let id = "com.alfredForMe.bookmark"
    let name = "Bookmarks"
    let keyword: String? = "bm"
    var isEnabled = true
    let priority = 60

    private var bookmarks: [BookmarkItem] = []
    private var lastIndexTime: Date?

    struct BookmarkItem {
        let title: String
        let url: String
        let browser: String
    }

    func initialize() {
        indexBookmarks()
    }

    func canHandle(query: SearchQuery) -> Bool {
        if query.isKeywordTrigger, let kw = query.keyword {
            return kw.lowercased() == "bm" || kw.lowercased() == "bookmark"
        }
        // Also search bookmarks in general queries if keyword typed
        return false
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        // Re-index if stale (> 5 min)
        if let lastTime = lastIndexTime, Date().timeIntervalSince(lastTime) > 300 {
            indexBookmarks()
        }

        let searchTerm = (query.argument ?? query.raw).lowercased()

        let filtered: [BookmarkItem]
        if searchTerm.isEmpty {
            filtered = Array(bookmarks.prefix(20))
        } else {
            filtered = bookmarks.filter {
                $0.title.lowercased().contains(searchTerm) ||
                $0.url.lowercased().contains(searchTerm)
            }
        }

        return filtered.prefix(15).enumerated().map { index, bookmark in
            SearchResult(
                id: "bookmark:\(bookmark.url)",
                title: bookmark.title,
                subtitle: "\(bookmark.browser) · \(bookmark.url)",
                icon: NSImage(systemSymbolName: "bookmark.fill", accessibilityDescription: nil),
                category: .bookmark,
                relevanceScore: 0.7 - Double(index) * 0.01,
                plugin: id,
                userData: [
                    "url": bookmark.url,
                    "title": bookmark.title
                ]
            )
        }
    }

    func execute(result: SearchResult) async {
        if let urlString = result.userData["url"],
           let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let urlString = result.userData["url"] else { return [] }

        return [
            ResultAction(title: "在浏览器中打开", shortcut: "⏎") {
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            },
            ResultAction(title: "复制链接") {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(urlString, forType: .string)
            },
            ResultAction(title: "复制标题") {
                if let title = result.userData["title"] {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(title, forType: .string)
                }
            },
        ]
    }

    // MARK: - Bookmark Indexing

    private func indexBookmarks() {
        DispatchQueue.global(qos: .background).async { [weak self] in
            var allBookmarks: [BookmarkItem] = []

            // Chrome bookmarks
            allBookmarks += self?.loadChromeBookmarks() ?? []

            // Safari bookmarks
            allBookmarks += self?.loadSafariBookmarks() ?? []

            // Firefox bookmarks
            allBookmarks += self?.loadFirefoxBookmarks() ?? []

            DispatchQueue.main.async {
                self?.bookmarks = allBookmarks
                self?.lastIndexTime = Date()
                print("🔖 Indexed \(allBookmarks.count) bookmarks")
            }
        }
    }

    private func loadChromeBookmarks() -> [BookmarkItem] {
        let paths = [
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Default/Bookmarks",
            NSHomeDirectory() + "/Library/Application Support/Google/Chrome/Profile 1/Bookmarks",
        ]

        var bookmarks: [BookmarkItem] = []

        for path in paths {
            guard FileManager.default.fileExists(atPath: path),
                  let data = FileManager.default.contents(atPath: path),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let roots = json["roots"] as? [String: Any] else { continue }

            for (_, value) in roots {
                if let folder = value as? [String: Any] {
                    bookmarks += extractChromeBookmarks(from: folder)
                }
            }
        }

        return bookmarks
    }

    private func extractChromeBookmarks(from node: [String: Any]) -> [BookmarkItem] {
        var results: [BookmarkItem] = []

        if let type = node["type"] as? String {
            if type == "url", let name = node["name"] as? String, let url = node["url"] as? String {
                results.append(BookmarkItem(title: name, url: url, browser: "Chrome"))
            } else if type == "folder", let children = node["children"] as? [[String: Any]] {
                for child in children {
                    results += extractChromeBookmarks(from: child)
                }
            }
        }

        return results
    }

    private func loadSafariBookmarks() -> [BookmarkItem] {
        let path = NSHomeDirectory() + "/Library/Safari/Bookmarks.plist"
        guard FileManager.default.fileExists(atPath: path),
              let data = FileManager.default.contents(atPath: path),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
            return []
        }

        return extractSafariBookmarks(from: plist)
    }

    private func extractSafariBookmarks(from dict: [String: Any]) -> [BookmarkItem] {
        var results: [BookmarkItem] = []

        if let urlString = dict["URLString"] as? String,
           let title = (dict["URIDictionary"] as? [String: Any])?["title"] as? String ?? dict["Title"] as? String {
            results.append(BookmarkItem(title: title, url: urlString, browser: "Safari"))
        }

        if let children = dict["Children"] as? [[String: Any]] {
            for child in children {
                results += extractSafariBookmarks(from: child)
            }
        }

        return results
    }

    private func loadFirefoxBookmarks() -> [BookmarkItem] {
        // Firefox stores bookmarks in SQLite, which requires more complex handling
        // For now, we'll skip Firefox or implement basic support
        let profilesPath = NSHomeDirectory() + "/Library/Application Support/Firefox/Profiles"
        guard FileManager.default.fileExists(atPath: profilesPath) else { return [] }

        // Find the default profile
        guard let profiles = try? FileManager.default.contentsOfDirectory(atPath: profilesPath) else { return [] }

        for profile in profiles {
            let dbPath = "\(profilesPath)/\(profile)/places.sqlite"
            guard FileManager.default.fileExists(atPath: dbPath) else { continue }

            // Use sqlite3 command to extract bookmarks
            return extractFirefoxBookmarks(dbPath: dbPath)
        }

        return []
    }

    private func extractFirefoxBookmarks(dbPath: String) -> [BookmarkItem] {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/sqlite3")
        process.arguments = [
            dbPath,
            "SELECT b.title, p.url FROM moz_bookmarks b JOIN moz_places p ON b.fk = p.id WHERE b.type = 1 AND b.title IS NOT NULL LIMIT 500;"
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return []
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else { return [] }

        return output.components(separatedBy: "\n").compactMap { line -> BookmarkItem? in
            let parts = line.split(separator: "|", maxSplits: 1)
            guard parts.count == 2 else { return nil }
            return BookmarkItem(
                title: String(parts[0]),
                url: String(parts[1]),
                browser: "Firefox"
            )
        }
    }
}
