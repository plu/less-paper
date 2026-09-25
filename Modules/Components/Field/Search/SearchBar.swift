import DesignTokens
import SwiftUI

// A search field and the way out of it. The bar owns the focus, so a caller supplies only the text
// and what finishing means. `dismissalCount` is for callers that can finish a search from somewhere
// other than this button — a committed query, a filter applied from a result — and have no other
// way to tell the field to let go of the keyboard.
public struct SearchBar: View {

    public var body: some View {
        HStack(spacing: .x0) {
            SearchField(
                isFocused: $isFocused,
                submitted: submitted,
                text: text
            )
            // The field's own `X` wipes the text and leaves the user in the field with the keyboard
            // up, which is not a way out. Shown on content as well as on focus because a query that
            // survived a push still needs one.
            //
            // An icon rather than the word, with the tap target spelled out: the glyph is about
            // 15pt on its own, and this one sits a thumb's width from a field people are typing
            // into. The label is what VoiceOver announces and what the journey looks for.
            //
            // Always in the hierarchy, collapsed and faded out when there is nothing to cancel,
            // rather than inside an `if`. A list row does not run a transition on a structural
            // change: with the `if`, the button was inserted at full opacity on the same frame the
            // field started narrowing — it arrived before the space it arrives in existed, which
            // was measured frame by frame, not assumed. Width and opacity are ordinary animatable
            // values, so the two now move together.
            Button {
                isFocused = false
                cancelled()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.m3Primary)
                    .frame(width: .x5 + .x3, height: .x5 + .x3)
                    .contentShape(.rect)
            }
            .accessibilityHidden(!isCancelVisible)
            .accessibilityLabel(.cancel)
            .buttonStyle(.plain)
            .disabled(!isCancelVisible)
            .frame(width: isCancelVisible ? .x5 + .x3 : .x0)
            .opacity(isCancelVisible ? 1 : 0)
            .clipped()
        }
        // Keyed on the button rather than on focus: it is the button's presence that changes the
        // field's width, and text arriving without a focus change — a query that survived a push —
        // moves the same layout.
        .animation(.default, value: isCancelVisible)
        .onChange(of: dismissalCount) { isFocused = false }
    }

    public init(
        text: Binding<String>,
        cancelled: @escaping () -> Void,
        dismissalCount: Int = 0,
        submitted: @escaping () -> Void = {}
    ) {
        self.text = text
        self.cancelled = cancelled
        self.dismissalCount = dismissalCount
        self.submitted = submitted
    }

    private var isCancelVisible: Bool {
        isFocused || !text.wrappedValue.isEmpty
    }

    // Deliberately not raised on appear: the field is a row of a list rather than the only thing in
    // a sheet, and a list that takes the keyboard the moment it is shown hides what it exists to
    // show.
    @FocusState
    private var isFocused: Bool

    private let cancelled: () -> Void

    private let dismissalCount: Int

    private let submitted: () -> Void

    private let text: Binding<String>
}
