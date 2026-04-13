import AppKit
import Carbon
import Combine
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
  // MARK: - Core Managers
  let settingsManager = SettingsManager.shared
  let pluginManager = PluginManager.shared
  let themeManager = ThemeManager.shared

  private var searchEngine: SearchEngine!
  private var hotkeyManager: HotkeyManager!
  private var clipboardManager: ClipboardManager!
  private var searchPanelController: SearchPanelController!
  private var clipboardPanelController: ClipboardPanelController!
  private var statusBarController: StatusBarController!
  private var settingsWindow: NSWindow?
  private var cancellables = Set<AnyCancellable>()

  func applicationDidFinishLaunching(_ notification: Notification) {
    // Setup standard macOS menu bar (required for copy/paste shortcuts)
    setupMainMenu()

    // Initialize core systems
    setupManagers()
    setupPlugins()
    setupUI()
    setupHotkey()

    // Delay showing the search panel so everything is initialized
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.searchPanelController.show()
    }
  }

  func applicationWillTerminate(_ notification: Notification) {
    hotkeyManager.unregisterAll()
    clipboardManager.stopMonitoring()
  }

  // MARK: - Menu

  private func setupMainMenu() {
    let l10n = LocalizationManager.shared
    let mainMenu = NSMenu()

    // App menu
    let appMenuItem = NSMenuItem()
    let appMenu = NSMenu()
    appMenu.addItem(
      NSMenuItem(
        title: l10n.t("menu.about"),
        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
        keyEquivalent: ""))
    appMenu.addItem(.separator())
    appMenu.addItem(
      NSMenuItem(
        title: l10n.t("menu.quit"), action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q")
    )
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Edit menu (enables ⌘C, ⌘V, ⌘X, ⌘A)
    let editMenuItem = NSMenuItem()
    let editMenu = NSMenu(title: l10n.t("menu.edit"))
    editMenu.addItem(
      NSMenuItem(title: l10n.t("menu.undo"), action: Selector(("undo:")), keyEquivalent: "z"))
    editMenu.addItem(
      NSMenuItem(title: l10n.t("menu.redo"), action: Selector(("redo:")), keyEquivalent: "Z"))
    editMenu.addItem(.separator())
    editMenu.addItem(
      NSMenuItem(title: l10n.t("menu.cut"), action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
    editMenu.addItem(
      NSMenuItem(title: l10n.t("menu.copy"), action: #selector(NSText.copy(_:)), keyEquivalent: "c")
    )
    editMenu.addItem(
      NSMenuItem(
        title: l10n.t("menu.paste"), action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
    editMenu.addItem(
      NSMenuItem(
        title: l10n.t("menu.selectAll"), action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"
      ))
    editMenuItem.submenu = editMenu
    mainMenu.addItem(editMenuItem)

    NSApp.mainMenu = mainMenu
  }

  // MARK: - Setup

  private func setupManagers() {
    searchEngine = SearchEngine(pluginManager: pluginManager)
    clipboardManager = ClipboardManager.shared
    clipboardManager.startMonitoring()
  }

  private func setupPlugins() {
    // Register all built-in plugins
    let plugins: [SearchPlugin] = [
      AppLauncherPlugin(),
      FileSearchPlugin(),
      WebSearchPlugin(),
      CalculatorPlugin(),
      SystemCommandPlugin(),
      ClipboardHistoryPlugin(clipboardManager: clipboardManager),
      SnippetPlugin(),
      DictionaryPlugin(),
      TerminalPlugin(),
      BookmarkPlugin(),
      FileNavigationPlugin(),
      AIChatPlugin(),
    ]

    for plugin in plugins {
      pluginManager.register(plugin: plugin)
    }

    // Load workflow plugins
    WorkflowEngine.shared.loadWorkflows()
    for workflow in WorkflowEngine.shared.workflowPlugins {
      pluginManager.register(plugin: workflow)
    }
  }

  private func setupUI() {
    searchPanelController = SearchPanelController(
      searchEngine: searchEngine,
      themeManager: themeManager,
      settingsManager: settingsManager
    )
    clipboardPanelController = ClipboardPanelController(
      clipboardManager: clipboardManager,
      themeManager: themeManager
    )
    statusBarController = StatusBarController(
      searchPanelController: searchPanelController
    )
  }

  private func setupHotkey() {
    hotkeyManager = HotkeyManager.shared
    let hotkey = settingsManager.globalHotkey
    hotkeyManager.register(hotkey: hotkey) { [weak self] in
      self?.searchPanelController.toggle()
    }

    // Register clipboard hotkey if configured
    if let cbHotkey = settingsManager.clipboardHotkey {
      hotkeyManager.register(hotkey: cbHotkey) { [weak self] in
        self?.clipboardPanelController.toggle()
      }
    }

    // Register AI chat hotkey if configured
    if let aiHotkey = settingsManager.aiChatHotkey {
      hotkeyManager.register(hotkey: aiHotkey) {
        AIChatWindowController.shared.showChatWindow()
      }
    }

    // Listen for hotkey changes
    settingsManager.$globalHotkey
      .dropFirst()
      .sink { [weak self] _ in
        self?.reregisterAllHotkeys()
      }
      .store(in: &cancellables)

    // Listen for clipboard hotkey changes
    settingsManager.$clipboardHotkey
      .dropFirst()
      .sink { [weak self] _ in
        self?.reregisterAllHotkeys()
      }
      .store(in: &cancellables)

    // Listen for AI chat hotkey changes
    settingsManager.$aiChatHotkey
      .dropFirst()
      .sink { [weak self] _ in
        self?.reregisterAllHotkeys()
      }
      .store(in: &cancellables)
  }

  private func reregisterAllHotkeys() {
    hotkeyManager.unregisterAll()
    let globalHk = settingsManager.globalHotkey
    hotkeyManager.register(hotkey: globalHk) { [weak self] in
      self?.searchPanelController.toggle()
    }
    if let cbHotkey = settingsManager.clipboardHotkey {
      hotkeyManager.register(hotkey: cbHotkey) { [weak self] in
        self?.clipboardPanelController.toggle()
      }
    }
    if let aiHotkey = settingsManager.aiChatHotkey {
      hotkeyManager.register(hotkey: aiHotkey) {
        AIChatWindowController.shared.showChatWindow()
      }
    }
  }

  // MARK: - Settings Window

  func showSettingsWindow() {
    if let window = settingsWindow {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let settingsView = SettingsView()
      .environmentObject(settingsManager)
      .environmentObject(pluginManager)
      .environmentObject(themeManager)

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 780, height: 560),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.title = LocalizationManager.shared.t("menu.settings")
    window.contentView = NSHostingView(rootView: settingsView)
    window.center()
    window.isReleasedWhenClosed = false
    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
    settingsWindow = window
  }
}
