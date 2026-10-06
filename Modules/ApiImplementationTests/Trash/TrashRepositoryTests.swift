@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct TrashRepositoryTests {

    @Test
    func emptyTrash_returnsVoid() async throws {
        try await repository.emptyTrash(
            [1, 2],
            .testValue()
        )
    }

    @Test
    func getTrash_returnsTestValue() async throws {
        let output = try await repository.getTrash(
            .testValue()
        )

        #expect(output == .testValue())
    }

    @Test
    func restoreDocuments_returnsVoid() async throws {
        try await repository.restoreDocuments(
            [1, 2],
            .testValue()
        )
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func trashCycle() async throws {
        let title = "Trash Cycle Test \(UUID())"
        let id = try await createTestDocument(title: title)

        try await documentsRepository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await waitForTrash(containing: id, present: true)

        try await repository.restoreDocuments(
            [id],
            .testValue()
        )
        try await waitForTrash(containing: id, present: false)

        try await documentsRepository.bulkEditDocuments(
            input: .init(documents: [id], method: .delete),
            server: .testValue()
        )
        try await waitForTrash(containing: id, present: true)

        try await repository.emptyTrash(
            [id],
            .testValue()
        )
        try await waitForTrash(containing: id, present: false)

        let remaining = try await documentsRepository.getAllDocumentIds(
            input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
            server: .testValue()
        )
        #expect(remaining.results.isEmpty)
    }

    private func createTestDocument(title: String) async throws -> Document.Id {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.pdf")
        try Data("Test PDF content".utf8).write(to: tempURL)
        try await documentsRepository.createDocument(
            input: .testValue(createdDate: Date(), title: title, url: tempURL),
            server: .testValue()
        )

        for _ in 0 ..< 30 {
            let output = try await documentsRepository.getAllDocumentIds(
                input: .testValue(filterRules: [.init(ruleType: .title, value: title)]),
                server: .testValue()
            )
            if let id = output.results.first?.id {
                return id
            }
            try await Task.sleep(for: .seconds(1))
        }

        throw DocumentConsumptionTimedOut()
    }

    private func waitForTrash(containing id: Document.Id, present: Bool) async throws {
        for _ in 0 ..< 30 {
            let trash = try await repository.getTrash(.testValue())
            let contains = trash.results.map(\.id).contains(id)
            if contains == present {
                return
            }
            try await Task.sleep(for: .seconds(1))
        }

        throw TrashDidNotSettle()
    }

    private struct DocumentConsumptionTimedOut: Error {}

    private struct TrashDidNotSettle: Error {}

    @Dependency(\.trashRepository)
    private var repository

    @Dependency(\.documentsRepository)
    private var documentsRepository
}
