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
