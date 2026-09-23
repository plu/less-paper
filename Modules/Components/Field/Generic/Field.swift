import DesignTokens
import SwiftUI

public struct Field<Input: View>: View {

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title {
                Text(title)
                    .frame(alignment: .topLeading)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .padding(.horizontal, scaledMetric * 4)
                    .padding(.top, scaledMetric)
                    .foregroundColor(titleColor)
                    .background(Capsule().foregroundColor(fillColor))
                    .zIndex(1)
                    .offset(x: scaledMetric * 12, y: 0)
                    .padding(.trailing, scaledMetric * 20)
                    .readSize(into: $titleSize)
            }

            input
                .frame(minHeight: scaledMetric * minHeight)
                .padding(.horizontal, scaledMetric * padding)
                .padding(scaledMetric * 2)
                .background(fillColor)
                .overlay(Capsule().stroke(borderColor, lineWidth: scaledMetric * borderWidth).padding(scaledMetric * 2))
                .clipShape(Capsule())
                .animation(.snappy, value: isFocused)
                .font(.body)
                .offset(x: 0, y: -titleSize.height / 1.7)
                .padding(.bottom, -titleSize.height / 2)

            if let error {
                Text(error)
                    .frame(alignment: .topLeading)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .padding(.leading, scaledMetric * 4)
                    .padding(.trailing, scaledMetric * 10 * 3)
                    .foregroundColor(.m3Error)
                    .offset(x: scaledMetric * 12, y: 0)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    public init(
        _ title: LocalizedStringResource? = nil,
        padding: Double = .x2 + .x3,
        @ViewBuilder input: () -> Input
    ) {
        self.title = title
        self.padding = padding
        self.input = input()
        self._error = .constant(nil)
        self._isFocused = .constant(false)
    }

    private var borderColor: Color {
        if error != nil {
            return .m3Error
        }
        return isFocused ? .m3Primary : .m3Outline
    }

    // Hairline at rest, doubled when focused or in error, so the three states differ by weight and
    // not only by hue — the one distinction a red-green colour-blind user cannot make unaided.
    private var borderWidth: Double {
        error != nil || isFocused ? 2 : 1
    }

    // Off the Material surface ladder deliberately — see the note on `Color.fieldFill`. The three
    // states get brighter as the field becomes more usable, in both themes, and no `m3` rung can
    // say that: light spends the top of its range on the caret while dark spends the bottom of its
    // range on a locked field, so one token would have to mean two different things.
    //
    // The title capsule shares this colour so the label always sits on the fill it belongs to. It
    // does not blend into the card *behind* the field: a notch masking a border can match only one
    // of the two surfaces it straddles, and the field is the one that stays right when the card
    // underneath changes.
    private var fillColor: Color {
        if isReadOnly {
            return .fieldFillReadOnly
        }
        return isFocused ? .fieldFillFocused : .fieldFill
    }

    private var titleColor: Color {
        if error != nil {
            return .m3Error
        }
        return isFocused ? .m3Primary : .m3OnSurface
    }

    private var isReadOnly = false

    @ScaledMetric
    private var scaledMetric: Double = 1.0

    @Binding
    private var error: String?

    // Mirrors the `@FocusState` that `FieldStateModifier` owns. The modifier applies it to the
    // whole field, so this is the only route by which the border can know where the caret is — a
    // field built without `state(_:)` never lights up.
    @Binding
    private var isFocused: Bool

    @State
    private var titleSize: CGSize = .zero

    private var minHeight: CGFloat {
        44
    }

    private let input: Input

    private let padding: Double

    private let title: LocalizedStringResource?
}

public extension Field {

    // For validation that runs on every keystroke. `state(_:)` cannot serve that case: its modifier
    // clears the error whenever the value changes, which is right for submit-time validation and
    // wrong when the error is a function of what is currently typed.
    func error(_ error: String?) -> Self {
        var copy = self
        copy._error = .constant(error)
        return copy
    }

    func readOnly(_ isReadOnly: Bool = true) -> Self {
        var copy = self
        copy.isReadOnly = isReadOnly
        return copy
    }

    func state<Value: Equatable>(
        _ state: Binding<FieldState<Value>>
    ) -> some View {
        var copy = self
        copy._error = state.error
        copy._isFocused = state.focused
        return copy.modifier(FieldStateModifier(state: state))
    }
}

#Preview {
    @Previewable
    @State
    var state = FieldState(
        error: "Firstname lorem ipsum, lorem ipsum, lorem ipsum, lorem ipsum",
        value: "John"
    )

    ScrollView {
        VStack(spacing: 8) {
            Field {
                TextField("Firstname", text: $state.value)
            }
            .state($state)

            ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                Field("Firstname") {
                    TextField("Firstname", text: .constant("John"))
                        .textFieldStyle(.plain)
                }
                .environment(\.sizeCategory, size)
            }
        }
        .padding()
    }
    .background(Color.m3Surface)
}
