import DesignTokens
@preconcurrency import Runestone
import SwiftUI

// Runestone rather than SwiftUI's TextEditor: OCR text runs to hundreds of kilobytes, and at that
// size TextEditor lagged while typing, jumped its scroll position and drew text outside its own
// clip. Runestone lays out only the lines on screen.
struct DocumentContentEditor: UIViewRepresentable {

    @Binding
    var text: String

    let accessibilityLabel: String

    static let accessibilityIdentifier = "DocumentContentEditor"

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> TextView {
        let textView = TextView()
        textView.editorDelegate = context.coordinator
        textView.theme = DocumentContentTheme()
        textView.backgroundColor = .clear
        textView.isLineWrappingEnabled = true
        // Wider at the sides than at the top: UITextView pads each line by 5pt on its own, which
        // Runestone does not, and x4 keeps the text where the system editor put it.
        textView.textContainerInset = UIEdgeInsets(top: .x3, left: .x4, bottom: .x3, right: .x4)
        // Inset top and bottom only, so the indicator runs along the box's edge but stays clear of
        // its rounded corners.
        textView.verticalScrollIndicatorInsets = UIEdgeInsets(top: .x4, left: 0, bottom: .x4, right: 0)
        // A long document is scrolled far more than it is typed into; dragging the text is how the
        // keyboard gets out of the way of what it covers.
        textView.keyboardDismissMode = .interactive
        textView.insertionPointColor = .m3Primary
        textView.selectionBarColor = .m3Primary
        textView.selectionHighlightColor = .m3Primary.withAlphaComponent(0.2)
        textView.accessibilityLabel = accessibilityLabel
        textView.accessibilityIdentifier = Self.accessibilityIdentifier
        textView.text = text
        context.coordinator.lastText = text
        return textView
    }

    func updateUIView(_ textView: TextView, context: Context) {
        context.coordinator.text = $text
        // Only a change that did not come from the view itself is written back: Reset, or the full
        // document arriving. Setting `text` replaces the whole document and moves the caret and the
        // scroll position to the top, so echoing each keystroke back would do both on every key.
        // The comparison is cheap in the common case: after a keystroke both sides hold the same
        // string storage.
        guard text != context.coordinator.lastText else {
            return
        }
        textView.text = text
        context.coordinator.lastText = text
    }

    @MainActor
    final class Coordinator: NSObject, @preconcurrency TextViewDelegate {

        var lastText: String

        var text: Binding<String>

        init(text: Binding<String>) {
            self.lastText = text.wrappedValue
            self.text = text
        }

        func textViewDidChange(_ textView: TextView) {
            let newText = textView.text
            lastText = newText
            text.wrappedValue = newText
        }
    }
}

// Colours from the design tokens, which resolve per trait, so the editor follows the theme without
// being told. Gutter and line-number colours are required by the protocol but never drawn: line
// numbers stay off, since OCR text has no lines worth numbering.
private final class DocumentContentTheme: Theme {

    let font = UIFont.preferredFont(forTextStyle: .body)

    let textColor = UIColor.m3OnSurface

    let gutterBackgroundColor = UIColor.clear

    let gutterHairlineColor = UIColor.clear

    let lineNumberColor = UIColor.m3OnSurfaceVariant

    let lineNumberFont = UIFont.preferredFont(forTextStyle: .caption1)

    let selectedLineBackgroundColor = UIColor.clear

    let selectedLinesLineNumberColor = UIColor.m3OnSurfaceVariant

    let selectedLinesGutterBackgroundColor = UIColor.clear

    let invisibleCharactersColor = UIColor.m3OutlineVariant

    let pageGuideHairlineColor = UIColor.clear

    let pageGuideBackgroundColor = UIColor.clear

    let markedTextBackgroundColor = UIColor.m3Primary.withAlphaComponent(0.2)

    func textColor(for highlightName: String) -> UIColor? {
        nil
    }
}
