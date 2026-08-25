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
                    .foregroundColor(.m3OnSurface)
                    .background(Capsule().foregroundColor(.m3SurfaceBright))
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
                .overlay(Capsule().stroke(borderColor, lineWidth: scaledMetric * 2).padding(scaledMetric * 2))
                .clipShape(Capsule())
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
    }

    private var borderColor: Color {
        error != nil ? .m3Error : .m3Outline
    }

    // The title capsule deliberately keeps `m3SurfaceBright`: it sits over the sheet, masking the
    // border line behind the label, so tinting it would draw a grey pill against the background
    // instead of blending into it.
    private var fillColor: Color {
        isReadOnly ? .m3SurfaceContainerHigh : .m3SurfaceBright
    }

    private var isReadOnly = false

    @ScaledMetric
    private var scaledMetric: Double = 1.0

    @Binding
    private var error: String?

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
