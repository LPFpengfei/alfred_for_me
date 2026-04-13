import AppKit
import Combine

// MARK: - Clipboard Manager

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published private(set) var history: [ClipboardItem] = []

    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private let maxHistorySize = 1000
    private let storageKey = "ClipboardHistory"

    private init() {
        loadHistory()
    }

    func startMonitoring() {
        lastChangeCount = NSPasteboard.general.changeCount
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }

    func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }

    func copyToClipboard(_ content: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)
    }

    func clearHistory() {
        history.removeAll()
        saveHistory()
    }

    func remove(item: ClipboardItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    func pasteItem(_ item: ClipboardItem) {
        copyToClipboard(item.content)
        // Simulate Cmd+V paste
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.simulatePaste()
        }
    }

    // MARK: - Private

    private func checkClipboard() {
        let pasteboard = NSPasteboard.general
        let currentCount = pasteboard.changeCount

        guard currentCount != lastChangeCount else { return }
        lastChangeCount = currentCount

        guard let content = pasteboard.string(forType: .string), !content.isEmpty else { return }

        // Avoid duplicates for the last item
        if let last = history.first, last.content == content { return }

        // Detect content type
        let contentType: ClipboardContentType
        if let _ = URL(string: content), content.hasPrefix("http") {
            contentType = .url
        } else if FileManager.default.fileExists(atPath: content) {
            contentType = .filePath
        } else {
            contentType = .text
        }

        // Get active app info
        let frontApp = NSWorkspace.shared.frontmostApplication
        let appName = frontApp?.localizedName
        let bundleID = frontApp?.bundleIdentifier

        let item = ClipboardItem(
            content: content,
            contentType: contentType,
            appName: appName,
            appBundleID: bundleID
        )

        DispatchQueue.main.async {
            self.history.insert(item, at: 0)
            if self.history.count > self.maxHistorySize {
                self.history = Array(self.history.prefix(self.maxHistorySize))
            }
            self.saveHistory()
        }
    }

    private func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true) // V key
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }

    private func loadHistory() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let items = try? JSONDecoder().decode([ClipboardItem].self, from: data) {
            history = items
        }
    }

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
