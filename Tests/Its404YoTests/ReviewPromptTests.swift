import XCTest
@testable import Its404Yo

final class ReviewPromptTests: XCTestCase {

    func testNeverOnFirstSuccessOrAtLaunch() {
        XCTAssertFalse(AppState.shouldAskForReview(afterSuccessfulCount: 0))
        XCTAssertFalse(AppState.shouldAskForReview(afterSuccessfulCount: 1))
    }

    func testAsksAtSecondAndFifthSuccess() {
        XCTAssertTrue(AppState.shouldAskForReview(afterSuccessfulCount: 2))
        XCTAssertTrue(AppState.shouldAskForReview(afterSuccessfulCount: 5))
    }

    func testQuietAtEveryOtherCount() {
        for count in [3, 4, 6, 7, 10, 100] {
            XCTAssertFalse(AppState.shouldAskForReview(afterSuccessfulCount: count))
        }
    }
}
