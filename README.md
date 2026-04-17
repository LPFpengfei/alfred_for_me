# AlfredForMe

> 一个高可用、高扩展的 macOS 个人定制化效率启动器，完整复刻 Alfred 核心功能。

## 架构

```
┌─────────────────────────────────────────────┐
│           UI Layer (SwiftUI + AppKit)       │
│   SearchPanel · Settings · StatusBar        │
├─────────────────────────────────────────────┤
│           Application Layer                 │
│   SearchEngine · QueryParser · Ranker       │
├─────────────────────────────────────────────┤
│           Plugin Layer (可扩展)              │
│   每个功能都是一个独立的 Plugin               │
├─────────────────────────────────────────────┤
│           Infrastructure Layer              │
│   HotkeyManager · ClipboardManager         │
│   SettingsManager · WorkflowEngine          │
│   ThemeManager                              │
└─────────────────────────────────────────────┘
```

## 已实现功能

### 核心功能

- ✅ **全局热键** - 可配置的全局快捷键呼出搜索 (默认 ⌘Space)
- ✅ **应用启动器** - 搜索并启动所有已安装的应用
- ✅ **文件搜索** - 基于 Spotlight 索引的文件搜索
- ✅ **文件导航** - 使用 `/` 或 `~` 浏览文件系统
- ✅ **Web 搜索** - 支持 Google/Bing/DuckDuckGo/GitHub/百度等 9 个搜索引擎
- ✅ **计算器** - 数学表达式求值，支持加减乘除、幂运算
- ✅ **系统命令** - 锁屏/睡眠/重启/关机/注销/清空废纸篓等 15 个系统命令
- ✅ **剪贴板历史** - 自动记录剪贴板变化，支持搜索和快速粘贴
- ✅ **代码片段** - 自定义文本片段，快速展开
- ✅ **词典查询** - 使用 macOS 内置词典查询单词
- ✅ **终端集成** - 使用 `>` 前缀执行 Shell 命令
- ✅ **浏览器书签** - 搜索 Chrome/Safari/Firefox 书签
- ✅ **工作流引擎** - 自定义工作流自动化

### 系统功能

- ✅ **插件化架构** - 所有功能通过 `SearchPlugin` 协议接入，易于扩展
- ✅ **主题系统** - 10 个内置主题 (Alfred Classic, Dark, macOS Light/Dark, Monokai, Solarized Dark/Light, Nord, Dracula, One Dark)，切换主题实时生效于搜索面板和剪贴板面板，NSVisualEffectView 根据主题明暗自动适配
- ✅ **外观模式** - 支持浅色 / 深色 / 跟随系统三种外观模式，独立于主题选择
- ✅ **自定义字体大小** - 搜索面板字体大小和结果图标大小可在设置中调节
- ✅ **结果排序** - 基于使用频率和匹配度的智能排序
- ✅ **模糊匹配** - 支持模糊搜索、缩写匹配、子序列匹配
- ✅ **设置界面** - 完整的偏好设置面板 (10 个分类)
- ✅ **菜单栏图标** - 常驻状态栏，快速访问
- ✅ **操作面板** - Tab 键展开详细操作列表
- ✅ **国际化 (i18n)** - 中文 / English 双语支持，所有 UI 文本（设置面板、搜索结果、操作按钮、AI 对话、搜索栏提示、错误提示等）均通过 LocalizationManager 管理，切换语言实时生效

## 搜索优化

搜索引擎经过精心优化，避免查询结果混乱：

- **精准匹配** - 系统命令仅在查询匹配已知命令别名时才显示（前缀匹配 / 包含匹配）
- **文件搜索限定** - Spotlight 文件搜索仅在使用关键词 `open`/`find`/`file` 或路径语法 (`/`、`~`、`.`) 时触发，不再对普通文字查询干扰
- **计算器误判修复** - 计算器仅对以数字/括号开头或 `=` 前缀的表达式生效，`C++`、`+1` 等不再误触发
- **URL 识别收紧** - Web 搜索仅识别常见 web 域名后缀 (`.com`、`.org`、`.cn` 等)，`test.zip` 等文件名不再被当作 URL
- **结果数量限制** - 每个插件最多返回 5 条结果，避免单个插件刷屏
- **弱匹配过滤** - 应用启动器过滤低相关度的模糊匹配结果

## 代码质量

- ✅ 零编译警告 - 修复 Swift 6 并发安全 (Sendable)、未使用返回值、废弃 API 等问题
- ✅ `UserNotifications` 替代废弃的 `NSUserNotification`
- ✅ 自签名证书签名，支持 keychain 自动解锁，签名失败自动回退 ad-hoc

## 搜索语法

| 语法 | 功能 | 示例 |
|------|------|------|
| `<text>` | 搜索应用 | `safari` |
| `open <query>` | 文件搜索 (Spotlight) | `open readme` |
| `find <query>` | 文件搜索 (Spotlight) | `find config.json` |
| `google <query>` | Web 搜索 (Google) | `google swift tutorial` |
| `bing <query>` | Web 搜索 (Bing) | `bing macOS tips` |
| `duck <query>` | Web 搜索 (DuckDuckGo) | `duck privacy` |
| `gh <query>` | Web 搜索 (GitHub) | `gh swift package` |
| `so <query>` | Web 搜索 (Stack Overflow) | `so swiftui layout` |
| `wiki <query>` | Web 搜索 (Wikipedia) | `wiki Alan Turing` |
| `yt <query>` | Web 搜索 (YouTube) | `yt WWDC 2025` |
| `baidu <query>` | Web 搜索 (百度) | `baidu 天气预报` |
| `= <expression>` | 计算器 | `= 2 + 3 * 4` |
| `> <command>` | 终端命令 | `> ls -la` |
| `$ <command>` | 终端命令 (别名) | `$ pwd` |
| `/ <path>` | 文件导航 | `/Applications` |
| `~ <path>` | 从 Home 导航 | `~/Documents` |
| `define <word>` | 词典查询 | `define serendipity` |
| `dict <word>` | 词典查询 (别名) | `dict hello` |
| `clipboard <search>` | 剪贴板历史 | `clipboard password` |
| `cb <search>` | 剪贴板历史 (别名) | `cb text` |
| `snip <search>` | 代码片段 | `snip email` |
| `snippet <search>` | 代码片段 (别名) | `snippet email` |
| `bm <search>` | 浏览器书签 | `bm github` |
| `bookmark <search>` | 浏览器书签 (别名) | `bookmark github` |
| `ai <question>` | AI 对话 | `ai what is swift` |
| `lock` | 锁屏 | `lock` |
| `sleep` | 睡眠 | `sleep` |

## 快捷键

| 快捷键 | 功能 |
|--------|------|
| ⌘ Space | 唤醒/隐藏搜索面板 |
| ↑/↓ | 上下选择结果 |
| ⏎ | 执行选中项 |
| Tab | 打开操作面板 |
| Esc | 关闭面板 |

## 构建 & 运行

### 前置要求

- macOS 13.0+
- Xcode 15.0+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen)

### 快速开始

```bash
# 安装 XcodeGen (如果尚未安装)
brew install xcodegen

# 生成 Xcode 项目
xcodegen generate

# 构建并运行
./run.sh

# 或在 Xcode 中打开
open AlfredForMe.xcodeproj
```

### 构建 Release 版本

```bash
./build.sh
```

## 扩展指南

### 创建自定义插件

1. 创建一个类实现 `SearchPlugin` 协议：

```swift
final class MyPlugin: SearchPlugin {
    let id = "com.myname.myPlugin"
    let name = "My Plugin"
    let keyword: String? = "my"  // 可选关键词触发
    var isEnabled = true
    let priority = 50

    func search(query: SearchQuery) async -> [SearchResult] {
        // 实现搜索逻辑
        return []
    }

    func execute(result: SearchResult) async {
        // 实现执行逻辑
    }
}
```

1. 在 `AppDelegate.setupPlugins()` 中注册：

```swift
pluginManager.register(plugin: MyPlugin())
```

### 创建工作流

工作流存储在 `~/Library/Application Support/AlfredForMe/Workflows/` 目录下，每个工作流是一个包含 `workflow.json` 的文件夹。

## 项目结构

```
AlfredForMe/
├── App/                    # 应用入口
│   ├── AlfredForMeApp.swift
│   └── AppDelegate.swift
├── Core/                   # 核心引擎
│   ├── Engine/
│   │   └── SearchEngine.swift
│   ├── Plugin/
│   │   └── PluginProtocol.swift
│   ├── ClipboardManager.swift
│   ├── HotkeyManager.swift
│   ├── SettingsManager.swift
│   └── WorkflowEngine.swift
├── Models/                 # 数据模型
│   └── Models.swift
├── Plugins/                # 内置插件
│   ├── AppLauncher/
│   ├── Bookmark/
│   ├── Calculator/
│   ├── ClipboardHistory/
│   ├── Dictionary/
│   ├── FileNavigation/
│   ├── FileSearch/
│   ├── Snippet/
│   ├── SystemCommand/
│   ├── Terminal/
│   └── WebSearch/
├── UI/                     # 界面
│   ├── SearchPanel/
│   ├── Settings/
│   ├── StatusBar/
│   └── Theme/
├── Utils/                  # 工具
│   └── Utilities.swift
└── Resources/              # 资源
    ├── Info.plist
    └── AlfredForMe.entitlements
```

## 依赖

- [GRDB.swift](https://github.com/groue/GRDB.swift) - SQLite 数据库
- [HotKey](https://github.com/soffes/HotKey) - 全局快捷键
- [Expression](https://github.com/nicklockwood/Expression) - 数学表达式求值

## License

MIT
