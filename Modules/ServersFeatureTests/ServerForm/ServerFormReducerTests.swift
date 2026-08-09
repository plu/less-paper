@testable import ServersFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct ServerFormReducerTests {

    @Test
    func test_view_cancelButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.cancelButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_saveButtonTapped_success() async throws {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                events.withValue { $0.append("storeToken") }
            }
            $0.updateCache.execute = { _ in
                events.withValue { $0.append("updateCache") }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, .testValue())
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        // Saving the first server selects it straight away, so its caches have
        // to be filled before it is announced as saved — otherwise the inbox
        // filter is built with no tags and shows every document.
        #expect(events.value == ["storeToken", "updateCache"])
    }

    @Test
    func test_view_saveButtonTapped_cacheError() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in }
            $0.updateCache.execute = { _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_saveButtonTapped_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_view_saveButtonTapped_mfaCodeRequired() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                throw ApiError.testValue(errors: ["MFA code is required"])
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.mfaCodeRequired) {
            $0.destination = .mfaForm(MfaFormReducer.State())
        }
    }

    @Test
    func test_mfaForm_cancelButtonTapped() async throws {
        var state = ServerFormReducer.State(input: .testValue())
        state.destination = .mfaForm(MfaFormReducer.State())
        state.input.code = "123456"
        state.isSaving = true

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        }

        await store.send(.destination(.presented(.mfaForm(.delegate(.cancel))))) {
            $0.destination = nil
            $0.input.code = nil
            $0.isSaving = false
        }
    }

    @Test
    func test_mfaForm_mfaCodeSubmitted() async throws {
        var state = ServerFormReducer.State(input: .testValue())
        state.destination = .mfaForm(MfaFormReducer.State())

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in }
        }

        let mfaCode = "123456"
        await store.send(.destination(.presented(.mfaForm(.delegate(.mfaCode(mfaCode)))))) {
            $0.destination = nil
            $0.input.code = mfaCode
        }
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, .testValue())
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }
    }

    @Test
    func test_view_addHeaderButtonTapped() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        await store.send(.view(.addHeaderButtonTapped)) {
            $0.input.headers = [
                HTTPHeader(id: UUID(0).uuidString, name: "", value: "")
            ]
        }
    }

    @Test
    func test_view_deleteHeaderButtonTapped() async throws {
        let header = HTTPHeader.testValue()
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(headers: [header])
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.deleteHeaderButtonTapped(header.id))) {
            $0.input.headers = []
        }
    }

    @Test
    func test_view_headerNameChanged() async throws {
        let header = HTTPHeader.testValue()
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(headers: [header])
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.headerNameChanged(header.id, "X-Custom"))) {
            $0.input.headers[id: header.id]?.name = "X-Custom"
        }
    }

    @Test
    func test_view_headerValueChanged() async throws {
        let header = HTTPHeader.testValue()
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue(headers: [header])
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.headerValueChanged(header.id, "some-value"))) {
            $0.input.headers[id: header.id]?.value = "some-value"
        }
    }

    @Test
    func test_view_headerNameChanged_missingHeader_isNoOp() async throws {
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        }

        await store.send(.view(.headerNameChanged("missing", "X-Custom")))
    }

    @Test
    func test_error_clearsCodeAndShowsToast() async throws {
        let toasts = LockIsolated<[Toast]>([])
        var state = ServerFormReducer.State(input: .testValue())
        state.input.code = "123456"

        let store = TestStore(initialState: state) {
            ServerFormReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        let error = ApiError.testValue(errors: ["Authentication failed"])
        await store.send(.error(error)) {
            $0.input.code = nil
        }
        #expect(toasts.value == [.error("Authentication failed")])
    }
}
