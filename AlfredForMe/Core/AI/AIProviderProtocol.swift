import Foundation

// MARK: - AI Provider Protocol

protocol AIProviderProtocol {
  func chat(messages: [[String: String]], config: AIConfig) async throws -> String
  func streamChat(messages: [[String: String]], config: AIConfig) async throws
    -> AsyncThrowingStream<AIStreamChunk, Error>
}

// MARK: - Async Stream Line Parser

struct SSELineParser {
  static func lines(from stream: URLSession.AsyncBytes) -> AsyncThrowingStream<String, Error> {
    AsyncThrowingStream { continuation in
      Task {
        var byteBuffer = Data()
        do {
          for try await byte in stream {
            if byte == UInt8(ascii: "\n") {
              if !byteBuffer.isEmpty {
                if let line = String(data: byteBuffer, encoding: .utf8) {
                  continuation.yield(line)
                }
                byteBuffer.removeAll(keepingCapacity: true)
              }
            } else {
              byteBuffer.append(byte)
            }
          }
          if !byteBuffer.isEmpty {
            if let line = String(data: byteBuffer, encoding: .utf8) {
              continuation.yield(line)
            }
          }
          continuation.finish()
        } catch {
          continuation.finish(throwing: error)
        }
      }
    }
  }
}

// MARK: - OpenAI Compatible Provider

struct OpenAIProvider: AIProviderProtocol {

  func chat(messages: [[String: String]], config: AIConfig) async throws -> String {
    let request = try buildRequest(messages: messages, config: config, stream: false)
    let (data, response) = try await URLSession.shared.data(for: request)
    try validateResponse(response)

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let choices = json["choices"] as? [[String: Any]],
      let first = choices.first,
      let message = first["message"] as? [String: Any],
      let content = message["content"] as? String
    else {
      throw AIError.invalidResponse
    }
    return content
  }

  func streamChat(messages: [[String: String]], config: AIConfig) async throws
    -> AsyncThrowingStream<AIStreamChunk, Error>
  {
    let request = try buildRequest(messages: messages, config: config, stream: true)
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    try validateResponse(response)

    return AsyncThrowingStream { continuation in
      Task {
        for try await line in SSELineParser.lines(from: bytes) {
          guard line.hasPrefix("data: ") else { continue }
          let payload = String(line.dropFirst(6))
          if payload == "[DONE]" { break }

          guard let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let delta = choices.first?["delta"] as? [String: Any],
            let content = delta["content"] as? String
          else { continue }

          continuation.yield(AIStreamChunk(content: content, isComplete: false))
        }
        continuation.yield(AIStreamChunk(content: "", isComplete: true))
        continuation.finish()
      }
    }
  }

  private func buildRequest(messages: [[String: String]], config: AIConfig, stream: Bool) throws
    -> URLRequest
  {
    guard let providerConfig = config.activeProvider else {
      throw AIError.noProviderConfigured
    }

    let baseURL =
      providerConfig.endpoint.hasSuffix("/")
      ? String(providerConfig.endpoint.dropLast()) : providerConfig.endpoint

    guard !providerConfig.apiKey.isEmpty else {
      throw AIError.noAPIKey
    }

    guard let modelId = config.activeModelId as String?, !modelId.isEmpty else {
      throw AIError.modelNotFound
    }

    let url = URL(string: "\(baseURL)/chat/completions")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Bearer \(providerConfig.apiKey)", forHTTPHeaderField: "Authorization")
    request.timeoutInterval = TimeInterval(config.timeout)

    var body: [String: Any] = [
      "model": modelId,
      "messages": messages,
      "temperature": config.temperature,
      "max_tokens": config.maxTokens,
      "stream": stream,
    ]
    if config.topP != 1.0 {
      body["top_p"] = config.topP
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  private func validateResponse(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else {
      throw AIError.networkError("无效的响应")
    }
    switch http.statusCode {
    case 200...299: break
    case 401: throw AIError.unauthorized
    case 429: throw AIError.rateLimited
    case 400...499: throw AIError.networkError("客户端错误: \(http.statusCode)")
    case 500...599: throw AIError.networkError("服务器错误: \(http.statusCode)")
    default: throw AIError.networkError("未知状态码: \(http.statusCode)")
    }
  }
}

// MARK: - Anthropic Compatible Provider

struct AnthropicProvider: AIProviderProtocol {

  func chat(messages: [[String: String]], config: AIConfig) async throws -> String {
    let request = try buildRequest(messages: messages, config: config, stream: false)
    let (data, response) = try await URLSession.shared.data(for: request)
    try validateResponse(response)

    guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
      let content = json["content"] as? [[String: Any]],
      let first = content.first,
      let text = first["text"] as? String
    else {
      throw AIError.invalidResponse
    }
    return text
  }

  func streamChat(messages: [[String: String]], config: AIConfig) async throws
    -> AsyncThrowingStream<AIStreamChunk, Error>
  {
    let request = try buildRequest(messages: messages, config: config, stream: true)
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    try validateResponse(response)

    return AsyncThrowingStream { continuation in
      Task {
        for try await line in SSELineParser.lines(from: bytes) {
          guard line.hasPrefix("data: ") else { continue }
          let payload = String(line.dropFirst(6))

          guard let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
          else { continue }

          let eventType = json["type"] as? String ?? ""

          if eventType == "content_block_delta",
            let delta = json["delta"] as? [String: Any],
            let text = delta["text"] as? String
          {
            continuation.yield(AIStreamChunk(content: text, isComplete: false))
          } else if eventType == "message_stop" {
            continuation.yield(AIStreamChunk(content: "", isComplete: true))
            break
          }
        }
        continuation.finish()
      }
    }
  }

  private func buildRequest(messages: [[String: String]], config: AIConfig, stream: Bool) throws
    -> URLRequest
  {
    guard let providerConfig = config.activeProvider else {
      throw AIError.noProviderConfigured
    }

    guard !providerConfig.apiKey.isEmpty else {
      throw AIError.noAPIKey
    }

    guard let modelId = config.activeModelId as String?, !modelId.isEmpty else {
      throw AIError.modelNotFound
    }

    // Separate system message
    var systemPrompt = ""
    var chatMessages: [[String: String]] = []
    for msg in messages {
      if msg["role"] == "system" {
        systemPrompt = msg["content"] ?? ""
      } else {
        chatMessages.append(msg)
      }
    }

    let baseURL =
      providerConfig.endpoint.hasSuffix("/")
      ? String(providerConfig.endpoint.dropLast()) : providerConfig.endpoint
    let url = URL(string: "\(baseURL)/messages")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue(providerConfig.apiKey, forHTTPHeaderField: "x-api-key")
    request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
    request.timeoutInterval = TimeInterval(config.timeout)

    var body: [String: Any] = [
      "model": modelId,
      "messages": chatMessages,
      "max_tokens": config.maxTokens,
      "temperature": config.temperature,
      "stream": stream,
    ]
    if !systemPrompt.isEmpty {
      body["system"] = systemPrompt
    }

    request.httpBody = try JSONSerialization.data(withJSONObject: body)
    return request
  }

  private func validateResponse(_ response: URLResponse) throws {
    guard let http = response as? HTTPURLResponse else {
      throw AIError.networkError("无效的响应")
    }
    switch http.statusCode {
    case 200...299: break
    case 401: throw AIError.unauthorized
    case 429: throw AIError.rateLimited
    default: throw AIError.networkError("HTTP \(http.statusCode)")
    }
  }
}
