@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct SetSavedViewVisibilityUseCaseTests {

    @Test
    func execute_preservesUnrelatedSettings_andMergesVisibility() async throws {
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

    @Shared(.savedViews(.testValue()))
    private var cache: IdentifiedArrayOf<ApiInterface.SavedView> = [.testValue(id: 5)]
}
