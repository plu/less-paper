import Dependencies
import Foundation

// The rendezvous between the requests a proxy bounced and the one login that answers them.
//
// Not an AsyncChannel like certificateApprovalChannel, which has exactly one consumer: a channel
// hands each element to one consumer, so a single event would release one of the ten requests a
// launch parks and leave the other nine waiting forever - and a parked request would swallow the
// redirect the reducer was meant to see. Continuations keyed by server let one login answer every
// request parked against that server.
public actor ForwardAuthCoordinator {

    public init() {}

    // Consumed by ForwardAuthReducer's bootstrap. Holding the stream is also what tells a parked
    // request that a login can be presented at all: the share extension links no presenter, so
    // awaitSignIn there fails the request immediately rather than waiting for a sign-in that
    // cannot happen, and the user gets ShareFormError.forwardAuthRequired.
    public func redirects() -> AsyncStream<ForwardAuthRedirect> {
        let (stream, continuation) = AsyncStream<ForwardAuthRedirect>.makeStream()
        presenter?.finish()
        presenter = continuation
        return stream
    }

    // Called from ApiClientDelegate.shouldRetry. Returns true once a login has landed a cookie and
    // the request should replay, false when the user backed out or no login can be presented.
    public func awaitSignIn(for redirect: ForwardAuthRedirect) async -> Bool {
        guard let presenter, !Task.isCancelled else {
            return false
        }

        let waiter = UUID()

        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                // Only the first request to park raises a login; the rest join the one it raised.
                // Ten concurrent bounces at launch are the ordinary case, not the edge case.
                let isFirst = waiters[redirect.id] == nil
                waiters[redirect.id, default: [:]][waiter] = continuation

                if isFirst {
                    presenter.yield(redirect)
                }
            }
        } onCancel: {
            Task { await self.cancel(waiter: waiter, for: redirect.id) }
        }
    }

    // Called by the reducer once the login is over. `signedIn` false - a dismissed sheet - fails
    // the parked requests instead of replaying them, or the app loops through login, replay and a
    // fresh bounce forever.
    public func resolve(_ redirect: ForwardAuthRedirect, signedIn: Bool) {
        let parked = waiters.removeValue(forKey: redirect.id) ?? [:]

        for continuation in parked.values {
            continuation.resume(returning: signedIn)
        }
    }

    // For tests: how many requests are parked against this server. A test that resolves before
    // every request it started has parked would pass against a rendezvous that releases one
    // waiter, which is the bug this type exists to prevent.
    public func waiterCount(for redirect: ForwardAuthRedirect) -> Int {
        waiters[redirect.id]?.count ?? 0
    }

    private var presenter: AsyncStream<ForwardAuthRedirect>.Continuation?

    private var waiters: [ForwardAuthRedirect.ID: [UUID: CheckedContinuation<Bool, Never>]] = [:]

    private func cancel(waiter: UUID, for redirect: ForwardAuthRedirect.ID) {
        guard let continuation = waiters[redirect]?.removeValue(forKey: waiter) else {
            return
        }

        if waiters[redirect]?.isEmpty == true {
            waiters[redirect] = nil
        }

        continuation.resume(returning: false)
    }
}

public extension DependencyValues {

    var forwardAuthCoordinator: ForwardAuthCoordinator {
        get { self[ForwardAuthCoordinatorKey.self] }
        set { self[ForwardAuthCoordinatorKey.self] = newValue }
    }

    private enum ForwardAuthCoordinatorKey: DependencyKey {
        static let liveValue = ForwardAuthCoordinator()
        static let testValue = ForwardAuthCoordinator()
    }
}
