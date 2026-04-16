import Carbon
import SwiftUI

// MARK: - Settings View

struct SettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @EnvironmentObject var pluginManager: PluginManager
  @EnvironmentObject var themeManager: ThemeManager
  @ObservedObject var l10n = LocalizationManager.shared

  @State private var selectedTab = SettingsTab.general

  enum SettingsTab: String, CaseIterable, Identifiable {
    case general, appearance, search, webSearch, plugins
    case clipboard, snippets, workflows, terminal, ai, advanced

    var id: String { rawValue }

    var displayName: String {
      let l10n = LocalizationManager.shared
      switch self {
      case .general: return l10n.t("settings.general")
      case .appearance: return l10n.t("settings.appearance")
      case .search: return l10n.t("settings.search")
      case .webSearch: return l10n.t("settings.webSearch")
      case .plugins: return l10n.t("settings.plugins")
      case .clipboard: return l10n.t("settings.clipboard")
      case .snippets: return l10n.t("settings.snippets")
      case .workflows: return l10n.t("settings.workflows")
      case .terminal: return l10n.t("settings.terminal")
      case .ai: return l10n.t("settings.ai")
      case .advanced: return l10n.t("settings.advanced")
      }
    }

    var icon: String {
      switch self {
      case .general: return "gearshape.fill"
      case .appearance: return "paintbrush.fill"
      case .search: return "magnifyingglass"
      case .webSearch: return "globe"
      case .plugins: return "puzzlepiece.extension.fill"
      case .clipboard: return "doc.on.clipboard.fill"
      case .snippets: return "curlybraces"
      case .workflows: return "bolt.fill"
      case .terminal: return "terminal.fill"
      case .ai: return "sparkles"
      case .advanced: return "wrench.and.screwdriver.fill"
      }
    }

    var sectionKey: String {
      switch self {
      case .general, .appearance: return "basic"
      case .search, .webSearch, .plugins: return "search"
      case .clipboard, .snippets, .workflows: return "features"
      case .terminal, .ai, .advanced: return "other"
      }
    }
  }

  private var groupedTabs: [(String, [SettingsTab])] {
    let l10n = LocalizationManager.shared
    let sections: [(key: String, name: String)] = [
      ("basic", l10n.t("settings.section.basic")),
      ("search", l10n.t("settings.section.search")),
      ("features", l10n.t("settings.section.features")),
      ("other", l10n.t("settings.section.other")),
    ]
    return sections.map { section in
      (section.name, SettingsTab.allCases.filter { $0.sectionKey == section.key })
    }
  }

  var body: some View {
    HStack(spacing: 0) {
      // Sidebar
      List(selection: $selectedTab) {
        // App Logo Header
        VStack(spacing: 6) {
          Image(nsImage: NSApp.applicationIconImage ?? NSImage())
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 56, height: 56)
          Text("AlfredForMe")
            .font(.system(size: 14, weight: .bold))
          Text("v\(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .listRowSeparator(.hidden)

        ForEach(groupedTabs, id: \.0) { section, tabs in
          Section {
            ForEach(tabs) { tab in
              Label(tab.displayName, systemImage: tab.icon)
                .tag(tab)
            }
          } header: {
            Text(section)
              .font(.system(size: 11, weight: .semibold))
              .foregroundColor(.secondary)
          }
        }
      }
      .listStyle(.sidebar)
      .frame(width: 180)

      // Content
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          // Header
          Text(selectedTab.displayName)
            .font(.system(size: 20, weight: .semibold))
            .padding(.horizontal, 28)
            .padding(.top, 24)
            .padding(.bottom, 16)

          settingsContent
            .padding(.horizontal, 28)
            .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(width: 780, height: 560)
  }

  @ViewBuilder
  private var settingsContent: some View {
    switch selectedTab {
    case .general: GeneralSettingsView()
    case .appearance: AppearanceSettingsView()
    case .search: SearchSettingsView()
    case .webSearch: WebSearchSettingsView()
    case .plugins: PluginSettingsView()
    case .clipboard: ClipboardSettingsView()
    case .snippets: SnippetSettingsView()
    case .workflows: WorkflowSettingsView()
    case .terminal: TerminalSettingsView()
    case .ai: AISettingsView()
    case .advanced: AdvancedSettingsView()
    }
  }
}

// MARK: - Settings Card

struct SettingsCard<Content: View>: View {
  let title: String
  @ViewBuilder let content: () -> Content

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(title)
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(.secondary)

      VStack(alignment: .leading, spacing: 0) {
        content()
      }
      .background(
        RoundedRectangle(cornerRadius: 10)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 10)
          .stroke(Color(nsColor: .separatorColor).opacity(0.5), lineWidth: 0.5)
      )
    }
  }
}

struct SettingsRow<Content: View>: View {
  let showDivider: Bool
  @ViewBuilder let content: () -> Content

  init(showDivider: Bool = true, @ViewBuilder content: @escaping () -> Content) {
    self.showDivider = showDivider
    self.content = content
  }

  var body: some View {
    VStack(spacing: 0) {
      content()
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
      if showDivider {
        Divider().padding(.leading, 14)
      }
    }
  }
}

// MARK: - General Settings

struct GeneralSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("general.language")) {
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("general.interfaceLanguage"))
            Spacer()
            Picker("", selection: $l10n.language) {
              ForEach(AppLanguage.allCases, id: \.self) { lang in
                Text(lang.displayName).tag(lang)
              }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 200)
          }
        }
      }

      SettingsCard(title: l10n.t("general.hotkey")) {
        SettingsRow {
          HStack {
            Text(l10n.t("general.globalHotkey"))
            Spacer()
            HotkeyRecorderButton(hotkey: $settingsManager.globalHotkey)
          }
        }
        SettingsRow {
          HStack {
            Text(l10n.t("general.clipboardHotkey"))
            Spacer()
            HotkeyRecorderButton(
              hotkey: Binding(
                get: {
                  settingsManager.clipboardHotkey
                    ?? HotkeyConfig(
                      keyCode: UInt32(kVK_ANSI_C), modifiers: UInt32(optionKey | cmdKey))
                },
                set: { settingsManager.clipboardHotkey = $0 }
              ))
          }
        }
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("general.aiChatHotkey"))
            Spacer()
            HotkeyRecorderButton(
              hotkey: Binding(
                get: {
                  settingsManager.aiChatHotkey
                    ?? HotkeyConfig(
                      keyCode: UInt32(kVK_ANSI_I), modifiers: UInt32(optionKey | cmdKey))
                },
                set: { settingsManager.aiChatHotkey = $0 }
              ))
          }
        }
      }

      SettingsCard(title: l10n.t("general.startup")) {
        SettingsRow(showDivider: false) {
          Toggle(l10n.t("general.launchAtLogin"), isOn: $settingsManager.launchAtLogin)
        }
      }

      SettingsCard(title: l10n.t("general.results")) {
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("general.maxResults"))
            Spacer()
            Stepper("\(settingsManager.maxResults)", value: $settingsManager.maxResults, in: 3...20)
          }
        }
      }
    }
  }
}

// MARK: - Appearance Settings

struct AppearanceSettingsView: View {
  @EnvironmentObject var themeManager: ThemeManager
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("appearance.mode")) {
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("appearance.label"))
            Spacer()
            Picker("", selection: $themeManager.appearanceMode) {
              ForEach(AppearanceMode.allCases) { mode in
                Text(mode.displayName).tag(mode)
              }
            }
            .labelsHidden()
            .pickerStyle(.segmented)
            .frame(width: 240)
          }
        }
      }

      SettingsCard(title: l10n.t("appearance.theme")) {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 12)], spacing: 12) {
          ForEach(themeManager.availableThemes) { theme in
            ThemePreviewCard(theme: theme, isSelected: theme.id == themeManager.current.id)
              .onTapGesture {
                themeManager.apply(theme: theme)
              }
          }
        }
        .padding(14)
      }

      SettingsCard(title: l10n.t("appearance.fontAndIcon")) {
        SettingsRow {
          HStack {
            Text(l10n.t("appearance.searchFontSize"))
            Spacer()
            Slider(value: $settingsManager.fontSize, in: 14...28, step: 1)
              .frame(width: 180)
            Text("\(Int(settingsManager.fontSize)) pt")
              .font(.system(size: 12, design: .monospaced))
              .foregroundColor(.secondary)
              .frame(width: 40)
          }
        }
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("appearance.iconSize"))
            Spacer()
            Slider(value: $settingsManager.resultIconSize, in: 24...48, step: 4)
              .frame(width: 180)
            Text("\(Int(settingsManager.resultIconSize)) px")
              .font(.system(size: 12, design: .monospaced))
              .foregroundColor(.secondary)
              .frame(width: 40)
          }
        }
      }
    }
  }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
  let theme: AppTheme
  let isSelected: Bool

  var body: some View {
    VStack(spacing: 0) {
      // Mini search bar preview
      VStack(spacing: 3) {
        HStack(spacing: 4) {
          Circle()
            .fill(theme.accentColor)
            .frame(width: 6, height: 6)
          RoundedRectangle(cornerRadius: 2)
            .fill(theme.textColor.opacity(0.6))
            .frame(height: 4)
        }
        .padding(.horizontal, 8)

        Rectangle()
          .fill(theme.separatorColor)
          .frame(height: 0.5)
          .padding(.horizontal, 4)

        // Result rows preview
        VStack(spacing: 2) {
          ForEach(0..<3, id: \.self) { i in
            HStack(spacing: 4) {
              RoundedRectangle(cornerRadius: 2)
                .fill(i == 0 ? theme.accentColor.opacity(0.5) : theme.subtitleColor.opacity(0.3))
                .frame(width: 8, height: 8)
              VStack(alignment: .leading, spacing: 1) {
                RoundedRectangle(cornerRadius: 1)
                  .fill(theme.textColor.opacity(0.7))
                  .frame(height: 2.5)
                RoundedRectangle(cornerRadius: 1)
                  .fill(theme.subtitleColor.opacity(0.5))
                  .frame(width: 40, height: 2)
              }
              Spacer()
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              RoundedRectangle(cornerRadius: 2)
                .fill(i == 0 ? theme.selectedColor : Color.clear)
            )
            .padding(.horizontal, 2)
          }
        }
      }
      .padding(.vertical, 6)
      .background(theme.backgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 6))

      Text(theme.name)
        .font(.system(size: 11))
        .foregroundColor(isSelected ? .accentColor : .secondary)
        .lineLimit(1)
        .padding(.top, 6)
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    )
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 1.5)
    )
  }
}

// MARK: - Search Settings

struct SearchSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared
  @State private var newScope = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("search.options")) {
        SettingsRow(showDivider: false) {
          Toggle(l10n.t("search.fuzzyMatching"), isOn: $settingsManager.fuzzyMatching)
        }
      }

      SettingsCard(title: l10n.t("search.scope")) {
        VStack(spacing: 0) {
          ForEach(Array(settingsManager.searchScope.enumerated()), id: \.element) { index, path in
            SettingsRow(showDivider: index < settingsManager.searchScope.count - 1) {
              HStack {
                Image(systemName: "folder.fill")
                  .foregroundColor(.secondary)
                  .font(.system(size: 12))
                Text(path)
                  .font(.system(size: 13))
                  .lineLimit(1)
                Spacer()
                Button(action: {
                  settingsManager.searchScope.removeAll { $0 == path }
                }) {
                  Image(systemName: "minus.circle.fill")
                    .foregroundColor(.red.opacity(0.8))
                    .font(.system(size: 14))
                }
                .buttonStyle(.plain)
              }
            }
          }
          if settingsManager.searchScope.isEmpty {
            SettingsRow(showDivider: false) {
              Text(l10n.t("search.noScope"))
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
          }
        }

        Divider().padding(.horizontal, 14)

        HStack(spacing: 8) {
          TextField(l10n.t("search.addPath"), text: $newScope)
            .textFieldStyle(.roundedBorder)
            .font(.system(size: 13))
          Button(l10n.t("action.add")) {
            if !newScope.isEmpty {
              settingsManager.searchScope.append(newScope)
              newScope = ""
            }
          }
          .disabled(newScope.isEmpty)
        }
        .padding(14)
      }
    }
  }
}

// MARK: - Web Search Settings

struct WebSearchSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared
  @State private var showingAddSheet = false

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("webSearch.engine")) {
        VStack(spacing: 0) {
          ForEach(Array(settingsManager.webSearchEngines.enumerated()), id: \.element.id) {
            index, engine in
            SettingsRow(showDivider: index < settingsManager.webSearchEngines.count - 1) {
              HStack(spacing: 12) {
                Toggle(
                  "",
                  isOn: Binding(
                    get: { engine.isEnabled },
                    set: { settingsManager.webSearchEngines[index].isEnabled = $0 }
                  )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                  Text(engine.name)
                    .font(.system(size: 13, weight: .medium))
                  Text(engine.keyword)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.secondary)
                }

                Spacer()

                if engine.keyword == settingsManager.defaultWebSearch {
                  Text(l10n.t("label.default"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(
                      RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor.opacity(0.12))
                    )
                }
              }
            }
          }
        }
      }

      HStack(spacing: 12) {
        Button(action: { showingAddSheet = true }) {
          Label(l10n.t("webSearch.addEngine"), systemImage: "plus")
        }

        Spacer()

        HStack(spacing: 6) {
          Text(l10n.t("webSearch.defaultEngine"))
            .font(.system(size: 13))
            .foregroundColor(.secondary)
          Picker("", selection: $settingsManager.defaultWebSearch) {
            ForEach(settingsManager.webSearchEngines) { engine in
              Text(engine.name).tag(engine.keyword)
            }
          }
          .labelsHidden()
          .frame(width: 150)
        }
      }
    }
    .sheet(isPresented: $showingAddSheet) {
      AddWebSearchSheet(isPresented: $showingAddSheet)
    }
  }
}

struct AddWebSearchSheet: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  @State private var name = ""
  @State private var keyword = ""
  @State private var urlTemplate = ""

  var body: some View {
    VStack(spacing: 20) {
      Text(l10n.t("webSearch.addEngine"))
        .font(.system(size: 16, weight: .semibold))

      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(l10n.t("webSearch.nameLabel")).font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
          TextField("Google", text: $name).textFieldStyle(.roundedBorder)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(l10n.t("webSearch.keywordLabel")).font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
          TextField("google", text: $keyword).textFieldStyle(.roundedBorder)
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(l10n.t("webSearch.urlTemplateLabel")).font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
          TextField("https://google.com/search?q={query}", text: $urlTemplate).textFieldStyle(
            .roundedBorder)
          Text(l10n.t("webSearch.urlTemplateHint"))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
      }

      Spacer()

      HStack {
        Button(l10n.t("action.cancel")) { isPresented = false }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(l10n.t("action.add")) {
          let engine = WebSearchEngine(name: name, keyword: keyword, urlTemplate: urlTemplate)
          settingsManager.webSearchEngines.append(engine)
          isPresented = false
        }
        .keyboardShortcut(.defaultAction)
        .disabled(name.isEmpty || keyword.isEmpty || urlTemplate.isEmpty)
      }
    }
    .padding(24)
    .frame(width: 420, height: 300)
  }
}

// MARK: - Plugin Settings

struct PluginSettingsView: View {
  @EnvironmentObject var pluginManager: PluginManager
  @ObservedObject var l10n = LocalizationManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("plugins.installed")) {
        VStack(spacing: 0) {
          ForEach(Array(pluginManager.plugins.enumerated()), id: \.element.id) { index, plugin in
            SettingsRow(showDivider: index < pluginManager.plugins.count - 1) {
              HStack(spacing: 12) {
                Toggle(
                  "",
                  isOn: Binding(
                    get: { plugin.isEnabled },
                    set: { pluginManager.plugins[index].isEnabled = $0 }
                  )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

                VStack(alignment: .leading, spacing: 2) {
                  Text(plugin.name)
                    .font(.system(size: 13, weight: .medium))

                  HStack(spacing: 8) {
                    if let keyword = plugin.keyword {
                      Text(keyword)
                        .font(.system(size: 10, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                          RoundedRectangle(cornerRadius: 3)
                            .fill(Color.accentColor.opacity(0.1))
                        )
                        .foregroundColor(.accentColor)
                    }
                    Text(plugin.id)
                      .font(.system(size: 10))
                      .foregroundColor(.secondary)
                  }
                }

                Spacer()

                Text("\(l10n.t("plugins.priorityLabel")) \(plugin.priority)")
                  .font(.system(size: 11))
                  .foregroundColor(.secondary)
              }
            }
          }
        }
      }
    }
  }
}

// MARK: - Clipboard Settings

struct ClipboardSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("clipboard.history")) {
        SettingsRow {
          Toggle(l10n.t("clipboard.enable"), isOn: $settingsManager.clipboardHistoryEnabled)
        }
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("clipboard.maxItems"))
            Spacer()
            Stepper(
              "\(settingsManager.clipboardHistorySize)",
              value: $settingsManager.clipboardHistorySize, in: 100...5000, step: 100)
          }
        }
      }

      SettingsCard(title: l10n.t("clipboard.hotkey")) {
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("clipboard.hotkeyDesc"))
            Spacer()
            Text("⌥⌘C")
              .font(.system(size: 13, weight: .medium, design: .rounded))
              .padding(.horizontal, 14)
              .padding(.vertical, 6)
              .background(
                RoundedRectangle(cornerRadius: 6)
                  .fill(Color.secondary.opacity(0.12))
              )
          }
        }
      }

      SettingsCard(title: l10n.t("clipboard.operations")) {
        SettingsRow(showDivider: false) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(l10n.t("clipboard.clearAll"))
                .font(.system(size: 13))
            }
            Spacer()
            Button(l10n.t("ai.clear")) {
              ClipboardManager.shared.clearHistory()
            }
            .foregroundColor(.red)
          }
        }
      }
    }
  }
}

// MARK: - Snippet Settings

struct SnippetSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared
  @State private var showingAddSheet = false
  @State private var editingSnippet: Snippet?

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("settings.snippets")) {
        if settingsManager.snippets.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "text.snippet")
              .font(.system(size: 28))
              .foregroundColor(.secondary.opacity(0.5))
            Text(l10n.t("snippet.empty"))
              .font(.system(size: 13))
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(settingsManager.snippets.enumerated()), id: \.element.id) {
              index, snippet in
              SettingsRow(showDivider: index < settingsManager.snippets.count - 1) {
                HStack(spacing: 12) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(snippet.name)
                      .font(.system(size: 13, weight: .medium))
                    Text(":\(snippet.keyword)")
                      .font(.system(size: 11, design: .monospaced))
                      .foregroundColor(.accentColor)
                  }

                  Spacer()

                  Text(String(snippet.content.prefix(30)))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                  Button(action: {
                    settingsManager.snippets.removeAll { $0.id == snippet.id }
                  }) {
                    Image(systemName: "trash")
                      .font(.system(size: 11))
                      .foregroundColor(.red.opacity(0.7))
                  }
                  .buttonStyle(.plain)
                }
              }
            }
          }
        }
      }

      Button(action: { showingAddSheet = true }) {
        Label(l10n.t("snippet.add"), systemImage: "plus")
      }
    }
    .sheet(isPresented: $showingAddSheet) {
      AddSnippetSheet(isPresented: $showingAddSheet)
    }
  }
}

struct AddSnippetSheet: View {
  @Binding var isPresented: Bool
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  @State private var name = ""
  @State private var keyword = ""
  @State private var content = ""
  @State private var autoExpand = true

  var body: some View {
    VStack(spacing: 20) {
      Text(l10n.t("snippet.add"))
        .font(.system(size: 16, weight: .semibold))

      VStack(alignment: .leading, spacing: 12) {
        VStack(alignment: .leading, spacing: 4) {
          Text(l10n.t("snippet.nameLabel")).font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
          TextField(l10n.t("snippet.namePlaceholder"), text: $name).textFieldStyle(.roundedBorder)
        }
        HStack(spacing: 12) {
          VStack(alignment: .leading, spacing: 4) {
            Text(l10n.t("snippet.keywordLabel")).font(.system(size: 12, weight: .medium))
              .foregroundColor(.secondary)
            TextField("keyword", text: $keyword).textFieldStyle(.roundedBorder)
          }
          VStack(alignment: .leading, spacing: 4) {
            Text(" ").font(.system(size: 12))
            Toggle(l10n.t("snippet.autoExpand"), isOn: $autoExpand)
          }
        }
        VStack(alignment: .leading, spacing: 4) {
          Text(l10n.t("snippet.contentLabel")).font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
          TextEditor(text: $content)
            .font(.system(size: 12, design: .monospaced))
            .frame(height: 100)
            .overlay(
              RoundedRectangle(cornerRadius: 6)
                .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
            )
        }
      }

      Spacer()

      HStack {
        Button(l10n.t("action.cancel")) { isPresented = false }
          .keyboardShortcut(.cancelAction)
        Spacer()
        Button(l10n.t("action.add")) {
          let snippet = Snippet(
            name: name, keyword: keyword, content: content, autoExpand: autoExpand)
          settingsManager.snippets.append(snippet)
          isPresented = false
        }
        .keyboardShortcut(.defaultAction)
        .disabled(name.isEmpty || keyword.isEmpty || content.isEmpty)
      }
    }
    .padding(24)
    .frame(width: 450, height: 380)
  }
}

// MARK: - Workflow Settings

struct WorkflowSettingsView: View {
  @StateObject private var engine = WorkflowEngine.shared
  @ObservedObject var l10n = LocalizationManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("settings.workflows")) {
        if engine.workflows.isEmpty {
          VStack(spacing: 8) {
            Image(systemName: "bolt.slash")
              .font(.system(size: 28))
              .foregroundColor(.secondary.opacity(0.5))
            Text(l10n.t("workflow.empty"))
              .font(.system(size: 13))
              .foregroundColor(.secondary)
            Text(l10n.t("workflow.emptyDesc"))
              .font(.system(size: 11))
              .foregroundColor(.secondary.opacity(0.7))
          }
          .frame(maxWidth: .infinity)
          .padding(.vertical, 24)
        } else {
          VStack(spacing: 0) {
            ForEach(Array(engine.workflows.enumerated()), id: \.element.id) { index, workflow in
              SettingsRow(showDivider: index < engine.workflows.count - 1) {
                HStack(spacing: 12) {
                  VStack(alignment: .leading, spacing: 2) {
                    Text(workflow.name)
                      .font(.system(size: 13, weight: .medium))
                    HStack(spacing: 6) {
                      Text(workflow.keyword)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(.accentColor)
                      Text("·")
                        .foregroundColor(.secondary)
                      Text("\(workflow.steps.count) \(l10n.t("workflow.steps"))")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    }
                  }
                  Spacer()
                  Text(workflow.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                }
              }
            }
          }
        }
      }

      HStack(spacing: 12) {
        Button(action: {}) {
          Label(l10n.t("workflow.import"), systemImage: "square.and.arrow.down")
        }
        Button(action: {}) {
          Label(l10n.t("workflow.create"), systemImage: "plus")
        }
      }
    }
  }
}

// MARK: - Terminal Settings

struct TerminalSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  let terminalOptions = ["Terminal", "iTerm2", "Alacritty", "Warp", "Kitty"]

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("terminal.app")) {
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("terminal.terminal"))
            Spacer()
            Picker("", selection: $settingsManager.terminalApp) {
              ForEach(terminalOptions, id: \.self) { option in
                Text(option).tag(option)
              }
            }
            .labelsHidden()
            .frame(width: 180)
          }
        }
      }

      SettingsCard(title: l10n.t("terminal.shell")) {
        SettingsRow {
          VStack(alignment: .leading, spacing: 6) {
            HStack {
              Text(l10n.t("terminal.shellPath"))
              Spacer()
              TextField("/bin/zsh", text: $settingsManager.shellPath)
                .textFieldStyle(.roundedBorder)
                .frame(width: 250)
            }
          }
        }
        SettingsRow(showDivider: false) {
          Text(l10n.t("terminal.commonShells"))
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

// MARK: - Advanced Settings

struct AdvancedSettingsView: View {
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared

  var body: some View {
    VStack(alignment: .leading, spacing: 20) {
      SettingsCard(title: l10n.t("advanced.versionInfo")) {
        SettingsRow(showDivider: false) {
          HStack {
            Text(l10n.t("advanced.versionLabel"))
            Spacer()
            Text("1.0.0")
              .foregroundColor(.secondary)
          }
        }
      }

      SettingsCard(title: l10n.t("advanced.dataManagement")) {
        SettingsRow {
          HStack {
            Text(l10n.t("advanced.exportSettings"))
            Spacer()
            Button(l10n.t("advanced.exportBtn")) {}
          }
        }
        SettingsRow {
          HStack {
            Text(l10n.t("advanced.importSettings"))
            Spacer()
            Button(l10n.t("advanced.importBtn")) {}
          }
        }
        SettingsRow(showDivider: false) {
          HStack {
            VStack(alignment: .leading, spacing: 2) {
              Text(l10n.t("advanced.resetAll"))
                .foregroundColor(.red)
              Text(l10n.t("advanced.resetWarning"))
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
            Spacer()
            Button(l10n.t("advanced.resetBtn")) {}
              .foregroundColor(.red)
          }
        }
      }

      SettingsCard(title: l10n.t("advanced.about")) {
        SettingsRow(showDivider: false) {
          Text(l10n.t("advanced.aboutDesc"))
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
      }
    }
  }
}

// MARK: - Hotkey Recorder Button

struct HotkeyRecorderButton: View {
  @Binding var hotkey: HotkeyConfig
  @ObservedObject var l10n = LocalizationManager.shared
  @State private var isRecording = false
  @State private var monitor: Any?

  var body: some View {
    Button(action: {
      if isRecording {
        stopRecording()
      } else {
        startRecording()
      }
    }) {
      Text(isRecording ? l10n.t("general.pressHotkey") : hotkey.displayName)
        .font(.system(size: 13, weight: .medium, design: .rounded))
        .foregroundColor(isRecording ? .accentColor : .primary)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(isRecording ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.12))
        )
        .overlay(
          RoundedRectangle(cornerRadius: 6)
            .stroke(isRecording ? Color.accentColor : Color.clear, lineWidth: 1)
        )
    }
    .buttonStyle(.plain)
    .onDisappear {
      stopRecording()
    }
  }

  private func startRecording() {
    isRecording = true
    monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
      if event.keyCode == UInt16(kVK_Escape) {
        stopRecording()
        return nil
      }

      let modifiers = event.modifierFlags
      var carbonMods: UInt32 = 0
      if modifiers.contains(.control) { carbonMods |= UInt32(controlKey) }
      if modifiers.contains(.option) { carbonMods |= UInt32(optionKey) }
      if modifiers.contains(.shift) { carbonMods |= UInt32(shiftKey) }
      if modifiers.contains(.command) { carbonMods |= UInt32(cmdKey) }

      guard carbonMods != 0 else { return event }

      hotkey = HotkeyConfig(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
      stopRecording()
      return nil
    }
  }

  private func stopRecording() {
    isRecording = false
    if let m = monitor {
      NSEvent.removeMonitor(m)
      monitor = nil
    }
  }
}
