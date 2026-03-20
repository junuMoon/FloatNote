import AppKit
import XCTest
@testable import FloatNote

final class MarkdownStylerTests: XCTestCase {
    private let baseFontSize: CGFloat = 12

    @MainActor
    func testEmptyHeadingStillReceivesHeadingStyle() throws {
        let text = "# "
        let styled = render(text)

        try assertFont(at: 0, in: styled, matches: MarkdownTheme.headingFont(level: 1, baseFontSize: baseFontSize))
        try assertColor(at: 0, in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
        try assertFont(at: 1, in: styled, matches: MarkdownTheme.headingFont(level: 1, baseFontSize: baseFontSize))
    }

    @MainActor
    func testHeadingStylesMarkerAndBody() throws {
        let text = "# Title"
        let styled = render(text)

        try assertColor(at: 0, in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
        try assertFont(at: location(of: "Title", in: text), in: styled, matches: MarkdownTheme.headingFont(level: 1, baseFontSize: baseFontSize))
        try assertColor(at: location(of: "Title", in: text), in: styled, matches: MarkdownTheme.ink)
    }

    @MainActor
    func testEmptyBulletStillReceivesListIndent() throws {
        let text = "- "
        let styled = render(text)

        try assertColor(at: 0, in: styled, matches: MarkdownTheme.listMarker)
        try assertFont(at: 0, in: styled, matches: MarkdownTheme.listMarkerFont(size: baseFontSize))
        try assertParagraphHeadIndent(at: 0, in: styled, equals: measuredPrefixWidth(leadingWhitespace: "", marker: "-", spacing: " ", markerFont: MarkdownTheme.listMarkerFont(size: baseFontSize)))
    }

    @MainActor
    func testBulletListWrappingKeepsLongWordOnFirstLine() throws {
        let text = "- " + String(repeating: "a", count: 80)
        let lineRanges = wrappedLineRanges(for: text, width: 120)

        XCTAssertGreaterThan(lineRanges.count, 1)
        XCTAssertTrue(lineText(in: text, range: lineRanges[0]).hasPrefix("- a"))
        try assertLineBreakStrategy(at: 0, in: render(text), includes: .hangulWordPriority)
    }

    @MainActor
    func testNumberedListStylesMarkerAndIndent() throws {
        let text = "12. item"
        let styled = render(text)

        try assertColor(at: 0, in: styled, matches: MarkdownTheme.listMarker)
        try assertFont(at: 0, in: styled, matches: MarkdownTheme.numberedListMarkerFont(size: baseFontSize))
        try assertParagraphHeadIndent(at: 0, in: styled, equals: measuredPrefixWidth(leadingWhitespace: "", marker: "12.", spacing: " ", markerFont: MarkdownTheme.numberedListMarkerFont(size: baseFontSize)))
    }

    @MainActor
    func testDoubleDigitNumberedListUsesWiderIndentThanSingleDigit() throws {
        let singleDigit = render("9. item")
        let doubleDigit = render("12. item")

        let singleDigitIndent = try paragraphHeadIndent(at: 0, in: singleDigit)
        let doubleDigitIndent = try paragraphHeadIndent(at: 0, in: doubleDigit)

        XCTAssertGreaterThan(doubleDigitIndent, singleDigitIndent)
    }

    @MainActor
    func testNumberedListWrappingKeepsLongWordOnFirstLine() throws {
        let text = "1. " + String(repeating: "a", count: 80)
        let lineRanges = wrappedLineRanges(for: text, width: 120)

        XCTAssertGreaterThan(lineRanges.count, 1)
        XCTAssertTrue(lineText(in: text, range: lineRanges[0]).hasPrefix("1. a"))
    }

    @MainActor
    func testQuoteStylesLineAndMarker() throws {
        let text = "> note"
        let styled = render(text)

        try assertColor(at: 0, in: styled, matches: MarkdownTheme.listMarker)
        try assertFont(at: 0, in: styled, matches: MarkdownTheme.listMarkerFont(size: baseFontSize))
        try assertColor(at: location(of: "note", in: text), in: styled, matches: MarkdownTheme.quote)
        try assertParagraphHeadIndent(at: location(of: "note", in: text), in: styled, equals: measuredPrefixWidth(leadingWhitespace: "", marker: ">", spacing: " ", markerFont: MarkdownTheme.listMarkerFont(size: baseFontSize)))
    }

    @MainActor
    func testQuoteWrappingKeepsLongWordOnFirstLine() throws {
        let text = "> " + String(repeating: "a", count: 80)
        let lineRanges = wrappedLineRanges(for: text, width: 120)

        XCTAssertGreaterThan(lineRanges.count, 1)
        XCTAssertTrue(lineText(in: text, range: lineRanges[0]).hasPrefix("> a"))
        try assertLineBreakStrategy(at: 0, in: render(text), includes: .hangulWordPriority)
    }

    @MainActor
    func testPlainParagraphUsesHangulWordPriority() throws {
        let styled = render("plain text")
        try assertLineBreakStrategy(at: 0, in: styled, includes: .hangulWordPriority)
    }

    @MainActor
    func testTypingParagraphUsesHangulWordPriority() {
        XCTAssertTrue(MarkdownStyler.typingParagraphStyle(baseFontSize: baseFontSize).lineBreakStrategy.contains(.hangulWordPriority))
    }

    @MainActor
    func testRuleStylesEntireLine() throws {
        let text = "---"
        let styled = render(text)

        try assertFont(at: 0, in: styled, matches: MarkdownTheme.smallCapsFont(size: max(11, baseFontSize)))
        try assertColor(at: 0, in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.55))
    }

    @MainActor
    func testFencedCodeBlockStylesFenceAndBody() throws {
        let text = """
        ```swift
        let value = 1
        ```
        """
        let styled = render(text)

        try assertFont(at: 0, in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertBackgroundColor(at: location(of: "let value = 1", in: text), in: styled, matches: MarkdownTheme.codeBackground)
        try assertFont(at: location(of: "let value = 1", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
    }

    @MainActor
    func testHeadingInsideFencedCodeBlockIsNotStyledAsHeading() throws {
        let text = """
        ```
        # Not heading
        ```
        """
        let styled = render(text)

        try assertFont(at: location(of: "Not heading", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertColor(at: 0, in: styled, matches: MarkdownTheme.codeInk)
    }

    @MainActor
    func testBulletInsideFencedCodeBlockIsNotStyledAsList() throws {
        let text = """
        ```
        - item
        ```
        """
        let styled = render(text)

        try assertColor(at: location(of: "-", in: text), in: styled, matches: MarkdownTheme.codeInk)
        try assertParagraphHeadIndent(at: location(of: "-", in: text), in: styled, equals: 12)
    }

    @MainActor
    func testUnclosedFenceStylesRemainingTextAsCode() throws {
        let text = """
        ```
        let value = 1
        """
        let styled = render(text)

        try assertFont(at: location(of: "let value = 1", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertBackgroundColor(at: location(of: "let value = 1", in: text), in: styled, matches: MarkdownTheme.codeBackground)
    }

    @MainActor
    func testInlineCodeUsesCodeFontAndBackground() throws {
        let text = "Use `code` here"
        let styled = render(text)

        try assertFont(at: location(of: "code", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertBackgroundColor(at: location(of: "code", in: text), in: styled, matches: MarkdownTheme.codeBackground)
    }

    @MainActor
    func testStrongStylesBodyAndMarkers() throws {
        let text = "**bold**"
        let styled = render(text)

        try assertColor(at: 0, in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
        try assertFont(at: location(of: "bold", in: text), in: styled, matches: MarkdownTheme.strongFont(size: baseFontSize))
    }

    @MainActor
    func testEmphasisStylesBodyAndMarkers() throws {
        let text = "*italic*"
        let styled = render(text)

        try assertColor(at: 0, in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
        try assertFont(at: location(of: "italic", in: text), in: styled, matches: MarkdownTheme.emphasisFont(size: baseFontSize))
    }

    @MainActor
    func testUnderscoreStrongStylesBody() throws {
        let text = "__bold__"
        let styled = render(text)

        try assertFont(at: location(of: "bold", in: text), in: styled, matches: MarkdownTheme.strongFont(size: baseFontSize))
    }

    @MainActor
    func testUnderscoreEmphasisStylesBody() throws {
        let text = "_italic_"
        let styled = render(text)

        try assertFont(at: location(of: "italic", in: text), in: styled, matches: MarkdownTheme.emphasisFont(size: baseFontSize))
    }

    @MainActor
    func testSnakeCaseDoesNotBecomeItalic() throws {
        let text = "snake_case_identifier"
        let styled = render(text)

        try assertFont(at: location(of: "case", in: text), in: styled, matches: MarkdownTheme.bodyFont(size: baseFontSize))
    }

    @MainActor
    func testLinkStylesLabelDestinationAndSyntax() throws {
        let text = "[label](https://example.com)"
        let styled = render(text)

        try assertColor(at: location(of: "label", in: text), in: styled, matches: MarkdownTheme.link)
        XCTAssertEqual(try underlineStyle(at: location(of: "label", in: text), in: styled), NSUnderlineStyle.single.rawValue)
        try assertColor(at: location(of: "https://example.com", in: text), in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
        try assertColor(at: location(of: "(", in: text), in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
        try assertColor(at: text.count - 1, in: styled, matches: MarkdownTheme.muted.withAlphaComponent(0.78))
    }

    @MainActor
    func testInlineStylesAreIgnoredInsideFencedCode() throws {
        let text = """
        ```
        **bold** *italic* [link](url)
        ```
        """
        let styled = render(text)

        try assertFont(at: location(of: "bold", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertFont(at: location(of: "italic", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertColor(at: location(of: "link", in: text), in: styled, matches: MarkdownTheme.codeInk)
    }

    @MainActor
    func testInlineCodeSuppressesNestedBold() throws {
        let text = "`**literal**`"
        let styled = render(text)

        try assertFont(at: location(of: "literal", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertColor(at: 1, in: styled, matches: MarkdownTheme.codeInk)
    }

    @MainActor
    func testInlineCodeInsideBoldPreservesCodeStyle() throws {
        let text = "**before `code` after**"
        let styled = render(text)

        try assertFont(at: location(of: "before", in: text), in: styled, matches: MarkdownTheme.strongFont(size: baseFontSize))
        try assertFont(at: location(of: "code", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertBackgroundColor(at: location(of: "code", in: text), in: styled, matches: MarkdownTheme.codeBackground)
        try assertFont(at: location(of: "after", in: text), in: styled, matches: MarkdownTheme.strongFont(size: baseFontSize))
    }

    @MainActor
    func testInlineCodeInsideEmphasisPreservesCodeStyle() throws {
        let text = "*before `code` after*"
        let styled = render(text)

        try assertFont(at: location(of: "before", in: text), in: styled, matches: MarkdownTheme.emphasisFont(size: baseFontSize))
        try assertFont(at: location(of: "code", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertBackgroundColor(at: location(of: "code", in: text), in: styled, matches: MarkdownTheme.codeBackground)
        try assertFont(at: location(of: "after", in: text), in: styled, matches: MarkdownTheme.emphasisFont(size: baseFontSize))
    }

    @MainActor
    func testInlineCodeContainingLinkSyntaxDoesNotBecomeLink() throws {
        let text = "`[label](url)`"
        let styled = render(text)

        try assertFont(at: location(of: "label", in: text), in: styled, matches: MarkdownTheme.codeFont(size: baseFontSize))
        try assertColor(at: location(of: "label", in: text), in: styled, matches: MarkdownTheme.codeInk)
        XCTAssertEqual(try underlineStyle(at: location(of: "label", in: text), in: styled), 0)
    }

    @MainActor
    private func render(_ text: String) -> NSAttributedString {
        MarkdownStyler.styledText(for: text, baseFontSize: baseFontSize)
    }

    private func location(of substring: String, in text: String) -> Int {
        let range = (text as NSString).range(of: substring)
        XCTAssertNotEqual(range.location, NSNotFound, "Missing substring \(substring)")
        return range.location
    }

    @MainActor
    private func wrappedLineRanges(for text: String, width: CGFloat) -> [NSRange] {
        let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 400))
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = false
        textView.textContainer?.lineFragmentPadding = 0
        textView.string = text

        MarkdownStyler.apply(to: textView, baseFontSize: baseFontSize)

        guard let layoutManager = textView.layoutManager, let textContainer = textView.textContainer else {
            XCTFail("Missing text system")
            return []
        }

        layoutManager.ensureLayout(for: textContainer)

        var ranges: [NSRange] = []
        var glyphIndex = 0

        while glyphIndex < layoutManager.numberOfGlyphs {
            var glyphRange = NSRange()
            _ = layoutManager.lineFragmentUsedRect(forGlyphAt: glyphIndex, effectiveRange: &glyphRange)
            ranges.append(layoutManager.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil))
            glyphIndex = NSMaxRange(glyphRange)
        }

        return ranges
    }

    private func lineText(in text: String, range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    @MainActor
    private func assertFont(
        at location: Int,
        in styled: NSAttributedString,
        matches expected: NSFont,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try XCTUnwrap(styled.attribute(.font, at: location, effectiveRange: nil) as? NSFont, file: file, line: line)
        XCTAssertEqual(actual.fontName, expected.fontName, file: file, line: line)
        XCTAssertEqual(actual.pointSize, expected.pointSize, accuracy: 0.01, file: file, line: line)
    }

    @MainActor
    private func assertColor(
        at location: Int,
        in styled: NSAttributedString,
        matches expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try XCTUnwrap(styled.attribute(.foregroundColor, at: location, effectiveRange: nil) as? NSColor, file: file, line: line)
        assertColor(actual, matches: expected, file: file, line: line)
    }

    @MainActor
    private func assertBackgroundColor(
        at location: Int,
        in styled: NSAttributedString,
        matches expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try XCTUnwrap(styled.attribute(.backgroundColor, at: location, effectiveRange: nil) as? NSColor, file: file, line: line)
        assertColor(actual, matches: expected, file: file, line: line)
    }

    private func assertParagraphHeadIndent(
        at location: Int,
        in styled: NSAttributedString,
        equals expected: CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let actual = try paragraphHeadIndent(at: location, in: styled, file: file, line: line)
        XCTAssertEqual(actual, expected, accuracy: 0.01, file: file, line: line)
    }

    private func assertLineBreakStrategy(
        at location: Int,
        in styled: NSAttributedString,
        includes expected: NSParagraphStyle.LineBreakStrategy,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        let paragraph = try XCTUnwrap(styled.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle, file: file, line: line)
        XCTAssertTrue(paragraph.lineBreakStrategy.contains(expected), file: file, line: line)
    }

    private func underlineStyle(
        at location: Int,
        in styled: NSAttributedString,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> Int {
        (styled.attribute(.underlineStyle, at: location, effectiveRange: nil) as? Int) ?? 0
    }

    private func paragraphHeadIndent(
        at location: Int,
        in styled: NSAttributedString,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws -> CGFloat {
        let paragraph = try XCTUnwrap(styled.attribute(.paragraphStyle, at: location, effectiveRange: nil) as? NSParagraphStyle, file: file, line: line)
        return paragraph.headIndent
    }

    @MainActor
    private func measuredPrefixWidth(
        leadingWhitespace: String,
        marker: String,
        spacing: String,
        markerFont: NSFont
    ) -> CGFloat {
        let bodyFont = MarkdownTheme.bodyFont(size: baseFontSize)
        return ceil(
            width(of: leadingWhitespace, font: bodyFont) +
            width(of: marker, font: markerFont) +
            width(of: spacing, font: bodyFont)
        )
    }

    private func width(of text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    @MainActor
    private func assertColor(
        _ actual: NSColor,
        matches expected: NSColor,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let actualRGB = actual.usingColorSpace(.extendedSRGB)
        let expectedRGB = expected.usingColorSpace(.extendedSRGB)

        XCTAssertNotNil(actualRGB, file: file, line: line)
        XCTAssertNotNil(expectedRGB, file: file, line: line)

        guard let actualRGB, let expectedRGB else { return }

        XCTAssertEqual(actualRGB.redComponent, expectedRGB.redComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.greenComponent, expectedRGB.greenComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.blueComponent, expectedRGB.blueComponent, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(actualRGB.alphaComponent, expectedRGB.alphaComponent, accuracy: 0.001, file: file, line: line)
    }
}
