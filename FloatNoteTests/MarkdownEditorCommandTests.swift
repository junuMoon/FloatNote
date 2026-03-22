import AppKit
import SwiftUI
import XCTest
@testable import FloatNote

@MainActor
final class MarkdownEditorCommandTests: XCTestCase {
    func testEnterOnEmptyBulletRemovesMarker() {
        let (coordinator, textView, _) = makeEditorState(text: "- ", cursor: 2)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
    }

    func testEnterOnEmptyNestedBulletRemovesMarker() {
        let (coordinator, textView, _) = makeEditorState(text: "  - ", cursor: 4)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 0))
    }

    func testEnterOnEmptyBulletAfterContentLeavesBlankLine() {
        let (coordinator, textView, _) = makeEditorState(text: "- item\n- ", cursor: 9)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "- item\n")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 7, length: 0))
    }

    func testEnterOnEmptyQuoteRemovesMarker() {
        let (coordinator, textView, _) = makeEditorState(text: "> ", cursor: 2)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "")
    }

    func testEnterAtEndOfListItemContinuesList() {
        let (coordinator, textView, _) = makeEditorState(text: "- item", cursor: 6)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "- item\n- ")
    }

    func testEnterInMiddleOfListItemFallsBackToDefaultBehavior() {
        let (coordinator, textView, _) = makeEditorState(text: "- item", cursor: 3)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertFalse(handled)
        XCTAssertEqual(textView.string, "- item")
    }

    private func makeEditorState(
        text: String,
        cursor: Int
    ) -> (MarkdownTextEditor.Coordinator, TrackingTextView, Box<String>) {
        let box = Box(text)
        let binding = Binding<String>(
            get: { box.value },
            set: { box.value = $0 }
        )
        let coordinator = MarkdownTextEditor.Coordinator(text: binding, fontSize: 12, onFocusChange: { _ in })
        let textView = TrackingTextView()
        textView.delegate = coordinator
        textView.string = text
        textView.setSelectedRange(NSRange(location: cursor, length: 0))
        coordinator.attach(textView: textView)
        return (coordinator, textView, box)
    }
}

private final class Box<Value> {
    var value: Value

    init(_ value: Value) {
        self.value = value
    }
}

final class AppFocusRestorerTests: XCTestCase {
    func testRememberStoresFrontmostAppWhenDifferentFromCurrent() {
        var restorer = AppFocusRestorer()

        restorer.remember(frontmostAppPID: 41, currentAppPID: 99)

        XCTAssertEqual(restorer.consumeTargetPID(currentAppPID: 99), 41)
    }

    func testRememberIgnoresCurrentApplication() {
        var restorer = AppFocusRestorer()

        restorer.remember(frontmostAppPID: 99, currentAppPID: 99)

        XCTAssertNil(restorer.consumeTargetPID(currentAppPID: 99))
    }

    func testConsumeClearsStoredTargetAfterUse() {
        var restorer = AppFocusRestorer()

        restorer.remember(frontmostAppPID: 41, currentAppPID: 99)

        XCTAssertEqual(restorer.consumeTargetPID(currentAppPID: 99), 41)
        XCTAssertNil(restorer.consumeTargetPID(currentAppPID: 99))
    }

    func testRememberReplacesPreviousTargetOnNextCapture() {
        var restorer = AppFocusRestorer()

        restorer.remember(frontmostAppPID: 41, currentAppPID: 99)
        restorer.remember(frontmostAppPID: 52, currentAppPID: 99)

        XCTAssertEqual(restorer.consumeTargetPID(currentAppPID: 99), 52)
    }
}
