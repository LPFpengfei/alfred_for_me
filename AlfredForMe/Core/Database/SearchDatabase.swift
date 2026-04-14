import Foundation
import SQLite3

// MARK: - SQLite transient destructor (tells SQLite to copy the string immediately)
private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Search Database (Inspired by Alfred's filecache.alfdb + knowledge.alfdb)

final class SearchDatabase {
  static let shared = SearchDatabase()

  private var db: OpaquePointer?
  private let dbQueue = DispatchQueue(label: "com.alfredForMe.searchDB", qos: .userInitiated)

  private init() {
    openDatabase()
    createTables()
  }

  deinit {
    sqlite3_close(db)
  }

  // MARK: - Database Setup

  private func openDatabase() {
    let dbPath = getDatabasePath()

    // Create directory if needed
    let dir = (dbPath as NSString).deletingLastPathComponent
    try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

    if sqlite3_open(dbPath, &db) != SQLITE_OK {
      print("⚠️ Failed to open search database")
    }

    // Enable WAL mode for better concurrent read/write performance
    exec("PRAGMA journal_mode=WAL")
    exec("PRAGMA synchronous=NORMAL")
  }

  private func getDatabasePath() -> String {
    let appSupport = FileManager.default.urls(
      for: .applicationSupportDirectory, in: .userDomainMask
    ).first!
    let appDir = appSupport.appendingPathComponent("AlfredForMe")
    return appDir.appendingPathComponent("search.alfdb").path
  }

  private func createTables() {
    // App/File cache table - like Alfred's filecache.alfdb
    // fileName: original name, nameSearch: lowercased, nameSplit: split words joined,
    // nameChars: first char of each word, altnames: alternative/localized names
    exec(
      """
          CREATE TABLE IF NOT EXISTS files (
              path TEXT PRIMARY KEY,
              fileName TEXT NOT NULL,
              nameSearch TEXT NOT NULL,
              nameSplit TEXT NOT NULL,
              nameChars TEXT NOT NULL,
              altnames TEXT,
              keywords TEXT,
              lastUsed INTEGER DEFAULT 0,
              filetype INTEGER DEFAULT 0,
              bundleId TEXT,
              hash TEXT
          )
      """)
    exec("CREATE INDEX IF NOT EXISTS idx_files_fileName ON files(fileName)")
    exec("CREATE INDEX IF NOT EXISTS idx_files_nameSearch ON files(nameSearch)")
    exec("CREATE INDEX IF NOT EXISTS idx_files_nameSplit ON files(nameSplit)")
    exec("CREATE INDEX IF NOT EXISTS idx_files_nameChars ON files(nameChars)")
    exec("CREATE INDEX IF NOT EXISTS idx_files_altnames ON files(altnames)")

    // Knowledge table - like Alfred's knowledge.alfdb
    // Records user selections: what item was selected for which query, and when
    exec(
      """
          CREATE TABLE IF NOT EXISTS knowledge (
              item TEXT NOT NULL,
              keyword TEXT NOT NULL,
              ts REAL NOT NULL,
              hidden INTEGER DEFAULT 0
          )
      """)
    exec("CREATE INDEX IF NOT EXISTS idx_knowledge_item ON knowledge(item)")
    exec("CREATE INDEX IF NOT EXISTS idx_knowledge_keyword ON knowledge(keyword)")
    exec("CREATE INDEX IF NOT EXISTS idx_knowledge_ts ON knowledge(ts)")

    // Tidy old knowledge (older than 90 days)
    let cutoff = Date().timeIntervalSince1970 - 90 * 86400
    exec("DELETE FROM knowledge WHERE ts < \(cutoff)")
  }

  // MARK: - File Cache Operations

  /// Insert or update a file in the cache with pre-processed search fields
  func cacheFile(
    path: String,
    displayName: String,
    alternativeNames: [String] = [],
    keywords: [String] = [],
    lastUsed: Int = 0,
    filetype: FileType = .other,
    bundleId: String? = nil
  ) {
    let nameSearch = displayName.lowercased()
    let nameSplit = extractNameSplit(from: displayName)
    let nameChars = extractNameChars(from: displayName)
    let altnames = alternativeNames.joined(separator: "|").lowercased()
    let kw = keywords.joined(separator: "|").lowercased()
    let hash = createHash(name: displayName, keywords: keywords, lastUsed: lastUsed)

    dbQueue.sync {
      var stmt: OpaquePointer?
      let sql = """
            INSERT OR REPLACE INTO files
            (path, fileName, nameSearch, nameSplit, nameChars, altnames, keywords, lastUsed, filetype, bundleId, hash)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """

      guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 2, (displayName as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 3, (nameSearch as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 4, (nameSplit as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 5, (nameChars as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 6, (altnames as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 7, (kw as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_int64(stmt, 8, Int64(lastUsed))
      sqlite3_bind_int(stmt, 9, Int32(filetype.rawValue))
      if let bid = bundleId {
        sqlite3_bind_text(stmt, 10, (bid as NSString).utf8String, -1, SQLITE_TRANSIENT)
      } else {
        sqlite3_bind_null(stmt, 10)
      }
      sqlite3_bind_text(stmt, 11, (hash as NSString).utf8String, -1, SQLITE_TRANSIENT)

      sqlite3_step(stmt)
    }
  }

  /// Search files with progressive multi-field matching (like Alfred)
  /// Short queries: fileName, nameSplit, altnames
  /// Longer queries: + nameSearch, nameChars
  func searchFiles(query: String, limit: Int = 20) -> [CachedFile] {
    let q = query.lowercased()
    let likePattern = "%\(escapeLike(q))%"

    // Build fuzzy query for nameChars (e.g., "vsc" matches files whose nameChars contains "vsc")
    let fuzzyPattern = buildFuzzyLikePattern(from: q)

    var results: [CachedFile] = []

    dbQueue.sync {
      var stmt: OpaquePointer?
      let sql: String

      if q.count <= 2 {
        // Short query - use fewer fields for speed
        sql = """
              SELECT path, fileName, nameSearch, nameSplit, nameChars, altnames, keywords,
                     lastUsed, filetype, bundleId
              FROM files
              WHERE fileName LIKE ? OR nameSplit LIKE ? OR altnames LIKE ?
              LIMIT ?
          """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 4, Int32(limit))
      } else {
        // Longer query - use all fields including nameChars
        sql = """
              SELECT path, fileName, nameSearch, nameSplit, nameChars, altnames, keywords,
                     lastUsed, filetype, bundleId
              FROM files
              WHERE fileName LIKE ? OR nameSearch LIKE ? OR nameSplit LIKE ?
                    OR nameChars LIKE ? OR altnames LIKE ?
              LIMIT ?
          """
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
        sqlite3_bind_text(stmt, 1, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 2, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 3, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 4, (fuzzyPattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_text(stmt, 5, (likePattern as NSString).utf8String, -1, SQLITE_TRANSIENT)
        sqlite3_bind_int(stmt, 6, Int32(limit))
      }

      defer { sqlite3_finalize(stmt) }

      while sqlite3_step(stmt) == SQLITE_ROW {
        let file = CachedFile(
          path: String(cString: sqlite3_column_text(stmt, 0)),
          fileName: String(cString: sqlite3_column_text(stmt, 1)),
          nameSearch: String(cString: sqlite3_column_text(stmt, 2)),
          nameSplit: String(cString: sqlite3_column_text(stmt, 3)),
          nameChars: String(cString: sqlite3_column_text(stmt, 4)),
          altnames: sqlite3_column_text(stmt, 5).map { String(cString: $0) } ?? "",
          keywords: sqlite3_column_text(stmt, 6).map { String(cString: $0) } ?? "",
          lastUsed: Int(sqlite3_column_int64(stmt, 7)),
          filetype: FileType(rawValue: Int(sqlite3_column_int(stmt, 8))) ?? .other,
          bundleId: sqlite3_column_text(stmt, 9).map { String(cString: $0) }
        )
        results.append(file)
      }
    }

    return results
  }

  /// Remove a file from cache
  func removeFile(path: String) {
    dbQueue.sync {
      var stmt: OpaquePointer?
      guard sqlite3_prepare_v2(db, "DELETE FROM files WHERE path = ?", -1, &stmt, nil) == SQLITE_OK
      else { return }
      defer { sqlite3_finalize(stmt) }
      sqlite3_bind_text(stmt, 1, (path as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_step(stmt)
    }
  }

  /// Clear all file cache
  func clearFileCache() {
    exec("DELETE FROM files")
  }

  /// Get count of cached files
  func fileCacheCount() -> Int {
    var count = 0
    dbQueue.sync {
      var stmt: OpaquePointer?
      guard sqlite3_prepare_v2(db, "SELECT COUNT(*) FROM files", -1, &stmt, nil) == SQLITE_OK else {
        return
      }
      defer { sqlite3_finalize(stmt) }
      if sqlite3_step(stmt) == SQLITE_ROW {
        count = Int(sqlite3_column_int(stmt, 0))
      }
    }
    return count
  }

  // MARK: - Knowledge Operations (User Behavior Learning)

  /// Record that a user selected an item for a given query
  func addKnowledge(item: String, keyword: String) {
    dbQueue.sync {
      var stmt: OpaquePointer?
      let sql = "INSERT INTO knowledge (item, keyword, ts) VALUES (?, ?, ?)"
      guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (item as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_text(stmt, 2, (keyword as NSString).utf8String, -1, SQLITE_TRANSIENT)
      sqlite3_bind_double(stmt, 3, Date().timeIntervalSince1970)

      sqlite3_step(stmt)
    }
  }

  /// Get knowledge-based weights for a set of items matching a keyword
  /// Returns: [itemId: weight] where weight = count of times selected
  func knowledgeWeights(keyword: String) -> [String: Int] {
    var weights: [String: Int] = [:]
    dbQueue.sync {
      var stmt: OpaquePointer?
      let sql = "SELECT item, COUNT(item) AS weight FROM knowledge WHERE keyword = ? GROUP BY item"
      guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_text(stmt, 1, (keyword as NSString).utf8String, -1, SQLITE_TRANSIENT)

      while sqlite3_step(stmt) == SQLITE_ROW {
        let item = String(cString: sqlite3_column_text(stmt, 0))
        let count = Int(sqlite3_column_int(stmt, 1))
        weights[item] = count
      }
    }
    return weights
  }

  /// Get recent usage weights (items used in the last N days)
  func recentUsageWeights(items: [String], days: Int = 30) -> [String: Int] {
    guard !items.isEmpty else { return [:] }
    let cutoff = Date().timeIntervalSince1970 - Double(days * 86400)
    let placeholders = items.map { _ in "?" }.joined(separator: ",")

    var weights: [String: Int] = [:]
    dbQueue.sync {
      var stmt: OpaquePointer?
      let sql = """
            SELECT item, COUNT(item) AS used
            FROM knowledge
            WHERE ts > ? AND item IN (\(placeholders))
            GROUP BY item
        """
      guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
      defer { sqlite3_finalize(stmt) }

      sqlite3_bind_double(stmt, 1, cutoff)
      for (i, item) in items.enumerated() {
        sqlite3_bind_text(stmt, Int32(i + 2), (item as NSString).utf8String, -1, SQLITE_TRANSIENT)
      }

      while sqlite3_step(stmt) == SQLITE_ROW {
        let item = String(cString: sqlite3_column_text(stmt, 0))
        let count = Int(sqlite3_column_int(stmt, 1))
        weights[item] = count
      }
    }
    return weights
  }

  /// Clear all knowledge data
  func clearKnowledge() {
    exec("DELETE FROM knowledge")
  }

  // MARK: - Name Processing (like Alfred's extractFuzzyComponentsFrom:)

  /// Extract split words from display name
  /// "Visual Studio Code" → "visual studio code"
  /// "Xcode" → "xcode"
  /// "IntelliJ IDEA" → "intelli j idea"  (CamelCase split)
  func extractNameSplit(from name: String) -> String {
    var words: [String] = []
    var currentWord = ""

    for (i, char) in name.enumerated() {
      if char == " " || char == "-" || char == "_" || char == "." {
        if !currentWord.isEmpty {
          words.append(currentWord)
          currentWord = ""
        }
      } else if char.isUppercase && i > 0 {
        // CamelCase split - but not for consecutive uppercase (acronyms)
        let prevIndex = name.index(name.startIndex, offsetBy: i - 1)
        if !name[prevIndex].isUppercase {
          if !currentWord.isEmpty {
            words.append(currentWord)
            currentWord = ""
          }
        }
        currentWord.append(char)
      } else {
        currentWord.append(char)
      }
    }
    if !currentWord.isEmpty {
      words.append(currentWord)
    }

    return words.joined(separator: " ").lowercased()
  }

  /// Extract first characters of each word for abbreviation matching
  /// "Visual Studio Code" → "vsc"
  /// "Activity Monitor" → "am"
  func extractNameChars(from name: String) -> String {
    let words = extractNameSplit(from: name).split(separator: " ")
    return String(words.compactMap { $0.first }).lowercased()
  }

  // MARK: - Helpers

  private func buildFuzzyLikePattern(from query: String) -> String {
    // For nameChars matching: "vsc" → "%v%s%c%"
    let chars = query.map { String($0) }
    return "%" + chars.joined(separator: "%") + "%"
  }

  private func escapeLike(_ str: String) -> String {
    str.replacingOccurrences(of: "%", with: "%%")
      .replacingOccurrences(of: "_", with: "__")
  }

  private func createHash(name: String, keywords: [String], lastUsed: Int) -> String {
    "\(name)|\(keywords.joined(separator: ","))|\(lastUsed)"
  }

  private func exec(_ sql: String) {
    sqlite3_exec(db, sql, nil, nil, nil)
  }
}

// MARK: - Models

struct CachedFile {
  let path: String
  let fileName: String
  let nameSearch: String
  let nameSplit: String
  let nameChars: String
  let altnames: String
  let keywords: String
  let lastUsed: Int
  let filetype: FileType
  let bundleId: String?
}

enum FileType: Int {
  case application = 1
  case systemPreference = 2
  case folder = 3
  case document = 4
  case other = 0
}
