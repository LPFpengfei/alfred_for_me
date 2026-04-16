import AppKit
import Foundation

// MARK: - Terminal Plugin

final class TerminalPlugin: SearchPlugin {
    let id = "com.alfredForMe.terminal"
    let name = "Terminal"
    let keyword: String? = ">"
    var isEnabled = true
    let priority = 85

    func canHandle(query: SearchQuery) -> Bool {
        return query.raw.hasPrefix(">") || query.raw.hasPrefix("$")
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let l10n = LocalizationManager.shared
        var command = query.raw
        if command.hasPrefix(">") || command.hasPrefix("$") {
            command = String(command.dropFirst()).trimmingCharacters(in: .whitespaces)
        }

        guard !command.isEmpty else {
            return [
                SearchResult(
                    id: "terminal:placeholder",
                    title: l10n.t("plugin.terminal.inputCmd"),
                    subtitle: l10n.t("plugin.terminal.cmdHint"),
                    icon: NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil),
                    category: .terminal,
                    relevanceScore: 0.9,
                    plugin: id,
                    actionable: false
                )
            ]
        }

        let terminalApp = SettingsManager.shared.terminalApp

        return [
            SearchResult(
                id: "terminal:run:\(command)",
                title: "\(l10n.t("plugin.terminal.run")) \(command)",
                subtitle: l10n.t("plugin.terminal.runIn").replacingOccurrences(
                    of: "{app}", with: terminalApp),
                icon: NSImage(systemSymbolName: "terminal.fill", accessibilityDescription: nil),
                category: .terminal,
                relevanceScore: 0.95,
                plugin: id,
                userData: [
                    "command": command,
                    "action": "run",
                ]
            ),
            SearchResult(
                id: "terminal:copy:\(command)",
                title: "\(l10n.t("plugin.terminal.copyCmd")) \(command)",
                subtitle: l10n.t("plugin.terminal.copyToClip"),
                icon: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil),
                category: .terminal,
                relevanceScore: 0.8,
                plugin: id,
                userData: [
                    "command": command,
                    "action": "copy",
                ]
            ),
        ]
    }

    func execute(result: SearchResult) async {
        guard let command = result.userData["command"],
            let action = result.userData["action"]
        else { return }

        switch action {
        case "run":
            await MainActor.run {
                runInTerminal(command: command)
            }
        case "copy":
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(command, forType: .string)
        default:
            break
        }
    }

    func actions(for result: SearchResult) -> [ResultAction] {
        guard let command = result.userData["command"] else { return [] }
        let l10n = LocalizationManager.shared

        return [
            ResultAction(title: l10n.t("action.runInTerminal"), shortcut: "⏎") { [weak self] in
                self?.runInTerminal(command: command)
            },
            ResultAction(title: l10n.t("action.runInITerm")) { [weak self] in
                self?.runInITerm(command: command)
            },
            ResultAction(title: l10n.t("action.copyCommand")) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(command, forType: .string)
            },
        ]
    }

    // MARK: - Terminal Execution

    private func runInTerminal(command: String) {
        let terminalApp = SettingsManager.shared.terminalApp
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")

        switch terminalApp {
        case "iTerm", "iTerm2":
            runInITerm(command: command)
        default:
            let script = """
                    tell application "Terminal"
                        activate
                        do script "\(escapedCommand)"
                    end tell
                """
            runAppleScript(script)
        }
    }

    private func runInITerm(command: String) {
        let escapedCommand = command.replacingOccurrences(of: "\"", with: "\\\"")
        let script = """
                tell application "iTerm2"
                    activate
                    tell current window
                        create tab with default profile
                        tell current session
                            write text "\(escapedCommand)"
                        end tell
                    end tell
                end tell
            """
        runAppleScript(script)
    }

    private func runAppleScript(_ script: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let appleScript = NSAppleScript(source: script)
            var error: NSDictionary?
            appleScript?.executeAndReturnError(&error)
            if let error = error {
                print("AppleScript error: \(error)")
            }
        }
    }
}
