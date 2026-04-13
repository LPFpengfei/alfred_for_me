import XCTest
@testable import AlfredForMe

final class FuzzyMatcherTests: XCTestCase {
    func testExactMatch() {
        let score = FuzzyMatcher.score(query: "safari", target: "Safari")
        XCTAssertEqual(score, 1.0)
    }

    func testPrefixMatch() {
        let score = FuzzyMatcher.score(query: "saf", target: "Safari")
        XCTAssertEqual(score, 0.9)
    }

    func testContainsMatch() {
        let score = FuzzyMatcher.score(query: "far", target: "Safari")
        XCTAssertEqual(score, 0.7)
    }

    func testAbbreviationMatch() {
        let score = FuzzyMatcher.score(query: "vsc", target: "Visual Studio Code")
        XCTAssertGreaterThan(score, 0.7)
    }

    func testNoMatch() {
        let score = FuzzyMatcher.score(query: "xyz", target: "Safari")
        XCTAssertEqual(score, 0)
    }

    func testSubsequenceMatch() {
        let score = FuzzyMatcher.score(query: "sfr", target: "Safari")
        XCTAssertGreaterThan(score, 0)
    }
}

final class QueryParserTests: XCTestCase {
    func testSimpleQuery() {
        let query = SearchQuery(raw: "safari")
        XCTAssertEqual(query.raw, "safari")
        XCTAssertEqual(query.keyword, "safari")
        XCTAssertNil(query.argument)
    }

    func testKeywordQuery() {
        let query = SearchQuery(raw: "google swift tutorials")
        XCTAssertEqual(query.keyword, "google")
        XCTAssertEqual(query.argument, "swift tutorials")
    }

    func testEmptyQuery() {
        let query = SearchQuery(raw: "")
        XCTAssertEqual(query.raw, "")
        XCTAssertNil(query.keyword)
        XCTAssertNil(query.argument)
    }
}

final class WebSearchEngineTests: XCTestCase {
    func testBuildURL() {
        let engine = WebSearchEngine(
            name: "Google",
            keyword: "google",
            urlTemplate: "https://www.google.com/search?q={query}"
        )
        let url = engine.buildURL(query: "swift programming")
        XCTAssertNotNil(url)
        XCTAssertTrue(url!.absoluteString.contains("swift"))
    }
}

final class FileSizeFormatterTests: XCTestCase {
    func testBytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 500), "500 B")
    }

    func testKilobytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1536), "1.5 KB")
    }

    func testMegabytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1_048_576), "1.0 MB")
    }

    func testGigabytes() {
        XCTAssertEqual(FileSizeFormatter.format(bytes: 1_073_741_824), "1.0 GB")
    }
}
