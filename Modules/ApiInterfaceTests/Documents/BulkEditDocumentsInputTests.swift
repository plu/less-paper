@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct BulkEditDocumentsInputTests {

    @Test
    func encode_delete() async throws {
        let input = BulkEditDocumentsInput(documents: [1, 2, 3], method: .delete)

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "delete"
        }
        """)
    }

    @Test
    func encode_merge() async throws {
        let input = BulkEditDocumentsInput(
            documents: [3, 1, 2],
            method: .merge(.testValue(deleteOriginals: true))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            3,
            1,
            2
          ],
          "method" : "merge",
          "parameters" : {
            "archive_fallback" : true,
            "delete_originals" : true
          }
        }
        """)
    }

    @Test
    func encode_merge_withDefaults() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2],
            method: .merge(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2
          ],
          "method" : "merge",
          "parameters" : {
            "archive_fallback" : true,
            "delete_originals" : false
          }
        }
        """)
    }

    @Test
    func encode_modifyTags() async throws {
        let input = BulkEditDocumentsInput.testValue()

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "modify_tags",
          "parameters" : {
            "add_tags" : [
              42,
              43
            ],
            "remove_tags" : [
              99,
              98
            ]
          }
        }
        """)
    }

    @Test
    func encode_setCorrespondent() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setCorrespondent(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_correspondent",
          "parameters" : {
            "correspondent" : 42
          }
        }
        """)
    }

    @Test
    func encode_setCorrespondent_withNilCorrespondent() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setCorrespondent(.testValue(correspondent: nil))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_correspondent",
          "parameters" : {
            "correspondent" : null
          }
        }
        """)
    }

    @Test
    func encode_setDocumentType() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setDocumentType(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_document_type",
          "parameters" : {
            "document_type" : 43
          }
        }
        """)
    }

    @Test
    func encode_setDocumentType_withNilDocumentType() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setDocumentType(.testValue(documentType: nil))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_document_type",
          "parameters" : {
            "document_type" : null
          }
        }
        """)
    }

    @Test
    func encode_setStoragePath() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setStoragePath(.testValue())
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_storage_path",
          "parameters" : {
            "storage_path" : 44
          }
        }
        """)
    }

    @Test
    func encode_setStoragePath_withNilStoragePath() async throws {
        let input = BulkEditDocumentsInput(
            documents: [1, 2, 3],
            method: .setStoragePath(.testValue(storagePath: nil))
        )

        let json = try String(decoding: JSONEncoder.apiEncoder.encode(input), as: UTF8.self)

        expectNoDifference(json, """
        {
          "documents" : [
            1,
            2,
            3
          ],
          "method" : "set_storage_path",
          "parameters" : {
            "storage_path" : null
          }
        }
        """)
    }
}
