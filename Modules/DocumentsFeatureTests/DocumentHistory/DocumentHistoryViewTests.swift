@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Dependencies
import SwiftUI
import Testing
import TestSupport

@MainActor
// Relative times are measured against the dependency clock, set here rather than around the view:
// `@Dependency` resolves when the body renders, outside any `withDependencies` scope in the test.
@Suite(
    .testDependencies { $0.date.now = .testValue() },
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentHistoryViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(state: .testValue(entries: [
                .testValue(
                    actor: .testValue(id: 2, username: "johannes"),
                    changes: [.field(key: "tags", old: .number(7), new: .array([.number(1), .number(7)]))],
                    id: 3,
                    timestamp: now.addingTimeInterval(-11 * 3600)
                ),
                .testValue(
                    actor: nil,
                    changes: [
                        .field(key: "document_type", old: nil, new: .string("1")),
                        .relation(key: "tags", operation: "add", objects: ["Privat"]),
                    ],
                    id: 2,
                    timestamp: now.addingTimeInterval(-21 * 3600)
                ),
                .testValue(
                    action: .create,
                    actor: nil,
                    changes: [.field(key: "title", old: nil, new: .string("Elternbrief"))],
                    id: 1,
                    timestamp: now.addingTimeInterval(-22 * 3600)
                ),
            ])),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: view(state: .testValue(entries: [
                .testValue(
                    actor: .testValue(id: 2, username: "johannes"),
                    changes: [.field(key: "tags", old: .number(7), new: .array([.number(1), .number(7)]))],
                    id: 3,
                    timestamp: now.addingTimeInterval(-11 * 3600)
                ),
                .testValue(
                    actor: nil,
                    changes: [
                        .field(key: "document_type", old: nil, new: .string("1")),
                        .relation(key: "tags", operation: "add", objects: ["Privat"]),
                    ],
                    id: 2,
                    timestamp: now.addingTimeInterval(-21 * 3600)
                ),
                .testValue(
                    action: .create,
                    actor: nil,
                    changes: [.field(key: "title", old: nil, new: .string("Elternbrief"))],
                    id: 1,
                    timestamp: now.addingTimeInterval(-22 * 3600)
                ),
            ])),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            ),
            named: "darkMode"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(entries: [])),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadError: "Audit log is disabled")),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    private let now = Date.testValue()

    private func view(state: DocumentHistoryReducer.State) -> some View {
        DocumentHistoryView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentHistoryReducer()
                }
            )
        )
    }
}
