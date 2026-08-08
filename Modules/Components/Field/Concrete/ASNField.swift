import SwiftUI

public struct ASNField: View {
    public var body: some View {
        Field(.asn, padding: .x0) {
            HStack {
                TextField(String(localized: .asn), text: $text)
                    .padding(.leading, .x2 + .x3)
                    .textFieldStyle(.plain)
                if text.isEmpty {
                    Spacer()
                    Button {
                        getNextButtonTapped()
                    } label: {
                        Image(systemName: "plus.circle")
                            .accessibilityLabel(.getNextArchiveSerialNumber)
                    }
                    .buttonStyle(.ghost(isLoading: $isLoading))
                }
            }
        }
    }

    public init(
        isLoading: Binding<Bool>,
        text: Binding<String>,
        getNextButtonTapped: @escaping () -> Void
    ) {
        _isLoading = isLoading
        _text = text
        self.getNextButtonTapped = getNextButtonTapped
    }

    private let getNextButtonTapped: () -> Void

    @Binding
    private var isLoading: Bool

    @Binding
    private var text: String
}
