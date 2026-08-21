@testable import PdfPasswordsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct PdfPasswordListReducerTests {

    @Test
    func onAppear_loadsStoredPasswords() async throws {
        let store = TestStore(initialState: PdfPasswordListReducer.State()) {
            PdfPasswordListReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [.testValue(filename: "a.pdf", id: "1", password: "a")]
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getPdfPasswordsResult) {
            $0.isLoaded = true
            $0.pdfPasswords = [
                PdfPasswordRowReducer.State(
                    pdfPassword: .testValue(filename: "a.pdf", id: "1", password: "a")
                )
            ]
        }
    }

    @Test
    func deletingARow_removesItFromTheListAndTheKeychain() async throws {
        let deleted = LockIsolated<[String]>([])
        var state = PdfPasswordListReducer.State()
        state.pdfPasswords = [
            PdfPasswordRowReducer.State(pdfPassword: .testValue(filename: "a.pdf", id: "1", password: "a")),
            PdfPasswordRowReducer.State(pdfPassword: .testValue(filename: "b.pdf", id: "2", password: "b"))
        ]

        let store = TestStore(initialState: state) {
            PdfPasswordListReducer()
        } withDependencies: {
            $0.deletePdfPassword.execute = { id in
                deleted.withValue { $0.append(id) }
            }
        }

        await store.send(.pdfPasswords(.element(id: "1", action: .delegate(.deletePdfPassword))))
        await store.receive(\.pdfPasswordDeleted) {
            $0.pdfPasswords.remove(id: "1")
        }

        #expect(deleted.value == ["1"])
    }
}
