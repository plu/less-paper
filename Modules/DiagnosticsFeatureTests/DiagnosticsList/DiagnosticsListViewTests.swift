@testable import DiagnosticsFeature

import ComposableArchitecture
import Foundation
import Logging
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DiagnosticsListViewTests {

    @Test
    func testSnapshot_populated() async throws {
        assertSnapshot(
            of: view(entries: Self.entries),
            as: .image(layout: .device(config: .iPhone12)),
            named: "populated"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(entries: []),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    // The messages come from error descriptions nobody controls, so one has to be longer than the
    // screen: this is the reference that catches a row that clips instead of wrapping.
    @Test
    func testSnapshot_longMessage() async throws {
        let entry = LogEntry(
            date: Self.date,
            level: .error,
            category: .api,
            message: "GET /api/documents/?page=2&ordering=-created&tags__id__all=4,7 → 500 (18422 bytes)"
        )

        assertSnapshot(
            of: view(entries: [entry]),
            as: .image(layout: .device(config: .iPhone12)),
            named: "long-message"
        )
    }

    private static let date = Date(timeIntervalSince1970: 1_756_290_271)

    private static let entries = [
        LogEntry(date: date, level: .error, category: .api, message: "GET /api/documents/ → 500 (312 bytes)"),
        LogEntry(date: date.addingTimeInterval(-4), level: .warning, category: .server, message: "certificate not trusted"),
        LogEntry(date: date.addingTimeInterval(-9), level: .info, category: .api, message: "GET /api/tags/ → 200 (4821 bytes)"),
        LogEntry(date: date.addingTimeInterval(-14), level: .info, category: .storage, message: "cache updated"),
    ]

    // Wrapped in a NavigationStack because that is how the screen is reached, and because the
    // toolbar is where sharing and clearing live - without it the references cover the list and
    // nothing else.
    private func view(entries: [LogEntry]) -> some View {
        NavigationStack {
            DiagnosticsListView(
                store: Store(
                    initialState: DiagnosticsListReducer.State(entries: entries, isLoaded: true),
                    reducer: { DiagnosticsListReducer() }
                )
            )
        }
    }
}
