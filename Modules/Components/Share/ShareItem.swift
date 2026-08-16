import Foundation

public struct ShareItem: Equatable, Identifiable, Sendable {

    public var id: URL { url }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
