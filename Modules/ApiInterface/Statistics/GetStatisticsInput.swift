import Foundation

public struct GetStatisticsInput: Codable, Equatable, Sendable {

    public init() {}
}

public extension GetStatisticsInput {

    static func testValue() -> Self {
        .init()
    }
}
