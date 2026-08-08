import ComposableArchitecture

extension ConfirmationDialogState where Action == TagRowReducer.Destination.Confirmation {

    static func confirmDelete(name: String) -> Self {
        Self(titleVisibility: .visible) {
            TextState(String(localized: .deleteConfirmation(name)))
        } actions: {
            ButtonState(role: .destructive, action: .deleteButtonTapped) {
                TextState(String(localized: .deleteTag))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: .cancel))
            }
        }
    }
}
