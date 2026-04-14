import AppKit
import SwiftUI
import UniformTypeIdentifiers

// MARK: - AI Chat View

struct AIChatView: View {
  @ObservedObject var engine: AIChatEngine
  @ObservedObject var l10n = LocalizationManager.shared
  @State private var inputText = ""
  @State private var showSessionList = false
  @State private var attachments: [ChatAttachment] = []
  @FocusState private var isInputFocused: Bool

  var body: some View {
    VStack(spacing: 0) {
      chatHeader
      Divider()
      messagesArea
      Divider()
      inputArea
    }
    .frame(minWidth: 500, minHeight: 400)
    .background(Color(nsColor: .windowBackgroundColor))
  }

  // MARK: - Header

  private var chatHeader: some View {
    HStack {
      Button(action: { showSessionList.toggle() }) {
        Image(systemName: "clock.arrow.circlepath")
          .font(.system(size: 14))
      }
      .buttonStyle(.borderless)
      .popover(isPresented: $showSessionList) {
        sessionListPopover
      }
      .help(l10n.t("ai.history"))

      Spacer()

      // Current model display (read-only, configure in settings)
      HStack(spacing: 4) {
        Image(systemName: "sparkles")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
        Text("\(engine.activeProviderName) / \(engine.activeModelName)")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 4)
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(6)

      Spacer()

      Button(action: { engine.newSession() }) {
        Image(systemName: "plus.bubble")
          .font(.system(size: 14))
      }
      .buttonStyle(.borderless)
      .help(l10n.t("ai.new_session"))
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
  }

  // MARK: - Model Picker

  // MARK: - Session List

  private var sessionListPopover: some View {
    VStack(alignment: .leading, spacing: 0) {
      Text(l10n.t("ai.history"))
        .font(.headline)
        .padding(8)
      Divider()

      if engine.sessions.isEmpty {
        Text(l10n.t("ai.no_history"))
          .foregroundColor(.secondary)
          .padding()
      } else {
        ScrollView {
          LazyVStack(alignment: .leading, spacing: 2) {
            ForEach(engine.sessions) { session in
              sessionRow(session)
            }
          }
          .padding(4)
        }
        .frame(maxHeight: 300)
      }
    }
    .frame(width: 280)
  }

  private func sessionRow(_ session: ChatSession) -> some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(session.title)
          .font(.system(size: 13))
          .lineLimit(1)
        HStack(spacing: 4) {
          if let pName = session.providerName {
            Text(pName)
              .font(.system(size: 10))
              .foregroundColor(.accentColor)
          }
          Text(session.updatedAt.formatted(date: .abbreviated, time: .shortened))
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Button(action: { engine.deleteSession(session) }) {
        Image(systemName: "trash")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .buttonStyle(.borderless)
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .contentShape(Rectangle())
    .onTapGesture {
      engine.loadSession(session)
      showSessionList = false
    }
    .cornerRadius(4)
  }

  // MARK: - Messages Area

  private var messagesArea: some View {
    ScrollViewReader { proxy in
      ScrollView {
        LazyVStack(alignment: .leading, spacing: 12) {
          if engine.currentSession.messages.isEmpty {
            emptyStateView
          }

          ForEach(engine.currentSession.messages) { message in
            MessageBubbleView(message: message)
              .id(message.id)
          }

          if engine.isGenerating && !engine.streamingContent.isEmpty {
            streamingBubble
              .id("streaming")
          }

          if engine.isGenerating && engine.streamingContent.isEmpty {
            typingIndicator
              .id("typing")
          }
        }
        .padding()
      }
      .onChange(of: engine.currentSession.messages.count) { _ in
        withAnimation {
          if let last = engine.currentSession.messages.last {
            proxy.scrollTo(last.id, anchor: .bottom)
          }
        }
      }
      .onChange(of: engine.streamingContent) { _ in
        withAnimation {
          proxy.scrollTo("streaming", anchor: .bottom)
        }
      }
    }
  }

  private var emptyStateView: some View {
    VStack(spacing: 16) {
      Spacer()

      Image(nsImage: NSApp.applicationIconImage ?? NSImage())
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 48, height: 48)

      Text(l10n.t("ai.startChat"))
        .font(.system(size: 20, weight: .semibold))

      Spacer()
    }
    .frame(maxWidth: .infinity)
  }

  private var streamingBubble: some View {
    HStack(alignment: .top, spacing: 8) {
      Image(systemName: "sparkles")
        .font(.system(size: 14))
        .foregroundColor(.accentColor)
        .frame(width: 24)

      Text(engine.streamingContent)
        .font(.system(size: 13))
        .textSelection(.enabled)
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(12)

      Spacer(minLength: 40)
    }
  }

  private var typingIndicator: some View {
    HStack(spacing: 4) {
      Image(systemName: "sparkles")
        .font(.system(size: 14))
        .foregroundColor(.accentColor)
        .frame(width: 24)

      HStack(spacing: 4) {
        ForEach(0..<3) { i in
          Circle()
            .fill(Color.secondary)
            .frame(width: 6, height: 6)
            .opacity(0.4)
            .animation(
              .easeInOut(duration: 0.6)
                .repeatForever()
                .delay(Double(i) * 0.2),
              value: engine.isGenerating
            )
        }
      }
      .padding(10)
      .background(Color(nsColor: .controlBackgroundColor))
      .cornerRadius(12)

      Spacer()
    }
  }

  // MARK: - Input Area

  private var inputArea: some View {
    VStack(spacing: 0) {
      // Attachment preview
      if !attachments.isEmpty {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(attachments) { att in
              HStack(spacing: 4) {
                Image(systemName: att.isImage ? "photo" : "doc")
                  .font(.system(size: 10))
                Text(att.fileName)
                  .font(.system(size: 11))
                  .lineLimit(1)
                Button(action: {
                  attachments.removeAll { $0.id == att.id }
                }) {
                  Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
                .buttonStyle(.borderless)
              }
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(Color(nsColor: .controlBackgroundColor))
              .cornerRadius(6)
            }
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
        }
      }

      VStack(spacing: 0) {
        // Text input
        ChatInputTextField(
          text: $inputText,
          placeholder: l10n.t("ai.inputPlaceholder"),
          onSubmit: sendMessage
        )
        .frame(minHeight: 24, maxHeight: 80)
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 6)

        // Bottom row: attachment + send
        HStack {
          Button(action: pickAttachment) {
            Image(systemName: "paperclip")
              .font(.system(size: 15))
              .foregroundColor(.secondary)
          }
          .buttonStyle(.borderless)
          .help(l10n.t("ai.addAttachment"))

          Spacer()

          if engine.isGenerating {
            Button(action: { engine.stopGenerating() }) {
              Image(systemName: "stop.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help(l10n.t("ai.stop"))
          } else {
            Button(action: sendMessage) {
              Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 22))
                .foregroundColor(
                  inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                    ? Color.secondary.opacity(0.4) : .accentColor)
            }
            .buttonStyle(.borderless)
            .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .help(l10n.t("ai.send"))
          }
        }
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
      }
      .background(
        RoundedRectangle(cornerRadius: 16)
          .fill(Color(nsColor: .controlBackgroundColor))
      )
      .overlay(
        RoundedRectangle(cornerRadius: 16)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
      )
      .padding(.horizontal, 12)
      .padding(.vertical, 10)
    }
  }

  private func sendMessage() {
    let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !text.isEmpty else { return }
    let currentAttachments = attachments
    inputText = ""
    attachments = []
    Task {
      await engine.send(message: text, attachments: currentAttachments)
    }
  }

  private func pickAttachment() {
    let panel = NSOpenPanel()
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowsMultipleSelection = true
    panel.allowedContentTypes = [.image, .plainText, .pdf, .json]
    panel.begin { response in
      guard response == .OK else { return }
      for url in panel.urls {
        guard let data = try? Data(contentsOf: url) else { continue }
        let fileName = url.lastPathComponent
        let mimeType: String
        if let uti = UTType(filenameExtension: url.pathExtension) {
          mimeType = uti.preferredMIMEType ?? "application/octet-stream"
        } else {
          mimeType = "application/octet-stream"
        }
        let attachment = ChatAttachment(fileName: fileName, mimeType: mimeType, data: data)
        attachments.append(attachment)
      }
    }
  }
}

// MARK: - Message Bubble

struct MessageBubbleView: View {
  let message: ChatMessage

  var body: some View {
    HStack(alignment: .top, spacing: 8) {
      if message.role == .user {
        Spacer(minLength: 40)
      }

      if message.role != .user {
        Image(systemName: message.role == .assistant ? "sparkles" : "gearshape")
          .font(.system(size: 14))
          .foregroundColor(message.role == .assistant ? .accentColor : .orange)
          .frame(width: 24)
      }

      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
        // Attachment previews
        if !message.attachments.isEmpty {
          HStack(spacing: 4) {
            ForEach(message.attachments) { att in
              HStack(spacing: 3) {
                Image(systemName: att.isImage ? "photo" : "doc")
                  .font(.system(size: 10))
                Text(att.fileName)
                  .font(.system(size: 10))
              }
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.15))
              .cornerRadius(4)
            }
          }
        }

        Text(message.content)
          .font(.system(size: 13))
          .textSelection(.enabled)
          .padding(10)
          .background(
            message.role == .user
              ? Color.accentColor.opacity(0.15)
              : Color(nsColor: .controlBackgroundColor)
          )
          .cornerRadius(12)

        Text(message.timestamp.formatted(date: .omitted, time: .shortened))
          .font(.caption2)
          .foregroundColor(.secondary.opacity(0.6))
      }

      if message.role == .user {
        Image(systemName: "person.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(.secondary)
          .frame(width: 24)
      }

      if message.role != .user {
        Spacer(minLength: 40)
      }
    }
    .contextMenu {
      Button(LocalizationManager.shared.t("action.copy")) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
      }
    }
  }
}

// MARK: - Chat Input TextField (Enter to send, Shift+Enter for newline)

struct ChatInputTextField: NSViewRepresentable {
  @Binding var text: String
  var placeholder: String
  var onSubmit: () -> Void

  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  func makeNSView(context: Context) -> NSScrollView {
    let scrollView = NSTextView.scrollableTextView()
    let textView = scrollView.documentView as! NSTextView
    textView.delegate = context.coordinator
    textView.font = .systemFont(ofSize: 13)
    textView.textColor = .labelColor
    textView.backgroundColor = .clear
    textView.drawsBackground = false
    textView.isRichText = false
    textView.isAutomaticQuoteSubstitutionEnabled = false
    textView.textContainerInset = NSSize(width: 0, height: 2)
    textView.textContainer?.lineFragmentPadding = 0
    scrollView.drawsBackground = false
    scrollView.hasVerticalScroller = false
    scrollView.borderType = .noBorder
    return scrollView
  }

  func updateNSView(_ scrollView: NSScrollView, context: Context) {
    let textView = scrollView.documentView as! NSTextView
    context.coordinator.parent = self
    if textView.string != text {
      textView.string = text
    }
    // Update placeholder visibility
    context.coordinator.updatePlaceholder(textView)
  }

  class Coordinator: NSObject, NSTextViewDelegate {
    var parent: ChatInputTextField
    var placeholderLabel: NSTextField?

    init(_ parent: ChatInputTextField) {
      self.parent = parent
    }

    func textDidChange(_ notification: Notification) {
      guard let textView = notification.object as? NSTextView else { return }
      parent.text = textView.string
      updatePlaceholder(textView)
    }

    func updatePlaceholder(_ textView: NSTextView) {
      if textView.string.isEmpty {
        if placeholderLabel == nil {
          let label = NSTextField(labelWithString: parent.placeholder)
          label.font = .systemFont(ofSize: 13)
          label.textColor = .placeholderTextColor
          label.isEditable = false
          label.isBordered = false
          label.drawsBackground = false
          label.translatesAutoresizingMaskIntoConstraints = false
          textView.addSubview(label)
          NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(
              equalTo: textView.leadingAnchor,
              constant: textView.textContainerInset.width
                + (textView.textContainer?.lineFragmentPadding ?? 0)),
            label.topAnchor.constraint(
              equalTo: textView.topAnchor, constant: textView.textContainerInset.height),
          ])
          placeholderLabel = label
        }
        placeholderLabel?.stringValue = parent.placeholder
        placeholderLabel?.isHidden = false
      } else {
        placeholderLabel?.isHidden = true
      }
    }

    func textView(
      _ textView: NSTextView, doCommandBy commandSelector: Selector
    ) -> Bool {
      if commandSelector == #selector(NSResponder.insertNewline(_:)) {
        // Shift+Enter → newline, Enter → send
        if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
          textView.insertNewlineIgnoringFieldEditor(nil)
          return true
        }
        parent.onSubmit()
        return true
      }
      return false
    }
  }
}

// MARK: - AI Chat Window Controller

final class AIChatWindowController: NSObject {
  static let shared = AIChatWindowController()
  private var window: NSWindow?

  func showChatWindow() {
    if let window = window {
      window.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    let chatView = AIChatView(engine: AIChatEngine.shared)
    let hostingView = NSHostingView(rootView: chatView)

    let win = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    win.contentView = hostingView
    win.title = LocalizationManager.shared.t("ai.chat")
    win.center()
    win.setFrameAutosaveName("AIChatWindow")
    win.isReleasedWhenClosed = false
    win.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)

    self.window = win
  }
}
