import ComposableArchitecture
import Dependencies

extension Effect where Action == CustomFieldQueryCardsReducer.Action {
    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }
}
