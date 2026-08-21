import Foundation
import SwiftSharing

struct DocumentFilterMatchCount: Equatable, Sendable {

    // nil until the first count is known, which hides the capsule rather than showing a zero the
    // user would read as "nothing matches".
    var count: Int?

    var isRecalculating = false
}

extension SharedReaderKey where Self == InMemoryKey<DocumentFilterMatchCount>.Default {

    // Not scoped to a server, unlike its neighbours in ApiInterface: only one filter sheet exists
    // at a time, and this is ephemeral presentation state rather than data.
    static var documentFilterMatchCount: Self {
        Self[
            .inMemory("documentFilterMatchCount"),
            default: .init()
        ]
    }
}
