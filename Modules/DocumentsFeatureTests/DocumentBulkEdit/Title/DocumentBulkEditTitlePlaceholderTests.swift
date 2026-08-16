@testable import DocumentsFeature

import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentBulkEditTitlePlaceholderTests {

    @Test
    func test_allCases_areBraceWrappedAndUnique() async throws {
        let rawValues = DocumentBulkEditTitlePlaceholder.allCases.map(\.rawValue)

        #expect(rawValues.count == 22)
        #expect(Set(rawValues).count == 22)
        for rawValue in rawValues {
            #expect(rawValue.hasPrefix("{"))
            #expect(rawValue.hasSuffix("}"))
        }
    }

    @Test
    func test_localized_resolvesForEveryCase() async throws {
        for placeholder in DocumentBulkEditTitlePlaceholder.allCases {
            let description = String(localized: placeholder.localized)

            #expect(!description.isEmpty)
            #expect(description != placeholder.rawValue)
        }
    }

    @Test
    func test_id_isRawValue() async throws {
        #expect(DocumentBulkEditTitlePlaceholder.asn.id == "{asn}")
    }
}
