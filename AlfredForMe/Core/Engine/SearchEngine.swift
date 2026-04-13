import Combine
import Foundation

// MARK: - Search Engine

final class SearchEngine: ObservableObject {
  @Published var results: [SearchResult] = []
  @Published var isSearching = false

  private let pluginManager: PluginManager
  private let resultRanker = ResultRanker()
  private var searchTask: Task<Void, Never>?
  private let debounceInterval: TimeInterval = 0.15

  init(pluginManager: PluginManager) {
    self.pluginManager = pluginManager
  }

  func search(query: String) {
    // Cancel previous search
    searchTask?.cancel()

    let trimmed = query.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else {
      results = []
      isSearching = false
      return
    }

    isSearching = true

    searchTask = Task { [weak self] in
      guard let self = self else { return }

      // Debounce
      try? await Task.sleep(nanoseconds: UInt64(debounceInterval * 1_000_000_000))
      guard !Task.isCancelled else { return }

      let searchQuery = QueryParser.parse(raw: trimmed, pluginManager: pluginManager)
      let matchingPlugins = pluginManager.plugins(for: searchQuery)

      // Run all matching plugins concurrently
      var allResults: [SearchResult] = []

      await withTaskGroup(of: [SearchResult].self) { group in
        for plugin in matchingPlugins {
          group.addTask {
            guard !Task.isCancelled else { return [] }
            return await plugin.search(query: searchQuery)
          }
        }

        for await pluginResults in group {
          allResults.append(contentsOf: pluginResults)
        }
      }

      guard !Task.isCancelled else { return }

      // Rank and sort results
      let ranked = self.resultRanker.rank(results: allResults, query: searchQuery)

      await MainActor.run {
        self.results = ranked
        self.isSearching = false
      }
    }
  }

  func execute(result: SearchResult) {
    Task {
      if let plugin = pluginManager.plugin(for: result.plugin) {
        // Update usage for ranking
        resultRanker.recordUsage(resultId: result.id, query: result.title)
        await plugin.execute(result: result)
      }
    }
  }

  func actions(for result: SearchResult) -> [ResultAction] {
    pluginManager.plugin(for: result.plugin)?.actions(for: result) ?? []
  }

  func clear() {
    searchTask?.cancel()
    results = []
    isSearching = false
  }
}

// MARK: - Query Parser

struct QueryParser {
  static func parse(raw: String, pluginManager: PluginManager) -> SearchQuery {
    let parts = raw.split(separator: " ", maxSplits: 1)
    guard let firstWord = parts.first else {
      return SearchQuery(raw: raw)
    }

    // Check if any plugin has this keyword (primary or via canHandle alias)
    let keyword = String(firstWord).lowercased()
    let argument = parts.count > 1 ? String(parts[1]) : nil

    let hasKeywordPlugin = pluginManager.enabledPlugins().contains { plugin in
      if plugin.keyword?.lowercased() == keyword { return true }
      // Also check if plugin canHandle this as a keyword trigger (for aliases like "cb")
      if plugin.keyword != nil {
        let testQuery = SearchQuery(
          raw: raw, keyword: keyword, argument: argument, isKeywordTrigger: true)
        return plugin.canHandle(query: testQuery)
      }
      return false
    }

    if hasKeywordPlugin {
      return SearchQuery(
        raw: raw,
        keyword: keyword,
        argument: argument,
        isKeywordTrigger: true
      )
    }

    return SearchQuery(raw: raw)
  }
}

// MARK: - Result Ranker

final class ResultRanker {
  private var usageHistory: [String: Int] = [:]
  private let usageHistoryKey = "SearchResultUsageHistory"

  init() {
    loadUsageHistory()
  }

  func rank(results: [SearchResult], query: SearchQuery) -> [SearchResult] {
    return results.sorted { a, b in
      let scoreA = calculateScore(result: a, query: query)
      let scoreB = calculateScore(result: b, query: query)
      return scoreA > scoreB
    }
  }

  func recordUsage(resultId: String, query: String) {
    let key = "\(query.lowercased()):\(resultId)"
    usageHistory[key, default: 0] += 1
    saveUsageHistory()
  }

  private func calculateScore(result: SearchResult, query: SearchQuery) -> Double {
    var score = result.relevanceScore

    // Category bonus
    score += Double(100 - result.category.sortOrder) / 100.0

    // Usage history bonus
    let key = "\(query.raw.lowercased()):\(result.id)"
    if let usage = usageHistory[key] {
      score += min(Double(usage) * 0.1, 1.0)
    }

    // Exact match bonus
    if result.title.lowercased() == query.raw.lowercased() {
      score += 2.0
    } else if result.title.lowercased().hasPrefix(query.raw.lowercased()) {
      score += 1.0
    }

    return score
  }

  private func loadUsageHistory() {
    if let data = UserDefaults.standard.dictionary(forKey: usageHistoryKey) as? [String: Int] {
      usageHistory = data
    }
  }

  private func saveUsageHistory() {
    UserDefaults.standard.set(usageHistory, forKey: usageHistoryKey)
  }
}
