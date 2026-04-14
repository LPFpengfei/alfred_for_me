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

      // Run all matching plugins concurrently with INCREMENTAL display
      // This ensures fast plugins (Calculator, AppLauncher) show results immediately
      // without waiting for slow plugins (FileSearch with Spotlight timeout)
      var allResults: [SearchResult] = []

      await withTaskGroup(of: [SearchResult].self) { group in
        for plugin in matchingPlugins {
          group.addTask {
            guard !Task.isCancelled else { return [] }
            return await plugin.search(query: searchQuery)
          }
        }

        for await pluginResults in group {
          guard !Task.isCancelled else { return }
          allResults.append(contentsOf: pluginResults)

          // Incrementally update UI as each plugin returns results
          let ranked = self.resultRanker.rank(results: allResults, query: searchQuery)
          await MainActor.run {
            self.results = ranked
          }
        }
      }

      guard !Task.isCancelled else { return }

      await MainActor.run {
        self.isSearching = false
      }
    }
  }

  func execute(result: SearchResult) {
    Task {
      if let plugin = pluginManager.plugin(for: result.plugin) {
        // Record to knowledge DB (like Alfred's addResultToKnowledge:withQuery:)
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

// MARK: - Result Ranker (Knowledge-aware, like Alfred's sortResults:withQuery:)

final class ResultRanker {
  private let db = SearchDatabase.shared

  func rank(results: [SearchResult], query: SearchQuery) -> [SearchResult] {
    let queryKey = query.raw.lowercased()

    // Fetch knowledge weights from DB (like Alfred's knowledge.alfdb)
    let knowledgeWeights = db.knowledgeWeights(keyword: queryKey)

    // Also fetch recent usage (last 30 days) for items in results
    let itemIds = results.map { $0.id }
    let recentWeights = db.recentUsageWeights(items: itemIds, days: 30)

    return results.sorted { a, b in
      let scoreA = calculateScore(
        result: a, query: query,
        knowledgeWeight: knowledgeWeights[a.id] ?? 0,
        recentWeight: recentWeights[a.id] ?? 0)
      let scoreB = calculateScore(
        result: b, query: query,
        knowledgeWeight: knowledgeWeights[b.id] ?? 0,
        recentWeight: recentWeights[b.id] ?? 0)
      return scoreA > scoreB
    }
  }

  /// Record usage to knowledge DB (like Alfred's addResultToKnowledge:withQuery:)
  func recordUsage(resultId: String, query: String) {
    let keyword = query.lowercased()
    db.addKnowledge(item: resultId, keyword: keyword)
  }

  /// Multi-factor scoring like Alfred's weight system:
  /// - baseWeight: from plugin relevance score
  /// - keyWeight: from keyword/text match quality
  /// - usedWeight: from knowledge DB (frequency-based)
  private func calculateScore(
    result: SearchResult,
    query: SearchQuery,
    knowledgeWeight: Int,
    recentWeight: Int
  ) -> Double {
    // Base weight from plugin
    var score = result.relevanceScore

    // Category bonus (like Alfred's preferencesSortWeight)
    score += Double(100 - result.category.sortOrder) / 100.0

    // Knowledge weight bonus (frequency from DB)
    // Like Alfred: "select item, count(item) as weight from knowledge where keyword = ?"
    if knowledgeWeight > 0 {
      score += min(Double(knowledgeWeight) * 0.2, 2.0)
    }

    // Recent usage bonus (time-decayed frequency)
    if recentWeight > 0 {
      score += min(Double(recentWeight) * 0.1, 1.0)
    }

    // Exact match bonus
    let queryLower = query.raw.lowercased()
    let titleLower = result.title.lowercased()
    if titleLower == queryLower {
      score += 2.0
    } else if titleLower.hasPrefix(queryLower) {
      score += 1.0
    } else if titleLower.contains(queryLower) {
      score += 0.3
    }

    return score
  }
}
