@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct SavedViewsRepositoryTests {

    @Test
    func createSavedView_returnsTestValue() async throws {
        let output = try await repository.createSavedView(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteSavedView_returnsVoid() async throws {
        try await repository.deleteSavedView(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getSavedViews_returnsTestValue() async throws {
        let output = try await repository.getSavedViews(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateSavedView_returnsTestValue() async throws {
        let output = try await repository.updateSavedView(
            id: 1,
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getSavedViews_acceptsAnAbsoluteURL() async throws {
        // The `next` link paperless answers with is absolute; the seed never fills a second page,
        // so the endpoint itself stands in for one. What matters is the absolute URL is used
        // verbatim rather than rebuilt from the input.
        let server = Server.testValue()
        let viaURL = try await repository.getSavedViews(
            input: .init(url: server.url.appending(path: "/api/saved_views/")),
            server: server
        )

        #expect(viaURL.count >= viaURL.results.count)
    }

    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud() async throws {
        var savedView = try await createSavedView()
        #expect(savedView.id > 0)
        #expect(savedView.name == "Test SavedView")
        #expect(savedView.userCanChange == true)

        var savedViews = try await getSavedViews()
        #expect(savedViews.results.map(\.id) == [savedView.id])
        #expect(savedViews.count == 1)
        #expect(savedViews.next == nil)

        let firstSavedView = try #require(savedViews.results.first)
        #expect(savedView.id == firstSavedView.id)
        #expect(savedView.name == firstSavedView.name)
        #expect(savedView.owner == firstSavedView.owner)
        #expect(savedView.userCanChange == firstSavedView.userCanChange)

        var updateSavedViewInput = SaveSavedViewInput(savedView: savedView)
        updateSavedViewInput.name = "Updated Name"
        savedView = try await repository.updateSavedView(
            id: savedView.id,
            input: updateSavedViewInput,
            server: .testValue()
        )
        #expect(savedView.name == "Updated Name")

        try await deleteSavedView(savedView.id)
        savedViews = try await getSavedViews()
        #expect(savedViews.results.map(\.id) == [])
        #expect(savedViews.next == nil)
        #expect(savedViews.results == [])
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createSavedView() async throws -> SaveSavedViewOutput {
        let input = SaveSavedViewInput(
            name: "Test SavedView"
        )
        return try await repository.createSavedView(
            input: input,
            server: .testValue()
        )
    }

    private func deleteSavedView(_ id: SavedView.Id) async throws -> DeleteSavedViewOutput {
        try await repository.deleteSavedView(
            id: id,
            server: .testValue()
        )
    }

    private func getSavedViews() async throws -> GetSavedViewsOutput {
        let input = GetSavedViewsInput()
        return try await repository.getSavedViews(
            input: input,
            server: .testValue()
        )
    }

    @Dependency(\.savedViewsRepository)
    private var repository
}
