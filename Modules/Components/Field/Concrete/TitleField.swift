import SwiftUI

public struct TitleField: View {
    public var body: some View {
        // Two layouts rather than one with a hidden button: the no-action shape has to stay
        // byte-identical to what ShareFormView and bulk edit already render, and Field's padding
        // differs between them.
        if let suggestButtonTapped {
            Field(.title, padding: .x0) {
                HStack {
                    TextField(String(localized: .title), text: $text)
                        .padding(.leading, .x2 + .x3)
                        .textFieldStyle(.plain)
                    Spacer()
                    Button {
                        suggestButtonTapped()
                    } label: {
                        Image(systemName: "sparkles")
                            .accessibilityLabel(.suggestTitle)
                    }
                    .buttonStyle(.ghost())
                }
            }
        } else {
            Field(.title) {
                TextField(String(localized: .title), text: $text)
                    .textFieldStyle(.plain)
            }
        }
    }

    public init(text: Binding<String>, suggestButtonTapped: (() -> Void)? = nil) {
        _text = text
        self.suggestButtonTapped = suggestButtonTapped
    }

    private let suggestButtonTapped: (() -> Void)?

    @Binding
    private var text: String
}
