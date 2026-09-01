import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: PermissionsFormReducer.self)
public struct PermissionsFormView: View {

    public var body: some View {
        VStack(alignment: .leading, spacing: .x4) {
            owner()
            changePermissions()
            viewPermissions()
        }
        .background(Color.m3Surface)
        .onAppear { send(.onAppear) }
    }

    public init(store: StoreOf<PermissionsFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<PermissionsFormReducer>

    @ViewBuilder
    private func changePermissions() -> some View {
        VStack(alignment: .leading, spacing: .x0) {
            Text(.change)
                .fontWeight(.semibold)
                .padding(.horizontal)
            VStack(alignment: .leading) {
                MultiSelectField(
                    options: store.options.users.elements,
                    selection: $store.selection.change.users,
                    title: .users
                )
                MultiSelectField(
                    options: store.options.groups.elements,
                    selection: $store.selection.change.groups,
                    title: .groups
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
        }
    }

    @ViewBuilder
    private func owner() -> some View {
        VStack(alignment: .leading, spacing: .x0) {
            SingleSelectField(
                options: store.options.users.elements,
                selection: $store.selection.owner,
                title: .owner
            )
            .padding()
            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
        }
    }

    @ViewBuilder
    private func viewPermissions() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(.view)
                .fontWeight(.semibold)
                .padding(.horizontal)
            VStack(alignment: .leading) {
                MultiSelectField(
                    options: store.options.users.elements,
                    selection: $store.selection.view.users,
                    title: .users
                )
                MultiSelectField(
                    options: store.options.groups.elements,
                    selection: $store.selection.view.groups,
                    title: .groups
                )
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
        }
    }
}

#Preview {
    ScrollView {
        PermissionsFormView(
            store: Store(
                initialState: .testValue(),
                reducer: {
                    PermissionsFormReducer()
                }
            )
        )
        .padding()
    }
    .background(Color.m3Surface)
}
