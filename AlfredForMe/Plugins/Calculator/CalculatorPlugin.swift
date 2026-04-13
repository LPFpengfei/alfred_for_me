import AppKit
import Foundation

// MARK: - Calculator Plugin

final class CalculatorPlugin: SearchPlugin {
  let id = "com.alfredForMe.calculator"
  let name = "Calculator"
  var isEnabled = true
  let priority = 95

  // Regex to detect math expressions
  private let mathPattern = try! NSRegularExpression(
    pattern: #"^[\d\s\+\-\*\/\%\(\)\.\^]+$"#,
    options: []
  )

  func canHandle(query: SearchQuery) -> Bool {
    let text = query.raw.trimmingCharacters(in: .whitespaces)
    guard !text.isEmpty else { return false }

    // Check if it starts with = or looks like math
    if text.hasPrefix("=") { return true }

    let range = NSRange(text.startIndex..., in: text)
    return mathPattern.firstMatch(in: text, range: range) != nil
      && text.contains(where: { "+-*/%^".contains($0) })
  }

  func search(query: SearchQuery) async -> [SearchResult] {
    var expression = query.raw.trimmingCharacters(in: .whitespaces)
    if expression.hasPrefix("=") {
      expression = String(expression.dropFirst()).trimmingCharacters(in: .whitespaces)
    }

    guard !expression.isEmpty else { return [] }

    // Normalize expression
    expression =
      expression
      .replacingOccurrences(of: "×", with: "*")
      .replacingOccurrences(of: "÷", with: "/")
      .replacingOccurrences(of: "^", with: "**")

    guard let result = evaluateExpression(expression) else { return [] }

    let formattedResult = formatNumber(result)
    let formattedExpression = query.raw.trimmingCharacters(in: .whitespaces)

    return [
      SearchResult(
        id: "calc:\(expression)",
        title: formattedResult,
        subtitle: "\(formattedExpression) =",
        icon: NSImage(systemSymbolName: "equal.circle.fill", accessibilityDescription: nil),
        category: .calculator,
        relevanceScore: 1.0,
        plugin: id,
        userData: ["result": formattedResult, "expression": expression]
      )
    ]
  }

  func execute(result: SearchResult) async {
    if let value = result.userData["result"] {
      NSPasteboard.general.clearContents()
      NSPasteboard.general.setString(value, forType: .string)
    }
  }

  func actions(for result: SearchResult) -> [ResultAction] {
    guard let value = result.userData["result"] else { return [] }

    return [
      ResultAction(title: "复制结果", shortcut: "⏎") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
      },
      ResultAction(title: "复制为整数") {
        if let doubleVal = Double(value) {
          let intStr = String(Int(doubleVal))
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(intStr, forType: .string)
        }
      },
    ]
  }

  // MARK: - Expression Evaluation

  private func evaluateExpression(_ expression: String) -> Double? {
    // Use NSExpression for safe evaluation
    let sanitized =
      expression
      .replacingOccurrences(of: "**", with: "↑")  // Placeholder for power
      .trimmingCharacters(in: .whitespaces)

    // Handle power operator
    if sanitized.contains("↑") {
      return evaluateWithPower(sanitized)
    }

    // Validate: only allow digits, operators, parens, dots, spaces
    // NSExpression(format:) throws ObjC exceptions on invalid input which Swift cannot catch
    let allowed = CharacterSet(charactersIn: "0123456789.+-*/% ()")
    guard sanitized.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
    // Must contain at least one digit
    guard sanitized.contains(where: { $0.isNumber }) else { return nil }
    // Balanced parentheses check
    var depth = 0
    for ch in sanitized {
      if ch == "(" { depth += 1 } else if ch == ")" { depth -= 1 }
      if depth < 0 { return nil }
    }
    guard depth == 0 else { return nil }
    // Reject empty parens, consecutive operators, trailing operators
    let trimmed = sanitized.replacingOccurrences(of: " ", with: "")
    if trimmed.contains("()") { return nil }
    // Reject if ends or starts with an operator (except leading minus)
    let ops = CharacterSet(charactersIn: "+-*/%")
    if let last = trimmed.unicodeScalars.last, ops.contains(last) { return nil }
    if let first = trimmed.unicodeScalars.first, CharacterSet(charactersIn: "+*/%").contains(first)
    {
      return nil
    }

    let nsExpression = NSExpression(format: sanitized)
    if let result = nsExpression.expressionValue(with: nil, context: nil) as? NSNumber {
      return result.doubleValue
    }
    return nil
  }

  private func evaluateWithPower(_ expression: String) -> Double? {
    // Simple power handling: split on ↑ and compute
    let parts = expression.split(separator: "↑", maxSplits: 1)
    guard parts.count == 2 else {
      // Try without power
      let cleaned = expression.replacingOccurrences(of: "↑", with: "")
      return evaluateExpression(cleaned)
    }

    let baseExpr = String(parts[0]).trimmingCharacters(in: .whitespaces)
    let expExpr = String(parts[1]).trimmingCharacters(in: .whitespaces)

    guard let base = evaluateExpression(baseExpr),
      let exp = evaluateExpression(expExpr)
    else { return nil }

    return pow(base, exp)
  }

  private func formatNumber(_ number: Double) -> String {
    if number == number.rounded() && abs(number) < 1e15 {
      return String(format: "%.0f", number)
    }

    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.maximumFractionDigits = 10
    formatter.minimumFractionDigits = 0
    formatter.usesGroupingSeparator = false

    return formatter.string(from: NSNumber(value: number)) ?? String(number)
  }
}
