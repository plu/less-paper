import ComposableArchitecture

extension ConfirmationDialogState where Action == StoragePathRowReducer.Destination.Confirmation {

    static func confirmDelete(name: String) -> Self {
        Self(titleVisibility: .visible) {
            TextState(String(localized: .deleteConfirmation(name)))
        } actions: {
            ButtonState(role: .destructive, action: .deleteButtonTapped) {
                TextState(String(localized: .deleteStoragePath))
            }
            ButtonState(role: .cancel) {
                TextState(String(localized: .cancel))
            }
        }
    }
}
