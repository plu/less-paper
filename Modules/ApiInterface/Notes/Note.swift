import Foundation
import Tagged

public struct Note: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias Id = Tagged<Note, Int>

    public let created: Date

    public let id: Id

    public let note: String

    public let user: Author

    public init(
        created: Date,
        id: Id,
        note: String,
        user: Author
    ) {
        self.created = created
        self.id = id
        self.note = note
        self.user = user
    }
}

public extension Note {

    // The nested user the notes endpoint returns carries four fields where User carries thirteen,
    // so it cannot be decoded as one. Nesting keeps User.Id resolving to the real User.
    struct Author: Codable, Equatable, Hashable, Identifiable, Sendable {

        public let id: User.Id

        public let username: String

        public init(
            id: User.Id,
            username: String
        ) {
            self.id = id
            self.username = username
        }
    }
}

extension Note.Author: CustomStringConvertible {
    public var description: String {
        username
    }
}

public extension Note {

    static func testValue(
        created: Date = .testValue(),
        id: Id = 1,
        note: String = "Needs a signature",
        user: Author = .testValue()
    ) -> Self {
        .init(
            created: created,
            id: id,
            note: note,
            user: user
        )
    }
}

public extension Note.Author {

    static func testValue(
        id: User.Id = 1,
        username: String = "admin"
    ) -> Self {
        .init(
            id: id,
            username: username
        )
    }
}
