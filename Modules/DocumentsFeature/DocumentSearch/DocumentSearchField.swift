import Components
import DesignTokens
import SwiftUI

// The list's search field, kept apart from `DocumentSearchBarView` so the styling — the `Field`,
// the icon, the placeholder and every metric — lives in one place and the bar is only about what
// surrounds it.
struct DocumentSearchField: View {

    var body: some View {
        Field(padding: .x0) {
            HStack(spacing: .x0) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.m3Primary)
                    .padding(.leading, .x2 + .x3)
                // A search field, not prose: the observed default capitalised the first letter of
                // the query, which is not what anyone means when they type a tag's name.
                TextField(String(localized: .search), text: text)
                    .autocorrectionDisabled()
                    .focused(isFocused)
                    .padding(.leading, .x2)
                    .submitLabel(.search)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .onSubmit(submitted)
                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.m3Outline)
                    }
                    .accessibilityLabel(.clearSearch)
                    .buttonStyle(.plain)
                    .padding(.leading, .x2)
                    .padding(.trailing, .x2 + .x3)
                }
            }
        }
    }

    init(
        isFocused: FocusState<Bool>.Binding,
        submitted: @escaping () -> Void,
        text: Binding<String>
    ) {
        self.isFocused = isFocused
        self.submitted = submitted
        self.text = text
    }

    private let isFocused: FocusState<Bool>.Binding

    private let submitted: () -> Void

    private let text: Binding<String>
}
