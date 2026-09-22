import Components
import DesignTokens
import SwiftUI

// One view for both copies of the search field — the one on the documents list that opens the
// sheet, and the real one inside it. Built twice they would drift the first time someone restyled
// one, and the point of the pair is that the affordance and the field read as the same control.
struct DocumentSearchField: View {

    var body: some View {
        Field(padding: .x0) {
            HStack(spacing: .x0) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.m3Primary)
                    .padding(.leading, .x2 + .x3)
                input
                    .padding(.leading, .x2)
            }
        }
    }

    init(query: String) {
        self.query = query
        isFocused = nil
        submitted = nil
        text = nil
    }

    init(
        isFocused: FocusState<Bool>.Binding,
        submitted: @escaping () -> Void,
        text: Binding<String>
    ) {
        self.isFocused = isFocused
        self.submitted = submitted
        self.text = text
        query = ""
    }

    @ViewBuilder
    private var input: some View {
        if let text, let isFocused, let submitted {
            // A search field, not prose: the observed default capitalised the first letter of the
            // query, which is not what anyone means when they type a tag's name.
            TextField(String(localized: .search), text: text)
                .autocorrectionDisabled()
                .focused(isFocused)
                .submitLabel(.search)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .onSubmit(submitted)
        } else {
            // `Text`, never a disabled `TextField`: a tap on the list copy has to reach the button
            // underneath and present the sheet, and a text field in the way would take focus and
            // raise a keyboard on a screen that has nothing to type into.
            HStack(spacing: .x0) {
                Text(query.isEmpty ? String(localized: .search) : query)
                    .foregroundStyle(query.isEmpty ? Color.m3Outline : Color.m3OnSurface)
                    .lineLimit(1)
                Spacer(minLength: .x0)
            }
        }
    }

    private let isFocused: FocusState<Bool>.Binding?

    private let query: String

    private let submitted: (() -> Void)?

    private let text: Binding<String>?
}
