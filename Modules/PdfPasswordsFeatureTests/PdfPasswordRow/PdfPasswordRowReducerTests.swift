@testable import PdfPasswordsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct PdfPasswordRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: PdfPasswordRowReducer.State(
            pdfPassword: .testValue()
        )) {
            PdfPasswordRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let pdfPassword = PdfPassword.testValue(filename: "statement.pdf")
        let presented = LockIsolated<(title: LocalizedStringResource, name: String)?>(nil)
        let store = TestStore(initialState: PdfPasswordRowReducer.State(
            pdfPassword: pdfPassword
        )) {
            PdfPasswordRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { title, name in
                presented.setValue((title, name))
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate, .deletePdfPassword)

        #expect(presented.value?.title == .deletePdfPassword)
        #expect(presented.value?.name == pdfPassword.filename)
    }

    @Test
    func test_view_revealButtonTapped() async throws {
        let store = TestStore(initialState: PdfPasswordRowReducer.State(
            pdfPassword: .testValue()
        )) {
            PdfPasswordRowReducer()
        }

        await store.send(.view(.revealButtonTapped)) {
            $0.isRevealed = true
        }
    }
}
