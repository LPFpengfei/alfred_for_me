import AppKit
import Combine
import SwiftUI

// MARK: - Status Bar Controller

final class StatusBarController: NSObject {
  private var statusItem: NSStatusItem!
  private weak var searchPanelController: SearchPanelController?
  private var languageCancellable: AnyCancellable?

  init(searchPanelController: SearchPanelController) {
    self.searchPanelController = searchPanelController
    super.init()
    setupStatusBar()
    languageCancellable = LocalizationManager.shared.$language
      .dropFirst()
      .receive(on: DispatchQueue.main)
      .sink { [weak self] _ in
        self?.rebuildMenu()
      }
  }

  private func setupStatusBar() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

    if let button = statusItem.button {
      if let appIcon = NSApp.applicationIconImage {
        let size = NSSize(width: 18, height: 18)
        let icon = NSImage(size: size, flipped: false) { rect in
          appIcon.draw(in: rect)
          return true
        }
        icon.isTemplate = false
        button.image = icon
      } else {
        button.image = NSImage(systemSymbolName: "command", accessibilityDescription: "AlfredForMe")
        button.image?.size = NSSize(width: 18, height: 18)
      }
    }

    rebuildMenu()
  }

  private func rebuildMenu() {
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
