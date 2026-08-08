import SwiftUI

public struct TitleField: View {
    public var body: some View {
        Field(.title) {
            TextField(String(localized: .title), text: $text)
                .textFieldStyle(.plain)
        }
    }

    public init(text: Binding<String>) {
        _text = text
    }

    @Binding
    private var text: String
}
