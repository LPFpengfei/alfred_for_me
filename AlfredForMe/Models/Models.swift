import AppKit
import Carbon
import UniformTypeIdentifiers

// MARK: - Search Result

struct SearchResult: Identifiable, Hashable {
  let id: String
  let title: String
  let subtitle: String
  let icon: NSImage?
  let category: ResultCategory
  let relevanceScore: Double
  let plugin: String
  let actionable: Bool
  let userData: [String: String]

  init(
    id: String = UUID().uuidString,
    title: String,
    subtitle: String = "",
    icon: NSImage? = nil,
    category: ResultCategory = .general,
    relevanceScore: Double = 0.5,
    plugin: String,
    actionable: Bool = true,
    userData: [String: String] = [:]
  ) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
    self.icon = icon
    self.category = category
    self.relevanceScore = relevanceScore
    self.plugin = plugin
    self.actionable = actionable
    self.userData = userData
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: SearchResult, rhs: SearchResult) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - Result Category

enum ResultCategory: String, CaseIterable, Codable {
  case application = "Applications"
  case file = "Files"
  case folder = "Folders"
  case webSearch = "Web Search"
  case calculator = "Calculator"
  case system = "System"
  case clipboard = "Clipboard"
  case snippet = "Snippets"
  case dictionary = "Dictionary"
  case bookmark = "Bookmarks"
  case contact = "Contacts"
  case workflow = "Workflows"
  case terminal = "Terminal"
  case general = "General"
  case navigation = "Navigation"

  var sortOrder: Int {
    switch self {
    case .application: return 0
    case .file, .folder, .navigation: return 1
    case .calculator: return 2
    case .system: return 3
    case .bookmark: return 4
    case .clipboard: return 5
    case .snippet: return 6
    case .dictionary: return 7
    case .webSearch: return 8
    case .workflow: return 9
    case .terminal: return 10
    case .contact: return 11
    case .general: return 12
    }
  }
}

// MARK: - Search Query

struct SearchQuery {
  let raw: String
  let keyword: String?
  let argument: String?
  let isKeywordTrigger: Bool

  init(raw: String) {
    self.raw = raw

    let parts = raw.split(separator: " ", maxSplits: 1)
    if parts.count >= 1 {
      let potentialKeyword = String(parts[0])
      self.keyword = potentialKeyword
      self.argument = parts.count > 1 ? String(parts[1]) : nil
    } else {
      self.keyword = nil
      self.argument = nil
    }
    self.isKeywordTrigger = false
  }

  init(raw: String, keyword: String?, argument: String?, isKeywordTrigger: Bool) {
    self.raw = raw
    self.keyword = keyword
    self.argument = argument
    self.isKeywordTrigger = isKeywordTrigger
  }
}

// MARK: - Result Action

struct ResultAction: Identifiable {
  let id: String
  let title: String
  let icon: NSImage?
  let shortcut: String?
  let handler: () -> Void

  init(
    id: String = UUID().uuidString,
    title: String,
    icon: NSImage? = nil,
    shortcut: String? = nil,
    handler: @escaping () -> Void
  ) {
    self.id = id
    self.title = title
    self.icon = icon
    self.shortcut = shortcut
    self.handler = handler
  }
}

// MARK: - Hotkey Configuration

struct HotkeyConfig: Codable, Equatable {
  var keyCode: UInt32
  var modifiers: UInt32

  static let defaultHotkey = HotkeyConfig(
    keyCode: UInt32(kVK_Space),
    modifiers: UInt32(optionKey)
  )
}

// MARK: - Clipboard Item

struct ClipboardItem: Identifiable, Codable {
  let id: String
  let content: String
  let contentType: ClipboardContentType
  let timestamp: Date
  let appName: String?
  let appBundleID: String?

  init(
    content: String, contentType: ClipboardContentType = .text, appName: String? = nil,
    appBundleID: String? = nil
  ) {
    self.id = UUID().uuidString
    self.content = content
    self.contentType = contentType
    self.timestamp = Date()
    self.appName = appName
    self.appBundleID = appBundleID
  }
}

enum ClipboardContentType: String, Codable {
  case text
  case url
  case filePath
  case image
  case color
}

// MARK: - Snippet

struct Snippet: Identifiable, Codable {
  let id: String
  var name: String
  var keyword: String
  var content: String
  var autoExpand: Bool
  var collection: String

  init(
    name: String, keyword: String, content: String, autoExpand: Bool = true,
    collection: String = "Default"
  ) {
    self.id = UUID().uuidString
    self.name = name
    self.keyword = keyword
    self.content = content
    self.autoExpand = autoExpand
    self.collection = collection
  }
}

// MARK: - Web Search Engine

struct WebSearchEngine: Identifiable, Codable {
  let id: String
  var name: String
  var keyword: String
  var urlTemplate: String
  var iconName: String?
  var isEnabled: Bool

  init(
    name: String, keyword: String, urlTemplate: String, iconName: String? = nil,
    isEnabled: Bool = true
  ) {
    self.id = UUID().uuidString
    self.name = name
    self.keyword = keyword
    self.urlTemplate = urlTemplate
    self.iconName = iconName
    self.isEnabled = isEnabled
  }

  func buildURL(query: String) -> URL? {
    let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
    let urlString = urlTemplate.replacingOccurrences(of: "{query}", with: encoded)
    return URL(string: urlString)
  }

  static let defaults: [WebSearchEngine] = [
    WebSearchEngine(
      name: "Google", keyword: "google", urlTemplate: "https://www.google.com/search?q={query}",
      iconName: "globe"),
    WebSearchEngine(
      name: "Bing", keyword: "bing", urlTemplate: "https://www.bing.com/search?q={query}",
      iconName: "globe"),
    WebSearchEngine(
      name: "DuckDuckGo", keyword: "duck", urlTemplate: "https://duckduckgo.com/?q={query}",
      iconName: "globe"),
    WebSearchEngine(
      name: "GitHub", keyword: "gh", urlTemplate: "https://github.com/search?q={query}",
      iconName: "globe"),
    WebSearchEngine(
      name: "Stack Overflow", keyword: "so",
      urlTemplate: "https://stackoverflow.com/search?q={query}", iconName: "globe"),
    WebSearchEngine(
      name: "Wikipedia", keyword: "wiki",
      urlTemplate: "https://en.wikipedia.org/wiki/Special:Search?search={query}", iconName: "globe"),
    WebSearchEngine(
      name: "YouTube", keyword: "yt",
      urlTemplate: "https://www.youtube.com/results?search_query={query}", iconName: "globe"),
    WebSearchEngine(
      name: "Amazon", keyword: "amazon", urlTemplate: "https://www.amazon.com/s?k={query}",
      iconName: "globe"),
    WebSearchEngine(
      name: "百度", keyword: "baidu", urlTemplate: "https://www.baidu.com/s?wd={query}",
      iconName: "globe"),
  ]
}

// MARK: - Workflow

struct Workflow: Identifiable, Codable {
  let id: String
  var name: String
  var keyword: String
  var description: String
  var isEnabled: Bool
  var steps: [WorkflowStep]
  var bundlePath: String?

  init(
    name: String, keyword: String, description: String = "", isEnabled: Bool = true,
    steps: [WorkflowStep] = [], bundlePath: String? = nil
  ) {
    self.id = UUID().uuidString
    self.name = name
    self.keyword = keyword
    self.description = description
    self.isEnabled = isEnabled
    self.steps = steps
    self.bundlePath = bundlePath
  }
}

struct WorkflowStep: Identifiable, Codable {
  let id: String
  var type: WorkflowStepType
  var config: [String: String]

  init(type: WorkflowStepType, config: [String: String] = [:]) {
    self.id = UUID().uuidString
    self.type = type
    self.config = config
  }
}

enum WorkflowStepType: String, Codable {
  case keyword
  case script
  case openURL
  case openFile
  case copyToClipboard
  case notification
  case filter
  case transform
}
