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
        textView.isContinuousSpellCheckingEnabled = false
        textView.isGrammarCheckingEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
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
        private static let indentationUnit = "  "

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
            switch commandSelector {
            case #selector(NSResponder.insertNewline(_:)):
                return continueMarkdownList(in: textView)
            case #selector(NSResponder.insertTab(_:)):
                return changeIndentation(in: textView, direction: .indent)
            case #selector(NSResponder.insertBacktab(_:)):
                return changeIndentation(in: textView, direction: .outdent)
            default:
                return false
            }
        }

        private func continueMarkdownList(in textView: NSTextView) -> Bool {
            let selection = textView.selectedRange()
            guard selection.length == 0 else { return false }

            let nsString = textView.string as NSString
            let location = min(selection.location, nsString.length)
            let lineRange = nsString.lineRange(for: NSRange(location: location, length: 0))
            let lineContentRange = rangeWithoutTrailingNewlines(in: nsString, lineRange: lineRange)
            let line = nsString.substring(with: lineContentRange)

            guard location == NSMaxRange(lineContentRange) else {
                return false
            }

            guard let action = MarkdownContinuation.action(for: line) else {
                return false
            }

            switch action {
            case let .insert(insertion):
                textView.insertText(insertion, replacementRange: selection)
            case .terminateList:
                textView.insertText("", replacementRange: lineContentRange)
            }

            return true
        }

        private func rangeWithoutTrailingNewlines(in nsString: NSString, lineRange: NSRange) -> NSRange {
            var length = lineRange.length

            while length > 0 {
                let scalar = nsString.character(at: lineRange.location + length - 1)
                guard scalar == 10 || scalar == 13 else { break }
                length -= 1
            }

            return NSRange(location: lineRange.location, length: length)
        }

        private func changeIndentation(in textView: NSTextView, direction: IndentationDirection) -> Bool {
            let selection = textView.selectedRange()
            let nsString = textView.string as NSString

            if nsString.length == 0 {
                guard direction == .indent else { return true }
                textView.insertText(Self.indentationUnit, replacementRange: selection)
                return true
            }

            let affectedRange = nsString.lineRange(for: selection)
            let lineSegments = lineSegments(in: nsString, within: affectedRange)
            guard !lineSegments.isEmpty else { return false }

            let relativeSelectionStart = selection.location - affectedRange.location
            let relativeSelectionEnd = NSMaxRange(selection) - affectedRange.location
            let isCaretSelection = selection.length == 0

            var startDelta = 0
            var endDelta = 0
            var transformedBlock = ""

            for lineSegment in lineSegments {
                let lineOffset = lineSegment.contentRange.location - affectedRange.location
                let transform = indentationTransform(for: lineSegment.content, direction: direction)

                transformedBlock += transform.content
                transformedBlock += lineSegment.lineEnding

                if lineOffset < relativeSelectionStart || (isCaretSelection && lineOffset == relativeSelectionStart) {
                    startDelta += transform.delta
                }

                if lineOffset < relativeSelectionEnd || (isCaretSelection && lineOffset == relativeSelectionEnd) {
                    endDelta += transform.delta
                }
            }

            textView.insertText(transformedBlock, replacementRange: affectedRange)

            let newLocation = max(0, selection.location + startDelta)
            let newLength = max(0, selection.length + endDelta - startDelta)
            textView.setSelectedRange(NSRange(location: newLocation, length: newLength))
            return true
        }

        private func lineSegments(in nsString: NSString, within range: NSRange) -> [LineSegment] {
            var segments: [LineSegment] = []

            nsString.enumerateSubstrings(in: range, options: [.byLines, .substringNotRequired]) { _, contentRange, enclosingRange, _ in
                let lineEndingRange = NSRange(
                    location: NSMaxRange(contentRange),
                    length: NSMaxRange(enclosingRange) - NSMaxRange(contentRange)
                )

                segments.append(
                    LineSegment(
                        contentRange: contentRange,
                        content: nsString.substring(with: contentRange),
                        lineEnding: lineEndingRange.length > 0 ? nsString.substring(with: lineEndingRange) : ""
                    )
                )
            }

            if segments.isEmpty, range.location == 0, range.length == 0 {
                segments.append(LineSegment(contentRange: range, content: "", lineEnding: ""))
            }

            return segments
        }

        private func indentationTransform(
            for line: String,
            direction: IndentationDirection
        ) -> (content: String, delta: Int) {
            switch direction {
            case .indent:
                return (Self.indentationUnit + line, Self.indentationUnit.count)
            case .outdent:
                if line.hasPrefix(Self.indentationUnit) {
                    return (String(line.dropFirst(Self.indentationUnit.count)), -Self.indentationUnit.count)
                }

                if line.hasPrefix("\t") {
                    return (String(line.dropFirst()), -1)
                }

                if line.hasPrefix(" ") {
                    return (String(line.dropFirst()), -1)
                }

                return (line, 0)
            }
        }

        private struct LineSegment {
            let contentRange: NSRange
            let content: String
            let lineEnding: String
        }

        private enum IndentationDirection {
            case indent
            case outdent
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
