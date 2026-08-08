import Foundation
import Tagged

public struct ListOutput<Element: Codable & Equatable & Sendable, Id: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {

    public var count: Int

    public var next: URL?

    public var results: [Element]

    public init(
        count: Int = 0,
        next: URL? = nil,
        results: [Element] = []
    ) {
        self.count = count
        self.next = next
        self.results = results
    }
}

public extension ListOutput {

    mutating func merge(_ other: Self) {
        count = other.count
        next = other.next
        results.append(contentsOf: other.results)
    }
}
