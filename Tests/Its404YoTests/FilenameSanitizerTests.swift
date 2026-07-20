import XCTest
@testable import Its404Yo

final class FilenameSanitizerTests: XCTestCase {

    func testKeepsCleanNames() {
        XCTAssertEqual(FilenameSanitizer.sanitize("Kick_01.wav"), "Kick_01.wav")
        XCTAssertEqual(FilenameSanitizer.sanitize("My Drums"), "My Drums")
        XCTAssertEqual(FilenameSanitizer.sanitize("Vox (dry).aif"), "Vox (dry).aif")
    }

    func testFoldsDiacriticsToASCII() {
        XCTAssertEqual(FilenameSanitizer.sanitize("Café Crème.wav"), "Cafe Creme.wav")
    }

    func testReplacesIllegalCharacters() {
        XCTAssertEqual(FilenameSanitizer.sanitize("bad:name?.wav"), "bad_name.wav")
        XCTAssertEqual(FilenameSanitizer.sanitize("a/b\\c.wav"), "a_b_c.wav")
    }

    func testNonLatinFallsBackToSample() {
        XCTAssertEqual(FilenameSanitizer.sanitize("ドラム.wav"), "sample.wav")
    }

    func testTrimsAndCollapsesWhitespace() {
        XCTAssertEqual(FilenameSanitizer.sanitize("  weird   name .wav"), "weird name.wav")
    }

    func testCapsLongBaseButKeepsExtension() {
        let long = String(repeating: "a", count: 200) + ".wav"
        let out = FilenameSanitizer.sanitize(long)
        XCTAssertTrue(out.hasSuffix(".wav"))
        XCTAssertLessThanOrEqual(out.count, FilenameSanitizer.maxBaseLength + 4)
    }

    func testEmptyResultFallsBack() {
        XCTAssertEqual(FilenameSanitizer.sanitize("***"), "sample")
    }
}
