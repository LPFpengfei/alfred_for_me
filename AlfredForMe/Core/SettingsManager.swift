import Carbon
import Combine
import Foundation

// MARK: - Settings Manager

final class SettingsManager: ObservableObject {
  static let shared = SettingsManager()

  // MARK: - General
  @Published var globalHotkey: HotkeyConfig {
    didSet { save(hotkey: globalHotkey, forKey: "globalHotkey") }
  }

  @Published var maxResults: Int {
    didSet { UserDefaults.standard.set(maxResults, forKey: "maxResults") }
  }

  @Published var launchAtLogin: Bool {
    didSet { UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin") }
  }

  // MARK: - Appearance
  @Published var selectedTheme: String {
    didSet { UserDefaults.standard.set(selectedTheme, forKey: "selectedTheme") }
  }

  @Published var fontSize: CGFloat {
    didSet { UserDefaults.standard.set(fontSize, forKey: "fontSize") }
  }

  @Published var resultIconSize: CGFloat {
    didSet { UserDefaults.standard.set(resultIconSize, forKey: "resultIconSize") }
  }

  // MARK: - Search
  @Published var fuzzyMatching: Bool {
    didSet { UserDefaults.standard.set(fuzzyMatching, forKey: "fuzzyMatching") }
  }

  @Published var searchScope: [String] {
    didSet { UserDefaults.standard.set(searchScope, forKey: "searchScope") }
  }

  // MARK: - Web Search
  @Published var webSearchEngines: [WebSearchEngine] {
    didSet { saveWebSearchEngines() }
  }

  @Published var defaultWebSearch: String {
    didSet { UserDefaults.standard.set(defaultWebSearch, forKey: "defaultWebSearch") }
  }

  // MARK: - Clipboard
  @Published var clipboardHistoryEnabled: Bool {
    didSet { UserDefaults.standard.set(clipboardHistoryEnabled, forKey: "clipboardHistoryEnabled") }
  }

  @Published var clipboardHistorySize: Int {
    didSet { UserDefaults.standard.set(clipboardHistorySize, forKey: "clipboardHistorySize") }
  }

  @Published var clipboardHotkey: HotkeyConfig? {
    didSet {
      if let hk = clipboardHotkey {
        save(hotkey: hk, forKey: "clipboardHotkey")
      } else {
        UserDefaults.standard.removeObject(forKey: "clipboardHotkey")
      }
    }
  }

  // MARK: - Snippets
  @Published var snippets: [Snippet] {
    didSet { saveSnippets() }
  }

  // MARK: - Terminal
  @Published var terminalApp: String {
    didSet { UserDefaults.standard.set(terminalApp, forKey: "terminalApp") }
  }

  @Published var shellPath: String {
    didSet { UserDefaults.standard.set(shellPath, forKey: "shellPath") }
  }

  private init() {
    let defaults = UserDefaults.standard

    // Load or set defaults
    self.globalHotkey = Self.loadHotkey(forKey: "globalHotkey") ?? HotkeyConfig.defaultHotkey
    self.maxResults = defaults.object(forKey: "maxResults") as? Int ?? 9
    self.launchAtLogin = defaults.bool(forKey: "launchAtLogin")
    self.selectedTheme = defaults.string(forKey: "selectedTheme") ?? "Alfred Classic"
    self.fontSize = CGFloat(defaults.object(forKey: "fontSize") as? Double ?? 18.0)
    self.resultIconSize = CGFloat(defaults.object(forKey: "resultIconSize") as? Double ?? 36.0)
    self.fuzzyMatching = defaults.object(forKey: "fuzzyMatching") as? Bool ?? true
    self.searchScope = defaults.stringArray(forKey: "searchScope") ?? ["/Applications", "/Users"]
    self.webSearchEngines = Self.loadWebSearchEngines()
    self.defaultWebSearch = defaults.string(forKey: "defaultWebSearch") ?? "google"
    self.clipboardHistoryEnabled =
      defaults.object(forKey: "clipboardHistoryEnabled") as? Bool ?? true
    self.clipboardHistorySize = defaults.object(forKey: "clipboardHistorySize") as? Int ?? 1000
    self.clipboardHotkey =
      Self.loadHotkey(forKey: "clipboardHotkey")
      ?? HotkeyConfig(keyCode: 0x08, modifiers: UInt32(optionKey | cmdKey))
    self.snippets = Self.loadSnippets()
    self.terminalApp = defaults.string(forKey: "terminalApp") ?? "Terminal"
    self.shellPath = defaults.string(forKey: "shellPath") ?? "/bin/zsh"
  }

  // MARK: - Serialization Helpers

  private func save(hotkey: HotkeyConfig, forKey key: String) {
    if let data = try? JSONEncoder().encode(hotkey) {
      UserDefaults.standard.set(data, forKey: key)
    }
  }

  private static func loadHotkey(forKey key: String) -> HotkeyConfig? {
    guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(HotkeyConfig.self, from: data)
  }

  private func saveWebSearchEngines() {
    if let data = try? JSONEncoder().encode(webSearchEngines) {
      UserDefaults.standard.set(data, forKey: "webSearchEngines")
    }
  }

  private static func loadWebSearchEngines() -> [WebSearchEngine] {
    guard let data = UserDefaults.standard.data(forKey: "webSearchEngines"),
      let engines = try? JSONDecoder().decode([WebSearchEngine].self, from: data)
    else {
      return WebSearchEngine.defaults
    }
    return engines
  }

  private func saveSnippets() {
    if let data = try? JSONEncoder().encode(snippets) {
      UserDefaults.standard.set(data, forKey: "snippets")
    }
  }

  private static func loadSnippets() -> [Snippet] {
    guard let data = UserDefaults.standard.data(forKey: "snippets"),
      let snippets = try? JSONDecoder().decode([Snippet].self, from: data)
    else {
      return []
    }
    return snippets
  }
}
