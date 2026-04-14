import AppKit
import SwiftUI

// MARK: - Clipboard Panel View

struct ClipboardPanelView: View {
  @ObservedObject var viewModel: ClipboardPanelViewModel
  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    VStack(spacing: 0) {
      // Search bar
      ClipboardSearchBar(
        searchText: $viewModel.searchText,
        onKeyDown: { viewModel.handleKeyDown($0) },
        onSubmit: { viewModel.executeSelected() },
        onTextChanged: { newText in viewModel.setSearchText(newText) }
      )

      Rectangle()
        .fill(themeManager.current.separatorColor.opacity(0.5))
        .frame(height: 1)
        .padding(.horizontal, 12)

      // Main content: list + preview
      HStack(spacing: 0) {
        // Left: clipboard list
        ClipboardListView(
          items: viewModel.displayItems,
          selectedIndex: $viewModel.selectedIndex,
          onSelect: { index in
            viewModel.selectItem(at: index)
            viewModel.executeSelected()
          },
          onDoubleClick: { index in
            viewModel.selectItem(at: index)
            viewModel.executeSelected()
          }
        )
        .frame(width: 340)

        Rectangle()
          .fill(themeManager.current.separatorColor.opacity(0.5))
          .frame(width: 1)

        // Right: preview panel
        ClipboardPreviewView(item: viewModel.displaySelectedItem)
      }

      Rectangle()
        .fill(themeManager.current.separatorColor.opacity(0.5))
        .frame(height: 1)
        .padding(.horizontal, 12)

      // Bottom: pagination + shortcuts
      ClipboardBottomBar(
        currentPage: viewModel.currentPage,
        totalPages: viewModel.displayTotalPages,
        totalItems: viewModel.displayFilteredCount,
        onPreviousPage: { viewModel.previousPage() },
        onNextPage: { viewModel.nextPage() }
      )
    }
  }
}

// MARK: - Clipboard Search Bar

struct ClipboardSearchBar: View {
  @Binding var searchText: String
  let onKeyDown: (NSEvent) -> Bool
  let onSubmit: () -> Void
  let onTextChanged: (String) -> Void

  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: "doc.on.clipboard")
        .font(.system(size: 18, weight: .medium))
        .foregroundColor(themeManager.current.accentColor)

      SearchTextField(
        text: $searchText,
        placeholder: LocalizationManager.shared.t("clipboard.searchPlaceholder"),
        onSubmit: onSubmit,
        onKeyDown: onKeyDown,
        theme: themeManager.current,
        onTextChanged: onTextChanged
      )
      .font(.system(size: themeManager.current.fontSize - 2))

      if !searchText.isEmpty {
        Button(action: {
          searchText = ""
          onTextChanged("")
        }) {
          Image(systemName: "xmark.circle.fill")
            .foregroundColor(themeManager.current.subtitleColor)
        }
        .buttonStyle(.plain)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .frame(height: 48)
  }
}

// MARK: - Clipboard List View

struct ClipboardListView: View {
  let items: [ClipboardItem]
  @Binding var selectedIndex: Int
  let onSelect: (Int) -> Void
  let onDoubleClick: (Int) -> Void

  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    ScrollViewReader { proxy in
      ScrollView(.vertical, showsIndicators: true) {
        VStack(spacing: 0) {
          if items.isEmpty {
            Text(LocalizationManager.shared.t("clipboard.empty"))
              .font(.system(size: 13))
              .foregroundColor(themeManager.current.subtitleColor)
              .frame(maxWidth: .infinity)
              .padding(.top, 40)
          } else {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
              ClipboardRowView(
                item: item,
                isSelected: index == selectedIndex,
                index: index
              )
              .id(item.id)
              .onTapGesture(count: 2) {
                onDoubleClick(index)
              }
              .onTapGesture {
                onSelect(index)
              }
            }
          }
        }
        .padding(.vertical, 4)
      }
      .onChange(of: selectedIndex) { newIndex in
        if newIndex >= 0 && newIndex < items.count {
          withAnimation(.easeInOut(duration: 0.1)) {
            proxy.scrollTo(items[newIndex].id, anchor: .center)
          }
        }
      }
    }
  }
}

// MARK: - Clipboard Row View

struct ClipboardRowView: View {
  let item: ClipboardItem
  let isSelected: Bool
  let index: Int

  @EnvironmentObject var themeManager: ThemeManager

  private var iconName: String {
    switch item.contentType {
    case .text: return "doc.text"
    case .url: return "link"
    case .filePath: return "folder"
    case .image: return "photo"
    case .color: return "paintpalette"
    }
  }

  private var preview: String {
    if item.contentType == .image {
      return LocalizationManager.shared.t("clipboard.imageItem")
    }
    return String(item.content.prefix(80)).replacingOccurrences(of: "\n", with: " ↵ ")
  }

  private var timeAgo: String {
    let interval = Date().timeIntervalSince(item.timestamp)
    let l10n = LocalizationManager.shared
    if interval < 60 { return l10n.t("plugin.clipboard.justNow") }
    if interval < 3600 { return "\(Int(interval / 60))\(l10n.t("plugin.clipboard.minutesAgo"))" }
    if interval < 86400 { return "\(Int(interval / 3600))\(l10n.t("plugin.clipboard.hoursAgo"))" }
    return "\(Int(interval / 86400))\(l10n.t("plugin.clipboard.daysAgo"))"
  }

  var body: some View {
    HStack(spacing: 10) {
      if item.contentType == .image, let imageData = item.imageData,
        let nsImage = NSImage(data: imageData)
      {
        Image(nsImage: nsImage)
          .resizable()
          .aspectRatio(contentMode: .fill)
          .frame(width: 24, height: 24)
          .clipShape(RoundedRectangle(cornerRadius: 5))
      } else {
        Image(systemName: iconName)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(isSelected ? .white : themeManager.current.accentColor)
          .frame(width: 24, height: 24)
          .background(
            RoundedRectangle(cornerRadius: 5)
              .fill(
                isSelected
                  ? themeManager.current.accentColor.opacity(0.15)
                  : themeManager.current.separatorColor.opacity(0.3))
          )
      }

      VStack(alignment: .leading, spacing: 2) {
        Text(preview)
          .font(.system(size: 12, weight: isSelected ? .medium : .regular))
          .foregroundColor(themeManager.current.textColor)
          .lineLimit(1)

        HStack(spacing: 6) {
          if let appName = item.appName {
            Text(appName)
              .font(.system(size: 10))
              .foregroundColor(themeManager.current.subtitleColor)
          }
          Text(timeAgo)
            .font(.system(size: 10))
            .foregroundColor(themeManager.current.subtitleColor)
        }
      }

      Spacer()
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .frame(height: 42)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(isSelected ? themeManager.current.selectedColor : Color.clear)
    )
    .padding(.horizontal, 4)
    .contentShape(Rectangle())
  }
}

// MARK: - Clipboard Preview View

struct ClipboardPreviewView: View {
  let item: ClipboardItem?

  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if let item = item {
        // Header
        HStack(spacing: 8) {
          Image(systemName: "eye")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(themeManager.current.accentColor)
          Text(LocalizationManager.shared.t("clipboard.preview"))
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(themeManager.current.textColor)

          Spacer()

          // Metadata
          if let appName = item.appName {
            Text(appName)
              .font(.system(size: 10))
              .foregroundColor(themeManager.current.subtitleColor)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(
                RoundedRectangle(cornerRadius: 4)
                  .fill(themeManager.current.separatorColor.opacity(0.5))
              )
          }

          Text(contentTypeLabel(item.contentType))
            .font(.system(size: 10))
            .foregroundColor(themeManager.current.subtitleColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
              RoundedRectangle(cornerRadius: 4)
                .fill(themeManager.current.separatorColor.opacity(0.5))
            )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)

        Rectangle()
          .fill(themeManager.current.separatorColor.opacity(0.3))
          .frame(height: 1)
          .padding(.horizontal, 10)

        // Content
        if item.contentType == .image, let imageData = item.imageData,
          let nsImage = NSImage(data: imageData)
        {
          VStack {
            Spacer()
            Image(nsImage: nsImage)
              .resizable()
              .aspectRatio(contentMode: .fit)
              .frame(maxWidth: 280, maxHeight: 280)
              .clipShape(RoundedRectangle(cornerRadius: 6))
            Spacer()
          }
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .padding(14)
        } else {
          ScrollView(.vertical, showsIndicators: true) {
            Text(item.content)
              .font(.system(size: 12, design: .monospaced))
              .foregroundColor(themeManager.current.textColor)
              .frame(maxWidth: .infinity, alignment: .topLeading)
              .padding(14)
              .textSelection(.enabled)
          }
        }

        Rectangle()
          .fill(themeManager.current.separatorColor.opacity(0.3))
          .frame(height: 1)
          .padding(.horizontal, 10)

        // Footer
        HStack {
          if item.contentType == .image, let imageData = item.imageData,
            let nsImage = NSImage(data: imageData)
          {
            let size = nsImage.size
            Text("\(Int(size.width))×\(Int(size.height)) px")
              .font(.system(size: 10))
              .foregroundColor(themeManager.current.subtitleColor)
          } else {
            Text("\(item.content.count) \(LocalizationManager.shared.t("clipboard.characters"))")
              .font(.system(size: 10))
              .foregroundColor(themeManager.current.subtitleColor)
          }

          Spacer()

          Text(LocalizationManager.shared.t("clipboard.enterToPaste"))
            .font(.system(size: 10))
            .foregroundColor(themeManager.current.subtitleColor)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 6)

      } else {
        // Empty state
        VStack(spacing: 8) {
          Image(systemName: "doc.on.clipboard")
            .font(.system(size: 28))
            .foregroundColor(themeManager.current.subtitleColor.opacity(0.5))
          Text(LocalizationManager.shared.t("clipboard.selectToPreview"))
            .font(.system(size: 12))
            .foregroundColor(themeManager.current.subtitleColor)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
  }

  private func contentTypeLabel(_ type: ClipboardContentType) -> String {
    switch type {
    case .text: return "Text"
    case .url: return "URL"
    case .filePath: return "Path"
    case .image: return "Image"
    case .color: return "Color"
    }
  }
}

// MARK: - Bottom Bar

struct ClipboardBottomBar: View {
  let currentPage: Int
  let totalPages: Int
  let totalItems: Int
  let onPreviousPage: () -> Void
  let onNextPage: () -> Void

  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    HStack(spacing: 12) {
      // Shortcuts hint
      HStack(spacing: 8) {
        ShortcutHint(key: "↑↓", label: LocalizationManager.shared.t("clipboard.navigate"))
        ShortcutHint(key: "⏎", label: LocalizationManager.shared.t("clipboard.paste"))
        ShortcutHint(key: "⌘←→", label: LocalizationManager.shared.t("clipboard.page"))
        ShortcutHint(key: "ESC", label: LocalizationManager.shared.t("clipboard.close"))
      }

      Spacer()

      // Page indicator
      HStack(spacing: 6) {
        Text("\(totalItems) \(LocalizationManager.shared.t("clipboard.items"))")
          .font(.system(size: 10))
          .foregroundColor(themeManager.current.subtitleColor)

        if totalPages > 1 {
          Button(action: onPreviousPage) {
            Image(systemName: "chevron.left")
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(
                currentPage > 0
                  ? themeManager.current.accentColor
                  : themeManager.current.subtitleColor.opacity(0.4)
              )
          }
          .buttonStyle(.plain)
          .disabled(currentPage == 0)

          Text("\(currentPage + 1)/\(totalPages)")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundColor(themeManager.current.textColor)

          Button(action: onNextPage) {
            Image(systemName: "chevron.right")
              .font(.system(size: 9, weight: .bold))
              .foregroundColor(
                currentPage < totalPages - 1
                  ? themeManager.current.accentColor
                  : themeManager.current.subtitleColor.opacity(0.4)
              )
          }
          .buttonStyle(.plain)
          .disabled(currentPage >= totalPages - 1)
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 8)
    .frame(height: 32)
  }
}

struct ShortcutHint: View {
  let key: String
  let label: String

  @EnvironmentObject var themeManager: ThemeManager

  var body: some View {
    HStack(spacing: 3) {
      Text(key)
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundColor(themeManager.current.subtitleColor)
        .padding(.horizontal, 4)
        .padding(.vertical, 1)
        .background(
          RoundedRectangle(cornerRadius: 3)
            .fill(themeManager.current.separatorColor.opacity(0.5))
        )
      Text(label)
        .font(.system(size: 9))
        .foregroundColor(themeManager.current.subtitleColor.opacity(0.7))
    }
  }
}
