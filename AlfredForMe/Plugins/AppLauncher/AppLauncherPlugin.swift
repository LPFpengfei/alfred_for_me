import AppKit
import Combine

// MARK: - App Launcher Plugin

final class AppLauncherPlugin: SearchPlugin {
  let id = "com.alfredForMe.appLauncher"
  let name = "Application Launcher"
  var isEnabled = true
  let priority = 100

  private var applications: [AppInfo] = []
  private var indexTimer: Timer?

  struct AppInfo {
    let name: String
    let path: String
    let bundleIdentifier: String?
    let icon: NSImage
  }

  func initialize() {
    indexApplications()

    // Re-index every 5 minutes
    indexTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      self?.indexApplications()
    }
  }

  func cleanup() {
    indexTimer?.invalidate()
  }

  func canHandle(query: SearchQuery) -> Bool {
    !query.raw.isEmpty && !query.isKeywordTrigger
  }

  func search(query: SearchQuery) async -> [SearchResult] {
    let searchText = query.raw.lowercased()

    return applications.compactMap { app in
      let score = fuzzyMatch(query: searchText, target: app.name.lowercased())
      guard score > 0 else { return nil }

      return SearchResult(
        id: "app:\(app.path)",
        title: app.name,
        subtitle: abbreviatePath(app.path),
        icon: app.icon,
        category: .application,
        relevanceScore: score,
        plugin: id,
        userData: ["path": app.path]
      )
    }
  }

  func execute(result: SearchResult) async {
    if let path = result.userData["path"] {
      try? await NSWorkspace.shared.openApplication(
        at: URL(fileURLWithPath: path),
        configuration: NSWorkspace.OpenConfiguration()
      )
    }
  }

  func actions(for result: SearchResult) -> [ResultAction] {
    guard let path = result.userData["path"] else { return [] }

    return [
      ResultAction(title: "打开", shortcut: "⏎") { [weak self] in
        Task { await self?.execute(result: result) }
      },
      ResultAction(title: "在 Finder 中显示", shortcut: "⌘⏎") {
        NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
      },
      ResultAction(title: "复制路径") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(path, forType: .string)
      },
      ResultAction(title: "移到废纸篓") {
        do {
          try FileManager.default.trashItem(at: URL(fileURLWithPath: path), resultingItemURL: nil)
        } catch {
          print("Failed to trash: \(error)")
        }
      },
    ]
  }

  // MARK: - Indexing

  private func indexApplications() {
    DispatchQueue.global(qos: .background).async { [weak self] in
      let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
        "/System/Library/CoreServices",
      ]

      var apps: [AppInfo] = []

      for searchPath in searchPaths {
        let url = URL(fileURLWithPath: searchPath)
        guard
          let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isApplicationKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
          )
        else { continue }

        for case let fileURL as URL in enumerator {
          guard fileURL.pathExtension == "app" else { continue }

          let name = fileURL.deletingPathExtension().lastPathComponent
          let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
          icon.size = NSSize(width: 32, height: 32)

          let bundle = Bundle(url: fileURL)
          let bundleID = bundle?.bundleIdentifier

          apps.append(
            AppInfo(
              name: name,
              path: fileURL.path,
              bundleIdentifier: bundleID,
              icon: icon
            ))
        }
      }

      DispatchQueue.main.async {
        self?.applications = apps
        print("📱 Indexed \(apps.count) applications")
      }
    }
  }

  // MARK: - Fuzzy Matching

  private func fuzzyMatch(query: String, target: String) -> Double {
    if target == query { return 1.0 }
    if target.hasPrefix(query) { return 0.9 }
    if target.contains(query) { return 0.7 }

    // Abbreviation match (e.g., "vsc" matches "Visual Studio Code")
    let words = target.split(separator: " ")
    if words.count > 1 {
      let abbreviation = String(words.compactMap { $0.first })
      if abbreviation.hasPrefix(query) { return 0.8 }
    }

    // Character-by-character fuzzy match
    var queryIndex = query.startIndex
    var targetIndex = target.startIndex
    var matchCount = 0

    while queryIndex < query.endIndex && targetIndex < target.endIndex {
      if query[queryIndex] == target[targetIndex] {
        matchCount += 1
        queryIndex = query.index(after: queryIndex)
      }
      targetIndex = target.index(after: targetIndex)
    }

    let matched = queryIndex == query.endIndex
    if matched {
      return Double(matchCount) / Double(target.count) * 0.6
    }

    return 0
  }

  private func abbreviatePath(_ path: String) -> String {
    let home = NSHomeDirectory()
    if path.hasPrefix(home) {
      return "~" + path.dropFirst(home.count)
    }
    return path
  }
}
