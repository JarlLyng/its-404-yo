import XCTest
@testable import Its404Yo

final class FeedbackMailTests: XCTestCase {

    private func decoded(_ url: URL) -> [String: String] {
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    func testAddressedToSupport() {
        let url = FeedbackMail.url(appVersion: "1.2.0", build: "6", osVersion: "26.0.1")
        XCTAssertEqual(url.scheme, "mailto")
        XCTAssertTrue(url.absoluteString.hasPrefix("mailto:support@iamjarl.com?"))
    }

    func testSubjectAndBodyRoundTrip() {
        let q = decoded(FeedbackMail.url(appVersion: "1.2.0", build: "6", osVersion: "26.0.1"))
        XCTAssertEqual(q["subject"], "It's 404, yo! 1.2.0 feedback")
        XCTAssertEqual(q["body"], "\n\n\n--\nIt's 404, yo! 1.2.0 (6)\nmacOS 26.0.1\n")
    }

    /// `queryItems` would leave these raw and split the query on them.
    func testReservedCharactersAreEncoded() {
        let url = FeedbackMail.url(appVersion: "1&2=3+4", build: "b?#", osVersion: "x y")
        // Read the raw query via URLComponents: URL.query returns nil for non-hierarchical
        // URLs like mailto: on older Foundation (the CI runner), but not on newer macOS.
        let query = URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery ?? ""
        XCTAssertFalse(query.isEmpty)
        XCTAssertEqual(query.components(separatedBy: "&").count, 2, "exactly subject and body")
        XCTAssertFalse(query.contains("+"))
        XCTAssertFalse(query.contains(" "))
        let q = decoded(url)
        XCTAssertEqual(q["subject"], "It's 404, yo! 1&2=3+4 feedback")
        XCTAssertTrue(q["body"]?.contains("(b?#)") ?? false)
    }

    func testCurrentUsesTheRunningAppsVersion() {
        let q = decoded(FeedbackMail.current())
        XCTAssertTrue(q["subject"]?.hasPrefix("It's 404, yo! ") ?? false)
        XCTAssertTrue(q["body"]?.contains("macOS ") ?? false)
    }
}
