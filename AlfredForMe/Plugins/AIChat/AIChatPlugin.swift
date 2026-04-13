import AppKit
import Foundation

// MARK: - AI Chat Plugin

final class AIChatPlugin: SearchPlugin {
  let id = "ai-chat"
  let name = "AI Chat"
  var isEnabled = true
  var keyword: String? = "ai"

  private let engine = AIChatEngine.shared

  func canHandle(query: SearchQuery) -> Bool {
    let text = query.raw.lowercased().trimmingCharacters(in: .whitespaces)
    return text.hasPrefix("ai ") || text == "ai"
  }

  func search(query: SearchQuery) async -> [SearchResult] {
    let text = query.raw.trimmingCharacters(in: .whitespaces)

    // If just "ai" keyword, show open chat option
    if text.lowercased() == "ai" {
      return [
        SearchResult(
          id: "ai-open-chat",
          title: LocalizationManager.shared.t("ai.open_chat"),
          subtitle: LocalizationManager.shared.t("ai.open_chat_hint"),
          icon: NSImage(
            systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil),
          category: .general,
          relevanceScore: 1.0,
          plugin: id,
          userData: ["action": "open-chat"]
        ),
        SearchResult(
          id: "ai-new-session",
          title: LocalizationManager.shared.t("ai.new_session"),
          subtitle: LocalizationManager.shared.t("ai.new_session_hint"),
          icon: NSImage(systemSymbolName: "plus.bubble", accessibilityDescription: nil),
          category: .general,
          relevanceScore: 0.9,
          plugin: id,
          userData: ["action": "new-session"]
        ),
      ]
    }

    // Extract the question after "ai "
    let question = String(text.dropFirst(3)).trimmingCharacters(in: .whitespaces)
    guard !question.isEmpty else { return [] }

    return [
      SearchResult(
        id: "ai-quick-\(question.hashValue)",
        title: "\(LocalizationManager.shared.t("ai.ask")): \(question)",
        subtitle: "\(engine.activeProviderName) / \(engine.activeModelName)",
        icon: NSImage(systemSymbolName: "sparkles", accessibilityDescription: nil),
        category: .general,
        relevanceScore: 1.0,
        plugin: id,
        userData: ["action": "quick-ask", "question": question]
      ),
      SearchResult(
        id: "ai-chat-\(question.hashValue)",
        title: "\(LocalizationManager.shared.t("ai.chat_with")): \(question)",
        subtitle: LocalizationManager.shared.t("ai.open_in_chat"),
        icon: NSImage(
          systemSymbolName: "bubble.left.and.bubble.right", accessibilityDescription: nil),
        category: .general,
        relevanceScore: 0.9,
        plugin: id,
        userData: ["action": "chat-ask", "question": question]
      ),
    ]
  }

  func execute(result: SearchResult) async {
    let action = result.userData["action"] ?? ""

    switch action {
    case "open-chat":
      await MainActor.run {
        AIChatWindowController.shared.showChatWindow()
      }

    case "new-session":
      await MainActor.run {
        engine.newSession()
        AIChatWindowController.shared.showChatWindow()
      }

    case "quick-ask":
      if let question = result.userData["question"] {
        let answer = await engine.quickAsk(question: question)
        await MainActor.run {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(answer, forType: .string)
        }
      }

    case "chat-ask":
      if let question = result.userData["question"] {
        await MainActor.run {
          AIChatWindowController.shared.showChatWindow()
        }
        await engine.send(message: question)
      }

    default:
      break
    }
  }

  func actions(for result: SearchResult) -> [ResultAction] {
    return [
      ResultAction(
        id: "copy",
        title: LocalizationManager.shared.t("action.copy"),
        icon: NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: nil),
        handler: {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(result.title, forType: .string)
        }
      )
    ]
  }
}
