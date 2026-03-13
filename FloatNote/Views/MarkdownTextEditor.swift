import AppKit
import SwiftUI

@MainActor
struct MarkdownTextEditor: NSViewRepresentable {
    @Binding var text: String
    let fontSize: CGFloat
    let focusToken: UUID
    let onFocusChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, fontSize: fontSize, onFocusChange: onFocusChange)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = TrackingTextView()
        textView.delegate = context.coordinator
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.insertionPointColor = MarkdownTheme.ink
        textView.textColor = MarkdownTheme.ink
        textView.font = MarkdownTheme.bodyFont(size: fontSize)
        textView.typingAttributes = MarkdownStyler.typingAttributes(baseFontSize: fontSize)
        textView.defaultParagraphStyle = MarkdownStyler.typingParagraphStyle(baseFontSize: fontSize)
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
        context.coordinator.onFocusChange = onFocusChange
        context.coordinator.fontSize = fontSize
        context.coordinator.render(text: text)
        context.coordinator.focusIfNeeded(using: focusToken)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        @Binding private var text: String
        var fontSize: CGFloat
        private weak var textView: NSTextView?
        var onFocusChange: (Bool) -> Void
        private var isApplyingProgrammaticChange = false
        private var lastFocusToken: UUID?

        init(text: Binding<String>, fontSize: CGFloat, onFocusChange: @escaping (Bool) -> Void) {
            _text = text
            self.fontSize = fontSize
            self.onFocusChange = onFocusChange
        }

        func attach(textView: TrackingTextView) {
            self.textView = textView
            textView.onFocusChange = { [weak self] isFocused in
                self?.onFocusChange(isFocused)
            }
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

            textView.font = MarkdownTheme.bodyFont(size: fontSize)
            textView.defaultParagraphStyle = MarkdownStyler.typingParagraphStyle(baseFontSize: fontSize)
            MarkdownStyler.apply(to: textView, baseFontSize: fontSize)
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

            MarkdownStyler.apply(to: textView, baseFontSize: fontSize)
        }

        func textDidEndEditing(_ notification: Notification) {
            guard let textView, !isApplyingProgrammaticChange else { return }
            text = textView.string
            MarkdownStyler.apply(to: textView, baseFontSize: fontSize)
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            guard commandSelector == #selector(NSResponder.insertNewline(_:)) else {
                return false
            }

            return continueMarkdownList(in: textView)
        }

        private func continueMarkdownList(in textView: NSTextView) -> Bool {
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return false }

            let nsString = textView.string as NSString
            let location = min(selection.location, nsString.length)
            let lineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
            let prefixRange = NSRange(location: lineRange.location, length: location - lineRange.location)
            let linePrefix = nsString.substring(with: prefixRange)

            guard let insertion = MarkdownContinuation.insertion(for: linePrefix) else {
                return false
            }

            textView.insertText(insertion, replacementRange: selection)
            return true
        }
    }
}

final class TrackingTextView: NSTextView {
    var onFocusChange: ((Bool) -> Void)?

    override func becomeFirstResponder() -> Bool {
        let didBecomeFirstResponder = super.becomeFirstResponder()
        if didBecomeFirstResponder {
            onFocusChange?(true)
        }
        return didBecomeFirstResponder
    }

    override func resignFirstResponder() -> Bool {
        let didResignFirstResponder = super.resignFirstResponder()
        if didResignFirstResponder {
            onFocusChange?(false)
        }
        return didResignFirstResponder
    }
}

private enum MarkdownContinuation {
    private static let bulletPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s+(.+)$"#)
    private static let numberedPattern = try! NSRegularExpression(pattern: #"^(\s*)(\d+)\.\s+(.+)$"#)
    private static let quotePattern = try! NSRegularExpression(pattern: #"^(\s*)>\s+(.+)$"#)

    static func insertion(for linePrefix: String) -> String? {
        let trimmedLine = linePrefix.trimmingCharacters(in: .newlines)
        let range = NSRange(location: 0, length: (trimmedLine as NSString).length)

        if let match = bulletPattern.firstMatch(in: trimmedLine, range: range) {
            let nsString = trimmedLine as NSString
            let indent = nsString.substring(with: match.range(at: 1))
            let marker = nsString.substring(with: match.range(at: 2))
            return "\n\(indent)\(marker) "
        }

        if let match = numberedPattern.firstMatch(in: trimmedLine, range: range) {
            let nsString = trimmedLine as NSString
            let indent = nsString.substring(with: match.range(at: 1))
            let numberString = nsString.substring(with: match.range(at: 2))
            let nextNumber = (Int(numberString) ?? 0) + 1
            return "\n\(indent)\(nextNumber). "
        }

        if let match = quotePattern.firstMatch(in: trimmedLine, range: range) {
            let nsString = trimmedLine as NSString
            let indent = nsString.substring(with: match.range(at: 1))
            return "\n\(indent)> "
        }

        return nil
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

    static func apply(to textView: NSTextView, baseFontSize: CGFloat) {
        guard let storage = textView.textStorage else { return }

        let selection = textView.selectedRanges
        let string = textView.string
        let nsString = string as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        storage.beginEditing()
        storage.setAttributes(baseAttributes(baseFontSize: baseFontSize), range: fullRange)

        guard fullRange.length > 0 else {
            storage.endEditing()
            textView.typingAttributes = typingAttributes(baseFontSize: baseFontSize)
            textView.selectedRanges = selection
            return
        }

        let fencedRanges = applyBlockLevelStyles(
            to: storage,
            text: string,
            nsString: nsString,
            baseFontSize: baseFontSize
        )
        applyInlineStyles(
            to: storage,
            text: string,
            excludedRanges: fencedRanges,
            baseFontSize: baseFontSize
        )

        storage.endEditing()
        textView.typingAttributes = typingAttributes(baseFontSize: baseFontSize)
        textView.selectedRanges = selection
    }

    static func typingAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.bodyFont(size: baseFontSize),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: typingParagraphStyle(baseFontSize: baseFontSize)
        ]
    }

    private static func applyBlockLevelStyles(
        to storage: NSTextStorage,
        text: String,
        nsString: NSString,
        baseFontSize: CGFloat
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

                storage.addAttributes(codeBlockAttributes(level: .fence, baseFontSize: baseFontSize), range: lineRange)
                continue
            }

            if openFenceStart != nil {
                storage.addAttributes(codeBlockAttributes(level: .body, baseFontSize: baseFontSize), range: lineRange)
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

            storage.addAttributes(headingAttributes(level: level, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(markerAttributes(), range: markerRange)
            storage.addAttributes(headingBodyAttributes(level: level, baseFontSize: baseFontSize), range: bodyRange)
        }

        for match in bulletRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            storage.addAttributes(listAttributes(indent: 24, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
        }

        for match in numberedListRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            storage.addAttributes(listAttributes(indent: 28, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
        }

        for match in quoteRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            storage.addAttributes(quoteAttributes(baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(markerAttributes(), range: match.range(at: 2))
        }

        for match in ruleRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }
            storage.addAttributes(ruleAttributes(baseFontSize: baseFontSize), range: match.range)
        }

        return fencedRanges
    }

    private static func applyInlineStyles(
        to storage: NSTextStorage,
        text: String,
        excludedRanges: [NSRange],
        baseFontSize: CGFloat
    ) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)

        for match in inlineCodeRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }
            storage.addAttributes(codeSpanAttributes(baseFontSize: baseFontSize), range: match.range)
        }

        for match in boldRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }

            storage.addAttributes(markerAttributes(), range: NSRange(location: match.range.location, length: 2))
            storage.addAttributes(
                markerAttributes(),
                range: NSRange(location: NSMaxRange(match.range) - 2, length: 2)
            )
            storage.addAttributes(strongAttributes(baseFontSize: baseFontSize), range: match.range(at: 1))
        }

        for match in italicRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: excludedRanges) else { continue }
            storage.addAttributes(markerAttributes(), range: NSRange(location: match.range.location, length: 1))
            storage.addAttributes(
                markerAttributes(),
                range: NSRange(location: NSMaxRange(match.range) - 1, length: 1)
            )
            storage.addAttributes(emphasisAttributes(baseFontSize: baseFontSize), range: match.range(at: 1))
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

    private static func baseAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.bodyFont(size: baseFontSize),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: baseParagraphStyle(baseFontSize: baseFontSize)
        ]
    }

    private static func headingAttributes(level: Int, baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing(for: baseFontSize) + 0.5
        paragraph.paragraphSpacing = paragraphSpacing(for: baseFontSize) + 2
        paragraph.paragraphSpacingBefore = level == 1 ? 5 : 3

        return [
            .font: MarkdownTheme.headingFont(level: level, baseFontSize: baseFontSize),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: paragraph
        ]
    }

    private static func headingBodyAttributes(level: Int, baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.headingFont(level: level, baseFontSize: baseFontSize),
            .foregroundColor: MarkdownTheme.ink
        ]
    }

    private static func listAttributes(indent: CGFloat, baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = baseParagraphStyle(baseFontSize: baseFontSize)
        paragraph.headIndent = indent
        paragraph.firstLineHeadIndent = 0

        return [
            .paragraphStyle: paragraph
        ]
    }

    private static func quoteAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = baseParagraphStyle(baseFontSize: baseFontSize)
        paragraph.headIndent = 18
        paragraph.firstLineHeadIndent = 0

        return [
            .paragraphStyle: paragraph,
            .foregroundColor: MarkdownTheme.quote
        ]
    }

    private static func ruleAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: MarkdownTheme.muted.withAlphaComponent(0.55),
            .font: MarkdownTheme.smallCapsFont(size: max(11, baseFontSize))
        ]
    }

    private static func codeBlockAttributes(level: CodeBlockLevel, baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = max(1, lineSpacing(for: baseFontSize) - 0.5)
        paragraph.paragraphSpacing = max(2, paragraphSpacing(for: baseFontSize) - 1)
        paragraph.paragraphSpacingBefore = level == .body ? 0 : 4
        paragraph.headIndent = 12
        paragraph.firstLineHeadIndent = 12

        return [
            .font: MarkdownTheme.codeFont(size: baseFontSize),
            .foregroundColor: MarkdownTheme.codeInk,
            .backgroundColor: MarkdownTheme.codeBackground,
            .paragraphStyle: paragraph
        ]
    }

    private static func codeSpanAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.codeFont(size: baseFontSize),
            .foregroundColor: MarkdownTheme.codeInk,
            .backgroundColor: MarkdownTheme.codeBackground
        ]
    }

    private static func strongAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.strongFont(size: baseFontSize),
            .foregroundColor: MarkdownTheme.ink
        ]
    }

    private static func emphasisAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.emphasisFont(size: baseFontSize),
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

    private static func baseParagraphStyle(baseFontSize: CGFloat) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing(for: baseFontSize)
        paragraph.paragraphSpacing = paragraphSpacing(for: baseFontSize)
        paragraph.paragraphSpacingBefore = 0
        return paragraph
    }

    static func typingParagraphStyle(baseFontSize: CGFloat) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing(for: baseFontSize)
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        return paragraph
    }

    private static func lineSpacing(for baseFontSize: CGFloat) -> CGFloat {
        max(1.5, floor(baseFontSize * 0.18 * 10) / 10)
    }

    private static func paragraphSpacing(for baseFontSize: CGFloat) -> CGFloat {
        max(2.5, floor(baseFontSize * 0.28 * 10) / 10)
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

    static func bodyFont(size: CGFloat) -> NSFont {
        textFont(size: size)
    }

    static func strongFont(size: CGFloat) -> NSFont {
        textFont(size: size, weight: .semibold)
    }

    static func emphasisFont(size: CGFloat) -> NSFont {
        italicTextFont(size: size)
    }

    static func codeFont(size: CGFloat) -> NSFont {
        NSFont.monospacedSystemFont(ofSize: max(11, size - 0.5), weight: .regular)
    }

    static func smallCapsFont(size: CGFloat) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: .medium)
    }

    static func headingFont(level: Int, baseFontSize: CGFloat) -> NSFont {
        switch level {
        case 1: textFont(size: baseFontSize + 7, weight: .bold)
        case 2: textFont(size: baseFontSize + 4.5, weight: .bold)
        case 3: textFont(size: baseFontSize + 2.5, weight: .semibold)
        case 4: textFont(size: baseFontSize + 1.5, weight: .semibold)
        case 5: textFont(size: baseFontSize + 0.5, weight: .medium)
        default: textFont(size: baseFontSize, weight: .medium)
        }
    }

    static func textFont(size: CGFloat, weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }

    static func italicTextFont(size: CGFloat) -> NSFont {
        let base = textFont(size: size)
        let italic = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        return italic.pointSize == 0 ? base : italic
    }
}
