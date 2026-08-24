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
struct SaveSavedViewUseCaseTests {

    @Test
    func execute_createSavedView() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveSavedViewInput?>(nil)
        try await withDependencies {
            $0.savedViewsRepository.createSavedView = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
        } operation: {
            let useCase = SaveSavedViewUseCase.liveValue

            let savedViews = try await useCase.execute(
                id: nil,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(savedViews, .testValue(id: 2))
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2)
        ])
    }

    @Test
    func execute_updateSavedView() async throws {
        #expect(cache == [.testValue(id: 1)])

        let inputReceived = LockIsolated<SaveSavedViewInput?>(nil)
        try await withDependencies {
            $0.savedViewsRepository.updateSavedView = { _, input, _ in
                inputReceived.setValue(input)
                return .testValue(name: "Updated")
            }
        } operation: {
            let useCase = SaveSavedViewUseCase.liveValue

            let savedViews = try await useCase.execute(
                id: 1,
                input: .testValue(),
                server: .testValue()
            )

            expectNoDifference(inputReceived.value, .testValue())
            expectNoDifference(savedViews, .testValue(name: "Updated"))
        }

        #expect(cache == [.testValue(name: "Updated")])
    }

    @Test
    func execute_onVersion9_sendsVisibilityInTheBodyAndSkipsUISettings() async throws {
        let server = Server.testValue()

        let inputReceived = LockIsolated<SaveSavedViewInput?>(nil)
        let uiSettingsRequested = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.createSavedView = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2, showInSidebar: true, showOnDashboard: true)
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                uiSettingsRequested.setValue(true)
                return .testValue()
            }
        } operation: {
            let savedView = try await SaveSavedViewUseCase.liveValue.execute(
                id: nil,
                input: .testValue(showInSidebar: true, showOnDashboard: true),
                server: server
            )

            expectNoDifference(savedView, .testValue(id: 2, showInSidebar: true, showOnDashboard: true))
        }

        #expect(inputReceived.value?.showInSidebar == true)
        #expect(inputReceived.value?.showOnDashboard == true)
        #expect(uiSettingsRequested.value == false)
        #expect(cache[id: 2]?.showInSidebar == true)
        #expect(cache[id: 2]?.showOnDashboard == true)
    }

    @Test
    func execute_onVersion10_movesVisibilityIntoUISettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let inputReceived = LockIsolated<SaveSavedViewInput?>(nil)
        let settingsReceived = LockIsolated<[String: JSONValue]?>(nil)

        try await withDependencies {
            $0.savedViewsRepository.createSavedView = { input, _ in
                inputReceived.setValue(input)
                return .testValue(id: 2)
            }
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
            let savedView = try await SaveSavedViewUseCase.liveValue.execute(
                id: nil,
                input: .testValue(showInSidebar: true, showOnDashboard: false),
                server: server
            )

            expectNoDifference(savedView, .testValue(id: 2, showInSidebar: true, showOnDashboard: false))
        }

        #expect(inputReceived.value?.showInSidebar == nil)
        #expect(inputReceived.value?.showOnDashboard == nil)

        let settings = try #require(settingsReceived.value)

        expectNoDifference(settings["theme"], .object(["color": .string("dark")]))

        let savedViews = try #require(settings["saved_views"]?.objectValue)

        expectNoDifference(savedViews["sidebar_views_show_count"], .bool(true))
        expectNoDifference(savedViews["sidebar_views_visible_ids"], .array([.number(4), .number(2)]))
        expectNoDifference(savedViews["dashboard_views_visible_ids"], .array([.number(4)]))

        #expect(cache[id: 2]?.showInSidebar == true)
        #expect(cache[id: 2]?.showOnDashboard == false)
    }

    @Test
    func execute_withoutVisibility_leavesUISettingsAlone() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let uiSettingsRequested = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.updateSavedView = { _, _, _ in .testValue(name: "Updated") }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                uiSettingsRequested.setValue(true)
                return .testValue()
            }
        } operation: {
            _ = try await SaveSavedViewUseCase.liveValue.execute(
                id: 1,
                input: .testValue(),
                server: server
            )
        }

        #expect(uiSettingsRequested.value == false)
    }

    @Shared(.savedViews(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.SavedView> = [.testValue(id: 1)]
}
