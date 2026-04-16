import AppKit
import Foundation

// MARK: - System Command Plugin

final class SystemCommandPlugin: SearchPlugin {
    let id = "com.alfredForMe.systemCommand"
    let name = "System Commands"
    var isEnabled = true
    let priority = 90

    private let commands: [SystemCommand] = [
        SystemCommand(
            nameKey: "sys.lockScreen",
            aliases: ["lock", "锁屏", "锁定屏幕", "lock screen"],
            icon: "lock.fill",
            descKey: "sys.lockScreenDesc",
            action: .lockScreen
        ),
        SystemCommand(
            nameKey: "sys.sleep",
            aliases: ["sleep", "休眠", "睡眠"],
            icon: "moon.fill",
            descKey: "sys.sleepDesc",
            action: .sleep
        ),
        SystemCommand(
            nameKey: "sys.restart",
            aliases: ["restart", "reboot", "重新启动", "重启"],
            icon: "arrow.clockwise.circle.fill",
            descKey: "sys.restartDesc",
            action: .restart
        ),
        SystemCommand(
            nameKey: "sys.shutdown",
            aliases: ["shutdown", "关闭", "关机", "power off"],
            icon: "power.circle.fill",
            descKey: "sys.shutdownDesc",
            action: .shutdown
        ),
        SystemCommand(
            nameKey: "sys.logout",
            aliases: ["logout", "log out", "登出", "注销"],
            icon: "rectangle.portrait.and.arrow.right.fill",
            descKey: "sys.logoutDesc",
            action: .logout
        ),
        SystemCommand(
            nameKey: "sys.emptyTrash",
            aliases: ["empty trash", "清空垃圾桶", "清空废纸篓"],
            icon: "trash.fill",
            descKey: "sys.emptyTrashDesc",
            action: .emptyTrash
        ),
        SystemCommand(
            nameKey: "sys.screensaver",
            aliases: ["screensaver", "screen saver", "屏保", "屏幕保护程序"],
            icon: "sparkles.tv.fill",
            descKey: "sys.screensaverDesc",
            action: .screensaver
        ),
        SystemCommand(
            nameKey: "sys.showDesktop",
            aliases: ["show desktop", "桌面", "显示桌面"],
            icon: "desktopcomputer",
            descKey: "sys.showDesktopDesc",
            action: .showDesktop
        ),
        SystemCommand(
            nameKey: "sys.clearClipboard",
            aliases: ["clear clipboard", "清空粘贴板", "清空剪贴板"],
            icon: "doc.on.clipboard",
            descKey: "sys.clearClipboardDesc",
            action: .clearClipboard
        ),
        SystemCommand(
            nameKey: "sys.toggleDarkMode",
            aliases: ["dark mode", "toggle dark", "暗色", "深色模式", "切换暗色模式"],
            icon: "circle.lefthalf.filled",
            descKey: "sys.toggleDarkModeDesc",
            action: .toggleDarkMode
        ),
        SystemCommand(
            nameKey: "sys.dnd",
            aliases: ["do not disturb", "dnd", "请勿打扰", "勿扰模式"],
            icon: "moon.circle.fill",
            descKey: "sys.dndDesc",
            action: .doNotDisturb
        ),
        SystemCommand(
            nameKey: "sys.quitAll",
            aliases: ["quit all", "关闭所有", "退出所有应用", "quit all apps"],
            icon: "xmark.circle.fill",
            descKey: "sys.quitAllDesc",
            action: .quitAllApps
        ),
        SystemCommand(
            nameKey: "sys.forceQuit",
            aliases: ["force quit", "强制关闭", "强制退出"],
            icon: "xmark.octagon.fill",
            descKey: "sys.forceQuitDesc",
            action: .forceQuit
        ),
        SystemCommand(
            nameKey: "sys.sysPrefs",
            aliases: ["system preferences", "settings", "系统设置", "系统偏好设置"],
            icon: "gearshape.fill",
            descKey: "sys.sysPrefsDesc",
            action: .systemPreferences
        ),
        SystemCommand(
            nameKey: "sys.ejectAll",
            aliases: ["eject", "eject all", "弹出", "弹出所有磁盘"],
            icon: "eject.fill",
            descKey: "sys.ejectAllDesc",
            action: .ejectAll
        ),
    ]

    func canHandle(query: SearchQuery) -> Bool {
        guard !query.raw.isEmpty && !query.isKeywordTrigger else { return false }
        // Only activate if the query actually matches at least one command
        let searchText = query.raw.lowercased()
        return commands.contains { cmd in
            cmd.name.lowercased().hasPrefix(searchText)
                || cmd.aliases.contains(where: { $0.lowercased().hasPrefix(searchText) })
                || searchText.count >= 2
                    && (cmd.name.lowercased().contains(searchText)
                        || cmd.aliases.contains(where: { $0.lowercased().contains(searchText) }))
        }
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let searchText = query.raw.lowercased()

        return commands.compactMap { cmd in
            let exactMatch =
                cmd.name.lowercased() == searchText
                || cmd.aliases.contains(where: { $0.lowercased() == searchText })
            let prefixMatch =
                cmd.name.lowercased().hasPrefix(searchText)
                || cmd.aliases.contains(where: { $0.lowercased().hasPrefix(searchText) })
            let containsMatch =
                searchText.count >= 2
                && (cmd.name.lowercased().contains(searchText)
                    || cmd.aliases.contains(where: { $0.lowercased().contains(searchText) }))

            guard exactMatch || prefixMatch || containsMatch else { return nil }

            let score = exactMatch ? 0.95 : (prefixMatch ? 0.8 : 0.6)

            return SearchResult(
                id: "system:\(cmd.action.rawValue)",
                title: cmd.name,
                subtitle: cmd.description,
                icon: NSImage(systemSymbolName: cmd.icon, accessibilityDescription: nil),
                category: .system,
                relevanceScore: score,
                plugin: id,
                userData: ["action": cmd.action.rawValue]
            )
        }
    }

    func execute(result: SearchResult) async {
        guard let actionStr = result.userData["action"],
            let action = SystemAction(rawValue: actionStr)
        else { return }

        await MainActor.run {
            performAction(action)
        }
    }

    // MARK: - Actions

    private func performAction(_ action: SystemAction) {
        switch action {
        case .lockScreen:
            runAppleScript(
                "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"
            )

        case .sleep:
            runAppleScript("tell application \"System Events\" to sleep")

        case .restart:
            runAppleScript("tell application \"System Events\" to restart")

        case .shutdown:
            runAppleScript("tell application \"System Events\" to shut down")

        case .logout:
            runAppleScript("tell application \"System Events\" to log out")

        case .emptyTrash:
            runAppleScript("tell application \"Finder\" to empty trash")

        case .screensaver:
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            task.arguments = ["-a", "ScreenSaverEngine"]
            try? task.run()

        case .showDesktop:
            runAppleScript(
                """
                    tell application "System Events"
                        key code 103
                    end tell
                """)

        case .clearClipboard:
            NSPasteboard.general.clearContents()

        case .toggleDarkMode:
            runAppleScript(
                """
                    tell application "System Events"
                        tell appearance preferences to set dark mode to not dark mode
                    end tell
                """)

        case .doNotDisturb:
            // macOS Monterey+ uses Focus
            runAppleScript(
                """
                    tell application "System Events"
                        tell process "ControlCenter"
                            click menu bar item "Focus" of menu bar 1
                        end tell
                    end tell
                """)

        case .quitAllApps:
            let runningApps = NSWorkspace.shared.runningApplications
            for app in runningApps {
                guard app.activationPolicy == .regular,
                    app.bundleIdentifier != Bundle.main.bundleIdentifier
                else { continue }
                app.terminate()
            }

        case .forceQuit:
            runAppleScript(
                """
                    tell application "System Events"
                        keystroke "." using {command down, option down}
                    end tell
                """)

        case .systemPreferences:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)

        case .ejectAll:
            runAppleScript(
                """
                    tell application "Finder"
                        eject (every disk whose ejectable is true)
                    end tell
                """)
        }
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

// MARK: - System Command Model

struct SystemCommand {
    let nameKey: String
    let aliases: [String]
    let icon: String
    let descKey: String
    let action: SystemAction

    var name: String { LocalizationManager.shared.t(nameKey) }
    var description: String { LocalizationManager.shared.t(descKey) }
}

enum SystemAction: String {
    case lockScreen
    case sleep
    case restart
    case shutdown
    case logout
    case emptyTrash
    case screensaver
    case showDesktop
    case clearClipboard
    case toggleDarkMode
    case doNotDisturb
    case quitAllApps
    case forceQuit
    case systemPreferences
    case ejectAll
}
