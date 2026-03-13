import AppKit
import SwiftUI

@MainActor
struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let focusToken: UUID

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = NSTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.insertionPointColor = MarkdownTheme.ink
        textView.textColor = MarkdownTheme.ink
        textView.font = MarkdownTheme.bodyFont
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindBar = true
        textView.usesFontPanel = false
        textView.usesRuler = false
        textView.isContinuousSpellCheckingEnabled = true
        textView.isAutomaticTextCompletionEnabled = true
        textView.textContainerInset = NSSize(width: 4, height: 8)
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.isHorizontallyResizable = false
        textView.isVerticallyResizable = true
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.autoresizingMask = [.width]

        scrollView.documentView = textView

        context.coordinator.attach(textView: textView)
        context.coordinator.render(text: text, moveCaretToEnd: true)
        context.coordinator.focusIfNeeded(using: focusToken)

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        context.coordinator.render(text: text)
        context.coordinator.focusIfNeeded(using: focusToken)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        private weak var textView: NSTextView?
        private var isApplyingProgrammaticChange = false
        private var lastFocusToken: UUID?

        init(text: Binding<String>) {
            _text = text
        }

        func attach(textView: NSTextView) {
            self.textView = textView
        }

        func render(text: String, moveCaretToEnd: Bool = false) {
            guard let textView else { return }

            if textView.string != text {
                isApplyingProgrammaticChange = true
                textView.string = text
                isApplyingProgrammaticChange = false

                if moveCaretToEnd {
                    let end = (text as NSString).length
                    textView.setSelectedRange(NSRange(location: end, length: 0))
                }
            }

            MarkdownStyler.apply(to: textView)
        }

        func focusIfNeeded(using token: UUID) {
            guard lastFocusToken != token, let textView else { return }

            lastFocusToken = token

            DispatchQueue.main.async {
                guard let window = textView.window else { return }
                window.makeFirstResponder(textView)
            }
        }

        func textDidChange(_ notification: Notification) {
            guard let textView, !isApplyingProgrammaticChange else { return }

            text = textView.string

            guard !textView.hasMarkedText() else {
                return
            }

            MarkdownStyler.apply(to: textView)
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView, !isApplyingProgrammaticChange else { return }
            text = textView.string
            MarkdownStyler.apply(to: textView)
        }
    }
}

@MainActor
private enum MarkdownStyler {
    private static let headingRegex = try! NSRegularExpression(pattern: #"^(\s*)(#{1,6})(\s+)(.+)$"#, options: [.anchorsMatchLines])
    private static let bulletRegex = try! NSRegularExpression(pattern: #"^(\s*)([-*+])(\s+)(.+)$"#, options: [.anchorsMatchLines])
    private static let numberedListRegex = try! NSRegularExpression(pattern: #"^(\s*)(\d+\.)(\s+)(.+)$"#, options: [.anchorsMatchLines])
    private static let quoteRegex = try! NSRegularExpression(pattern: #"^(\s*)(>)(\s?)(.+)?$"#, options: [.anchorsMatchLines])
    private static let ruleRegex = try! NSRegularExpression(pattern: #"^\s*((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$"#, options: [.anchorsMatchLines])
    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#)
    private static let boldRegex = try! NSRegularExpression(pattern: #"\*\*([^\*\n][^*\n]*?)\*\*"#)
    private static let italicRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^\*\n][^*\n]*?)\*(?!\*)"#)
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)\s]+)\)"#)

    static func apply(to textView: NSTextView) {
        guard let storage = textView.textStorage else { return }

        let selection = textView.selectedRanges
        let string = textView.string
        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        storage.beginEditing()
        storage.setAttributes(baseAttributes(), range: fullRange)

        guard fullRange.length > 0 else {
            storage.endEditing()
            textView.typingAttributes = baseAttributes()
            textView.selectedRanges = selection
            return
        }

        let fencedRanges = applyBlockLevelStyles(to: storage, text: string, nsString: nsString)
        applyInlineStyles(to: storage, text: string, excludedRanges: fencedRanges)

        storage.endEditing()
        textView.typingAttributes = baseAttributes()
        textView.selectedRanges = selection
    }

    private static func applyBlockLevelStyles(
        to storage: NSTextStorage,
        text: String,
        nsString: NSString
    ) -> [NSRange] {
        let fullRange = NSRange(location: 0, length: nsString.length)
        var fencedRanges: [NSRange] = []
        var openFenceStart: Int?
        var lineRanges: [NSRange] = []

        nsString.enumerateSubstrings(in: fullRange, options: [.byLines, .substringNotRequired]) { _, lineRange, _, _ in
            lineRanges.append(lineRange)
        }

        for lineRange in lineRanges {
            let line = nsString.substring(with: lineRange)
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("```") {
                if let start = openFenceStart {
                    fencedRanges.append(NSRange(location: start, length: NSMaxRange(lineRange) - start))
                    openFenceStart = nil
                } else {
                    openFenceStart = lineRange.location
                }

                storage.addAttributes(codeBlockAttributes(level: .fence), range: lineRange)
                continue
            }

            if openFenceStart != nil {
                storage.addAttributes(codeBlockAttributes(level: .body), range: lineRange)
                continue
            }
        }

        if let start = openFenceStart {
            fencedRanges.append(NSRange(location: start, length: fullRange.length - start))
        }

        let headingMatches = headingRegex.matches(in: text, range: fullRange)
        for match in headingMatches {
            let markerRange = match.range(at: 2)
            let bodyRange = match.range(at: 4)
            let level = max(1, min(6, markerRange.length))

            storage.addAttributes(headingAttributes(level: level), range: match.range)
            storage.addAttributes(markerAttributes(), range: markerRange)
            storage.addAttributes(headingBodyAttributes(level: level), range: bodyRange)
        }

        for match in bulletRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            storage.addAttributes(listAttributes(indent: 26), range: match.range)
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
        }

        for match in numberedListRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            storage.addAttributes(listAttributes(indent: 30), range: match.range)
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
        }

        for match in quoteRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            storage.addAttributes(quoteAttributes(), range: match.range)
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
        }

        for match in ruleRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }
            storage.addAttributes(ruleAttributes(), range: match.range)
        }

        return fencedRanges
    }

    private static func applyInlineStyles(
        to storage: NSTextStorage,
        text: String,
        excludedRanges: [NSRange]
    ) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        for match in inlineCodeRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }
            storage.addAttributes(codeSpanAttributes(), range: match.range)
        }

        for match in boldRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }

            storage.addAttributes(markerAttributes(), range: NSRange(location: match.range.location, length: 2))
            storage.addAttributes(
                markerAttributes(),
                range: NSRange(location: NSMaxRange(match.range) - 2, length: 2)
            )
            storage.addAttributes(strongAttributes(), range: match.range(at: 1))
        }

        for match in italicRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }
            storage.addAttributes(markerAttributes(), range: NSRange(location: match.range.location, length: 1))
            storage.addAttributes(
                markerAttributes(),
                range: NSRange(location: NSMaxRange(match.range) - 1, length: 1)
            )
            storage.addAttributes(emphasisAttributes(), range: match.range(at: 1))
        }

        for match in linkRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }

            storage.addAttributes(linkAttributes(), range: match.range(at: 1))
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
            storage.addAttributes(markerAttributes(), range: NSRange(location: match.range.location, length: 1))
            storage.addAttributes(
                markerAttributes(),
                range: NSRange(location: match.range.location + match.range(at: 1).length + 1, length: 1)
            )
        }
    }

    private static func baseAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.bodyFont,
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: baseParagraphStyle()
        ]
    }

    private static func headingAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 6
        paragraph.paragraphSpacing = 12
        paragraph.paragraphSpacingBefore = level == 1 ? 8 : 4

        return [
            .font: MarkdownTheme.headingFont(level: level),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: paragraph
        ]
    }

    private static func headingBodyAttributes(level: Int) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.headingFont(level: level),
            .foregroundColor: MarkdownTheme.ink
        ]
    }

    private static func listAttributes(indent: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = baseParagraphStyle()
        paragraph.headIndent = indent
        paragraph.firstLineHeadIndent = 0

        return [
            .paragraphStyle: paragraph
        ]
    }

    private static func quoteAttributes() -> [NSAttributedString.Key: Any] {
        let paragraph = baseParagraphStyle()
        paragraph.headIndent = 18
        paragraph.firstLineHeadIndent = 0

        return [
            .paragraphStyle: paragraph,
            .foregroundColor: MarkdownTheme.quote
        ]
    }

    private static func ruleAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: MarkdownTheme.muted.withAlphaComponent(0.55),
            .font: MarkdownTheme.smallCapsFont
        ]
    }

    private static func codeBlockAttributes(level: CodeBlockLevel) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 5
        paragraph.paragraphSpacing = 7
        paragraph.paragraphSpacingBefore = level == .body ? 0 : 6
        paragraph.headIndent = 14
        paragraph.firstLineHeadIndent = 14

        return [
            .font: MarkdownTheme.codeFont,
            .foregroundColor: MarkdownTheme.codeInk,
            .backgroundColor: MarkdownTheme.codeBackground,
            .paragraphStyle: paragraph
        ]
    }

    private static func codeSpanAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.codeFont,
            .foregroundColor: MarkdownTheme.codeInk,
            .backgroundColor: MarkdownTheme.codeBackground
        ]
    }

    private static func strongAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.strongFont,
            .foregroundColor: MarkdownTheme.ink
        ]
    }

    private static func emphasisAttributes() -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.emphasisFont,
            .foregroundColor: MarkdownTheme.ink
        ]
    }

    private static func linkAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: MarkdownTheme.link,
            .underlineStyle: NSUnderlineStyle.single.rawValue
        ]
    }

    private static func markerAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: MarkdownTheme.muted.withAlphaComponent(0.78)
        ]
    }

    private static func baseParagraphStyle() -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 7
        paragraph.paragraphSpacing = 8
        paragraph.paragraphSpacingBefore = 0
        return paragraph
    }

    private static func range(_ range: NSRange, intersectsAnyOf ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private enum CodeBlockLevel {
        case fence
        case body
    }
}

@MainActor
private enum MarkdownTheme {
    static let ink = NSColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
    static let muted = NSColor(red: 0.46, green: 0.41, blue: 0.35, alpha: 1)
    static let quote = NSColor(red: 0.37, green: 0.33, blue: 0.28, alpha: 1)
    static let link = NSColor(red: 0.23, green: 0.39, blue: 0.68, alpha: 1)
    static let codeInk = NSColor(red: 0.17, green: 0.16, blue: 0.15, alpha: 1)
    static let codeBackground = NSColor(red: 0.93, green: 0.90, blue: 0.84, alpha: 0.95)

    static let bodyFont = serifFont(size: 20)
    static let strongFont = serifFont(size: 20, weight: .semibold)
    static let emphasisFont = italicSerifFont(size: 20)
    static let codeFont = NSFont.monospacedSystemFont(ofSize: 17, weight: .regular)
    static let smallCapsFont = NSFont.systemFont(ofSize: 14, weight: .medium)

    static func headingFont(level: Int) -> NSFont {
        switch level {
        case 1: serifFont(size: 31, weight: .bold)
        case 2: serifFont(size: 28, weight: .bold)
        case 3: serifFont(size: 24, weight: .semibold)
        case 4: serifFont(size: 21, weight: .semibold)
        case 5: serifFont(size: 19, weight: .medium)
        default: serifFont(size: 18, weight: .medium)
        }
    }

    static func serifFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        let base = NSFont.systemFont(ofSize: size, weight: weight)

        if let descriptor = base.fontDescriptor.withDesign(.serif),
           let font = NSFont(descriptor: descriptor, size: size) {
            return font
        }

        return base
    }

    static func italicSerifFont(size: CGFloat) -> NSFont {
        let base = serifFont(size: size)
        let italic = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        return italic.pointSize == 0 ? base : italic
    }
}
