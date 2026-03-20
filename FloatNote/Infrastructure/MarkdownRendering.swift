import AppKit

enum MarkdownContinuation {
    enum Action: Equatable {
        case insert(String)
        case terminateList
    }

    private static let bulletPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s+(.+)$"#)
    private static let numberedPattern = try! NSRegularExpression(pattern: #"^(\s*)(\d+)\.\s+(.+)$"#)
    private static let quotePattern = try! NSRegularExpression(pattern: #"^(\s*)>\s+(.+)$"#)
    private static let emptyBulletPattern = try! NSRegularExpression(pattern: #"^(\s*)([-*+])\s*$"#)
    private static let emptyNumberedPattern = try! NSRegularExpression(pattern: #"^(\s*)(\d+)\.\s*$"#)
    private static let emptyQuotePattern = try! NSRegularExpression(pattern: #"^(\s*)>\s*$"#)

    static func action(for line: String) -> Action? {
        let trimmedLine = line.trimmingCharacters(in: .newlines)
        let range = NSRange(location: 0, length: (trimmedLine as NSString).length)

        if emptyBulletPattern.firstMatch(in: trimmedLine, range: range) != nil {
            return .terminateList
        }

        if emptyNumberedPattern.firstMatch(in: trimmedLine, range: range) != nil {
            return .terminateList
        }

        if emptyQuotePattern.firstMatch(in: trimmedLine, range: range) != nil {
            return .terminateList
        }

        if let match = bulletPattern.firstMatch(in: trimmedLine, range: range) {
            let nsString = trimmedLine as NSString
            let indent = nsString.substring(with: match.range(at: 1))
            let marker = nsString.substring(with: match.range(at: 2))
            return .insert("\n\(indent)\(marker) ")
        }

        if let match = numberedPattern.firstMatch(in: trimmedLine, range: range) {
            let nsString = trimmedLine as NSString
            let indent = nsString.substring(with: match.range(at: 1))
            let numberString = nsString.substring(with: match.range(at: 2))
            let nextNumber = (Int(numberString) ?? 0) + 1
            return .insert("\n\(indent)\(nextNumber). ")
        }

        if let match = quotePattern.firstMatch(in: trimmedLine, range: range) {
            let nsString = trimmedLine as NSString
            let indent = nsString.substring(with: match.range(at: 1))
            return .insert("\n\(indent)> ")
        }

        return nil
    }

    static func insertion(for linePrefix: String) -> String? {
        guard case let .insert(insertion) = action(for: linePrefix) else {
            return nil
        }

        return insertion
    }
}

@MainActor
enum MarkdownStyler {
    private static let headingRegex = try! NSRegularExpression(
        pattern: #"^(\s*)(#{1,6})(\s+)(.*)$"#,
        options: [.anchorsMatchLines]
    )
    private static let bulletRegex = try! NSRegularExpression(
        pattern: #"^(\s*)([-*+])(\s+)(.*)$"#,
        options: [.anchorsMatchLines]
    )
    private static let numberedListRegex = try! NSRegularExpression(
        pattern: #"^(\s*)(\d+\.)(\s+)(.*)$"#,
        options: [.anchorsMatchLines]
    )
    private static let quoteRegex = try! NSRegularExpression(
        pattern: #"^(\s*)(>)(\s?)(.+)?$"#,
        options: [.anchorsMatchLines]
    )
    private static let ruleRegex = try! NSRegularExpression(
        pattern: #"^\s*((\*\s*){3,}|(-\s*){3,}|(_\s*){3,})$"#,
        options: [.anchorsMatchLines]
    )
    private static let inlineCodeRegex = try! NSRegularExpression(pattern: #"`([^`\n]+)`"#)
    private static let strongAsteriskRegex = try! NSRegularExpression(pattern: #"\*\*([^\*\n][^*\n]*?)\*\*"#)
    private static let strongUnderscoreRegex = try! NSRegularExpression(pattern: #"(?<![\w_])__([^_\n][^_\n]*?)__(?![\w_])"#)
    private static let emphasisAsteriskRegex = try! NSRegularExpression(pattern: #"(?<!\*)\*([^\*\n][^*\n]*?)\*(?!\*)"#)
    private static let emphasisUnderscoreRegex = try! NSRegularExpression(pattern: #"(?<![\w_])_([^_\n][^_\n]*?)_(?![\w_])"#)
    private static let linkRegex = try! NSRegularExpression(pattern: #"\[([^\]]+)\]\(([^)\s]+)\)"#)

    static func apply(to textView: NSTextView, baseFontSize: CGFloat) {
        guard let storage = textView.textStorage else { return }

        let selection = textView.selectedRanges
        applyStyles(to: storage, text: textView.string, baseFontSize: baseFontSize)
        textView.typingAttributes = typingAttributes(baseFontSize: baseFontSize)
        textView.selectedRanges = selection
    }

    static func styledText(for text: String, baseFontSize: CGFloat) -> NSAttributedString {
        let attributedText = NSMutableAttributedString(string: text)
        applyStyles(to: attributedText, text: text, baseFontSize: baseFontSize)
        return attributedText
    }

    static func typingAttributes(baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        [
            .font: MarkdownTheme.bodyFont(size: baseFontSize),
            .foregroundColor: MarkdownTheme.ink,
            .paragraphStyle: typingParagraphStyle(baseFontSize: baseFontSize)
        ]
    }

    static func typingParagraphStyle(baseFontSize: CGFloat) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing(for: baseFontSize)
        paragraph.paragraphSpacing = 0
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakStrategy = [.hangulWordPriority]
        return paragraph
    }

    private static func applyStyles(
        to storage: NSMutableAttributedString,
        text: String,
        baseFontSize: CGFloat
    ) {
        if let textStorage = storage as? NSTextStorage {
            textStorage.beginEditing()
            applyStylesWithoutEditingWrapper(to: storage, text: text, baseFontSize: baseFontSize)
            textStorage.endEditing()
            return
        }

        applyStylesWithoutEditingWrapper(to: storage, text: text, baseFontSize: baseFontSize)
    }

    private static func applyStylesWithoutEditingWrapper(
        to storage: NSMutableAttributedString,
        text: String,
        baseFontSize: CGFloat
    ) {
        let nsString = text as NSString
        let fullRange = NSRange(location: 0, length: nsString.length)

        storage.setAttributes(baseAttributes(baseFontSize: baseFontSize), range: fullRange)

        guard fullRange.length > 0 else {
            return
        }

        let fencedRanges = applyBlockLevelStyles(
            to: storage,
            text: text,
            nsString: nsString,
            baseFontSize: baseFontSize
        )
        applyInlineStyles(
            to: storage,
            text: text,
            excludedRanges: fencedRanges,
            baseFontSize: baseFontSize
        )
    }

    private static func applyBlockLevelStyles(
        to storage: NSMutableAttributedString,
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

        for match in headingRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            let markerRange = match.range(at: 2)
            let bodyRange = match.range(at: 4)
            let level = max(1, min(6, markerRange.length))

            storage.addAttributes(headingAttributes(level: level, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(syntaxMarkerAttributes(), range: markerRange)

            if bodyRange.length > 0 {
                storage.addAttributes(headingBodyAttributes(level: level, baseFontSize: baseFontSize), range: bodyRange)
            }
        }

        for match in bulletRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            let indent = blockPrefixWidth(
                leadingWhitespace: nsString.substring(with: match.range(at: 1)),
                marker: nsString.substring(with: match.range(at: 2)),
                spacing: nsString.substring(with: match.range(at: 3)),
                markerFont: MarkdownTheme.listMarkerFont(size: baseFontSize),
                baseFontSize: baseFontSize
            )

            storage.addAttributes(listAttributes(indent: indent, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(blockMarkerAttributes(font: MarkdownTheme.listMarkerFont(size: baseFontSize)), range: match.range(at: 2))
        }

        for match in numberedListRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            let indent = blockPrefixWidth(
                leadingWhitespace: nsString.substring(with: match.range(at: 1)),
                marker: nsString.substring(with: match.range(at: 2)),
                spacing: nsString.substring(with: match.range(at: 3)),
                markerFont: MarkdownTheme.numberedListMarkerFont(size: baseFontSize),
                baseFontSize: baseFontSize
            )

            storage.addAttributes(listAttributes(indent: indent, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(blockMarkerAttributes(font: MarkdownTheme.numberedListMarkerFont(size: baseFontSize)), range: match.range(at: 2))
        }

        for match in quoteRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }

            let indent = blockPrefixWidth(
                leadingWhitespace: nsString.substring(with: match.range(at: 1)),
                marker: nsString.substring(with: match.range(at: 2)),
                spacing: nsString.substring(with: match.range(at: 3)),
                markerFont: MarkdownTheme.listMarkerFont(size: baseFontSize),
                baseFontSize: baseFontSize
            )

            storage.addAttributes(quoteAttributes(indent: indent, baseFontSize: baseFontSize), range: match.range)
            storage.addAttributes(blockMarkerAttributes(font: MarkdownTheme.listMarkerFont(size: baseFontSize)), range: match.range(at: 2))
        }

        for match in ruleRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, intersectsAnyOf: fencedRanges) else { continue }
            storage.addAttributes(ruleAttributes(baseFontSize: baseFontSize), range: match.range)
        }

        return fencedRanges
    }

    private static func applyInlineStyles(
        to storage: NSMutableAttributedString,
        text: String,
        excludedRanges: [NSRange],
        baseFontSize: CGFloat
    ) {
        let fullRange = NSRange(location: 0, length: (text as NSString).length)
        let inlineCodeRanges = inlineCodeRegex.matches(in: text, range: fullRange)
            .map(\.range)
            .filter { !range($0, intersectsAnyOf: excludedRanges) }
        let protectedRanges = excludedRanges + inlineCodeRanges

        for codeRange in inlineCodeRanges {
            storage.addAttributes(codeSpanAttributes(baseFontSize: baseFontSize), range: codeRange)
        }

        for match in strongAsteriskRegex.matches(in: text, range: fullRange) {
            applyDelimitedInlineMatch(
                match,
                to: storage,
                protectedRanges: protectedRanges,
                contentAttributes: strongAttributes(baseFontSize: baseFontSize),
                markerLength: 2
            )
        }

        for match in strongUnderscoreRegex.matches(in: text, range: fullRange) {
            applyDelimitedInlineMatch(
                match,
                to: storage,
                protectedRanges: protectedRanges,
                contentAttributes: strongAttributes(baseFontSize: baseFontSize),
                markerLength: 2
            )
        }

        for match in emphasisAsteriskRegex.matches(in: text, range: fullRange) {
            applyDelimitedInlineMatch(
                match,
                to: storage,
                protectedRanges: protectedRanges,
                contentAttributes: emphasisAttributes(baseFontSize: baseFontSize),
                markerLength: 1
            )
        }

        for match in emphasisUnderscoreRegex.matches(in: text, range: fullRange) {
            applyDelimitedInlineMatch(
                match,
                to: storage,
                protectedRanges: protectedRanges,
                contentAttributes: emphasisAttributes(baseFontSize: baseFontSize),
                markerLength: 1
            )
        }

        for match in linkRegex.matches(in: text, range: fullRange) {
            guard !range(match.range, isFullyContainedInAnyOf: protectedRanges) else { continue }

            applyAttributes(
                linkAttributes(),
                toFragmentsOf: match.range(at: 1),
                excluding: protectedRanges,
                in: storage
            )
            applyAttributes(
                syntaxMarkerAttributes(),
                toFragmentsOf: match.range(at: 2),
                excluding: protectedRanges,
                in: storage
            )

            for syntaxRange in linkSyntaxRanges(for: match) {
                applyAttributes(
                    syntaxMarkerAttributes(),
                    toFragmentsOf: syntaxRange,
                    excluding: protectedRanges,
                    in: storage
                )
            }
        }
    }

    private static func applyDelimitedInlineMatch(
        _ match: NSTextCheckingResult,
        to storage: NSMutableAttributedString,
        protectedRanges: [NSRange],
        contentAttributes: [NSAttributedString.Key: Any],
        markerLength: Int
    ) {
        guard !range(match.range, isFullyContainedInAnyOf: protectedRanges) else { return }

        let openingMarkerRange = NSRange(location: match.range.location, length: markerLength)
        let closingMarkerRange = NSRange(location: NSMaxRange(match.range) - markerLength, length: markerLength)

        applyAttributes(syntaxMarkerAttributes(), toFragmentsOf: openingMarkerRange, excluding: protectedRanges, in: storage)
        applyAttributes(syntaxMarkerAttributes(), toFragmentsOf: closingMarkerRange, excluding: protectedRanges, in: storage)
        applyAttributes(contentAttributes, toFragmentsOf: match.range(at: 1), excluding: protectedRanges, in: storage)
    }

    private static func applyAttributes(
        _ attributes: [NSAttributedString.Key: Any],
        toFragmentsOf range: NSRange,
        excluding excludedRanges: [NSRange],
        in storage: NSMutableAttributedString
    ) {
        for fragment in fragments(of: range, excluding: excludedRanges) {
            storage.addAttributes(attributes, range: fragment)
        }
    }

    private static func fragments(of range: NSRange, excluding excludedRanges: [NSRange]) -> [NSRange] {
        guard range.location != NSNotFound, range.length > 0 else { return [] }

        let sortedExclusions = excludedRanges
            .map { NSIntersectionRange(range, $0) }
            .filter { $0.length > 0 }
            .sorted { $0.location < $1.location }

        guard !sortedExclusions.isEmpty else { return [range] }

        var fragments: [NSRange] = []
        var cursor = range.location
        let end = NSMaxRange(range)

        for exclusion in sortedExclusions {
            if cursor < exclusion.location {
                fragments.append(NSRange(location: cursor, length: exclusion.location - cursor))
            }
            cursor = max(cursor, NSMaxRange(exclusion))
        }

        if cursor < end {
            fragments.append(NSRange(location: cursor, length: end - cursor))
        }

        return fragments
    }

    private static func linkSyntaxRanges(for match: NSTextCheckingResult) -> [NSRange] {
        let labelRange = match.range(at: 1)
        let destinationRange = match.range(at: 2)

        let openingBracket = NSRange(location: match.range.location, length: 1)
        let closingBracket = NSRange(location: labelRange.location + labelRange.length, length: 1)
        let openingParen = NSRange(location: destinationRange.location - 1, length: 1)
        let closingParen = NSRange(location: NSMaxRange(destinationRange), length: 1)

        return [openingBracket, closingBracket, openingParen, closingParen]
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
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.lineBreakStrategy = [.hangulWordPriority]

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
        paragraph.lineBreakMode = .byCharWrapping

        return [
            .paragraphStyle: paragraph
        ]
    }

    private static func quoteAttributes(indent: CGFloat, baseFontSize: CGFloat) -> [NSAttributedString.Key: Any] {
        let paragraph = baseParagraphStyle(baseFontSize: baseFontSize)
        paragraph.headIndent = indent
        paragraph.firstLineHeadIndent = 0
        paragraph.lineBreakMode = .byCharWrapping

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
        paragraph.lineBreakMode = .byCharWrapping
        paragraph.lineBreakStrategy = [.hangulWordPriority]

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

    private static func syntaxMarkerAttributes() -> [NSAttributedString.Key: Any] {
        [
            .foregroundColor: MarkdownTheme.muted.withAlphaComponent(0.78)
        ]
    }

    private static func blockMarkerAttributes(font: NSFont) -> [NSAttributedString.Key: Any] {
        [
            .font: font,
            .foregroundColor: MarkdownTheme.listMarker
        ]
    }

    private static func baseParagraphStyle(baseFontSize: CGFloat) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = lineSpacing(for: baseFontSize)
        paragraph.paragraphSpacing = paragraphSpacing(for: baseFontSize)
        paragraph.paragraphSpacingBefore = 0
        paragraph.lineBreakStrategy = [.hangulWordPriority]
        return paragraph
    }

    private static func lineSpacing(for baseFontSize: CGFloat) -> CGFloat {
        max(1.5, floor(baseFontSize * 0.18 * 10) / 10)
    }

    private static func paragraphSpacing(for baseFontSize: CGFloat) -> CGFloat {
        max(2.5, floor(baseFontSize * 0.28 * 10) / 10)
    }

    private static func blockPrefixWidth(
        leadingWhitespace: String,
        marker: String,
        spacing: String,
        markerFont: NSFont,
        baseFontSize: CGFloat
    ) -> CGFloat {
        let bodyFont = MarkdownTheme.bodyFont(size: baseFontSize)
        let indentWidth = width(of: leadingWhitespace, font: bodyFont)
        let markerWidth = width(of: marker, font: markerFont)
        let spacingWidth = width(of: spacing, font: bodyFont)

        return ceil(indentWidth + markerWidth + spacingWidth)
    }

    private static func width(of text: String, font: NSFont) -> CGFloat {
        (text as NSString).size(withAttributes: [.font: font]).width
    }

    private static func range(_ range: NSRange, intersectsAnyOf ranges: [NSRange]) -> Bool {
        ranges.contains { NSIntersectionRange($0, range).length > 0 }
    }

    private static func range(_ range: NSRange, isFullyContainedInAnyOf ranges: [NSRange]) -> Bool {
        ranges.contains { NSLocationInRange(range.location, $0) && NSLocationInRange(NSMaxRange(range) - 1, $0) }
    }

    private enum CodeBlockLevel {
        case fence
        case body
    }
}

@MainActor
enum MarkdownTheme {
    static let ink = NSColor(red: 0.14, green: 0.12, blue: 0.10, alpha: 1)
    static let muted = NSColor(red: 0.46, green: 0.41, blue: 0.35, alpha: 1)
    static let quote = NSColor(red: 0.37, green: 0.33, blue: 0.28, alpha: 1)
    static let listMarker = NSColor(red: 0.44, green: 0.40, blue: 0.35, alpha: 0.72)
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

    static func listMarkerFont(size: CGFloat) -> NSFont {
        textFont(size: max(11, size - 0.8), weight: .medium)
    }

    static func numberedListMarkerFont(size: CGFloat) -> NSFont {
        NSFont.monospacedDigitSystemFont(ofSize: max(11, size - 0.6), weight: .medium)
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
