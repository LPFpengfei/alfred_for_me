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
- ✅ **主题系统** - 10 个内置主题 (Alfred Classic, Dark, Nord, Dracula 等)
- ✅ **结果排序** - 基于使用频率和匹配度的智能排序
- ✅ **模糊匹配** - 支持模糊搜索、缩写匹配、子序列匹配
- ✅ **设置界面** - 完整的偏好设置面板 (10 个分类)
- ✅ **菜单栏图标** - 常驻状态栏，快速访问
- ✅ **操作面板** - Tab 键展开详细操作列表

## 搜索语法

| 语法 | 功能 | 示例 |
|------|------|------|
| `<text>` | 搜索应用/文件 | `safari` |
| `google <query>` | Web 搜索 | `google swift tutorial` |
| `= <expression>` | 计算器 | `= 2 + 3 * 4` |
| `> <command>` | 终端命令 | `> ls -la` |
| `/ <path>` | 文件导航 | `/Applications` |
| `~ <path>` | 从 Home 导航 | `~/Documents` |
| `define <word>` | 词典查询 | `define serendipity` |
| `clipboard <search>` | 剪贴板历史 | `clipboard password` |
| `snip <search>` | 代码片段 | `snip email` |
| `bm <search>` | 浏览器书签 | `bm github` |
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
# alfred_for_me
