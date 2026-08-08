@testable import PermissionsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct PermissionsFormReducerTests {

    @Test
    func test_binding_selection() async throws {
        let store = TestStore(initialState: PermissionsFormReducer.State(
            server: .testValue(),
            type: .tag(id: 1)
        )) {
            PermissionsFormReducer()
        } withDependencies: {
            $0.getPermissions.execute = { _, _ in
                .testValue(
                    owner: nil,
                    permissions: .testValue(
                        change: .testValue(
                            groups: [],
                            users: []
                        ),
                        view: .testValue(
                            groups: [],
                            users: []
                        )
                    )
                )
            }
        }

        await store.send(.binding(.set(\.selection, .testValue(
            change: .testValue(
                groups: [],
                users: []
            ),
            owner: .testValue(id: 77),
            view: .testValue(
                groups: [],
                users: []
            )
        )))) {
            $0.selection.owner = .testValue(id: 77)
        }
        await store.receive(\.delegate.permissionsUpdated, .testValue(
            owner: .value(.testValue(id: 77)),
            permissions: .init()
        ))
    }

    @Test
    func test_view_onAppear_success() async throws {
        let store = TestStore(initialState: PermissionsFormReducer.State(
            server: .testValue(),
            type: .tag(id: 1)
        )) {
            PermissionsFormReducer()
        } withDependencies: {
            $0.getPermissions.execute = { _, _ in
                .testValue(
                    owner: 1,
                    permissions: .testValue(
                        change: .testValue(
                            groups: [1],
                            users: [1]
                        ),
                        view: .testValue(
                            groups: [1],
                            users: [1]
                        )
                    )
                )
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.binding, .set(\.isLoading, true)) {
            $0.isLoading = true
        }
        await store.receive(\.getPermissionsResult) {
            $0.options = .init(
                groups: [.testValue()],
                users: [.testValue()]
            )
            $0.selection = .testValue()
        }
        await store.receive(\.binding, .set(\.isLoading, false)) {
            $0.isLoading = false
        }
    }

    @Shared(.currentUser(.testValue()))
    private var currentUser: User? = .testValue()

    @Shared(.groups(.testValue()))
    private var groups: IdentifiedArrayOf<Group> = [.testValue()]

    @Shared(.users(.testValue()))
    private var users: IdentifiedArrayOf<User> = [.testValue()]
}
