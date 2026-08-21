@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct SetSavedViewVisibilityUseCaseTests {

    @Test
    func execute_preservesUnrelatedSettings_andMergesVisibility() async throws {
        @Shared(.apiVersion(Server.testValue()))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let settingsReceived = LockIsolated<[String: JSONValue]?>(nil)

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .init(
                    settings: .init(raw: [
                        "theme": .object(["color": .string("dark")]),
                        "saved_views": .object([
                            "sidebar_views_show_count": .bool(true),
                            "dashboard_views_visible_ids": .array([.number(4)]),
                            "sidebar_views_visible_ids": .array([.number(4)])
                        ])
                    ]),
                    user: .testValue()
                )
            }
            $0.uiSettingsRepository.updateUISettings = { input, _ in
                settingsReceived.setValue(input.settings)
                return .testValue()
            }
        } operation: {
            let useCase = SetSavedViewVisibilityUseCase.liveValue

            try await useCase.execute(
                savedViewId: 5,
                showInSidebar: true,
                showOnDashboard: false,
                server: .testValue()
            )
        }

        let settings = try #require(settingsReceived.value)

        expectNoDifference(settings["theme"], .object(["color": .string("dark")]))

        let savedViews = try #require(settings["saved_views"]?.objectValue)

        expectNoDifference(savedViews["sidebar_views_show_count"], .bool(true))
        expectNoDifference(savedViews["sidebar_views_visible_ids"], .array([.number(4), .number(5)]))
        expectNoDifference(savedViews["dashboard_views_visible_ids"], .array([.number(4)]))

        #expect(cache[id: 5]?.showInSidebar == true)
        #expect(cache[id: 5]?.showOnDashboard == false)
    }

    @Test
    func execute_onVersion9_patchesTheSavedViewAndSkipsUiSettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let received = LockIsolated<(SavedView.Id, SetSavedViewVisibilityInput)?>(nil)
        let uiSettingsRequested = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.setSavedViewVisibility = { id, input, _ in
                received.setValue((id, input))
                return .testValue()
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                uiSettingsRequested.setValue(true)
                return .testValue()
            }
        } operation: {
            try await SetSavedViewVisibilityUseCase.liveValue.execute(
                savedViewId: 5,
                showInSidebar: true,
                showOnDashboard: false,
                server: server
            )
        }

        let (id, input) = try #require(received.value)

        #expect(id == 5)
        #expect(input == SetSavedViewVisibilityInput(showInSidebar: true, showOnDashboard: false))
        #expect(uiSettingsRequested.value == false)
        #expect(cache[id: 5]?.showInSidebar == true)
        #expect(cache[id: 5]?.showOnDashboard == false)
    }

    @Test
    func execute_onVersion10_doesNotPatchTheSavedView() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let patched = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.setSavedViewVisibility = { _, _, _ in
                patched.setValue(true)
                return .testValue()
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in .testValue() }
            $0.uiSettingsRepository.updateUISettings = { _, _ in .testValue() }
        } operation: {
            try await SetSavedViewVisibilityUseCase.liveValue.execute(
                savedViewId: 5,
                showInSidebar: true,
                showOnDashboard: false,
                server: server
            )
        }

        #expect(patched.value == false)
    }

    @Shared(.savedViews(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.SavedView> = [.testValue(id: 5)]
}
