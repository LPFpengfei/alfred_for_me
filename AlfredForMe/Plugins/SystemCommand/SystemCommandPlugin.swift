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
            name: "锁定屏幕",
            aliases: ["lock", "锁屏", "lock screen"],
            icon: "lock.fill",
            description: "锁定 Mac 屏幕",
            action: .lockScreen
        ),
        SystemCommand(
            name: "睡眠",
            aliases: ["sleep", "休眠"],
            icon: "moon.fill",
            description: "使 Mac 进入睡眠模式",
            action: .sleep
        ),
        SystemCommand(
            name: "重启",
            aliases: ["restart", "reboot", "重新启动"],
            icon: "arrow.clockwise.circle.fill",
            description: "重启 Mac",
            action: .restart
        ),
        SystemCommand(
            name: "关机",
            aliases: ["shutdown", "关闭", "power off"],
            icon: "power.circle.fill",
            description: "关闭 Mac",
            action: .shutdown
        ),
        SystemCommand(
            name: "注销",
            aliases: ["logout", "log out", "登出"],
            icon: "rectangle.portrait.and.arrow.right.fill",
            description: "注销当前用户",
            action: .logout
        ),
        SystemCommand(
            name: "清空废纸篓",
            aliases: ["empty trash", "清空垃圾桶"],
            icon: "trash.fill",
            description: "永久删除废纸篓中的所有文件",
            action: .emptyTrash
        ),
        SystemCommand(
            name: "屏幕保护程序",
            aliases: ["screensaver", "screen saver", "屏保"],
            icon: "sparkles.tv.fill",
            description: "启动屏幕保护程序",
            action: .screensaver
        ),
        SystemCommand(
            name: "显示桌面",
            aliases: ["show desktop", "桌面"],
            icon: "desktopcomputer",
            description: "显示桌面",
            action: .showDesktop
        ),
        SystemCommand(
            name: "清空剪贴板",
            aliases: ["clear clipboard", "清空粘贴板"],
            icon: "doc.on.clipboard",
            description: "清空系统剪贴板内容",
            action: .clearClipboard
        ),
        SystemCommand(
            name: "切换暗色模式",
            aliases: ["dark mode", "toggle dark", "暗色", "深色模式"],
            icon: "circle.lefthalf.filled",
            description: "切换系统暗色/亮色模式",
            action: .toggleDarkMode
        ),
        SystemCommand(
            name: "勿扰模式",
            aliases: ["do not disturb", "dnd", "请勿打扰"],
            icon: "moon.circle.fill",
            description: "切换勿扰模式",
            action: .doNotDisturb
        ),
        SystemCommand(
            name: "退出所有应用",
            aliases: ["quit all", "关闭所有", "quit all apps"],
            icon: "xmark.circle.fill",
            description: "退出所有正在运行的应用",
            action: .quitAllApps
        ),
        SystemCommand(
            name: "强制退出",
            aliases: ["force quit", "强制关闭"],
            icon: "xmark.octagon.fill",
            description: "打开强制退出窗口",
            action: .forceQuit
        ),
        SystemCommand(
            name: "系统偏好设置",
            aliases: ["system preferences", "settings", "系统设置"],
            icon: "gearshape.fill",
            description: "打开系统设置",
            action: .systemPreferences
        ),
        SystemCommand(
            name: "弹出所有磁盘",
            aliases: ["eject", "eject all", "弹出"],
            icon: "eject.fill",
            description: "弹出所有可弹出的磁盘",
            action: .ejectAll
        ),
    ]

    func canHandle(query: SearchQuery) -> Bool {
        !query.raw.isEmpty && !query.isKeywordTrigger
    }

    func search(query: SearchQuery) async -> [SearchResult] {
        let searchText = query.raw.lowercased()

        return commands.compactMap { cmd in
            let matches = cmd.name.lowercased().contains(searchText) ||
                cmd.aliases.contains(where: { $0.lowercased().contains(searchText) })

            guard matches else { return nil }

            let exactMatch = cmd.name.lowercased() == searchText || cmd.aliases.contains(where: { $0.lowercased() == searchText })
            let score = exactMatch ? 0.95 : 0.7

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
              let action = SystemAction(rawValue: actionStr) else { return }

        await MainActor.run {
            performAction(action)
        }
    }

    // MARK: - Actions

    private func performAction(_ action: SystemAction) {
        switch action {
        case .lockScreen:
            runAppleScript("tell application \"System Events\" to keystroke \"q\" using {command down, control down}")

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
            runAppleScript("""
                tell application "System Events"
                    key code 103
                end tell
            """)

        case .clearClipboard:
            NSPasteboard.general.clearContents()

        case .toggleDarkMode:
            runAppleScript("""
                tell application "System Events"
                    tell appearance preferences to set dark mode to not dark mode
                end tell
            """)

        case .doNotDisturb:
            // macOS Monterey+ uses Focus
            runAppleScript("""
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
                      app.bundleIdentifier != Bundle.main.bundleIdentifier else { continue }
                app.terminate()
            }

        case .forceQuit:
            runAppleScript("""
                tell application "System Events"
                    keystroke "." using {command down, option down}
                end tell
            """)

        case .systemPreferences:
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:")!)

        case .ejectAll:
            runAppleScript("""
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
    let name: String
    let aliases: [String]
    let icon: String
    let description: String
    let action: SystemAction
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
