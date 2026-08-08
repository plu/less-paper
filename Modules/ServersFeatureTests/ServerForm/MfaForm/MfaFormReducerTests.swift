@testable import ServersFeature

import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct MfaFormReducerTests {

    @Test
    func test_view_cancelButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            MfaFormReducer()
        }

        await store.send(.view(.cancelButtonTapped))
        await store.receive(\.delegate.cancel)
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        let store = TestStore(initialState: .testValue()) {
            MfaFormReducer()
        }

        await store.send(.view(.closeButtonTapped))
        await store.receive(\.delegate.cancel)
    }

    @Test
    func test_view_submitButtonTapped() async throws {
        let mfaCode = "123456"
        let store = TestStore(initialState: .testValue(mfaCode: mfaCode)) {
            MfaFormReducer()
        }

        await store.send(.view(.submitButtonTapped))
        await store.receive(\.delegate.mfaCode, mfaCode)
    }

    @Test
    func test_binding_mfaCode() async throws {
        let store = TestStore(initialState: .testValue()) {
            MfaFormReducer()
        }

        await store.send(.binding(.set(\.mfaCode, "123456"))) {
            $0.mfaCode = "123456"
        }
    }

    @Test
    func test_binding_ignored() async throws {
        let store = TestStore(initialState: .testValue()) {
            MfaFormReducer()
        }

        await store.send(.binding(.set(\.mfaCode, "test"))) {
            $0.mfaCode = "test"
        }
    }

    @Test
    func test_delegate_ignored() async throws {
        let store = TestStore(initialState: .testValue()) {
            MfaFormReducer()
        }

        await store.send(.delegate(.cancel))
    }
}
