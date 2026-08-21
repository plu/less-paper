@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetSavedViewsUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [])

        try await withDependencies {
            $0.savedViewsRepository.getSavedViews = { input, _ in
                switch input.url?.absoluteString {
                case "http://page/2":
                    return .testValue(next: .testValue(string: "http://page/3"), results: [.testValue(id: 2)])
                case "http://page/3":
                    return .testValue(next: nil, results: [.testValue(id: 3)])
                default:
                    return .testValue(next: .testValue(string: "http://page/2"), results: [.testValue(id: 1)])
                }
            }
        } operation: {
            let useCase = GetSavedViewsUseCase.liveValue

            let savedViews = try await useCase.execute(
                server: .testValue()
            )

            #expect(savedViews == [
                .testValue(id: 1),
                .testValue(id: 2),
                .testValue(id: 3)
            ])
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2),
            .testValue(id: 3)
        ])
    }

    @Test
    func execute_onVersion9_usesPayloadFieldsAndSkipsUiSettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let uiSettingsRequested = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.getSavedViews = { _, _ in
                .testValue(next: nil, results: [
                    .testValue(id: 1, showInSidebar: true, showOnDashboard: false)
                ])
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                uiSettingsRequested.setValue(true)
                return .testValue()
            }
        } operation: {
            let savedViews = try await GetSavedViewsUseCase.liveValue.execute(server: server)

            #expect(savedViews.first?.showInSidebar == true)
            #expect(savedViews.first?.showOnDashboard == false)
        }

        #expect(uiSettingsRequested.value == false)
    }

    @Test
    func execute_onVersion10_overlaysVisibilityFromUiSettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        try await withDependencies {
            $0.savedViewsRepository.getSavedViews = { _, _ in
                .testValue(next: nil, results: [
                    .testValue(id: 1, showInSidebar: true, showOnDashboard: true)
                ])
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .init(
                    settings: .testValue(savedViews: .testValue(
                        dashboardViewsVisibleIds: [1],
                        sidebarViewsVisibleIds: []
                    )),
                    user: .testValue()
                )
            }
        } operation: {
            let savedViews = try await GetSavedViewsUseCase.liveValue.execute(server: server)

            // UISettings is authoritative on v10, so the payload's `true` for sidebar loses.
            #expect(savedViews.first?.showInSidebar == false)
            #expect(savedViews.first?.showOnDashboard == true)
        }
    }

    @Shared(.savedViews(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.SavedView> = []
}
