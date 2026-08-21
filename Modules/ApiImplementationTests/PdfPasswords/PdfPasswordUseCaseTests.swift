@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct PdfPasswordUseCaseTests {

    @Test
    func get_returnsWhatTheKeychainHolds() async throws {
        let stored = [PdfPassword.testValue()]

        try await withDependencies {
            $0.keychain.getPdfPasswords = { stored }
        } operation: {
            let result = try await GetPdfPasswordsUseCase.liveValue.execute()
            expectNoDifference(result, stored)
        }
    }

    @Test
    func save_appendsToTheStoredList() async throws {
        let written = LockIsolated<[PdfPassword]?>(nil)

        try await withDependencies {
            $0.keychain.getPdfPasswords = { [.testValue(filename: "old.pdf", id: "1", password: "old")] }
            $0.keychain.setPdfPasswords = { written.setValue($0) }
            $0.uuid = .incrementing
        } operation: {
            try await SavePdfPasswordUseCase.liveValue.execute(filename: "new.pdf", password: "new")
        }

        expectNoDifference(written.value, [
            .testValue(filename: "old.pdf", id: "1", password: "old"),
            .testValue(filename: "new.pdf", id: UUID(0).uuidString, password: "new")
        ])
    }

    // Importing the same recurring document every month with the toggle left on would otherwise
    // grow one duplicate entry per import.
    @Test
    func save_isANoOpWhenThePasswordIsAlreadyStored() async throws {
        let written = LockIsolated<[PdfPassword]?>(nil)

        try await withDependencies {
            $0.keychain.getPdfPasswords = { [.testValue(filename: "january.pdf", id: "1", password: "secret")] }
            $0.keychain.setPdfPasswords = { written.setValue($0) }
            $0.uuid = .incrementing
        } operation: {
            try await SavePdfPasswordUseCase.liveValue.execute(filename: "february.pdf", password: "secret")
        }

        #expect(written.value == nil, "an already-stored password must not be written again")
    }

    @Test
    func delete_removesTheMatchingId() async throws {
        let written = LockIsolated<[PdfPassword]?>(nil)

        try await withDependencies {
            $0.keychain.getPdfPasswords = {
                [
                    .testValue(filename: "a.pdf", id: "1", password: "a"),
                    .testValue(filename: "b.pdf", id: "2", password: "b")
                ]
            }
            $0.keychain.setPdfPasswords = { written.setValue($0) }
        } operation: {
            try await DeletePdfPasswordUseCase.liveValue.execute(id: "1")
        }

        expectNoDifference(written.value, [.testValue(filename: "b.pdf", id: "2", password: "b")])
    }
}
