@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct FieldTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                Field {
                    TextField("Firstname", text: .constant("John"))
                }

                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                    Field("Firstname") {
                        TextField("Firstname", text: .constant("John"))
                            .textFieldStyle(.plain)
                    }
                    .environment(\.sizeCategory, size)
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }

    @Test
    func testSnapshot_error() async throws {
        var state = FieldState(value: "foo")
        state.error = "This is mandatory, you have to fill this field!"

        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                Field {
                    TextField("Firstname", text: .constant("John"))
                }
                .state(Binding(get: { state }, set: { state = $0 }))

                ForEach(ContentSizeCategory.allCases, id: \.self) { size in
                    Field("Firstname") {
                        TextField("Firstname", text: .constant("John"))
                            .textFieldStyle(.plain)
                    }
                    .state(Binding(get: { state }, set: { state = $0 }))
                    .environment(\.sizeCategory, size)
                }
            }.frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
}
