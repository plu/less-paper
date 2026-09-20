@testable import TrashFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TrashListViewTests {

    @Test
    func testSnapshot_populated() async throws {
        assertSnapshot(
            of: view(documents: Self.documents),
            as: .image(layout: .device(config: .iPhone12)),
            named: "populated"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(documents: []),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    private static let deletedAt = Date(timeIntervalSince1970: 1_756_290_271)

    private static let documents = [
        ApiInterface.Document.testValue(deletedAt: deletedAt, id: 1, title: "Invoice 2024"),
        ApiInterface.Document.testValue(deletedAt: deletedAt.addingTimeInterval(-86400), id: 2, title: "Puky"),
        // No deleted date: the field is optional, and a row still has to render without it.
        ApiInterface.Document.testValue(id: 3, title: "Sonos Era 300")
    ]

    private func view(documents: [ApiInterface.Document]) -> some View {
        NavigationStack {
            TrashListView(
                store: Store(
                    initialState: TrashListReducer.State(
                        documents: IdentifiedArray(uniqueElements: documents),
                        isLoaded: true,
                        server: .testValue()
                    ),
                    reducer: { TrashListReducer() }
                )
            )
        }
    }
}
