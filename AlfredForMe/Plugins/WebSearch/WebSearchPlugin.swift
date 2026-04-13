import AppKit
import Foundation

// MARK: - Web Search Plugin

final class WebSearchPlugin: SearchPlugin {
  let id = "com.alfredForMe.webSearch"
  let name = "Web Search"
  var isEnabled = true
  let priority = 40

  private var engines: [WebSearchEngine] {
    SettingsManager.shared.webSearchEngines
  }

  private var defaultEngine: WebSearchEngine? {
    let defaultKeyword = SettingsManager.shared.defaultWebSearch
    return engines.first { $0.keyword == defaultKeyword }
  }

  func canHandle(query: SearchQuery) -> Bool {
    if query.isKeywordTrigger, let kw = query.keyword {
      return engines.contains { $0.keyword.lowercased() == kw.lowercased() && $0.isEnabled }
    }
    // Only show web search as fallback for URL-like queries
    return looksLikeURL(query.raw)
  }

  func search(query: SearchQuery) async -> [SearchResult] {
    var results: [SearchResult] = []

    if query.isKeywordTrigger, let kw = query.keyword {
      // Keyword-triggered search
      if let engine = engines.first(where: {
        $0.keyword.lowercased() == kw.lowercased() && $0.isEnabled
      }) {
        let searchTerm = query.argument ?? ""
        if !searchTerm.isEmpty {
          results.append(makeResult(engine: engine, searchTerm: searchTerm, relevance: 0.95))
        } else {
          results.append(
            SearchResult(
              id: "web:\(engine.id):placeholder",
              title: "搜索 \(engine.name)...",
              subtitle: "输入搜索关键词",
              icon: nil,
              category: .webSearch,
              relevanceScore: 0.95,
              plugin: id,
              actionable: false,
              userData: ["engine": engine.keyword]
            ))
        }
      }
    } else {
      // Only show URL opening option for URL-like queries
      if looksLikeURL(query.raw) {
        results.append(
          SearchResult(
            id: "web:openurl:\(query.raw)",
            title: "打开 \(query.raw)",
            subtitle: "在浏览器中打开",
            icon: NSImage(systemSymbolName: "globe", accessibilityDescription: nil),
            category: .webSearch,
            relevanceScore: 0.95,
            plugin: id,
            userData: ["url": normalizeURL(query.raw)]
          ))
      }
    }

    return results
  }

  func execute(result: SearchResult) async {
    if let urlString = result.userData["url"],
      let url = URL(string: urlString)
    {
      NSWorkspace.shared.open(url)
    } else if let engineKeyword = result.userData["engine"],
      let searchTerm = result.userData["searchTerm"],
      let engine = engines.first(where: { $0.keyword == engineKeyword }),
      let url = engine.buildURL(query: searchTerm)
    {
      NSWorkspace.shared.open(url)
    }
  }

  func actions(for result: SearchResult) -> [ResultAction] {
    return [
      ResultAction(title: "在浏览器中搜索", shortcut: "⏎") { [weak self] in
        Task { await self?.execute(result: result) }
      },
      ResultAction(title: "复制搜索链接") {
        if let urlString = result.userData["url"] {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(urlString, forType: .string)
        }
      },
    ]
  }

  // MARK: - Helpers

  private func makeResult(engine: WebSearchEngine, searchTerm: String, relevance: Double)
    -> SearchResult
  {
    let url = engine.buildURL(query: searchTerm)
    return SearchResult(
      id: "web:\(engine.id):\(searchTerm)",
      title: "搜索 \(engine.name): \(searchTerm)",
      subtitle: url?.absoluteString ?? "",
      icon: NSImage(systemSymbolName: "globe", accessibilityDescription: nil),
      category: .webSearch,
      relevanceScore: relevance,
      plugin: id,
      userData: [
        "engine": engine.keyword,
        "searchTerm": searchTerm,
        "url": url?.absoluteString ?? "",
      ]
    )
  }

  private func looksLikeURL(_ text: String) -> Bool {
    let lowered = text.lowercased()
    if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") { return true }
    if lowered.contains(".") && !lowered.contains(" ") {
      let parts = lowered.split(separator: ".")
      if parts.count >= 2, let last = parts.last, last.count >= 2 && last.count <= 10 {
        return true
      }
    }
    return false
  }

  private func normalizeURL(_ text: String) -> String {
    let lowered = text.lowercased()
    if lowered.hasPrefix("http://") || lowered.hasPrefix("https://") {
      return text
    }
    return "https://\(text)"
  }
}
