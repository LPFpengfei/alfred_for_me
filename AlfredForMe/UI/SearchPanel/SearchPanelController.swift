import AppKit
import Combine
import SwiftUI

// MARK: - Search Panel Controller

final class SearchPanelController: NSObject {
  private var panel: NSPanel!
  private var searchEngine: SearchEngine
  private var themeManager: ThemeManager
  private var settingsManager: SettingsManager
  private var viewModel: SearchViewModel!
  private var isVisible = false
  private var globalClickMonitor: Any?
  private var localKeyMonitor: Any?
  private var visualEffectView: NSVisualEffectView!
  private var themeCancellable: AnyCancellable?

  init(searchEngine: SearchEngine, themeManager: ThemeManager, settingsManager: SettingsManager) {
    self.searchEngine = searchEngine
    self.themeManager = themeManager
    self.settingsManager = settingsManager
    super.init()
    setupPanel()
  }

  func toggle() {
    if isVisible {
      hide()
    } else {
      show()
    }
  }

  func show() {
    isVisible = false  // Reset state
    viewModel.clear()
    positionPanel()

    // Ensure the app is activated so windows can come to front
    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    panel.level = .floating
    panel.alphaValue = 1.0
    panel.makeKeyAndOrderFront(nil)
    panel.orderFrontRegardless()
    isVisible = true

    startEventMonitors()
  }

  func showWithQuery(_ query: String) {
    show()
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      // Search with the query but don't display it in the search bar
      self?.searchEngine.search(query: query)
    }
  }

  func hide() {
    guard isVisible else { return }
    stopEventMonitors()
    panel.orderOut(nil)
    isVisible = false
    // Switch back to accessory when hidden so dock icon disappears
    NSApp.setActivationPolicy(.accessory)
  }

  // MARK: - Event Monitors

  private func startEventMonitors() {
    stopEventMonitors()

    // Global click monitor - detect clicks outside the panel
    globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown,
    ]) { [weak self] _ in
      self?.hide()
    }

    // Local key monitor - detect ESC even when panel has focus
    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self, self.isVisible else { return event }
      if event.keyCode == 53 {  // Escape
        self.hide()
        return nil  // Consume the event
      }
      return event
    }
  }

  private func stopEventMonitors() {
    if let monitor = globalClickMonitor {
      NSEvent.removeMonitor(monitor)
      globalClickMonitor = nil
    }
    if let monitor = localKeyMonitor {
      NSEvent.removeMonitor(monitor)
      localKeyMonitor = nil
    }
  }

  // MARK: - Setup

  private func setupPanel() {
    let panelWidth: CGFloat = 720
    let panelHeight: CGFloat = 60

    let panel = NSPanel(
      contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
      styleMask: [.titled, .fullSizeContentView],
      backing: .buffered,
      defer: false
    )

    panel.isFloatingPanel = true
    panel.level = .floating
    panel.becomesKeyOnlyIfNeeded = false
    panel.titleVisibility = .hidden
    panel.titlebarAppearsTransparent = true
    panel.isMovableByWindowBackground = true
    panel.backgroundColor = .clear
    panel.isOpaque = false
    panel.hasShadow = true
    panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    panel.animationBehavior = .utilityWindow
    panel.hidesOnDeactivate = false
    panel.delegate = self

    self.viewModel = SearchViewModel(
      searchEngine: searchEngine,
      settingsManager: settingsManager,
      onDismiss: { [weak self] in self?.hide() },
      onResize: { [weak self] height in self?.resizePanel(to: height) }
    )

    // Visual effect view for frosted glass background
    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = .hudWindow
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 14
    visualEffectView.layer?.masksToBounds = true
    self.visualEffectView = visualEffectView

    let contentView = SearchPanelView(viewModel: viewModel)
      .environmentObject(themeManager)
      .environmentObject(settingsManager)

    let hostingView = NSHostingView(rootView: contentView)
    hostingView.translatesAutoresizingMaskIntoConstraints = false

    visualEffectView.addSubview(hostingView)
    visualEffectView.translatesAutoresizingMaskIntoConstraints = false

    let containerView = NSView(frame: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight))
    containerView.addSubview(visualEffectView)

    NSLayoutConstraint.activate([
      visualEffectView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
      visualEffectView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
      visualEffectView.topAnchor.constraint(equalTo: containerView.topAnchor),
      visualEffectView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
      hostingView.leadingAnchor.constraint(equalTo: visualEffectView.leadingAnchor),
      hostingView.trailingAnchor.constraint(equalTo: visualEffectView.trailingAnchor),
      hostingView.topAnchor.constraint(equalTo: visualEffectView.topAnchor),
      hostingView.bottomAnchor.constraint(equalTo: visualEffectView.bottomAnchor),
    ])

    panel.contentView = containerView
    self.panel = panel

    // Update visual effect material when theme changes
    updateVisualEffectMaterial()
    themeCancellable = themeManager.$current
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.updateVisualEffectMaterial()
      }
  }

  private func updateVisualEffectMaterial() {
    let theme = themeManager.current
    let isDark =
      theme.id.contains("dark") || theme.id == "monokai" || theme.id == "nord"
      || theme.id == "dracula" || theme.id == "one-dark" || theme.id == "solarized-dark"
    visualEffectView?.appearance = NSAppearance(named: isDark ? .darkAqua : .aqua)
    visualEffectView?.material = .hudWindow
  }

  private func positionPanel() {
    // Find the screen that contains the mouse pointer
    let mouseLocation = NSEvent.mouseLocation
    let screen =
      NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
      ?? NSScreen.screens.first
      ?? NSScreen.main
    guard let screen = screen else { return }
    let screenFrame = screen.visibleFrame
    let panelFrame = panel.frame

    let x = screenFrame.origin.x + (screenFrame.width - panelFrame.width) / 2
    let y = screenFrame.origin.y + screenFrame.height - panelFrame.height - screenFrame.height * 0.2

    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }

  private func resizePanel(to height: CGFloat) {
    let screen = NSScreen.main ?? NSScreen.screens.first
    guard let screen = screen else { return }
    let currentFrame = panel.frame
    let screenFrame = screen.visibleFrame

    let maxHeight = screenFrame.height * 0.7
    let newHeight = min(height, maxHeight)

    let newY = currentFrame.maxY - newHeight
    let newFrame = NSRect(
      x: currentFrame.origin.x, y: newY, width: currentFrame.width, height: newHeight)

    panel.setFrame(newFrame, display: true, animate: true)
  }
}

extension SearchPanelController: NSWindowDelegate {
  func windowDidResignKey(_ notification: Notification) {
    // Delay hide slightly to avoid race condition during show
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self, self.isVisible else { return }
      // Only hide if the panel is still not key
      if !self.panel.isKeyWindow {
        self.hide()
      }
    }
  }
}

// MARK: - Search View Model

final class SearchViewModel: ObservableObject {
  @Published var queryText: String = ""
  @Published var results: [SearchResult] = []
  @Published var selectedIndex: Int = 0
  @Published var isSearching = false
  @Published var showActionPanel = false
  @Published var actionResults: [ResultAction] = []

  let searchEngine: SearchEngine
  let settingsManager: SettingsManager
  let onDismiss: () -> Void
  let onResize: (CGFloat) -> Void

  private var cancellables = Set<AnyCancellable>()

  init(
    searchEngine: SearchEngine, settingsManager: SettingsManager, onDismiss: @escaping () -> Void,
    onResize: @escaping (CGFloat) -> Void
  ) {
    self.searchEngine = searchEngine
    self.settingsManager = settingsManager
    self.onDismiss = onDismiss
    self.onResize = onResize

    setupBindings()
  }

  func clear() {
    queryText = ""
    results = []
    selectedIndex = 0
    isSearching = false
    showActionPanel = false
    searchEngine.clear()
    onResize(60)
  }

  func search() {
    searchEngine.search(query: queryText)
  }

  func executeSelected() {
    guard selectedIndex < results.count else { return }
    let result = results[selectedIndex]
    searchEngine.execute(result: result)
    onDismiss()
  }

  func showActions() {
    guard selectedIndex < results.count else { return }
    let result = results[selectedIndex]
    actionResults = searchEngine.actions(for: result)
    showActionPanel = !actionResults.isEmpty
  }

  func moveSelection(by offset: Int) {
    let newIndex = selectedIndex + offset
    if newIndex >= 0 && newIndex < results.count {
      DispatchQueue.main.async { [weak self] in
        self?.selectedIndex = newIndex
      }
    }
  }

  func handleKeyDown(_ event: NSEvent) -> Bool {
    switch event.keyCode {
    case 53:  // Escape
      if showActionPanel {
        showActionPanel = false
      } else {
        onDismiss()
      }
      return true

    case 36:  // Return
      if showActionPanel {
        // Execute selected action
        if selectedIndex < actionResults.count {
          actionResults[selectedIndex].handler()
          onDismiss()
        }
      } else {
        executeSelected()
      }
      return true

    case 125:  // Down arrow
      moveSelection(by: 1)
      return true

    case 126:  // Up arrow
      moveSelection(by: -1)
      return true

    case 48:  // Tab - show actions
      showActions()
      return true

    default:
      return false
    }
  }

  // MARK: - Private

  private func setupBindings() {
    // Bind query text to search
    $queryText
      .debounce(for: .milliseconds(100), scheduler: DispatchQueue.main)
      .removeDuplicates()
      .sink { [weak self] query in
        self?.searchEngine.search(query: query)
      }
      .store(in: &cancellables)

    // Bind search engine results
    searchEngine.$results
      .receive(on: DispatchQueue.main)
      .sink { [weak self] results in
        guard let self = self else { return }
        self.results = results
        self.selectedIndex = 0

        // Calculate panel height
        // SearchBar(56) + Separator(1) + ResultsList padding(12) + titlebar(28) + bottom corner(14)
        let maxVisible = self.settingsManager.maxResults
        let visibleCount = min(results.count, maxVisible)
        let overhead: CGFloat = 111  // 56 + 1 + 12 + 28 + 14
        let resultRowHeight: CGFloat = 48
        let totalHeight = overhead + CGFloat(visibleCount) * resultRowHeight
        self.onResize(results.isEmpty ? 60 : totalHeight)
      }
      .store(in: &cancellables)

    searchEngine.$isSearching
      .receive(on: DispatchQueue.main)
      .assign(to: &$isSearching)
  }
}
