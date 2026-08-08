import ComposableArchitecture

extension ConfirmationDialogState where Action == DocumentTypeRowReducer.Destination.Confirmation {

    static func confirmDelete(name: String) -> Self {
        Self(titleVisibility: .visible) {
            TextState(String(localized: .deleteConfirmation(name)))
        } actions: {
            ButtonState(role: .destructive, action: .deleteButtonTapped) {
                TextState(String(localized: .deleteDocumentType))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: .cancel))
            }
        }
    }
}
