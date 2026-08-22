import Foundation
import Tagged

public struct BulkEditDocumentsInput: Encodable, Equatable, Sendable {

    public enum Method: Equatable, Sendable {
        case delete
        case merge(Merge)
        case modifyTags(ModifyTags)
        case setCorrespondent(SetCorrespondent)
        case setDocumentType(SetDocumentType)
        case setStoragePath(SetStoragePath)
    }

    public let documents: [Document.Id]
    public let method: Method

    public init(
        documents: [Document.Id],
        method: Method
    ) {
        self.documents = documents
        self.method = method
    }
}

public extension BulkEditDocumentsInput.Method {

    struct Merge: Encodable, Equatable, Sendable {
        public let archiveFallback: Bool
        public let deleteOriginals: Bool

        public init(
            archiveFallback: Bool,
            deleteOriginals: Bool
        ) {
            self.archiveFallback = archiveFallback
            self.deleteOriginals = deleteOriginals
        }
    }

    struct ModifyTags: Encodable, Equatable, Sendable {
        public let addTags: [Tag.Id]
        public let removeTags: [Tag.Id]

        public init(
            addTags: [Tag.Id],
            removeTags: [Tag.Id]
        ) {
            self.addTags = addTags
            self.removeTags = removeTags
        }
    }

    struct SetCorrespondent: Encodable, Equatable, Sendable {
        @NullEncodable
        public var correspondent: Correspondent.Id?

        public init(correspondent: Correspondent.Id?) {
            self.correspondent = correspondent
        }
    }

    struct SetDocumentType: Encodable, Equatable, Sendable {
        @NullEncodable
        public var documentType: DocumentType.Id?

        public init(documentType: DocumentType.Id?) {
            self.documentType = documentType
        }
    }

    struct SetStoragePath: Encodable, Equatable, Sendable {
        @NullEncodable
        public var storagePath: StoragePath.Id?

        public init(storagePath: StoragePath.Id?) {
            self.storagePath = storagePath
        }
    }
}

private extension BulkEditDocumentsInput.Method {
    var key: String {
        switch self {
        case .delete:
            "delete"
        case .merge:
            "merge"
        case .modifyTags:
            "modify_tags"
        case .setCorrespondent:
            "set_correspondent"
        case .setDocumentType:
            "set_document_type"
        case .setStoragePath:
            "set_storage_path"
        }
    }
}

extension BulkEditDocumentsInput {

    private enum CodingKeys: String, CodingKey {
        case documents, method, parameters
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(documents, forKey: .documents)
        try container.encode(method.key, forKey: .method)
        switch method {
        case .delete:
            break
        case let .merge(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .modifyTags(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .setCorrespondent(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .setDocumentType(parameters):
            try container.encode(parameters, forKey: .parameters)
        case let .setStoragePath(parameters):
            try container.encode(parameters, forKey: .parameters)
        }
    }
}

public extension BulkEditDocumentsInput {

    static func testValue(
        documents: [Document.Id] = [1, 2, 3],
        method: Method = .modifyTags(.testValue())
    ) -> Self {
        .init(
            documents: documents,
            method: method
        )
    }
}

public extension BulkEditDocumentsInput.Method.Merge {

    static func testValue(
        archiveFallback: Bool = true,
        deleteOriginals: Bool = false
    ) -> Self {
        .init(
            archiveFallback: archiveFallback,
            deleteOriginals: deleteOriginals
        )
    }
}

public extension BulkEditDocumentsInput.Method.ModifyTags {

    static func testValue(
        addTags: [Tag.Id] = [42, 43],
        removeTags: [Tag.Id] = [99, 98]
    ) -> Self {
        .init(
            addTags: addTags,
            removeTags: removeTags
        )
    }
}

public extension BulkEditDocumentsInput.Method.SetCorrespondent {

    static func testValue(
        correspondent: Correspondent.Id? = 42
    ) -> Self {
        .init(correspondent: correspondent)
    }
}

public extension BulkEditDocumentsInput.Method.SetDocumentType {

    static func testValue(
        documentType: DocumentType.Id? = 43
    ) -> Self {
        .init(documentType: documentType)
    }
}

public extension BulkEditDocumentsInput.Method.SetStoragePath {

    static func testValue(
        storagePath: StoragePath.Id? = 44
    ) -> Self {
        .init(storagePath: storagePath)
    }
}
