import AppKit
import Foundation

// MARK: - Clipboard History Plugin

final class ClipboardHistoryPlugin: SearchPlugin {
  let id = "com.alfredForMe.clipboardHistory"
  let name = "Clipboard History"
  let keyword: String? = "clipboard"
  var isEnabled = true
  let priority = 70

  private weak var clipboardManager: ClipboardManager?

  init(clipboardManager: ClipboardManager) {
    self.clipboardManager = clipboardManager
  }

  func canHandle(query: SearchQuery) -> Bool {
    if query.isKeywordTrigger, let kw = query.keyword {
      return kw.lowercased() == "clipboard" || kw.lowercased() == "cb"
    }
    return false
  }

  func search(query: SearchQuery) async -> [SearchResult] {
    guard let manager = clipboardManager else { return [] }

    let items = manager.history
    let searchTerm = query.argument?.lowercased()

    let filtered: [ClipboardItem]
    if let searchTerm = searchTerm, !searchTerm.isEmpty {
      filtered = items.filter { $0.content.lowercased().contains(searchTerm) }
    } else {
      filtered = items
    }

    return filtered.prefix(20).enumerated().map { index, item in
      let preview = item.content.prefix(100).replacingOccurrences(of: "\n", with: " ")
      let timeAgo = timeAgoString(from: item.timestamp)
      let subtitle = [item.appName, timeAgo].compactMap { $0 }.joined(separator: " · ")

      return SearchResult(
        id: "clipboard:\(item.id)",
        title: String(preview),
        subtitle: subtitle,
        icon: iconForType(item.contentType),
        category: .clipboard,
        relevanceScore: 0.8 - Double(index) * 0.01,
        plugin: id,
        userData: [
          "itemId": item.id,
          "content": item.content,
        ]
      )
    }
  }

  func execute(result: SearchResult) async {
    if let content = result.userData["content"] {
      clipboardManager?.copyToClipboard(content)
      clipboardManager?.pasteItem(ClipboardItem(content: content))
    }
  }

  func actions(for result: SearchResult) -> [ResultAction] {
    guard let content = result.userData["content"] else { return [] }
    let l10n = LocalizationManager.shared

    return [
      ResultAction(title: l10n.t("action.pasteClip"), shortcut: "⏎") { [weak self] in
        self?.clipboardManager?.copyToClipboard(content)
        self?.clipboardManager?.pasteItem(ClipboardItem(content: content))
      },
      ResultAction(title: l10n.t("action.copyToClipboard"), shortcut: "⌘C") { [weak self] in
        self?.clipboardManager?.copyToClipboard(content)
      },
      ResultAction(title: l10n.t("action.deleteEntry")) { [weak self] in
        guard let itemId = result.userData["itemId"] else { return }
        if let item = self?.clipboardManager?.history.first(where: { $0.id == itemId }) {
          self?.clipboardManager?.remove(item: item)
        }
      },
      ResultAction(title: l10n.t("action.clearAllHistory")) { [weak self] in
        self?.clipboardManager?.clearHistory()
      },
    ]
  }

  // MARK: - Helpers

  private func iconForType(_ type: ClipboardContentType) -> NSImage? {
    let name: String
    switch type {
    case .text: name = "doc.text"
    case .url: name = "link"
    case .filePath: name = "folder"
    case .image: name = "photo"
    case .color: name = "paintpalette"
    }
    return NSImage(systemSymbolName: name, accessibilityDescription: nil)
  }

  private func timeAgoString(from date: Date) -> String {
    let l10n = LocalizationManager.shared
    let interval = Date().timeIntervalSince(date)

    if interval < 60 { return l10n.t("plugin.clipboard.justNow") }
    if interval < 3600 { return "\(Int(interval / 60)) \(l10n.t("plugin.clipboard.minutesAgo"))" }
    if interval < 86400 { return "\(Int(interval / 3600)) \(l10n.t("plugin.clipboard.hoursAgo"))" }
    if interval < 604800 { return "\(Int(interval / 86400)) \(l10n.t("plugin.clipboard.daysAgo"))" }

    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
