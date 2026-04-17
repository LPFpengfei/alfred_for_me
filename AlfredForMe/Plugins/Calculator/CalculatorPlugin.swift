import AppKit
import Expression
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

    // Only trigger with = prefix, or pure math expressions
    if text.hasPrefix("=") { return true }

    // Must start with a digit or opening paren, and only contain math chars
    guard let first = text.first, first.isNumber || first == "(" || first == "." else {
      return false
    }

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
      ResultAction(title: LocalizationManager.shared.t("action.copyResult"), shortcut: "⏎") {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
      },
      ResultAction(title: LocalizationManager.shared.t("action.copyAsInt")) {
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
    // Use the Expression library for safe evaluation (no ObjC exceptions)
    do {
      let expr = Expression(expression)
      let result = try expr.evaluate()
      guard result.isFinite else { return nil }
      return result
    } catch {
      return nil
    }
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
