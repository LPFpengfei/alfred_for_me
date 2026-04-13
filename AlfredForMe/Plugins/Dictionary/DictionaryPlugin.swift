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
            return kw.lowercased() == "define" || kw.lowercased() == "dict" || kw.lowercased() == "d"
        }
        return false
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        guard let word = query.argument?.trimmingCharacters(in: .whitespaces), !word.isEmpty else {
            return [
                SearchResult(
                    id: "dict:placeholder",
                    title: "输入要查询的单词...",
                    subtitle: "define <单词>",
                    icon: NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: nil),
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

            results.append(SearchResult(
                id: "dict:\(word)",
                title: word,
                subtitle: preview,
                icon: NSImage(systemSymbolName: "character.book.closed.fill", accessibilityDescription: nil),
                category: .dictionary,
                relevanceScore: 0.9,
                plugin: id,
                userData: [
                    "word": word,
                    "definition": definition
                ]
            ))
        }

        // Always offer to open in Dictionary app
        results.append(SearchResult(
            id: "dict:open:\(word)",
            title: "在词典中查看 \"\(word)\"",
            subtitle: "打开 macOS 词典应用",
            icon: NSImage(systemSymbolName: "book.fill", accessibilityDescription: nil),
            category: .dictionary,
            relevanceScore: 0.7,
            plugin: id,
            userData: [
                "word": word,
                "action": "openDict"
            ]
        ))

        return results
    }

    func execute(result: SearchResult) async {
        guard let word = result.userData["word"] else { return }

        if result.userData["action"] == "openDict" {
            // Open in Dictionary app
            let url = URL(string: "dict://\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)")!
            NSWorkspace.shared.open(url)
        } else if let definition = result.userData["definition"] {
            // Copy definition
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(definition, forType: .string)
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let word = result.userData["word"] else { return [] }

        return [
            ResultAction(title: "在词典中打开", shortcut: "⏎") {
                let url = URL(string: "dict://\(word.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? word)")!
                NSWorkspace.shared.open(url)
            },
            ResultAction(title: "复制定义") {
                if let definition = result.userData["definition"] {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(definition, forType: .string)
                }
            },
            ResultAction(title: "复制单词") {
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
