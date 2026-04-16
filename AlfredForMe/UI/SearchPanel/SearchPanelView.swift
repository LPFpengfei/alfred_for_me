import AppKit
import SwiftUI

// MARK: - Search Panel View

struct SearchPanelView: View {
  @ObservedObject var viewModel: SearchViewModel
  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    VStack(spacing: 0) {
      SearchBarView(
        queryText: $viewModel.queryText,
        isSearching: viewModel.isSearching,
        onSubmit: { viewModel.executeSelected() },
        onKeyDown: { viewModel.handleKeyDown($0) }
      )

      if !viewModel.results.isEmpty {
        Rectangle()
          .fill(themeManager.current.separatorColor.opacity(0.5))
          .frame(height: 1)
          .padding(.horizontal, 16)

        ResultsListView(
          results: viewModel.results,
          selectedIndex: $viewModel.selectedIndex,
          maxVisible: viewModel.settingsManager.maxResults,
          onSelect: { index in
            viewModel.selectedIndex = index
            viewModel.executeSelected()
          }
        )
        .padding(.vertical, 6)
      }

      if viewModel.showActionPanel {
        Rectangle()
          .fill(themeManager.current.separatorColor.opacity(0.5))
          .frame(height: 1)
          .padding(.horizontal, 16)

        ActionPanelView(
          actions: viewModel.actionResults,
          onSelect: { action in
            action.handler()
            viewModel.onDismiss()
          }
        )
      }
    }
    .background(themeManager.current.backgroundColor)
  }
}

// MARK: - Search Bar View

struct SearchBarView: View {
  @Binding var queryText: String
  let isSearching: Bool
  let onSubmit: () -> Void
  let onKeyDown: (NSEvent) -> Bool

  @EnvironmentObject var themeManager: ThemeManager
  @EnvironmentObject var settingsManager: SettingsManager
  @ObservedObject var l10n = LocalizationManager.shared
  @FocusState private var isFocused: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "magnifyingglass")
        .font(.system(size: 20, weight: .medium))
        .foregroundColor(themeManager.current.accentColor)

      SearchTextField(
        text: $queryText,
        placeholder: l10n.t("search.appFilesWeb"),
        onSubmit: onSubmit,
        onKeyDown: onKeyDown,
        theme: themeManager.current,
        fontSize: settingsManager.fontSize
      )
      .font(.system(size: settingsManager.fontSize))

      if isSearching {
        ProgressView()
          .scaleEffect(0.5)
          .progressViewStyle(.circular)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 14)
    .frame(height: 56)
    .onAppear {
      isFocused = true
    }
  }
}

// MARK: - NSTextField Wrapper for Key Handling

struct SearchTextField: NSViewRepresentable {
  @Binding var text: String
  let placeholder: String
  let onSubmit: () -> Void
  let onKeyDown: (NSEvent) -> Bool
  let theme: AppTheme
  var fontSize: CGFloat? = nil
  var onTextChanged: ((String) -> Void)? = nil

  private var effectiveFontSize: CGFloat { fontSize ?? theme.fontSize }

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> CustomSearchField {
    let textField = CustomSearchField()
    textField.delegate = context.coordinator
    textField.onKeyDown = onKeyDown
    textField.placeholderString = placeholder
    textField.isBordered = false
    textField.drawsBackground = false
    textField.focusRingType = .none
    textField.font = .systemFont(ofSize: effectiveFontSize)
    textField.textColor = NSColor(theme.textColor)
    textField.cell?.wraps = false
    textField.cell?.isScrollable = true

    // Auto focus
    DispatchQueue.main.async {
      textField.window?.makeFirstResponder(textField)
    }

    return textField
  }

  func updateNSView(_ textField: CustomSearchField, context: Context) {
    context.coordinator.parent = self
    if textField.stringValue != text {
      textField.stringValue = text
    }
    textField.textColor = NSColor(theme.textColor)
    textField.font = .systemFont(ofSize: effectiveFontSize)
  }

  class Coordinator: NSObject, NSTextFieldDelegate {
    var parent: SearchTextField

    init(_ parent: SearchTextField) {
      self.parent = parent
    }

    func controlTextDidChange(_ obj: Notification) {
      if let textField = obj.object as? NSTextField {
        let newText = textField.stringValue
        if let onTextChanged = parent.onTextChanged {
          // Direct callback path: let callback handle all state updates
          // Do NOT write Binding to avoid triggering a premature SwiftUI render
          // before refreshDisplay has updated displayItems.
          onTextChanged(newText)
        } else {
          // Binding-only path (search panel)
          parent.text = newText
        }
      }
    }

    func control(_ control: NSControl, textView: NSTextView, doCommandBy commandSelector: Selector)
      -> Bool
    {
      if commandSelector == #selector(NSResponder.insertNewline(_:)) {
        parent.onSubmit()
        return true
      }
      if commandSelector == #selector(NSResponder.moveUp(_:)) {
        let event =
          NSApp.currentEvent ?? NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil,
            characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 126)!
        _ = parent.onKeyDown(event)
        return true
      }
      if commandSelector == #selector(NSResponder.moveDown(_:)) {
        let event =
          NSApp.currentEvent ?? NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil,
            characters: "", charactersIgnoringModifiers: "",
            isARepeat: false, keyCode: 125)!
        _ = parent.onKeyDown(event)
        return true
      }
      if commandSelector == #selector(NSResponder.insertTab(_:)) {
        let event =
          NSApp.currentEvent ?? NSEvent.keyEvent(
            with: .keyDown, location: .zero, modifierFlags: [],
            timestamp: 0, windowNumber: 0, context: nil,
            characters: "\t", charactersIgnoringModifiers: "\t",
            isARepeat: false, keyCode: 48)!
        _ = parent.onKeyDown(event)
        return true
      }
      return false
    }
  }
}

class CustomSearchField: NSTextField {
  var onKeyDown: ((NSEvent) -> Bool)?

  override func keyDown(with event: NSEvent) {
    if let handler = onKeyDown, handler(event) {
      return
    }
    super.keyDown(with: event)
  }
}

// MARK: - Results List View

struct ResultsListView: View {
  let results: [SearchResult]
  @Binding var selectedIndex: Int
  let maxVisible: Int
  let onSelect: (Int) -> Void

  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical, showsIndicators: false) {
        LazyVStack(spacing: 0) {
          ForEach(Array(results.prefix(maxVisible).enumerated()), id: \.offset) { index, result in
            ResultRowView(
              result: result,
              isSelected: index == selectedIndex,
              index: index
            )
            .id(index)
            .onTapGesture {
              onSelect(index)
            }
          }
        }
      }
      .onChange(of: selectedIndex) { newIndex in
        withAnimation(.easeInOut(duration: 0.15)) {
          proxy.scrollTo(newIndex, anchor: .center)
        }
      }
    }
  }
}

// MARK: - Result Row View

struct ResultRowView: View {
  let result: SearchResult
  let isSelected: Bool
  let index: Int

  @EnvironmentObject var themeManager: ThemeManager
  @EnvironmentObject var settingsManager: SettingsManager

  private var iconImageSize: CGFloat { settingsManager.resultIconSize - 6 }
  private var iconFrameSize: CGFloat { settingsManager.resultIconSize }

  var body: some View {
    HStack(spacing: 14) {
      // Icon
      ZStack {
        if let icon = result.icon {
          Image(nsImage: icon)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: iconImageSize, height: iconImageSize)
        } else {
          Image(systemName: iconForCategory(result.category))
            .font(.system(size: iconImageSize * 0.53, weight: .medium))
            .foregroundColor(isSelected ? .white : themeManager.current.accentColor)
        }
      }
      .frame(width: iconFrameSize, height: iconFrameSize)
      .background(
        RoundedRectangle(cornerRadius: 8)
          .fill(
            isSelected
              ? themeManager.current.accentColor.opacity(0.15)
              : themeManager.current.separatorColor.opacity(0.3))
      )

      VStack(alignment: .leading, spacing: 2) {
        Text(result.title)
          .font(.system(size: 14, weight: isSelected ? .medium : .regular))
          .foregroundColor(themeManager.current.textColor)
          .lineLimit(1)

        if !result.subtitle.isEmpty {
          Text(result.subtitle)
            .font(.system(size: 11))
            .foregroundColor(themeManager.current.subtitleColor)
            .lineLimit(1)
        }
      }

      Spacer()

      if isSelected {
        HStack(spacing: 2) {
          Text("⏎")
            .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .foregroundColor(themeManager.current.subtitleColor)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(
          RoundedRectangle(cornerRadius: 5)
            .fill(themeManager.current.separatorColor.opacity(0.5))
        )
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 6)
    .frame(height: 48)
    .background(
      RoundedRectangle(cornerRadius: 8)
        .fill(isSelected ? themeManager.current.selectedColor : Color.clear)
    )
    .padding(.horizontal, 6)
    .contentShape(Rectangle())
  }

  private func iconForCategory(_ category: ResultCategory) -> String {
    switch category {
    case .application: return "app.fill"
    case .file: return "doc.fill"
    case .folder: return "folder.fill"
    case .webSearch: return "globe"
    case .calculator: return "equal.circle.fill"
    case .system: return "gearshape.fill"
    case .clipboard: return "doc.on.clipboard"
    case .snippet: return "text.snippet"
    case .dictionary: return "character.book.closed.fill"
    case .bookmark: return "bookmark.fill"
    case .contact: return "person.fill"
    case .workflow: return "bolt.fill"
    case .terminal: return "terminal.fill"
    case .general: return "magnifyingglass"
    case .navigation: return "folder.fill"
    }
  }
}

// MARK: - Action Panel View

struct ActionPanelView: View {
  let actions: [ResultAction]
  let onSelect: (ResultAction) -> Void

  @State private var selectedAction = 0
  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    VStack(spacing: 2) {
      ForEach(Array(actions.enumerated()), id: \.offset) { index, action in
        HStack(spacing: 12) {
          if let icon = action.icon {
            Image(nsImage: icon)
              .resizable()
              .frame(width: 16, height: 16)
          }

          Text(action.title)
            .font(.system(size: 13))
            .foregroundColor(themeManager.current.textColor)

          Spacer()

          if let shortcut = action.shortcut {
            Text(shortcut)
              .font(.system(size: 10, design: .rounded))
              .foregroundColor(themeManager.current.subtitleColor)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                RoundedRectangle(cornerRadius: 4)
                  .fill(themeManager.current.separatorColor.opacity(0.5))
              )
          }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(
          RoundedRectangle(cornerRadius: 6)
            .fill(index == selectedAction ? themeManager.current.selectedColor : Color.clear)
        )
        .padding(.horizontal, 6)
        .onTapGesture {
          onSelect(action)
        }
      }
    }
    .padding(.vertical, 6)
  }
}
