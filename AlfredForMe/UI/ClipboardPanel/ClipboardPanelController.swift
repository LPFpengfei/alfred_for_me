import AppKit
import Combine
import SwiftUI

// MARK: - Clipboard Panel Controller

final class ClipboardPanelController: NSObject {
  private var panel: NSPanel!
  private var clipboardManager: ClipboardManager
  private var themeManager: ThemeManager
  private var viewModel: ClipboardPanelViewModel!
  private var isVisible = false
  private var globalClickMonitor: Any?
  private var localKeyMonitor: Any?

  init(clipboardManager: ClipboardManager, themeManager: ThemeManager) {
    self.clipboardManager = clipboardManager
    self.themeManager = themeManager
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
    isVisible = false
    viewModel.reset()
    positionPanel()

    NSApp.setActivationPolicy(.regular)
    NSApp.activate(ignoringOtherApps: true)

    panel.level = .floating
    panel.alphaValue = 1.0
    panel.makeKeyAndOrderFront(nil)
    panel.orderFrontRegardless()
    isVisible = true

    startEventMonitors()
  }

  func hide() {
    guard isVisible else { return }
    stopEventMonitors()
    panel.orderOut(nil)
    isVisible = false
    NSApp.setActivationPolicy(.accessory)
  }

  // MARK: - Event Monitors

  private func startEventMonitors() {
    stopEventMonitors()

    globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
      .leftMouseDown, .rightMouseDown,
    ]) { [weak self] _ in
      self?.hide()
    }

    localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
      guard let self = self, self.isVisible else { return event }
      if event.keyCode == 53 {  // Escape
        self.hide()
        return nil
      }
      // Forward navigation keys to ViewModel before the text field consumes them
      switch event.keyCode {
      case 125, 126, 48, 36:  // Down, Up, Tab, Return
        if self.viewModel.handleKeyDown(event) {
          return nil
        }
      case 124, 123:  // Right, Left with Cmd for page nav
        if event.modifierFlags.contains(.command),
          self.viewModel.handleKeyDown(event)
        {
          return nil
        }
      case 51:  // Delete with Cmd
        if event.modifierFlags.contains(.command),
          self.viewModel.handleKeyDown(event)
        {
          return nil
        }
      default:
        break
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
    let panelWidth: CGFloat = 860
    let panelHeight: CGFloat = 500

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

    self.viewModel = ClipboardPanelViewModel(
      clipboardManager: clipboardManager,
      onDismiss: { [weak self] in self?.hide() }
    )

    let visualEffectView = NSVisualEffectView()
    visualEffectView.material = .hudWindow
    visualEffectView.blendingMode = .behindWindow
    visualEffectView.state = .active
    visualEffectView.wantsLayer = true
    visualEffectView.layer?.cornerRadius = 14
    visualEffectView.layer?.masksToBounds = true

    let contentView = ClipboardPanelView(viewModel: viewModel)
      .environmentObject(themeManager)

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
  }

  private func positionPanel() {
    let mouseLocation = NSEvent.mouseLocation
    let screen =
      NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) })
      ?? NSScreen.screens.first
      ?? NSScreen.main
    guard let screen = screen else { return }
    let screenFrame = screen.visibleFrame
    let panelFrame = panel.frame

    let x = screenFrame.origin.x + (screenFrame.width - panelFrame.width) / 2
    let y =
      screenFrame.origin.y + screenFrame.height - panelFrame.height - screenFrame.height * 0.15

    panel.setFrameOrigin(NSPoint(x: x, y: y))
  }
}

extension ClipboardPanelController: NSWindowDelegate {
  func windowDidResignKey(_ notification: Notification) {
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      guard let self = self, self.isVisible else { return }
      if !self.panel.isKeyWindow {
        self.hide()
      }
    }
  }
}

// MARK: - Clipboard Panel View Model

final class ClipboardPanelViewModel: ObservableObject {
  @Published var searchText: String = ""
  @Published var selectedIndex: Int = 0
  @Published var currentPage: Int = 0
  @Published private(set) var displayItems: [ClipboardItem] = []
  @Published private(set) var displaySelectedItem: ClipboardItem? = nil
  @Published private(set) var displayFilteredCount: Int = 0
  @Published private(set) var displayTotalPages: Int = 1

  let clipboardManager: ClipboardManager
  let onDismiss: () -> Void
  let pageSize = 30

  private var cancellables = Set<AnyCancellable>()
  private var allFilteredItems: [ClipboardItem] = []

  init(clipboardManager: ClipboardManager, onDismiss: @escaping () -> Void) {
    self.clipboardManager = clipboardManager
    self.onDismiss = onDismiss
    setupBindings()
  }

  private func setupBindings() {
    // React to search text changes: reset page/index and refilter
    $searchText
      .removeDuplicates()
      .sink { [weak self] _ in
        guard let self = self else { return }
        self.currentPage = 0
        self.selectedIndex = 0
        self.refilter()
      }
      .store(in: &cancellables)

    // React to clipboard history changes: refilter
    clipboardManager.$history
      .dropFirst()
      .sink { [weak self] _ in
        self?.refilter()
      }
      .store(in: &cancellables)
  }

  // MARK: - Imperative State Updates

  private func refilter() {
    if searchText.isEmpty {
      allFilteredItems = clipboardManager.history
    } else {
      allFilteredItems = clipboardManager.history.filter {
        $0.content.localizedCaseInsensitiveContains(searchText)
      }
    }
    displayFilteredCount = allFilteredItems.count
    displayTotalPages = max(1, Int(ceil(Double(allFilteredItems.count) / Double(pageSize))))
    if currentPage >= displayTotalPages {
      currentPage = max(0, displayTotalPages - 1)
    }
    updatePagedItems()
  }

  private func updatePagedItems() {
    let start = currentPage * pageSize
    if start < allFilteredItems.count {
      let end = min(start + pageSize, allFilteredItems.count)
      displayItems = Array(allFilteredItems[start..<end])
    } else {
      displayItems = []
    }
    if selectedIndex >= displayItems.count && !displayItems.isEmpty {
      selectedIndex = displayItems.count - 1
    }
    updateSelectedItem()
  }

  private func updateSelectedItem() {
    if selectedIndex >= 0 && selectedIndex < displayItems.count {
      displaySelectedItem = displayItems[selectedIndex]
    } else {
      displaySelectedItem = displayItems.first
    }
  }

  func reset() {
    searchText = ""
    selectedIndex = 0
    currentPage = 0
  }

  func moveSelection(by offset: Int) {
    let count = displayItems.count
    guard count > 0 else { return }
    let newIndex = selectedIndex + offset
    if newIndex >= 0 && newIndex < count {
      selectedIndex = newIndex
      updateSelectedItem()
    }
  }

  func nextPage() {
    if currentPage < displayTotalPages - 1 {
      currentPage += 1
      selectedIndex = 0
      updatePagedItems()
    }
  }

  func previousPage() {
    if currentPage > 0 {
      currentPage -= 1
      selectedIndex = 0
      updatePagedItems()
    }
  }

  func executeSelected() {
    guard let item = displaySelectedItem else { return }
    clipboardManager.copyToClipboard(item.content)
    clipboardManager.pasteItem(item)
    onDismiss()
  }

  func deleteSelected() {
    guard let item = displaySelectedItem else { return }
    clipboardManager.remove(item: item)
    if selectedIndex >= displayItems.count - 1 && selectedIndex > 0 {
      selectedIndex -= 1
    }
  }

  func handleKeyDown(_ event: NSEvent) -> Bool {
    switch event.keyCode {
    case 53:  // Escape
      onDismiss()
      return true

    case 36:  // Return - paste selected
      executeSelected()
      return true

    case 125:  // Down arrow
      moveSelection(by: 1)
      return true

    case 126:  // Up arrow
      moveSelection(by: -1)
      return true

    case 48:  // Tab - next item, Shift+Tab - previous
      if event.modifierFlags.contains(.shift) {
        moveSelection(by: -1)
      } else {
        moveSelection(by: 1)
      }
      return true

    case 124:  // Right arrow - next page
      if event.modifierFlags.contains(.command) {
        nextPage()
        return true
      }
      return false

    case 123:  // Left arrow - previous page
      if event.modifierFlags.contains(.command) {
        previousPage()
        return true
      }
      return false

    case 51:  // Delete key
      if event.modifierFlags.contains(.command) {
        deleteSelected()
        return true
      }
      return false

    default:
      return false
    }
  }
}
