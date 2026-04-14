import AppKit
import Foundation

// MARK: - File Search Plugin (Optimized with NSMetadataQuery like Alfred)

final class FileSearchPlugin: SearchPlugin {
  let id = "com.alfredForMe.fileSearch"
  let name = "File Search"
  var isEnabled = true
  let priority = 80

  private let fileKeywords = ["open", "find", "file"]

  /// Reusable metadata query (like Alfred's AlfredMetadataQuerier)
  private var metadataQuery: NSMetadataQuery?
  private var previousTerm: String?

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

  // MARK: - Spotlight Search (NSMetadataQuery, like Alfred's AlfredMetadataQuerier)

  private func spotlightSearch(query: String) async -> [SearchResult] {
    // Build multi-field MDQuery string like Alfred
    let queryString = buildMDQueryString(query: query)

    return await withCheckedContinuation { continuation in
      DispatchQueue.main.async { [weak self] in
        guard let self = self else {
          continuation.resume(returning: [])
          return
        }

        // Stop previous query
        self.metadataQuery?.stop()
        self.metadataQuery = nil

        let mdQuery = NSMetadataQuery()
        mdQuery.predicate = NSPredicate(fromMetadataQueryString: queryString)
        mdQuery.searchScopes = [
          NSMetadataQueryLocalComputerScope
        ]
        // Like Alfred: sort by last used date for relevance
        mdQuery.sortDescriptors = [
          NSSortDescriptor(key: NSMetadataItemFSContentChangeDateKey, ascending: false)
        ]

        // Use a flag to prevent double-resume (crash protection)
        // mdQuery.stop() can synchronously post NSMetadataQueryDidFinishGathering,
        // which would cause the observer and timeout to both try to resume.
        var resumed = false

        var observer: NSObjectProtocol?
        observer = NotificationCenter.default.addObserver(
          forName: .NSMetadataQueryDidFinishGathering,
          object: mdQuery,
          queue: .main
        ) { [weak self] notification in
          guard !resumed else { return }
          resumed = true

          if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
          }

          mdQuery.stop()

          let results =
            self?.processMetadataResults(
              query: mdQuery,
              searchText: query
            ) ?? []

          self?.previousTerm = query
          continuation.resume(returning: results)
        }

        self.metadataQuery = mdQuery

        if !mdQuery.start() {
          guard !resumed else { return }
          resumed = true
          if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
          }
          continuation.resume(returning: [])
          return
        }

        // Timeout: if query takes too long, return what we have
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
          guard !resumed else { return }
          resumed = true

          if let obs = observer {
            NotificationCenter.default.removeObserver(obs)
          }
          mdQuery.stop()

          let results =
            self?.processMetadataResults(
              query: mdQuery,
              searchText: query
            ) ?? []
          continuation.resume(returning: results)
        }
      }
    }
  }

  /// Build MDQuery string like Alfred's buildQueryField + queryString methods
  /// Alfred uses: kMDItemDisplayName, kMDItemAlternateNames, kMDItemFinderComment,
  ///              kMDItemContentType filtering, and 'cd' (case/diacritic insensitive)
  private func buildMDQueryString(query: String) -> String {
    // Escape special characters for MDQuery string literals
    let escaped = escapeMDQueryString(query)
    let words = escaped.split(separator: " ")

    var conditions: [String] = []

    if words.count <= 1 {
      // Single word: match on display name and alternate names
      // Using 'cd' modifier like Alfred (case-insensitive, diacritic-insensitive)
      conditions.append(
        "(kMDItemDisplayName == '*\(escaped)*'cd || kMDItemAlternateNames == '*\(escaped)*'cd)"
      )
    } else {
      // Multi-word: each word must match somewhere (AND)
      // Like Alfred's split word matching
      for word in words {
        conditions.append(
          "(kMDItemDisplayName == '*\(word)*'cd || kMDItemAlternateNames == '*\(word)*'cd)"
        )
      }
    }

    // Exclude system files (like Alfred: kMDItemSupportFileType != 'MDSystemFile')
    conditions.append("(kMDItemSupportFileType != 'MDSystemFile')")

    // Exclude Alfred-ignored files
    conditions.append("(kMDItemFinderComment != 'alfred:ignore'wc)")

    return conditions.joined(separator: " && ")
  }

  /// Escape special characters in MDQuery string values
  private func escapeMDQueryString(_ str: String) -> String {
    var result = str
    // Escape backslashes first, then single quotes
    result = result.replacingOccurrences(of: "\\", with: "\\\\")
    result = result.replacingOccurrences(of: "'", with: "\\'")
    return result
  }

  /// Process NSMetadataQuery results into SearchResults
  private func processMetadataResults(query: NSMetadataQuery, searchText: String) -> [SearchResult]
  {
    let searchLower = searchText.lowercased()
    var results: [SearchResult] = []
    let count = min(query.resultCount, 20)

    for i in 0..<count {
      guard let item = query.result(at: i) as? NSMetadataItem else { continue }
      guard let path = item.value(forAttribute: NSMetadataItemPathKey) as? String else { continue }
      let displayName =
        item.value(forAttribute: NSMetadataItemDisplayNameKey) as? String
        ?? URL(fileURLWithPath: path).lastPathComponent

      var isDir: ObjCBool = false
      FileManager.default.fileExists(atPath: path, isDirectory: &isDir)

      let icon = NSWorkspace.shared.icon(forFile: path)
      icon.size = NSSize(width: 32, height: 32)

      let category: ResultCategory = isDir.boolValue ? .folder : .file

      // Score based on match quality + position
      var score = 0.7 - Double(i) * 0.02
      let nameLower = displayName.lowercased()
      if nameLower == searchLower {
        score = 0.95
      } else if nameLower.hasPrefix(searchLower) {
        score = 0.85
      } else if nameLower.contains(searchLower) {
        score = 0.75
      }

      results.append(
        SearchResult(
          id: "file:\(path)",
          title: displayName,
          subtitle: abbreviatePath(path),
          icon: icon,
          category: category,
          relevanceScore: score,
          plugin: id,
          userData: ["path": path]
        ))
    }

    return results
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
