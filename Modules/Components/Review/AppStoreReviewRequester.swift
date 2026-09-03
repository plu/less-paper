import Dependencies
import DependenciesMacros
import StoreKit
import UIKit

// The StoreKit edge, kept as thin as it can be: everything that decides *whether* to ask lives in
// ReviewPrompt, which is testable, and this is only the part that cannot be.
@DependencyClient
public struct AppStoreReviewRequester: Sendable {

    // Answers whether the prompt was actually asked for, so a caller rationing its asks does not
    // spend one on a request that never left the building.
    public var request: @Sendable () async -> Bool = { false }
}

extension AppStoreReviewRequester: TestDependencyKey {

    public static let previewValue = Self(request: { false })

    public static let testValue = Self(request: { false })
}

public extension DependencyValues {

    var appStoreReviewRequester: AppStoreReviewRequester {
        get { self[AppStoreReviewRequester.self] }
        set { self[AppStoreReviewRequester.self] = newValue }
    }
}

extension AppStoreReviewRequester: DependencyKey {

    public static let liveValue = Self(request: request)
}

private extension AppStoreReviewRequester {

    @MainActor
    static func request() async -> Bool {
        // No foreground scene means there is nowhere to show the prompt - the app went to the
        // background while the caller was waiting for its moment to settle. StoreKit would drop the
        // request silently, so say so instead and let the caller keep its budget.
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else {
            return false
        }

        AppStore.requestReview(in: scene)
        return true
    }
}
