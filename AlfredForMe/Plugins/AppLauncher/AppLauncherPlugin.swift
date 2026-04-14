import AppKit
import Combine

// MARK: - App Launcher Plugin (Optimized with DB-backed cache like Alfred)

final class AppLauncherPlugin: SearchPlugin {
  let id = "com.alfredForMe.appLauncher"
  let name = "Application Launcher"
  var isEnabled = true
  let priority = 100

  private var iconCache: [String: NSImage] = [:]
  private var indexTimer: Timer?
  private let db = SearchDatabase.shared
  private var isIndexed = false

  func initialize() {
    indexApplications()

    // Re-index every 5 minutes
    indexTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
      self?.indexApplications()
    }

    // Watch for app install/uninstall via workspace notifications
    NSWorkspace.shared.notificationCenter.addObserver(
      forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
    ) { [weak self] _ in
      // Delayed re-index to catch new apps
      DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
        self?.indexApplications()
      }
    }
  }

  func cleanup() {
    indexTimer?.invalidate()
    NSWorkspace.shared.notificationCenter.removeObserver(self)
  }

  func canHandle(query: SearchQuery) -> Bool {
    !query.raw.isEmpty && !query.isKeywordTrigger
  }

  func search(query: SearchQuery) async -> [SearchResult] {
    let searchText = query.raw.lowercased()

    // Query from DB cache (like Alfred's appsMatchingQuery:)
    let cached = db.searchFiles(query: searchText, limit: 30)

    // Get knowledge weights for this query
    let knowledgeWeights = db.knowledgeWeights(keyword: searchText)

    return cached.compactMap { file in
      guard file.filetype == .application || file.filetype == .systemPreference else { return nil }

      let score = calculateMatchScore(
        query: searchText,
        file: file,
        knowledgeWeight: knowledgeWeights[file.path] ?? 0
      )
      guard score > 0 else { return nil }

      let icon = getCachedIcon(for: file.path)

      return SearchResult(
        id: "app:\(file.path)",
        title: file.fileName,
        subtitle: abbreviatePath(file.path),
        icon: icon,
        category: .application,
        relevanceScore: score,
        plugin: id,
        userData: ["path": file.path]
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

  // MARK: - Indexing (Populates SQLite cache like Alfred's populateDefaults)

  private func indexApplications() {
    DispatchQueue.global(qos: .background).async { [weak self] in
      guard let self = self else { return }

      let searchPaths = [
        "/Applications",
        "/System/Applications",
        "/System/Applications/Utilities",
        NSHomeDirectory() + "/Applications",
        "/System/Library/CoreServices",
      ]

      var appCount = 0

      for searchPath in searchPaths {
        let url = URL(fileURLWithPath: searchPath)
        guard
          let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.isApplicationKey, .localizedNameKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
          )
        else { continue }

        for case let fileURL as URL in enumerator {
          guard fileURL.pathExtension == "app" else { continue }

          let name = fileURL.deletingPathExtension().lastPathComponent
          let bundle = Bundle(url: fileURL)
          let bundleID = bundle?.bundleIdentifier

          // Collect alternative names (like Alfred's altnames field)
          var altNames: [String] = []
          if let localizedName = try? fileURL.resourceValues(forKeys: [.localizedNameKey])
            .localizedName,
            localizedName != name + ".app"
          {
            altNames.append(localizedName.replacingOccurrences(of: ".app", with: ""))
          }
          if let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName")
            as? String,
            displayName != name
          {
            altNames.append(displayName)
          }
          if let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String,
            bundleName != name
          {
            altNames.append(bundleName)
          }

          // Collect keywords from Spotlight comments
          var keywords: [String] = []
          if let bundleID = bundleID {
            keywords.append(bundleID)
          }

          let filetype: FileType
          if searchPath.contains("Utilities") || searchPath.contains("CoreServices") {
            filetype = .systemPreference
          } else {
            filetype = .application
          }

          self.db.cacheFile(
            path: fileURL.path,
            displayName: name,
            alternativeNames: altNames,
            keywords: keywords,
            lastUsed: 0,
            filetype: filetype,
            bundleId: bundleID
          )

          // Pre-cache icon
          DispatchQueue.main.async {
            let icon = NSWorkspace.shared.icon(forFile: fileURL.path)
            icon.size = NSSize(width: 32, height: 32)
            self.iconCache[fileURL.path] = icon
          }

          appCount += 1
        }
      }

      DispatchQueue.main.async {
        self.isIndexed = true
        print("📱 Indexed \(appCount) applications into DB cache")
      }
    }
  }

  // MARK: - Scoring (Multi-factor like Alfred's weight system)

  /// Calculate match score combining relevance + knowledge + recency
  private func calculateMatchScore(query: String, file: CachedFile, knowledgeWeight: Int) -> Double
  {
    var score = 0.0
    let nameLC = file.nameSearch
    let nameSplit = file.nameSplit
    let nameChars = file.nameChars

    // 1. Exact match (highest priority)
    if nameLC == query {
      score = 1.0
    }
    // 2. Prefix match on full name
    else if nameLC.hasPrefix(query) {
      score = 0.9
    }
    // 3. Prefix match on any split word
    else if nameSplit.split(separator: " ").contains(where: { $0.lowercased().hasPrefix(query) }) {
      score = 0.85
    }
    // 4. Abbreviation match (first chars of words, like Alfred's nameChars)
    else if nameChars.hasPrefix(query) {
      score = 0.8
    }
    // 5. Contains match
    else if nameLC.contains(query) {
      score = 0.7
    }
    // 6. Alternative names match
    else if !file.altnames.isEmpty && file.altnames.contains(query) {
      score = 0.65
    }
    // 7. Fuzzy subsequence match
    else {
      let fuzzy = fuzzySubsequenceScore(query: query, target: nameLC)
      if fuzzy > 0 {
        score = fuzzy * 0.6
      }
    }

    guard score > 0 else { return 0 }

    // Knowledge bonus (like Alfred's usedWeight from knowledge.alfdb)
    // "select item, count(item) as weight from knowledge where keyword = ? group by item"
    if knowledgeWeight > 0 {
      score += min(Double(knowledgeWeight) * 0.15, 1.5)
    }

    // Application type bonus
    if file.filetype == .application {
      score += 0.05
    }

    return score
  }

  /// Subsequence fuzzy match with position weighting
  private func fuzzySubsequenceScore(query: String, target: String) -> Double {
    var queryIdx = query.startIndex
    var targetIdx = target.startIndex
    var matchCount = 0
    var gapPenalty = 0.0
    var lastMatchPos = -1

    while queryIdx < query.endIndex && targetIdx < target.endIndex {
      if query[queryIdx] == target[targetIdx] {
        matchCount += 1
        let currentPos = target.distance(from: target.startIndex, to: targetIdx)
        if lastMatchPos >= 0 {
          let gap = currentPos - lastMatchPos - 1
          gapPenalty += Double(gap) * 0.02
        }
        lastMatchPos = currentPos
        queryIdx = query.index(after: queryIdx)
      }
      targetIdx = target.index(after: targetIdx)
    }

    guard queryIdx == query.endIndex else { return 0 }

    let baseScore = Double(matchCount) / Double(max(target.count, 1))
    return max(baseScore - gapPenalty, 0.1)
  }

  // MARK: - Icon Cache

  private func getCachedIcon(for path: String) -> NSImage {
    if let cached = iconCache[path] {
      return cached
    }
    let icon = NSWorkspace.shared.icon(forFile: path)
    icon.size = NSSize(width: 32, height: 32)
    iconCache[path] = icon
    return icon
  }

  private func abbreviatePath(_ path: String) -> String {
    let home = NSHomeDirectory()
    if path.hasPrefix(home) {
      return "~" + path.dropFirst(home.count)
    }
    return path
  }
}
