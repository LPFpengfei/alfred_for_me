import Foundation

// MARK: - Fuzzy Matcher

struct FuzzyMatcher {
    /// Returns a score between 0 and 1 indicating how well the query matches the target.
    /// Returns 0 if there's no match.
    static func score(query: String, target: String) -> Double {
        let query = query.lowercased()
        let target = target.lowercased()

        if target == query { return 1.0 }
        if target.hasPrefix(query) { return 0.9 }
        if target.contains(query) { return 0.7 }

        // Abbreviation match (first letters of words)
        let words = target.split(whereSeparator: { " -_.".contains($0) })
        if words.count > 1 {
            let abbr = String(words.compactMap { $0.first })
            if abbr.lowercased().hasPrefix(query) { return 0.85 }
        }

        // Subsequence match
        var qi = query.startIndex
        var ti = target.startIndex
        var matchedChars = 0
        var gapPenalty = 0.0
        var lastMatchIndex: String.Index?
        var consecutiveBonus = 0.0

        while qi < query.endIndex && ti < target.endIndex {
            if query[qi] == target[ti] {
                matchedChars += 1

                // Bonus for consecutive matches
                if let last = lastMatchIndex, target.index(after: last) == ti {
                    consecutiveBonus += 0.1
                }

                // Bonus for matching at word boundary
                if ti == target.startIndex || " -_.".contains(target[target.index(before: ti)]) {
                    consecutiveBonus += 0.15
                }

                lastMatchIndex = ti
                qi = query.index(after: qi)
            } else if lastMatchIndex != nil {
                gapPenalty += 0.02
            }
            ti = target.index(after: ti)
        }

        guard qi == query.endIndex else { return 0 }

        let baseScore = Double(matchedChars) / Double(max(target.count, 1))
        let finalScore = min(1.0, baseScore * 0.6 + consecutiveBonus - gapPenalty)

        return max(0, finalScore)
    }

    /// Match and highlight: returns the ranges in target that match the query
    static func matchRanges(query: String, target: String) -> [Range<String.Index>] {
        let queryLower = query.lowercased()
        let targetLower = target.lowercased()

        var ranges: [Range<String.Index>] = []
        var qi = queryLower.startIndex
        var ti = targetLower.startIndex

        while qi < queryLower.endIndex && ti < targetLower.endIndex {
            if queryLower[qi] == targetLower[ti] {
                // Map back to original string indices
                let offset = targetLower.distance(from: targetLower.startIndex, to: ti)
                let originalIndex = target.index(target.startIndex, offsetBy: offset)
                let nextIndex = target.index(after: originalIndex)
                ranges.append(originalIndex..<nextIndex)

                qi = queryLower.index(after: qi)
            }
            ti = targetLower.index(after: ti)
        }

        return ranges
    }
}

// MARK: - File Size Formatter

struct FileSizeFormatter {
    static func format(bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0

        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }

        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
    }
}

// MARK: - Date Formatter

extension Date {
    var relativeDescription: String {
        let interval = Date().timeIntervalSince(self)

        if interval < 60 { return "刚刚" }
        if interval < 3600 { return "\(Int(interval / 60))分钟前" }
        if interval < 86400 { return "\(Int(interval / 3600))小时前" }
        if interval < 604800 { return "\(Int(interval / 86400))天前" }
        if interval < 2592000 { return "\(Int(interval / 604800))周前" }

        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }
}

// MARK: - Process Helper

struct ProcessRunner {
    /// Run a process and return its output
    static func run(
        _ executable: String,
        arguments: [String] = [],
        environment: [String: String]? = nil,
        timeout: TimeInterval = 10
    ) async -> (output: String, exitCode: Int32)? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: executable)
                process.arguments = arguments

                if let env = environment {
                    var processEnv = ProcessInfo.processInfo.environment
                    for (key, value) in env {
                        processEnv[key] = value
                    }
                    process.environment = processEnv
                }

                let outputPipe = Pipe()
                process.standardOutput = outputPipe
                process.standardError = Pipe()

                do {
                    try process.run()

                    // Timeout handling
                    let deadline = DispatchTime.now() + timeout
                    DispatchQueue.global().asyncAfter(deadline: deadline) {
                        if process.isRunning {
                            process.terminate()
                        }
                    }

                    process.waitUntilExit()

                    let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
                    let output = String(data: data, encoding: .utf8) ?? ""

                    continuation.resume(returning: (output: output, exitCode: process.terminationStatus))
                } catch {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
}
