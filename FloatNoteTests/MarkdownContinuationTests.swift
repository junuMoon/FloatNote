import XCTest
@testable import FloatNote

final class MarkdownContinuationTests: XCTestCase {
    func testBulletContinuationKeepsMarker() {
        XCTAssertEqual(MarkdownContinuation.insertion(for: "- item"), "\n- ")
    }

    func testIndentedBulletContinuationKeepsIndentation() {
        XCTAssertEqual(MarkdownContinuation.insertion(for: "  * item"), "\n  * ")
    }

    func testNumberedContinuationIncrementsNumber() {
        XCTAssertEqual(MarkdownContinuation.insertion(for: "9. item"), "\n10. ")
    }

    func testIndentedNumberedContinuationKeepsIndentation() {
        XCTAssertEqual(MarkdownContinuation.insertion(for: "   3. item"), "\n   4. ")
    }

    func testQuoteContinuationKeepsMarker() {
        XCTAssertEqual(MarkdownContinuation.insertion(for: "> note"), "\n> ")
    }

    func testPlainTextDoesNotContinueMarkdown() {
        XCTAssertNil(MarkdownContinuation.insertion(for: "plain text"))
    }

    func testEmptyListItemDoesNotForceAnotherListItem() {
        XCTAssertNil(MarkdownContinuation.insertion(for: "- "))
    }

    func testEmptyBulletTerminatesList() {
        XCTAssertEqual(MarkdownContinuation.action(for: "- "), .terminateList)
    }

    func testEmptyNumberedItemTerminatesList() {
        XCTAssertEqual(MarkdownContinuation.action(for: "1. "), .terminateList)
    }

    func testEmptyQuoteTerminatesList() {
        XCTAssertEqual(MarkdownContinuation.action(for: "> "), .terminateList)
    }
}
