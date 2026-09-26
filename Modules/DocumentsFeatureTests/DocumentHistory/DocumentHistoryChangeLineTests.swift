@testable import DocumentsFeature

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentHistoryChangeLineTests {

    @Test
    func relation_readsOperationKeyAndObjects() {
        let line = DocumentHistoryChangeLine(
            change: .relation(key: "tags", operation: "add", objects: ["Audio", "Manual"]),
            server: .testValue()
        )

        #expect(line == .init(label: "Add Tags", value: "Audio, Manual"))
    }

    @Test
    func customField_readsFieldAndValue() {
        let line = DocumentHistoryChangeLine(
            change: .customField(field: "Invoice", value: "42"),
            server: .testValue()
        )

        #expect(line == .init(label: "Invoice", value: "42"))
    }

    // Underscores survive, matching the web's titlecase pipe.
    @Test
    func field_titleCasesTheKeyLikeTheWeb() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "archive_serial_number", old: nil, new: .string("2")),
            server: .testValue()
        )

        #expect(line == .init(label: "Archive_serial_number", value: "2"))
    }

    @Test
    func field_resolvesACorrespondentIdToItsName() {
        withDependencies {
            $0.apiCache.correspondent = { id, _ in id == 8 ? .testValue(id: 8, name: "ACME") : nil }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "correspondent", old: nil, new: .string("8")),
                server: .testValue()
            )

            #expect(line == .init(label: "Correspondent", value: "ACME"))
        }
    }

    @Test
    func field_fallsBackToTheIdWhenTheCacheHasNoMatch() {
        withDependencies {
            $0.apiCache.correspondent = { _, _ in nil }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "correspondent", old: nil, new: .string("8")),
                server: .testValue()
            )

            #expect(line == .init(label: "Correspondent", value: "8"))
        }
    }

    @Test
    func field_resolvesAStoragePathToItsPath() {
        withDependencies {
            $0.apiCache.storagePath = { _, _ in .testValue(id: 3, path: "Emma/{{ created_year }}") }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "storage_path", old: nil, new: .string("3")),
                server: .testValue()
            )

            #expect(line == .init(label: "Storage_path", value: "Emma/{{ created_year }}"))
        }
    }

    @Test
    func field_resolvesAnOwnerToTheUsername() {
        withDependencies {
            $0.apiCache.user = { _, _ in .testValue(id: 2, username: "johannes") }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "owner", old: nil, new: .string("2")),
                server: .testValue()
            )

            #expect(line == .init(label: "Owner", value: "johannes"))
        }
    }

    // The web shows "Tags: 7" here. The ids are in the cache, so the app can do better.
    @Test
    func field_resolvesRawTagIdsToNames() {
        withDependencies {
            $0.apiCache.tag = { id, _ in
                switch id {
                case 96: .testValue(id: 96, name: "Invoice")
                case 97: .testValue(id: 97, name: "Paid")
                default: nil
                }
            }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "tags", old: .number(97), new: .array([.number(96), .number(97), .number(5)])),
                server: .testValue()
            )

            #expect(line == .init(label: "Tags", value: "Invoice, Paid, 5"))
        }
    }

    @Test
    func field_showsANoteIdAsAnInteger() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "Note Added", old: nil, new: .number(40)),
            server: .testValue()
        )

        #expect(line == .init(label: "Note Added", value: "40"))
    }

    @Test
    func field_cutsContentAtAHundredCharacters() {
        let content = String(repeating: "a", count: 150)
        let line = DocumentHistoryChangeLine(
            change: .field(key: "content", old: nil, new: .string(content)),
            server: .testValue()
        )

        #expect(line.value == String(repeating: "a", count: 100) + "…")
    }

    @Test
    func field_leavesShortContentWhole() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "content", old: nil, new: .string("Sub")),
            server: .testValue()
        )

        #expect(line.value == "Sub")
    }

    @Test
    func field_showsAnEmDashWhenTheNewValueIsGone() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "Note Deleted", old: .number(40), new: nil),
            server: .testValue()
        )

        #expect(line == .init(label: "Note Deleted", value: "—"))
    }
}
