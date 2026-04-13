import Combine
import Foundation

// MARK: - AI Chat Engine

final class AIChatEngine: ObservableObject {
  static let shared = AIChatEngine()

  @Published var config: AIConfig {
    didSet { saveConfig() }
  }
  @Published var currentSession: ChatSession
  @Published var sessions: [ChatSession] = []
  @Published var isGenerating = false
  @Published var streamingContent = ""

  private var currentTask: Task<Void, Never>?
  private let configKey = "AIConfig_v2"
  private let sessionsKey = "AIChatSessions"

  private init() {
    self.config = Self.loadConfig()
    self.currentSession = ChatSession()
    self.sessions = Self.loadSessions()
  }

  // MARK: - Active Provider/Model Info

  var activeProviderName: String {
    config.activeProvider?.name ?? "未配置"
  }

  var activeModelName: String {
    config.activeModel?.name ?? "未选择"
  }

  var allAvailableModels: [(provider: AIProviderConfig, model: AIModelEntry)] {
    config.providers.filter(\.isEnabled).flatMap { p in
      p.models.map { m in (provider: p, model: m) }
    }
  }

  /// Switch to a different provider+model on the fly
  func switchTo(providerId: String, modelId: String) {
    config.activeProviderId = providerId
    config.activeModelId = modelId
  }

  // MARK: - Public API

  func send(message: String, attachments: [ChatAttachment] = []) async {
    guard !message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
    guard let providerConfig = config.activeProvider else {
      let errorMsg = ChatMessage(role: .assistant, content: "⚠️ 请先在设置中配置 AI 服务商")
      await MainActor.run { currentSession.addMessage(errorMsg) }
      return
    }

    let userMessage = ChatMessage(role: .user, content: message, attachments: attachments)
    await MainActor.run {
      currentSession.addMessage(userMessage)
      currentSession.providerName = providerConfig.name
      isGenerating = true
      streamingContent = ""
    }

    do {
      let provider = makeProvider(for: providerConfig)
      let messages = buildMessages(attachments: attachments, providerConfig: providerConfig)

      if config.streamResponse {
        var fullContent = ""
        let stream = try await provider.streamChat(messages: messages, config: config)

        for try await chunk in stream {
          guard !Task.isCancelled else { throw AIError.cancelled }
          fullContent += chunk.content
          await MainActor.run { self.streamingContent = fullContent }
        }

        let assistantMessage = ChatMessage(role: .assistant, content: fullContent)
        await MainActor.run {
          currentSession.addMessage(assistantMessage)
          isGenerating = false
          streamingContent = ""
          saveSessions()
        }
      } else {
        let response = try await provider.chat(messages: messages, config: config)
        let assistantMessage = ChatMessage(role: .assistant, content: response)
        await MainActor.run {
          currentSession.addMessage(assistantMessage)
          isGenerating = false
          saveSessions()
        }
      }
    } catch {
      let errorMessage = ChatMessage(
        role: .assistant, content: "⚠️ 错误: \(error.localizedDescription)")
      await MainActor.run {
        currentSession.addMessage(errorMessage)
        isGenerating = false
        streamingContent = ""
      }
    }
  }

  func quickAsk(question: String) async -> String {
    guard let providerConfig = config.activeProvider else {
      return "Error: No AI provider configured"
    }
    let provider = makeProvider(for: providerConfig)
    let messages: [[String: Any]] = [
      ["role": "system", "content": config.systemPrompt],
      ["role": "user", "content": question],
    ]
    let stringMessages = messages.map { dict -> [String: String] in
      dict.compactMapValues { $0 as? String }
    }

    do {
      return try await provider.chat(messages: stringMessages, config: config)
    } catch {
      return "Error: \(error.localizedDescription)"
    }
  }

  func stopGenerating() {
    currentTask?.cancel()
    currentTask = nil
    isGenerating = false
    streamingContent = ""
  }

  func newSession() {
    if !currentSession.messages.isEmpty {
      if let firstUser = currentSession.messages.first(where: { $0.role == .user }) {
        currentSession.title = String(firstUser.content.prefix(40))
      }
      sessions.insert(currentSession, at: 0)
      saveSessions()
    }
    currentSession = ChatSession()
  }

  func clearCurrentSession() {
    currentSession = ChatSession()
  }

  func loadSession(_ session: ChatSession) {
    if !currentSession.messages.isEmpty {
      sessions.insert(currentSession, at: 0)
    }
    currentSession = session
    sessions.removeAll { $0.id == session.id }
    saveSessions()
  }

  func deleteSession(_ session: ChatSession) {
    sessions.removeAll { $0.id == session.id }
    saveSessions()
  }

  func availableModels() -> [AIModel] {
    // Legacy compatibility
    return []
  }

  func testConnection() async -> Result<String, AIError> {
    guard let providerConfig = config.activeProvider else {
      return .failure(.noProviderConfigured)
    }
    let provider = makeProvider(for: providerConfig)
    do {
      let response = try await provider.chat(
        messages: [["role": "user", "content": "Say 'ok'"]],
        config: config
      )
      return .success(response)
    } catch let error as AIError {
      return .failure(error)
    } catch {
      return .failure(.networkError(error.localizedDescription))
    }
  }

  func testProvider(_ providerConfig: AIProviderConfig, modelId: String) async -> Result<
    String, AIError
  > {
    let provider = makeProvider(for: providerConfig)
    // Temporarily build a config for this provider
    var testConfig = config
    testConfig.activeProviderId = providerConfig.id
    testConfig.activeModelId = modelId
    do {
      let response = try await provider.chat(
        messages: [["role": "user", "content": "Say 'ok'"]],
        config: testConfig
      )
      return .success(response)
    } catch let error as AIError {
      return .failure(error)
    } catch {
      return .failure(.networkError(error.localizedDescription))
    }
  }

  // MARK: - Private

  private func makeProvider(for providerConfig: AIProviderConfig) -> AIProviderProtocol {
    switch providerConfig.protocolType {
    case .openaiCompatible:
      return OpenAIProvider()
    case .anthropicCompatible:
      return AnthropicProvider()
    }
  }

  private func buildMessages(attachments: [ChatAttachment] = [], providerConfig: AIProviderConfig)
    -> [[String: String]]
  {
    var messages: [[String: String]] = []

    if !config.systemPrompt.isEmpty {
      messages.append(["role": "system", "content": config.systemPrompt])
    }

    for msg in currentSession.messages {
      var content = msg.content
      // If there are image attachments, add base64 description for Anthropic/OpenAI vision
      if !msg.attachments.isEmpty {
        let imageDescs = msg.attachments.filter(\.isImage).map { "[图片: \($0.fileName)]" }
        if !imageDescs.isEmpty {
          content += "\n" + imageDescs.joined(separator: "\n")
        }
      }
      messages.append(["role": msg.role.rawValue, "content": content])
    }

    return messages
  }

  // MARK: - Persistence

  private func saveConfig() {
    if let data = try? JSONEncoder().encode(config) {
      UserDefaults.standard.set(data, forKey: configKey)
    }
  }

  private static func loadConfig() -> AIConfig {
    guard let data = UserDefaults.standard.data(forKey: "AIConfig_v2"),
      let config = try? JSONDecoder().decode(AIConfig.self, from: data)
    else {
      return AIConfig.default
    }
    return config
  }

  private func saveSessions() {
    let toSave = Array(sessions.prefix(50))
    if let data = try? JSONEncoder().encode(toSave) {
      UserDefaults.standard.set(data, forKey: sessionsKey)
    }
  }

  private static func loadSessions() -> [ChatSession] {
    guard let data = UserDefaults.standard.data(forKey: "AIChatSessions"),
      let sessions = try? JSONDecoder().decode([ChatSession].self, from: data)
    else {
      return []
    }
    return sessions
  }
}
