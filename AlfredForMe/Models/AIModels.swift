import Foundation

// MARK: - AI Protocol Type

enum AIProtocolType: String, CaseIterable, Codable, Identifiable {
  case openaiCompatible = "openai"
  case anthropicCompatible = "anthropic"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .openaiCompatible: return "OpenAI 兼容"
    case .anthropicCompatible: return "Anthropic 兼容"
    }
  }

  var description: String {
    switch self {
    case .openaiCompatible:
      return "兼容 OpenAI Chat Completions API（OpenAI、DeepSeek、Moonshot、通义千问、本地 Ollama 等）"
    case .anthropicCompatible: return "兼容 Anthropic Messages API（Claude 系列）"
    }
  }
}

// MARK: - AI Provider (user-configured endpoint)

struct AIProviderConfig: Identifiable, Codable, Hashable {
  let id: String
  var name: String
  var protocolType: AIProtocolType
  var endpoint: String
  var apiKey: String
  var models: [AIModelEntry]
  var isEnabled: Bool

  init(
    name: String, protocolType: AIProtocolType, endpoint: String, apiKey: String = "",
    models: [AIModelEntry] = [], isEnabled: Bool = true
  ) {
    self.id = UUID().uuidString
    self.name = name
    self.protocolType = protocolType
    self.endpoint = endpoint
    self.apiKey = apiKey
    self.models = models
    self.isEnabled = isEnabled
  }

  static let builtInExamples: [AIProviderConfig] = [
    AIProviderConfig(
      name: "OpenAI",
      protocolType: .openaiCompatible,
      endpoint: "https://api.openai.com/v1",
      models: [
        AIModelEntry(id: "gpt-4o", name: "GPT-4o"),
        AIModelEntry(id: "gpt-4o-mini", name: "GPT-4o Mini"),
        AIModelEntry(id: "gpt-4-turbo", name: "GPT-4 Turbo"),
        AIModelEntry(id: "o1", name: "o1"),
      ]
    ),
    AIProviderConfig(
      name: "Anthropic",
      protocolType: .anthropicCompatible,
      endpoint: "https://api.anthropic.com/v1",
      models: [
        AIModelEntry(id: "claude-sonnet-4-20250514", name: "Claude Sonnet 4"),
        AIModelEntry(id: "claude-3-5-sonnet-20241022", name: "Claude 3.5 Sonnet"),
        AIModelEntry(id: "claude-3-5-haiku-20241022", name: "Claude 3.5 Haiku"),
      ]
    ),
    AIProviderConfig(
      name: "DeepSeek",
      protocolType: .openaiCompatible,
      endpoint: "https://api.deepseek.com/v1",
      models: [
        AIModelEntry(id: "deepseek-chat", name: "DeepSeek V3"),
        AIModelEntry(id: "deepseek-reasoner", name: "DeepSeek R1"),
      ]
    ),
  ]

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: AIProviderConfig, rhs: AIProviderConfig) -> Bool {
    lhs.id == rhs.id
  }
}

// MARK: - AI Model Entry (simplified)

struct AIModelEntry: Identifiable, Codable, Hashable {
  let id: String
  var name: String

  init(id: String, name: String) {
    self.id = id
    self.name = name
  }
}

// MARK: - AI Configuration

struct AIConfig: Codable {
  var providers: [AIProviderConfig]
  var activeProviderId: String
  var activeModelId: String
  var temperature: Double
  var topP: Double
  var maxTokens: Int
  var timeout: Int
  var systemPrompt: String
  var streamResponse: Bool

  var activeProvider: AIProviderConfig? {
    providers.first { $0.id == activeProviderId }
  }

  var activeModel: AIModelEntry? {
    activeProvider?.models.first { $0.id == activeModelId }
  }

  static let `default` = AIConfig(
    providers: [],
    activeProviderId: "",
    activeModelId: "",
    temperature: 0.7,
    topP: 1.0,
    maxTokens: 4096,
    timeout: 60,
    systemPrompt: "You are a helpful assistant. Respond concisely and accurately.",
    streamResponse: true
  )
}

// MARK: - Chat Message

struct ChatMessage: Identifiable, Codable {
  let id: String
  var role: ChatRole
  var content: String
  let timestamp: Date
  var attachments: [ChatAttachment]

  init(role: ChatRole, content: String, attachments: [ChatAttachment] = []) {
    self.id = UUID().uuidString
    self.role = role
    self.content = content
    self.timestamp = Date()
    self.attachments = attachments
  }
}

enum ChatRole: String, Codable {
  case system
  case user
  case assistant
}

// MARK: - Chat Attachment

struct ChatAttachment: Identifiable, Codable {
  let id: String
  var fileName: String
  var mimeType: String
  var data: Data

  init(fileName: String, mimeType: String, data: Data) {
    self.id = UUID().uuidString
    self.fileName = fileName
    self.mimeType = mimeType
    self.data = data
  }

  var isImage: Bool {
    mimeType.hasPrefix("image/")
  }

  var base64: String {
    data.base64EncodedString()
  }
}

// MARK: - Chat Session

struct ChatSession: Identifiable, Codable {
  let id: String
  var title: String
  var messages: [ChatMessage]
  let createdAt: Date
  var updatedAt: Date
  var providerName: String?

  init(title: String = "New Chat") {
    self.id = UUID().uuidString
    self.title = title
    self.messages = []
    self.createdAt = Date()
    self.updatedAt = Date()
  }

  mutating func addMessage(_ message: ChatMessage) {
    messages.append(message)
    updatedAt = Date()
  }
}

// MARK: - AI Response

struct AIStreamChunk {
  let content: String
  let isComplete: Bool
}

enum AIError: Error, LocalizedError {
  case noAPIKey
  case invalidEndpoint
  case networkError(String)
  case apiError(String)
  case decodingError(String)
  case cancelled
  case unauthorized
  case rateLimited
  case modelNotFound
  case invalidResponse
  case configurationError(String)
  case noProviderConfigured

  var errorDescription: String? {
    switch self {
    case .noAPIKey: return "API Key 未配置"
    case .invalidEndpoint: return "无效的 API 端点"
    case .networkError(let msg): return "网络错误: \(msg)"
    case .apiError(let msg): return "API 错误: \(msg)"
    case .decodingError(let msg): return "解码错误: \(msg)"
    case .cancelled: return "请求已取消"
    case .unauthorized: return "未授权 - 请检查 API Key"
    case .rateLimited: return "请求频率受限"
    case .modelNotFound: return "模型未找到"
    case .invalidResponse: return "无效的响应"
    case .configurationError(let msg): return "配置错误: \(msg)"
    case .noProviderConfigured: return "未配置 AI 服务商"
    }
  }
}

// MARK: - Legacy compatibility

enum AIProvider: String, CaseIterable, Codable, Identifiable {
  case openai = "openai"
  case anthropic = "anthropic"
  case google = "google"
  case ollama = "ollama"
  case custom = "custom"

  var id: String { rawValue }

  var displayName: String {
    switch self {
    case .openai: return "OpenAI"
    case .anthropic: return "Anthropic"
    case .google: return "Google"
    case .ollama: return "Ollama"
    case .custom: return "Custom"
    }
  }

  var defaultEndpoint: String {
    switch self {
    case .openai: return "https://api.openai.com/v1"
    case .anthropic: return "https://api.anthropic.com/v1"
    case .google: return "https://generativelanguage.googleapis.com/v1beta"
    case .ollama: return "http://localhost:11434"
    case .custom: return ""
    }
  }

  var defaultModels: [AIModel] { [] }
  var requiresAPIKey: Bool { true }
}

struct AIModel: Identifiable, Codable, Hashable {
  let id: String
  var name: String
  var provider: AIProvider
  var contextWindow: Int
  var isCustom: Bool

  init(
    id: String, name: String, provider: AIProvider, contextWindow: Int = 8192,
    isCustom: Bool = false
  ) {
    self.id = id
    self.name = name
    self.provider = provider
    self.contextWindow = contextWindow
    self.isCustom = isCustom
  }
}
