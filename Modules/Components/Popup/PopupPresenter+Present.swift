import Foundation
import SwiftUI

public extension PopupPresenter {

    /**
     * Presents a popup and suspends until it resolves a value, then dismisses it.
     *
     * The popup builder receives a `resolve` callback to hand back the user's answer. Because the
     * caller stays suspended until then, a `send` captured from an `Effect.run` closure is still
     * live when the popup resolves — unlike the fire-and-forget `present`, where it is not.
     *
     * - Parameters:
     *   - popup: Builds the popup view from a callback that resolves it with a value
     * - Returns: The resolved value, or `nil` if the surrounding task was cancelled first
     */
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
