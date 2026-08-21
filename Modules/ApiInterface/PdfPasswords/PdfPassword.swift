import Foundation

public struct PdfPassword: Codable, Equatable, Identifiable, Sendable {

    public let filename: String

    public let id: String

    public let password: String

    public init(
        filename: String,
        id: String,
        password: String
    ) {
        self.filename = filename
        self.id = id
        self.password = password
    }
}

public extension PdfPassword {

    static func testValue(
        filename: String = "statement.pdf",
        id: String = "9E2B1B2E-2F0B-4C9E-8B0E-1B2E2F0B4C9E",
        password: String = "s3cr3t"
    ) -> Self {
        .init(
            filename: filename,
            id: id,
            password: password
        )
    }
}
