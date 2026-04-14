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

  func copyImageToClipboard(_ imageData: Data) {
    let pasteboard = NSPasteboard.general
    pasteboard.clearContents()
    if let image = NSImage(data: imageData) {
      pasteboard.writeObjects([image])
    }
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

  /// Stable fingerprint for image data (size + CRC-like prefix/suffix bytes)
  private func imageFingerprint(_ data: Data) -> String {
    let count = data.count
    guard count > 0 else { return "img_0" }
    // Use size + first 64 bytes + last 64 bytes for a stable fingerprint
    let headLen = min(64, count)
    let tailLen = min(64, count)
    let head = data.prefix(headLen)
    let tail = data.suffix(tailLen)
    let headHash = head.reduce(UInt64(0)) { ($0 &<< 1) ^ UInt64($1) }
    let tailHash = tail.reduce(UInt64(0)) { ($0 &<< 1) ^ UInt64($1) }
    return "img_\(count)_\(headHash)_\(tailHash)"
  }

  private func checkClipboard() {
    let pasteboard = NSPasteboard.general
    let currentCount = pasteboard.changeCount

    guard currentCount != lastChangeCount else { return }
    lastChangeCount = currentCount

    // Get active app info
    let frontApp = NSWorkspace.shared.frontmostApplication
    let appName = frontApp?.localizedName
    let bundleID = frontApp?.bundleIdentifier

    // Check for image first (TIFF is the canonical image type on macOS pasteboard)
    let imageTypes: [NSPasteboard.PasteboardType] = [.tiff, .png]
    if let imageType = imageTypes.first(where: { pasteboard.data(forType: $0) != nil }),
      let imageData = pasteboard.data(forType: imageType)
    {
      // Stable fingerprint for dedup (works across app restarts)
      let fingerprint = imageFingerprint(imageData)

      // Dedup: remove any existing item with same fingerprint
      history.removeAll { $0.content == fingerprint }

      let item = ClipboardItem(
        content: fingerprint,
        contentType: .image,
        appName: appName,
        appBundleID: bundleID,
        imageData: imageData
      )

      history.insert(item, at: 0)
      if history.count > maxHistorySize {
        history = Array(history.prefix(maxHistorySize))
      }
      saveHistory()
      return
    }

    guard let content = pasteboard.string(forType: .string), !content.isEmpty else { return }

    // Detect content type
    let contentType: ClipboardContentType
    if URL(string: content) != nil, content.hasPrefix("http") {
      contentType = .url
    } else if FileManager.default.fileExists(atPath: content) {
      contentType = .filePath
    } else {
      contentType = .text
    }

    // Dedup: remove ALL existing items with same content, keep only latest
    history.removeAll { $0.content == content }

    let item = ClipboardItem(
      content: content,
      contentType: contentType,
      appName: appName,
      appBundleID: bundleID
    )

    history.insert(item, at: 0)
    if history.count > maxHistorySize {
      history = Array(history.prefix(maxHistorySize))
    }
    saveHistory()
  }

  private func simulatePaste() {
    let source = CGEventSource(stateID: .hidSystemState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)  // V key
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
  }

  private func loadHistory() {
    if let data = UserDefaults.standard.data(forKey: storageKey),
      let items = try? JSONDecoder().decode([ClipboardItem].self, from: data)
    {
      // Dedup on load: keep only the first (most recent) occurrence of each content
      var seen = Set<String>()
      var deduped: [ClipboardItem] = []
      for item in items {
        if seen.insert(item.content).inserted {
          deduped.append(item)
        }
      }
      history = deduped
      if deduped.count != items.count {
        saveHistory()  // Persist the cleaned-up list
      }
    }
  }

  private func saveHistory() {
    if let data = try? JSONEncoder().encode(history) {
      UserDefaults.standard.set(data, forKey: storageKey)
    }
  }
}
