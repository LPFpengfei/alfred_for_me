import AppKit
import SwiftUI

// MARK: - Status Bar Controller

final class StatusBarController: NSObject {
  private var statusItem: NSStatusItem!
  private weak var searchPanelController: SearchPanelController?

  init(searchPanelController: SearchPanelController) {
    self.searchPanelController = searchPanelController
    super.init()
    setupStatusBar()
  }

  private func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem.button {
      button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "AlfredForMe")
      button.image?.size = NSSize(width: 18, height: 18)
    }

    let l10n = LocalizationManager.shared
    let menu = NSMenu()
    menu.addItem(
      NSMenuItem(
        title: l10n.t("statusbar.openSearch"), action: #selector(openSearch), keyEquivalent: " "))
    menu.items.first?.target = self

    menu.addItem(NSMenuItem.separator())

    let aiChatItem = NSMenuItem(
      title: l10n.t("ai.chat"), action: #selector(openAIChat), keyEquivalent: "")
    aiChatItem.target = self
    menu.addItem(aiChatItem)

    menu.addItem(NSMenuItem.separator())

    let prefsItem = NSMenuItem(
      title: l10n.t("statusbar.preferences"), action: #selector(openPreferences), keyEquivalent: ","
    )
    prefsItem.target = self
    menu.addItem(prefsItem)

    let aboutItem = NSMenuItem(
      title: l10n.t("statusbar.about"), action: #selector(showAbout), keyEquivalent: "")
    aboutItem.target = self
    menu.addItem(aboutItem)

    menu.addItem(NSMenuItem.separator())

    let quitItem = NSMenuItem(
      title: l10n.t("statusbar.quit"), action: #selector(quitApp), keyEquivalent: "q")
    quitItem.target = self
    menu.addItem(quitItem)

    statusItem.menu = menu
  }

  @objc private func openSearch() {
    searchPanelController?.show()
  }

  @objc private func openAIChat() {
    AIChatWindowController.shared.showChatWindow()
  }

  @objc private func openPreferences() {
    if let delegate = NSApp.delegate as? AppDelegate {
      delegate.showSettingsWindow()
    }
  }

  @objc private func showAbout() {
    NSApp.orderFrontStandardAboutPanel(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  @objc private func quitApp() {
    NSApp.terminate(nil)
  }
}
