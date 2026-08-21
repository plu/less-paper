@testable import ShareFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import PDFKit
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct ShareFormRememberPasswordTests {

    @Test
    func unlockButtonTapped_withRememberOn_savesThePassword() async throws {
        let saved = LockIsolated<[String]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "s3cr3t")

        var state = ShareFormReducer.State(files: [url], server: .testValue())
        state.input.password = "s3cr3t"
        state.input.shouldRememberPassword = true

        let store = TestStore(initialState: state) {
            ShareFormReducer()
        } withDependencies: {
            $0.savePdfPassword.execute = { filename, password in
                saved.withValue { $0.append("\(filename):\(password)") }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.unlockButtonTapped))
        await store.finish()

        #expect(saved.value == ["statement.pdf:s3cr3t"])
    }

    @Test
    func unlockButtonTapped_withRememberOff_savesNothing() async throws {
        let saved = LockIsolated<[String]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "s3cr3t")

        var state = ShareFormReducer.State(files: [url], server: .testValue())
        state.input.password = "s3cr3t"
        state.input.shouldRememberPassword = false

        let store = TestStore(initialState: state) {
            ShareFormReducer()
        } withDependencies: {
            $0.savePdfPassword.execute = { filename, password in
                saved.withValue { $0.append("\(filename):\(password)") }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.unlockButtonTapped))
        await store.finish()

        #expect(saved.value.isEmpty)
    }

    // A password that does not open the document must never reach the keychain, which is why the
    // save hangs off the success branch of unlock(withPassword:) rather than off the button tap.
    @Test
    func unlockButtonTapped_withWrongPassword_savesNothingAndToasts() async throws {
        let saved = LockIsolated<[String]>([])
        let toasts = LockIsolated<[Toast]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "s3cr3t")

        var state = ShareFormReducer.State(files: [url], server: .testValue())
        state.input.password = "wrong"
        state.input.shouldRememberPassword = true

        let store = TestStore(initialState: state) {
            ShareFormReducer()
        } withDependencies: {
            $0.savePdfPassword.execute = { filename, password in
                saved.withValue { $0.append("\(filename):\(password)") }
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.unlockButtonTapped))
        await store.finish()

        #expect(saved.value.isEmpty)
        #expect(toasts.value.count == 1)
    }
}
