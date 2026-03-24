import AppKit
import Carbon
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

    func testEnterAtEndOfNestedBulletContinuesNestedList() {
        let (coordinator, textView, _) = makeEditorState(text: "  - item", cursor: 8)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertNewline(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "  - item\n  - ")
    }

    func testTabOnBulletItemIndentsLine() {
        let (coordinator, textView, _) = makeEditorState(text: "- item", cursor: 6)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertTab(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "  - item")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 8, length: 0))
    }

    func testShiftTabOnNestedBulletOutdentsLine() {
        let (coordinator, textView, _) = makeEditorState(text: "  - item", cursor: 8)

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertBacktab(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "- item")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 6, length: 0))
    }

    func testTabOnSelectedBulletItemsIndentsEachLine() {
        let text = "- one\n- two"
        let (coordinator, textView, _) = makeEditorState(text: text, selection: NSRange(location: 0, length: text.count))

        let handled = coordinator.textView(textView, doCommandBy: #selector(NSResponder.insertTab(_:)))

        XCTAssertTrue(handled)
        XCTAssertEqual(textView.string, "  - one\n  - two")
        XCTAssertEqual(textView.selectedRange(), NSRange(location: 0, length: 15))
    }

    private func makeEditorState(
        text: String,
        cursor: Int
    ) -> (MarkdownTextEditor.Coordinator, TrackingTextView, Box<String>) {
        makeEditorState(text: text, selection: NSRange(location: cursor, length: 0))
    }

    private func makeEditorState(
        text: String,
        selection: NSRange
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
        textView.setSelectedRange(selection)
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

final class ScreenTargetResolverTests: XCTestCase {
    func testFocusedContextScreenWinsOverPreviousWindowScreen() {
        let resolved = ScreenTargetResolver.resolve(
            focusedContextScreen: "focused",
            mainScreen: "main",
            mouseScreen: "mouse",
            windowScreen: "window",
            allScreens: ["fallback"]
        )

        XCTAssertEqual(resolved, "focused")
    }

    func testMainScreenWinsBeforeMouseAndWindowFallback() {
        let resolved = ScreenTargetResolver.resolve(
            focusedContextScreen: nil as String?,
            mainScreen: "main",
            mouseScreen: "mouse",
            windowScreen: "window",
            allScreens: ["fallback"]
        )

        XCTAssertEqual(resolved, "main")
    }

    func testResolverOnlyUsesWindowScreenAsLateFallback() {
        let resolved = ScreenTargetResolver.resolve(
            focusedContextScreen: nil as String?,
            mainScreen: nil,
            mouseScreen: nil,
            windowScreen: "window",
            allScreens: ["fallback"]
        )

        XCTAssertEqual(resolved, "window")
    }
}

final class FrontmostWindowResolverTests: XCTestCase {
    func testResolverReturnsFirstVisibleLayerZeroWindowForMatchingProcess() {
        let resolved = FrontmostWindowResolver.frame(
            for: 42,
            in: [
                makeWindowInfo(pid: 11, layer: 0, alpha: 1, bounds: CGRect(x: 10, y: 20, width: 300, height: 200)),
                makeWindowInfo(pid: 42, layer: 1, alpha: 1, bounds: CGRect(x: 30, y: 40, width: 400, height: 300)),
                makeWindowInfo(pid: 42, layer: 0, alpha: 1, bounds: CGRect(x: 50, y: 60, width: 500, height: 350))
            ]
        )

        XCTAssertEqual(resolved, CGRect(x: 50, y: 60, width: 500, height: 350))
    }

    func testResolverIgnoresTransparentOffscreenAndEmptyWindows() {
        let resolved = FrontmostWindowResolver.frame(
            for: 42,
            in: [
                makeWindowInfo(pid: 42, layer: 0, alpha: 0, bounds: CGRect(x: 10, y: 20, width: 300, height: 200)),
                makeWindowInfo(pid: 42, layer: 0, alpha: 1, bounds: CGRect(x: 10, y: 20, width: 0, height: 200)),
                makeWindowInfo(pid: 42, layer: 0, alpha: 1, onscreen: false, bounds: CGRect(x: 10, y: 20, width: 300, height: 200)),
                makeWindowInfo(pid: 42, layer: 0, alpha: 1, bounds: CGRect(x: 80, y: 90, width: 320, height: 240))
            ]
        )

        XCTAssertEqual(resolved, CGRect(x: 80, y: 90, width: 320, height: 240))
    }

    private func makeWindowInfo(
        pid: Int,
        layer: Int,
        alpha: Double,
        onscreen: Bool = true,
        bounds: CGRect
    ) -> [String: Any] {
        [
            kCGWindowOwnerPID as String: pid,
            kCGWindowLayer as String: layer,
            kCGWindowAlpha as String: alpha,
            kCGWindowIsOnscreen as String: onscreen,
            kCGWindowBounds as String: CGRectCreateDictionaryRepresentation(bounds) as NSDictionary
        ]
    }
}

final class DisplayScreenMatcherTests: XCTestCase {
    func testMatchReturnsScreenForMatchingDisplayID() {
        let resolved = DisplayScreenMatcher.match(
            displayID: 77,
            screens: [
                (12, "left"),
                (77, "right")
            ]
        )

        XCTAssertEqual(resolved, "right")
    }

    func testMatchReturnsNilWhenDisplayIDIsMissing() {
        let resolved = DisplayScreenMatcher.match(
            displayID: 90,
            screens: [
                (12, "left"),
                (77, "right")
            ]
        )

        XCTAssertNil(resolved)
    }
}

final class PreferencesMigrationTests: XCTestCase {
    func testLegacyToggleShortcutMigratesToOptionA() throws {
        let preferences = try decodePreferences(
            from: """
            {
              "toggleShortcut": {
                "keyCode": 0,
                "modifiers": 4
              }
            }
            """
        )

        XCTAssertEqual(preferences.toggleShortcut, .defaultToggle)
        XCTAssertEqual(preferences.toggleShortcut.label, "⌥A")
    }

    func testCustomToggleShortcutIsPreserved() throws {
        let preferences = try decodePreferences(
            from: """
            {
              "toggleShortcut": {
                "keyCode": 49,
                "modifiers": 2
              }
            }
            """
        )

        XCTAssertEqual(
            preferences.toggleShortcut,
            KeyShortcut(keyCode: UInt16(kVK_Space), modifiers: [.option])
        )
    }

    private func decodePreferences(from json: String) throws -> Preferences {
        let data = Data(json.utf8)
        return try JSONDecoder().decode(Preferences.self, from: data)
    }
}
