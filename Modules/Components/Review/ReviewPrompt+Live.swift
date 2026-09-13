import Dependencies
import Foundation
import SwiftSharing

extension ReviewPrompt: DependencyKey {

    public static let liveValue = Self(record: record(moment:))
}

private extension ReviewPrompt {

    // The third import rather than the first: the first two are someone still finding out whether
    // the app works, and only a third says filing things here has become a habit.
    static let importsBeforeAsking = 3

    // Well inside iOS's own three-per-year cap, which is silent - a prompt over that budget is
    // simply not shown, and we would never learn we had wasted it. One gate for both moments, so a
    // tip and a run of imports in the same month cannot spend two.
    static let cooldown: TimeInterval = 120 * 24 * 60 * 60

    static func record(moment: ReviewMoment) async {
        @Dependency(\.appStoreReviewRequester.request)
        var requestReview

        @Dependency(\.date.now)
        var now

        @Shared(.reviewImportCount)
        var importCount

        @Shared(.reviewRequestedAt)
        var requestedAt

        // The suite moved from `.standard` to the app group, so an existing install's cooldown
        // timestamp reads as absent here even though a review was already requested. Adopting the
        // old value once avoids asking sooner than intended; delete this once every install has
        // launched post-update. `review-import-count` gets no equivalent read-across - losing it
        // only ever delays the next ask, which errs the safe way.
        if requestedAt == nil,
           let legacyRequestedAt = UserDefaults.standard.object(forKey: "review-requested-at") as? Double {
            $requestedAt.withLock { $0 = legacyRequestedAt }
        }

        switch moment {
        case .documentImported:
            $importCount.withLock { $0 += 1 }
            guard importCount >= importsBeforeAsking else {
                return
            }
        case .tipReceived:
            break
        }

        if let requestedAt, now.timeIntervalSince1970 - requestedAt < cooldown {
            return
        }

        guard await requestReview() else {
            return
        }

        $requestedAt.withLock { $0 = now.timeIntervalSince1970 }
    }
}

extension SharedReaderKey where Self == AppStorageKey<Int>.Default {

    static var reviewImportCount: Self {
        Self[.appStorage("review-import-count"), default: 0]
    }
}

extension SharedReaderKey where Self == AppStorageKey<Double?> {

    // Seconds since 1970 rather than a Date: AppStorage stores a fixed set of primitives and Date
    // is not one of them. Absent means never asked.
    static var reviewRequestedAt: Self {
        .appStorage("review-requested-at")
    }
}
