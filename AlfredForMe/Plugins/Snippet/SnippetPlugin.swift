import AppKit
import Foundation

// MARK: - Snippet Plugin

final class SnippetPlugin: SearchPlugin {
    let id = "com.alfredForMe.snippet"
    let name = "Snippets"
    let keyword: String? = "snip"
    var isEnabled = true
    let priority = 70

    private var snippets: [Snippet] {
        SettingsManager.shared.snippets
    }

    func canHandle(query: SearchQuery) -> Bool {
        if query.isKeywordTrigger, let kw = query.keyword {
            return kw.lowercased() == "snip" || kw.lowercased() == "snippet"
        }
        return false
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let searchTerm = query.argument?.lowercased() ?? ""

        let filtered: [Snippet]
        if searchTerm.isEmpty {
            filtered = snippets
        } else {
            filtered = snippets.filter {
                $0.name.lowercased().contains(searchTerm)
                    || $0.keyword.lowercased().contains(searchTerm)
                    || $0.content.lowercased().contains(searchTerm)
            }
        }

        return filtered.enumerated().map { index, snippet in
            let preview = snippet.content.prefix(80).replacingOccurrences(of: "\n", with: " ")

            return SearchResult(
                id: "snippet:\(snippet.id)",
                title: snippet.name,
                subtitle: ":\(snippet.keyword) → \(preview)",
                icon: NSImage(systemSymbolName: "text.snippet", accessibilityDescription: nil),
                category: .snippet,
                relevanceScore: 0.8 - Double(index) * 0.01,
                plugin: id,
                userData: [
                    "snippetId": snippet.id,
                    "content": snippet.content,
                    "keyword": snippet.keyword,
                ]
            )
        }
    }

    func execute(result: SearchResult) async {
        if let content = result.userData["content"] {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(content, forType: .string)

            // Auto-paste after a short delay
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 100_000_000)
                SnippetPlugin.simulatePaste()
            }
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let content = result.userData["content"] else { return [] }

        return [
            ResultAction(title: LocalizationManager.shared.t("action.pasteClip"), shortcut: "⏎") {
                [weak self] in
                Task { await self?.execute(result: result) }
            },
            ResultAction(title: LocalizationManager.shared.t("action.copyToClipboard")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(content, forType: .string)
            },
            ResultAction(title: LocalizationManager.shared.t("action.editSnippet")) {
                // Open settings to snippet editor
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
            },
        ]
    }

    private static func simulatePaste() {
        let source = CGEventSource(stateID: .hidSystemState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
