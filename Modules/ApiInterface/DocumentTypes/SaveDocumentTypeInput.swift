import Foundation
import Tagged

public struct SaveDocumentTypeInput: Codable, Equatable, Sendable {

    public var isInsensitive: Bool

    public var match: String

    public var matchingAlgorithm: MatchingAlgorithm

    public var name: String

    public var owner: Clearable<User.Id>?

    public var setPermissions: Permissions?

    public init(
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String,
        owner: Clearable<User.Id>? = nil,
        setPermissions: Permissions? = nil
    ) {
        self.isInsensitive = isInsensitive
        self.match = match
        self.matchingAlgorithm = matchingAlgorithm
        self.name = name
        self.owner = owner
        self.setPermissions = setPermissions
    }
}

public extension SaveDocumentTypeInput {

    init(
        setPermissions: Permissions? = nil,
        documentType: DocumentType?
    ) {
        self.init(
            isInsensitive: documentType?.isInsensitive ?? true,
            match: documentType?.match ?? "",
            matchingAlgorithm: documentType?.matchingAlgorithm ?? .automatic,
            name: documentType?.name ?? "",
            owner: documentType?.owner.ifPresent { .value($0) },
            setPermissions: setPermissions
        )
    }
}

public extension SaveDocumentTypeInput {

    static func testValue(
        isInsensitive: Bool = true,
        match: String = "",
        matchingAlgorithm: MatchingAlgorithm = .automatic,
        name: String = "Test DocumentType",
        owner: Clearable<User.Id>? = .value(1),
        setPermissions: Permissions = .testValue()
    ) -> Self {
        .init(
            isInsensitive: isInsensitive,
            match: match,
            matchingAlgorithm: matchingAlgorithm,
            name: name,
            owner: owner,
            setPermissions: setPermissions
        )
    }
}
