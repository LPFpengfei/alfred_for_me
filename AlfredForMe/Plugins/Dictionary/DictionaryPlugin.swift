import AppKit
import Foundation

// MARK: - Dictionary Plugin

final class DictionaryPlugin: SearchPlugin {
    let id = "com.alfredForMe.dictionary"
    let name = "Dictionary"
    let keyword: String? = "define"
    var isEnabled = true
    let priority = 60

    func canHandle(query: SearchQuery) -> Bool {
        if query.isKeywordTrigger, let kw = query.keyword {
            return kw.lowercased() == "define" || kw.lowercased() == "dict"
        }
        return false
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let l10n = LocalizationManager.shared
        guard let word = query.argument?.trimmingCharacters(in: .whitespaces), !word.isEmpty else {
            return [
                SearchResult(
                    id: "dict:placeholder",
                    title: l10n.t("plugin.dict.inputWord"),
                    subtitle: l10n.t("plugin.dict.defineHint"),
                    icon: NSImage(
                        systemSymbolName: "character.book.closed.fill",
                        accessibilityDescription: nil),
                    category: .dictionary,
                    relevanceScore: 0.5,
                    plugin: id,
                    actionable: false
                )
            ]
        }

        var results: [SearchResult] = []

        // Use DCSCopyTextDefinition for system dictionary
        if let definition = lookupDefinition(word: word) {
            let preview = String(definition.prefix(200))

            results.append(
                SearchResult(
                    id: "dict:\(word)",
                    title: word,
                    subtitle: preview,
                    icon: NSImage(
                        systemSymbolName: "character.book.closed.fill",
                        accessibilityDescription: nil),
                    category: .dictionary,
                    relevanceScore: 0.9,
                    plugin: id,
                    userData: [
                        "word": word,
                        "definition": definition,
                    ]
                ))
        }

        // Always offer to open in Dictionary app
        results.append(
            SearchResult(
                id: "dict:open:\(word)",
                title: "\(l10n.t("plugin.dict.viewIn")) \"\(word)\"",
                subtitle: l10n.t("plugin.dict.openApp"),
                icon: NSImage(systemSymbolName: "book.fill", accessibilityDescription: nil),
                category: .dictionary,
                relevanceScore: 0.7,
                plugin: id,
                userData: [
                    "word": word,
                    "action": "openDict",
                ]
            ))

        return results
    }

    func execute(result: SearchResult) async {
        guard let word = result.userData["word"] else { return }

        if result.userData["action"] == "openDict" {
            // Open in Dictionary app
            let url = URL(
                string:
                    "dict://\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)"
            )!
            NSWorkspace.shared.open(url)
        } else if let definition = result.userData["definition"] {
            // Copy definition
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(definition, forType: .string)
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let word = result.userData["word"] else { return [] }
        let l10n = LocalizationManager.shared

        return [
            ResultAction(title: l10n.t("action.openInDict"), shortcut: "⏎") {
                let url = URL(
                    string:
                        "dict://\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)"
                )!
                NSWorkspace.shared.open(url)
            },
            ResultAction(title: l10n.t("action.copyDefinition")) {
                if let definition = result.userData["definition"] {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(definition, forType: .string)
                }
            },
            ResultAction(title: l10n.t("action.copyWord")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(word, forType: .string)
            },
        ]
    }

    // MARK: - Dictionary Lookup

    private func lookupDefinition(word: String) -> String? {
        let nsWord = word as NSString
        let range = CFRangeMake(0, nsWord.length)

        guard let definition = DCSCopyTextDefinition(nil, nsWord as CFString, range) else {
            return nil
        }

        return definition.takeRetainedValue() as String
    }
}
