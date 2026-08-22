import Foundation

public struct CreateNoteInput: Codable, Equatable, Sendable {

    public let note: String

    public init(note: String) {
        self.note = note
    }
}

public extension CreateNoteInput {

    static func testValue(note: String = "Needs a signature") -> Self {
        .init(note: note)
    }
}
