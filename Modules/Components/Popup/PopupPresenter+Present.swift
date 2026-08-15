import Foundation
import SwiftUI

public extension PopupPresenter {

    func present<Result: Sendable>(
        resolving popup: @escaping @Sendable @MainActor (_ resolve: @escaping @Sendable (Result) -> Void) -> any View
    ) async -> Result? {
        let (stream, continuation) = AsyncStream<Result>.makeStream()

        await present { popup { continuation.yield($0) } }

        var result: Result?
        for await value in stream {
            result = value
            break
        }
        continuation.finish()

        await dismiss()

        return result
    }
}
