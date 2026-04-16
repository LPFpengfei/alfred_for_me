import Combine
import Foundation
import SwiftUI

// MARK: - Language

enum AppLanguage: String, CaseIterable, Codable {
  case zhHans = "zh-Hans"
  case en = "en"

  var displayName: String {
    switch self {
    case .zhHans: return "中文"
    case .en: return "English"
    }
  }
}

// MARK: - Localization Manager

final class LocalizationManager: ObservableObject {
  static let shared = LocalizationManager()

  @Published var language: AppLanguage {
    didSet {
      UserDefaults.standard.set(language.rawValue, forKey: "appLanguage")
    }
  }

  private init() {
    let saved = UserDefaults.standard.string(forKey: "appLanguage") ?? "zh-Hans"
    self.language = AppLanguage(rawValue: saved) ?? .zhHans
  }

  func t(_ key: String) -> String {
    return L10n.string(key, language: language)
  }
}

// MARK: - Localization Keys & Strings

struct L10n {
  private static let strings: [String: [AppLanguage: String]] = [
    // MARK: - General
    "app.name": [.zhHans: "AlfredForMe", .en: "AlfredForMe"],
    "search.placeholder": [.zhHans: "搜索...", .en: "Search..."],
    "action.open": [.zhHans: "打开", .en: "Open"],
    "action.copy": [.zhHans: "复制", .en: "Copy"],
    "action.paste": [.zhHans: "粘贴", .en: "Paste"],
    "action.delete": [.zhHans: "删除", .en: "Delete"],
    "action.cancel": [.zhHans: "取消", .en: "Cancel"],
    "action.add": [.zhHans: "添加", .en: "Add"],
    "action.save": [.zhHans: "保存", .en: "Save"],
    "action.edit": [.zhHans: "编辑", .en: "Edit"],
    "action.confirm": [.zhHans: "确认", .en: "Confirm"],
    "label.default": [.zhHans: "默认", .en: "Default"],

    // MARK: - Status Bar
    "statusbar.openSearch": [.zhHans: "打开搜索", .en: "Open Search"],
    "statusbar.preferences": [.zhHans: "偏好设置...", .en: "Preferences..."],
    "statusbar.about": [.zhHans: "关于 AlfredForMe", .en: "About AlfredForMe"],
    "statusbar.quit": [.zhHans: "退出", .en: "Quit"],

    // MARK: - Settings Tabs
    "settings.general": [.zhHans: "通用", .en: "General"],
    "settings.appearance": [.zhHans: "外观", .en: "Appearance"],
    "settings.search": [.zhHans: "搜索", .en: "Search"],
    "settings.webSearch": [.zhHans: "Web 搜索", .en: "Web Search"],
    "settings.plugins": [.zhHans: "插件", .en: "Plugins"],
    "settings.clipboard": [.zhHans: "剪贴板", .en: "Clipboard"],
    "settings.snippets": [.zhHans: "代码片段", .en: "Snippets"],
    "settings.workflows": [.zhHans: "工作流", .en: "Workflows"],
    "settings.terminal": [.zhHans: "终端", .en: "Terminal"],
    "settings.ai": [.zhHans: "AI 对话", .en: "AI Chat"],
    "settings.advanced": [.zhHans: "高级", .en: "Advanced"],

    // MARK: - General Settings
    "general.hotkey": [.zhHans: "快捷键", .en: "Hotkey"],
    "general.globalHotkey": [.zhHans: "全局唤醒快捷键:", .en: "Global Activation Hotkey:"],
    "general.clickToModify": [.zhHans: "点击修改", .en: "Click to modify"],
    "general.startup": [.zhHans: "启动", .en: "Startup"],
    "general.launchAtLogin": [.zhHans: "开机自启动", .en: "Launch at Login"],
    "general.results": [.zhHans: "结果", .en: "Results"],
    "general.maxResults": [.zhHans: "最大显示结果数:", .en: "Max Visible Results:"],
    "general.language": [.zhHans: "语言", .en: "Language"],
    "general.interfaceLanguage": [.zhHans: "界面语言:", .en: "Interface Language:"],

    // MARK: - Appearance
    "appearance.theme": [.zhHans: "主题", .en: "Theme"],
    "appearance.font": [.zhHans: "字体", .en: "Font"],
    "appearance.searchFontSize": [.zhHans: "搜索框字体大小:", .en: "Search Bar Font Size:"],
    "appearance.iconSize": [.zhHans: "图标大小:", .en: "Icon Size:"],
    "appearance.mode": [.zhHans: "外观模式", .en: "Appearance Mode"],
    "appearance.label": [.zhHans: "外观", .en: "Appearance"],
    "appearance.light": [.zhHans: "浅色", .en: "Light"],
    "appearance.dark": [.zhHans: "深色", .en: "Dark"],
    "appearance.system": [.zhHans: "跟随系统", .en: "Follow System"],

    // MARK: - Search
    "search.options": [.zhHans: "搜索选项", .en: "Search Options"],
    "search.fuzzyMatching": [.zhHans: "模糊匹配", .en: "Fuzzy Matching"],
    "search.scope": [.zhHans: "搜索范围", .en: "Search Scope"],
    "search.addPath": [.zhHans: "添加路径...", .en: "Add path..."],

    // MARK: - Web Search
    "webSearch.addEngine": [.zhHans: "添加搜索引擎", .en: "Add Search Engine"],
    "webSearch.defaultEngine": [.zhHans: "默认搜索引擎:", .en: "Default Search Engine:"],
    "webSearch.keyword": [.zhHans: "关键词:", .en: "Keyword:"],
    "webSearch.name": [.zhHans: "名称:", .en: "Name:"],
    "webSearch.urlTemplate": [
      .zhHans: "URL 模板 ({query} 为搜索词):", .en: "URL Template ({query} for search term):",
    ],

    // MARK: - Plugins
    "plugins.priority": [.zhHans: "优先级:", .en: "Priority:"],

    // MARK: - Clipboard
    "clipboard.enable": [.zhHans: "启用剪贴板历史", .en: "Enable Clipboard History"],
    "clipboard.maxItems": [.zhHans: "保存条目数:", .en: "Max Items:"],
    "clipboard.clearAll": [.zhHans: "清空剪贴板历史", .en: "Clear Clipboard History"],
    "clipboard.history": [.zhHans: "剪贴板历史", .en: "Clipboard History"],
    "clipboard.operations": [.zhHans: "操作", .en: "Actions"],
    "clipboard.searchPlaceholder": [.zhHans: "搜索剪贴板历史...", .en: "Search clipboard history..."],
    "clipboard.empty": [.zhHans: "暂无剪贴板记录", .en: "No clipboard history"],
    "clipboard.imageItem": [.zhHans: "[图片]", .en: "[Image]"],
    "clipboard.preview": [.zhHans: "内容预览", .en: "Preview"],
    "clipboard.characters": [.zhHans: "个字符", .en: "characters"],
    "clipboard.enterToPaste": [.zhHans: "按 ⏎ 粘贴", .en: "Press ⏎ to paste"],
    "clipboard.selectToPreview": [.zhHans: "选择条目以预览内容", .en: "Select an item to preview"],
    "clipboard.navigate": [.zhHans: "导航", .en: "Navigate"],
    "clipboard.paste": [.zhHans: "粘贴", .en: "Paste"],
    "clipboard.page": [.zhHans: "翻页", .en: "Page"],
    "clipboard.close": [.zhHans: "关闭", .en: "Close"],
    "clipboard.items": [.zhHans: "条记录", .en: "items"],

    // MARK: - Snippets
    "snippet.add": [.zhHans: "添加代码片段", .en: "Add Snippet"],
    "snippet.autoExpand": [.zhHans: "自动展开", .en: "Auto Expand"],
    "snippet.content": [.zhHans: "内容:", .en: "Content:"],

    // MARK: - Workflows
    "workflow.empty": [.zhHans: "暂无工作流", .en: "No Workflows"],
    "workflow.emptyDesc": [
      .zhHans: "工作流可以将多个操作串联自动化执行", .en: "Workflows automate sequences of actions",
    ],
    "workflow.import": [.zhHans: "导入工作流...", .en: "Import Workflow..."],
    "workflow.create": [.zhHans: "新建工作流", .en: "New Workflow"],
    "workflow.steps": [.zhHans: "步", .en: "steps"],

    // MARK: - Terminal
    "terminal.app": [.zhHans: "终端应用", .en: "Terminal App"],
    "terminal.terminal": [.zhHans: "终端:", .en: "Terminal:"],
    "terminal.shell": [.zhHans: "Shell", .en: "Shell"],
    "terminal.shellPath": [.zhHans: "Shell 路径:", .en: "Shell Path:"],
    "terminal.commonShells": [
      .zhHans: "常用: /bin/zsh, /bin/bash, /usr/local/bin/fish",
      .en: "Common: /bin/zsh, /bin/bash, /usr/local/bin/fish",
    ],

    // MARK: - Advanced
    "advanced.options": [.zhHans: "高级选项", .en: "Advanced Options"],
    "advanced.version": [.zhHans: "版本:", .en: "Version:"],
    "advanced.resetAll": [.zhHans: "重置所有设置", .en: "Reset All Settings"],
    "advanced.data": [.zhHans: "数据", .en: "Data"],
    "advanced.export": [.zhHans: "导出设置...", .en: "Export Settings..."],
    "advanced.import": [.zhHans: "导入设置...", .en: "Import Settings..."],
    "advanced.about": [.zhHans: "关于", .en: "About"],
    "advanced.aboutDesc": [
      .zhHans: "AlfredForMe - 个人定制化启动器", .en: "AlfredForMe - Personal Customized Launcher",
    ],

    // MARK: - Result Actions
    "action.openInFinder": [.zhHans: "在 Finder 中显示", .en: "Reveal in Finder"],
    "action.copyPath": [.zhHans: "复制路径", .en: "Copy Path"],
    "action.copyFileName": [.zhHans: "复制文件名", .en: "Copy File Name"],
    "action.openInTerminal": [.zhHans: "在终端中打开", .en: "Open in Terminal"],
    "action.moveToTrash": [.zhHans: "移到废纸篓", .en: "Move to Trash"],
    "action.searchInBrowser": [.zhHans: "在浏览器中搜索", .en: "Search in Browser"],
    "action.copyLink": [.zhHans: "复制搜索链接", .en: "Copy Search Link"],
    "action.copyResult": [.zhHans: "复制结果", .en: "Copy Result"],
    "action.copyAsInt": [.zhHans: "复制为整数", .en: "Copy as Integer"],
    "action.pasteClip": [.zhHans: "粘贴", .en: "Paste"],
    "action.copyToClipboard": [.zhHans: "复制到剪贴板", .en: "Copy to Clipboard"],
    "action.deleteEntry": [.zhHans: "删除此条目", .en: "Delete This Entry"],
    "action.clearAllHistory": [.zhHans: "清空所有历史", .en: "Clear All History"],
    "action.editSnippet": [.zhHans: "编辑片段", .en: "Edit Snippet"],
    "action.openInDict": [.zhHans: "在词典中打开", .en: "Open in Dictionary"],
    "action.copyDefinition": [.zhHans: "复制定义", .en: "Copy Definition"],
    "action.copyWord": [.zhHans: "复制单词", .en: "Copy Word"],
    "action.runInTerminal": [.zhHans: "在终端中执行", .en: "Run in Terminal"],
    "action.runInITerm": [.zhHans: "在 iTerm 中执行", .en: "Run in iTerm"],
    "action.copyCommand": [.zhHans: "复制命令", .en: "Copy Command"],
    "action.openInBrowser": [.zhHans: "在浏览器中打开", .en: "Open in Browser"],
    "action.copyTitle": [.zhHans: "复制标题", .en: "Copy Title"],

    // MARK: - System Commands
    "sys.lockScreen": [.zhHans: "锁定屏幕", .en: "Lock Screen"],
    "sys.lockScreenDesc": [.zhHans: "锁定 Mac 屏幕", .en: "Lock Mac screen"],
    "sys.sleep": [.zhHans: "睡眠", .en: "Sleep"],
    "sys.sleepDesc": [.zhHans: "使 Mac 进入睡眠模式", .en: "Put Mac to sleep"],
    "sys.restart": [.zhHans: "重启", .en: "Restart"],
    "sys.restartDesc": [.zhHans: "重启 Mac", .en: "Restart Mac"],
    "sys.shutdown": [.zhHans: "关机", .en: "Shutdown"],
    "sys.shutdownDesc": [.zhHans: "关闭 Mac", .en: "Shut down Mac"],
    "sys.logout": [.zhHans: "注销", .en: "Log Out"],
    "sys.logoutDesc": [.zhHans: "注销当前用户", .en: "Log out current user"],
    "sys.emptyTrash": [.zhHans: "清空废纸篓", .en: "Empty Trash"],
    "sys.emptyTrashDesc": [.zhHans: "永久删除废纸篓中的所有文件", .en: "Permanently delete all files in Trash"],
    "sys.screensaver": [.zhHans: "屏幕保护程序", .en: "Screen Saver"],
    "sys.screensaverDesc": [.zhHans: "启动屏幕保护程序", .en: "Start screen saver"],
    "sys.showDesktop": [.zhHans: "显示桌面", .en: "Show Desktop"],
    "sys.showDesktopDesc": [.zhHans: "显示桌面", .en: "Show desktop"],
    "sys.clearClipboard": [.zhHans: "清空剪贴板", .en: "Clear Clipboard"],
    "sys.clearClipboardDesc": [.zhHans: "清空系统剪贴板内容", .en: "Clear system clipboard contents"],
    "sys.toggleDarkMode": [.zhHans: "切换暗色模式", .en: "Toggle Dark Mode"],
    "sys.toggleDarkModeDesc": [.zhHans: "切换系统暗色/亮色模式", .en: "Toggle system dark/light mode"],
    "sys.dnd": [.zhHans: "勿扰模式", .en: "Do Not Disturb"],
    "sys.dndDesc": [.zhHans: "切换勿扰模式", .en: "Toggle Do Not Disturb"],
    "sys.quitAll": [.zhHans: "退出所有应用", .en: "Quit All Apps"],
    "sys.quitAllDesc": [.zhHans: "退出所有正在运行的应用", .en: "Quit all running applications"],
    "sys.forceQuit": [.zhHans: "强制退出", .en: "Force Quit"],
    "sys.forceQuitDesc": [.zhHans: "打开强制退出窗口", .en: "Open Force Quit window"],
    "sys.sysPrefs": [.zhHans: "系统偏好设置", .en: "System Preferences"],
    "sys.sysPrefsDesc": [.zhHans: "打开系统设置", .en: "Open System Settings"],
    "sys.ejectAll": [.zhHans: "弹出所有磁盘", .en: "Eject All Disks"],
    "sys.ejectAllDesc": [.zhHans: "弹出所有可弹出的磁盘", .en: "Eject all removable disks"],

    // MARK: - Plugin Labels
    "plugin.terminal.inputCmd": [.zhHans: "输入要执行的命令...", .en: "Enter command to run..."],
    "plugin.terminal.runIn": [.zhHans: "在 {app} 中执行", .en: "Run in {app}"],
    "plugin.terminal.run": [.zhHans: "运行:", .en: "Run:"],
    "plugin.terminal.copyCmd": [.zhHans: "复制命令:", .en: "Copy command:"],
    "plugin.terminal.copyToClip": [.zhHans: "复制到剪贴板", .en: "Copy to clipboard"],
    "plugin.dict.inputWord": [.zhHans: "输入要查询的单词...", .en: "Enter a word to look up..."],
    "plugin.dict.viewIn": [.zhHans: "在词典中查看", .en: "View in Dictionary"],
    "plugin.dict.openApp": [.zhHans: "打开 macOS 词典应用", .en: "Open macOS Dictionary app"],
    "plugin.webSearch.search": [.zhHans: "搜索", .en: "Search"],
    "plugin.webSearch.inputKeyword": [.zhHans: "输入搜索关键词", .en: "Enter search keyword"],
    "plugin.webSearch.openUrl": [.zhHans: "打开", .en: "Open"],
    "plugin.webSearch.openInBrowser": [.zhHans: "在浏览器中打开", .en: "Open in browser"],
    "plugin.clipboard.justNow": [.zhHans: "刚刚", .en: "Just now"],
    "plugin.clipboard.minutesAgo": [.zhHans: "分钟前", .en: "minutes ago"],
    "plugin.clipboard.hoursAgo": [.zhHans: "小时前", .en: "hours ago"],
    "plugin.clipboard.daysAgo": [.zhHans: "天前", .en: "days ago"],
    "plugin.workflow.run": [.zhHans: "运行:", .en: "Run:"],

    // MARK: - AI Chat
    "ai.keyword": [.zhHans: "ai", .en: "ai"],
    "ai.askPlaceholder": [.zhHans: "输入你的问题...", .en: "Enter your question..."],
    "ai.inputPlaceholder": [.zhHans: "输入消息，Enter 发送", .en: "Type a message, Enter to send"],
    "ai.thinking": [.zhHans: "正在思考...", .en: "Thinking..."],
    "ai.askAI": [.zhHans: "问 AI:", .en: "Ask AI:"],
    "ai.chat": [.zhHans: "AI 对话", .en: "AI Chat"],
    "ai.sendMessage": [.zhHans: "发送", .en: "Send"],
    "ai.clearChat": [.zhHans: "清空对话", .en: "Clear Chat"],
    "ai.settings": [.zhHans: "AI 设置", .en: "AI Settings"],
    "ai.provider": [.zhHans: "服务商", .en: "Provider"],
    "ai.model": [.zhHans: "模型", .en: "Model"],
    "ai.apiKey": [.zhHans: "API Key", .en: "API Key"],
    "ai.apiEndpoint": [.zhHans: "API 端点", .en: "API Endpoint"],
    "ai.temperature": [.zhHans: "温度", .en: "Temperature"],
    "ai.maxTokens": [.zhHans: "最大 Token 数", .en: "Max Tokens"],
    "ai.systemPrompt": [.zhHans: "系统提示词", .en: "System Prompt"],
    "ai.systemPromptPlaceholder": [.zhHans: "输入自定义系统提示词...", .en: "Enter custom system prompt..."],
    "ai.customModels": [.zhHans: "自定义模型", .en: "Custom Models"],
    "ai.addModel": [.zhHans: "添加模型", .en: "Add Model"],
    "ai.modelName": [.zhHans: "模型名称:", .en: "Model Name:"],
    "ai.modelId": [.zhHans: "模型 ID:", .en: "Model ID:"],
    "ai.streamResponse": [.zhHans: "流式响应", .en: "Stream Response"],
    "ai.copyResponse": [.zhHans: "复制回复", .en: "Copy Response"],
    "ai.retry": [.zhHans: "重试", .en: "Retry"],
    "ai.stop": [.zhHans: "停止", .en: "Stop"],
    "ai.providers.openai": [.zhHans: "OpenAI", .en: "OpenAI"],
    "ai.providers.anthropic": [.zhHans: "Anthropic (Claude)", .en: "Anthropic (Claude)"],
    "ai.providers.google": [.zhHans: "Google (Gemini)", .en: "Google (Gemini)"],
    "ai.providers.ollama": [.zhHans: "Ollama (本地)", .en: "Ollama (Local)"],
    "ai.providers.custom": [.zhHans: "自定义 (OpenAI 兼容)", .en: "Custom (OpenAI Compatible)"],
    "ai.providerConfig": [.zhHans: "提供商配置", .en: "Provider Configuration"],
    "ai.chatOptions": [.zhHans: "对话选项", .en: "Chat Options"],
    "ai.testConnection": [.zhHans: "测试连接", .en: "Test Connection"],
    "ai.connectionSuccess": [.zhHans: "连接成功!", .en: "Connection successful!"],
    "ai.connectionFailed": [.zhHans: "连接失败:", .en: "Connection failed:"],
    "ai.noApiKey": [.zhHans: "请先配置 API Key", .en: "Please configure API Key first"],
    "ai.history": [.zhHans: "历史记录", .en: "History"],
    "ai.new_session": [.zhHans: "新建对话", .en: "New Session"],
    "ai.no_history": [.zhHans: "暂无历史记录", .en: "No history yet"],
    "ai.welcome": [.zhHans: "你好，有什么可以帮你的？", .en: "Hello, how can I help you?"],
    "ai.welcome_hint": [
      .zhHans: "输入消息开始对话，使用 ⌘Enter 发送", .en: "Type a message to start, press ⌘Enter to send",
    ],
    "ai.send": [.zhHans: "发送", .en: "Send"],
    "ai.clear": [.zhHans: "清空", .en: "Clear"],
    "ai.open_chat": [.zhHans: "打开 AI 对话", .en: "Open AI Chat"],
    "ai.open_chat_hint": [.zhHans: "打开独立的 AI 对话窗口", .en: "Open standalone AI chat window"],
    "ai.new_session_hint": [.zhHans: "开始一个新的对话", .en: "Start a new conversation"],
    "ai.ask": [.zhHans: "问 AI", .en: "Ask AI"],
    "ai.chat_with": [.zhHans: "在对话中询问", .en: "Chat about"],
    "ai.open_in_chat": [.zhHans: "打开对话窗口并发送", .en: "Open in chat window"],
    "ai.topP": [.zhHans: "Top P", .en: "Top P"],
    "ai.timeout": [.zhHans: "超时(秒)", .en: "Timeout(s)"],
    "ai.customEndpoint": [.zhHans: "自定义端点", .en: "Custom Endpoint"],
    "ai.selectModel": [.zhHans: "选择模型", .en: "Select Model"],
    "ai.noProviderHint": [
      .zhHans: "请先在设置中添加 AI 服务商", .en: "Please add an AI provider in settings first",
    ],
    "ai.startChat": [.zhHans: "开始对话", .en: "Start Chat"],
    "ai.startChatHint": [
      .zhHans: "输入消息开始与 AI 对话，可随时切换模型",
      .en: "Type a message to chat with AI, switch models anytime",
    ],
    "ai.addAttachment": [.zhHans: "添加附件", .en: "Add Attachment"],
    "ai.providerList": [.zhHans: "AI 服务商", .en: "AI Providers"],
    "ai.noProviderConfigured": [.zhHans: "尚未配置 AI 服务商", .en: "No AI provider configured"],
    "ai.addProviderHint": [
      .zhHans: "点击下方添加按钮开始配置", .en: "Click the add button below to configure",
    ],
    "ai.addProvider": [.zhHans: "添加服务商", .en: "Add Provider"],
    "ai.quickAdd": [.zhHans: "快速添加", .en: "Quick Add"],
    "ai.currentlyUsing": [.zhHans: "当前使用", .en: "Currently Using"],
    "ai.pleaseSelect": [.zhHans: "请选择", .en: "Please select"],
    "ai.editProvider": [.zhHans: "编辑服务商", .en: "Edit Provider"],
    "ai.providerName": [.zhHans: "名称", .en: "Name"],
    "ai.protocol": [.zhHans: "协议", .en: "Protocol"],
    "ai.endpoint": [.zhHans: "端点", .en: "Endpoint"],
    "ai.modelList": [.zhHans: "模型列表", .en: "Model List"],
    "ai.modelCount": [.zhHans: "个模型", .en: "models"],

    // MARK: - Menu
    "menu.about": [.zhHans: "关于 AlfredForMe", .en: "About AlfredForMe"],
    "menu.quit": [.zhHans: "退出 AlfredForMe", .en: "Quit AlfredForMe"],
    "menu.edit": [.zhHans: "编辑", .en: "Edit"],
    "menu.undo": [.zhHans: "撤销", .en: "Undo"],
    "menu.redo": [.zhHans: "重做", .en: "Redo"],
    "menu.cut": [.zhHans: "剪切", .en: "Cut"],
    "menu.copy": [.zhHans: "复制", .en: "Copy"],
    "menu.paste": [.zhHans: "粘贴", .en: "Paste"],
    "menu.selectAll": [.zhHans: "全选", .en: "Select All"],
    "menu.settings": [.zhHans: "AlfredForMe 设置", .en: "AlfredForMe Settings"],

    // MARK: - Clipboard Hotkey
    "clipboard.hotkey": [.zhHans: "剪贴板快捷键", .en: "Clipboard Hotkey"],
    "clipboard.hotkeyDesc": [.zhHans: "快速打开剪贴板历史:", .en: "Quick open clipboard history:"],

    // MARK: - Settings Sections
    "settings.section.basic": [.zhHans: "基本", .en: "Basic"],
    "settings.section.search": [.zhHans: "搜索", .en: "Search"],
    "settings.section.features": [.zhHans: "功能", .en: "Features"],
    "settings.section.other": [.zhHans: "其他", .en: "Other"],

    // MARK: - General Settings (extra)
    "general.clipboardHotkey": [.zhHans: "剪贴板快捷键", .en: "Clipboard Hotkey"],
    "general.aiChatHotkey": [.zhHans: "AI 对话快捷键", .en: "AI Chat Hotkey"],
    "general.pressHotkey": [.zhHans: "按下快捷键...", .en: "Press hotkey..."],

    // MARK: - Appearance (extra)
    "appearance.fontAndIcon": [.zhHans: "字体与图标", .en: "Font & Icon"],

    // MARK: - Search (extra)
    "search.noScope": [.zhHans: "暂无搜索范围", .en: "No search scope"],
    "search.appFilesWeb": [
      .zhHans: "搜索应用、文件、网页...", .en: "Search apps, files, web...",
    ],

    // MARK: - Web Search (extra)
    "webSearch.engine": [.zhHans: "搜索引擎", .en: "Search Engine"],
    "webSearch.nameLabel": [.zhHans: "名称", .en: "Name"],
    "webSearch.keywordLabel": [.zhHans: "关键词", .en: "Keyword"],
    "webSearch.urlTemplateLabel": [.zhHans: "URL 模板", .en: "URL Template"],
    "webSearch.urlTemplateHint": [
      .zhHans: "使用 {query} 作为搜索词占位符",
      .en: "Use {query} as search term placeholder",
    ],

    // MARK: - Plugins (extra)
    "plugins.installed": [.zhHans: "已安装插件", .en: "Installed Plugins"],
    "plugins.priorityLabel": [.zhHans: "优先级", .en: "Priority"],

    // MARK: - Snippets (extra)
    "snippet.empty": [.zhHans: "暂无代码片段", .en: "No snippets"],
    "snippet.nameLabel": [.zhHans: "名称", .en: "Name"],
    "snippet.namePlaceholder": [.zhHans: "片段名称", .en: "Snippet name"],
    "snippet.keywordLabel": [.zhHans: "关键词", .en: "Keyword"],
    "snippet.contentLabel": [.zhHans: "内容", .en: "Content"],

    // MARK: - Advanced (extra)
    "advanced.versionInfo": [.zhHans: "版本信息", .en: "Version Info"],
    "advanced.versionLabel": [.zhHans: "版本", .en: "Version"],
    "advanced.dataManagement": [.zhHans: "数据管理", .en: "Data Management"],
    "advanced.exportSettings": [.zhHans: "导出设置", .en: "Export Settings"],
    "advanced.exportBtn": [.zhHans: "导出...", .en: "Export..."],
    "advanced.importSettings": [.zhHans: "导入设置", .en: "Import Settings"],
    "advanced.importBtn": [.zhHans: "导入...", .en: "Import..."],
    "advanced.resetWarning": [
      .zhHans: "恢复所有设置为默认值，此操作不可撤销",
      .en: "Reset all settings to defaults. This cannot be undone",
    ],
    "advanced.resetBtn": [.zhHans: "重置", .en: "Reset"],

    // MARK: - Clipboard Content Types
    "clipboard.typeText": [.zhHans: "文本", .en: "Text"],
    "clipboard.typeUrl": [.zhHans: "URL", .en: "URL"],
    "clipboard.typePath": [.zhHans: "路径", .en: "Path"],
    "clipboard.typeImage": [.zhHans: "图片", .en: "Image"],
    "clipboard.typeColor": [.zhHans: "颜色", .en: "Color"],

    // MARK: - Dictionary Plugin (extra)
    "plugin.dict.defineHint": [.zhHans: "define <单词>", .en: "define <word>"],

    // MARK: - Terminal Plugin (extra)
    "plugin.terminal.cmdHint": [.zhHans: "> <命令>", .en: "> <command>"],

    // MARK: - AI Protocol Types
    "ai.protocolType.openai": [.zhHans: "OpenAI 兼容", .en: "OpenAI Compatible"],
    "ai.protocolType.anthropic": [.zhHans: "Anthropic 兼容", .en: "Anthropic Compatible"],
    "ai.protocolType.openaiDesc": [
      .zhHans: "兼容 OpenAI Chat Completions API（OpenAI、DeepSeek、Moonshot、通义千问、本地 Ollama 等）",
      .en:
        "Compatible with OpenAI Chat Completions API (OpenAI, DeepSeek, Moonshot, Qwen, local Ollama, etc.)",
    ],
    "ai.protocolType.anthropicDesc": [
      .zhHans: "兼容 Anthropic Messages API（Claude 系列）",
      .en: "Compatible with Anthropic Messages API (Claude series)",
    ],

    // MARK: - AI Errors
    "ai.error.noApiKey": [.zhHans: "API Key 未配置", .en: "API Key not configured"],
    "ai.error.invalidEndpoint": [.zhHans: "无效的 API 端点", .en: "Invalid API endpoint"],
    "ai.error.network": [.zhHans: "网络错误", .en: "Network error"],
    "ai.error.api": [.zhHans: "API 错误", .en: "API error"],
    "ai.error.decoding": [.zhHans: "解码错误", .en: "Decoding error"],
    "ai.error.cancelled": [.zhHans: "请求已取消", .en: "Request cancelled"],
    "ai.error.unauthorized": [
      .zhHans: "未授权 - 请检查 API Key", .en: "Unauthorized - check API Key",
    ],
    "ai.error.rateLimited": [.zhHans: "请求频率受限", .en: "Rate limited"],
    "ai.error.modelNotFound": [.zhHans: "模型未找到", .en: "Model not found"],
    "ai.error.invalidResponse": [.zhHans: "无效的响应", .en: "Invalid response"],
    "ai.error.config": [.zhHans: "配置错误", .en: "Configuration error"],
    "ai.error.noProvider": [.zhHans: "未配置 AI 服务商", .en: "No AI provider configured"],

    // MARK: - AI Engine (extra)
    "ai.notConfigured": [.zhHans: "未配置", .en: "Not configured"],
    "ai.notSelected": [.zhHans: "未选择", .en: "Not selected"],
    "ai.configureFirst": [
      .zhHans: "⚠️ 请先在设置中配置 AI 服务商",
      .en: "⚠️ Please configure an AI provider in settings first",
    ],
    "ai.errorPrefix": [.zhHans: "⚠️ 错误:", .en: "⚠️ Error:"],
    "ai.newChatTitle": [.zhHans: "新建对话", .en: "New Chat"],
    "ai.providerPlaceholder": [.zhHans: "如: OpenAI, DeepSeek", .en: "e.g. OpenAI, DeepSeek"],
  ]

  static func string(_ key: String, language: AppLanguage) -> String {
    return strings[key]?[language] ?? strings[key]?[.zhHans] ?? key
  }
}

// MARK: - View Extension for Localization

extension View {
  func localized() -> some View {
    self.environmentObject(LocalizationManager.shared)
  }
}
