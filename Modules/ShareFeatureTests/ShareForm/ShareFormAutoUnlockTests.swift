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
struct ShareFormAutoUnlockTests {

    @Test
    func onAppear_unlocksWithTheFirstMatchingStoredPassword() async throws {
        let url = try PdfFixture.locked(name: "statement.pdf", password: "second")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [url],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [
                    .testValue(filename: "a.pdf", id: "1", password: "first"),
                    .testValue(filename: "b.pdf", id: "2", password: "second"),
                    .testValue(filename: "c.pdf", id: "3", password: "third")
                ]
            }
        }
        store.exhaustivity = .off

        #expect(store.state.isLocked)

        await store.send(.view(.onAppear))
        await store.receive(\.fileUnlocked)
        await store.finish()

        #expect(store.state.isLocked == false)
    }

    // Every stored password failing is the normal case for a document the user has never unlocked.
    // It must fall through to the unlock form in silence rather than toasting once per password.
    @Test
    func onAppear_whenNoStoredPasswordMatches_staysLockedAndSaysNothing() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "actual")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [url],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [
                    .testValue(filename: "a.pdf", id: "1", password: "nope"),
                    .testValue(filename: "b.pdf", id: "2", password: "also-nope")
                ]
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.finish()

        #expect(store.state.isLocked)
        #expect(toasts.value.isEmpty, "auto-unlock must not toast")
    }

    @Test
    func onAppear_withAnUnlockedFile_readsNoStoredPasswords() async throws {
        let wasAsked = LockIsolated(false)
        let url = try PdfFixture.unlocked(name: "plain.pdf")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [url],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                wasAsked.setValue(true)
                return []
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.finish()

        #expect(wasAsked.value == false)
    }

    @Test
    func skipButtonTapped_autoUnlocksTheNextFile() async throws {
        let first = try PdfFixture.unlocked(name: "first.pdf")
        let second = try PdfFixture.locked(name: "second.pdf", password: "s3cr3t")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [first, second],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [.testValue(filename: "b.pdf", id: "1", password: "s3cr3t")]
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.skipButtonTapped))
        await store.receive(\.selectFile)
        await store.receive(\.fileUnlocked)
        await store.finish()

        #expect(store.state.currentIndex == 1)
        #expect(store.state.isLocked == false)
    }
}
