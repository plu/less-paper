#if DEBUG
import Dependencies
import Foundation
import SwiftSharing

// A read/write window onto the tip invitation's gate, for the simulator-only debug screen.
//
// Deliberately not a `@DependencyClient`: nothing in the app calls it, and giving it a test seam
// would be ceremony around a thing whose entire purpose is to reach past the seams and poke the
// real storage.
public enum TipInvitationDebug {

    public struct Snapshot: Equatable, Sendable {

        // Whether the live `defaultAppStorage` really is the app group suite, established by
        // writing a probe through it and reading that probe back through a separately opened
        // handle on the expected suite. `UserDefaults` will not say which suite it is, and the
        // failure this catches - `UserDefaults(suiteName:)` returning nil and silently falling
        // back to `.standard` - looks identical to working from the inside.
        public let isAppGroupStore: Bool

        public let firstActiveAt: Date?

        public let activeDays: Int

        public let lastActiveDay: Int?

        public let isSettled: Bool

        public let reviewRequestedAt: Date?

        // The verdict from the real gate, not a re-derivation of it. If this disagrees with the
        // four conditions below, the conditions are wrong, not this.
        public let isEligible: Bool

        public let tenureDays: Int?

        public let tenureDaysRequired: Int

        public let activeDaysRequired: Int

        public let daysSinceReviewPrompt: Int?

        public let daysClearOfReviewPromptRequired: Int

        public var hasEnoughTenure: Bool {
            (tenureDays ?? -1) >= tenureDaysRequired
        }

        public var hasEnoughActiveDays: Bool {
            activeDays >= activeDaysRequired
        }

        public var isClearOfReviewPrompt: Bool {
            guard let daysSinceReviewPrompt else {
                return true
            }
            return daysSinceReviewPrompt >= daysClearOfReviewPromptRequired
        }
    }

    // `expectedSuiteName` is passed in rather than read here: `AppGroup.identifier` lives in
    // `ApiInterface`, which `Components` does not depend on, and hardcoding the string would make
    // this quietly lie the day it changed.
    public static func read(expectedSuiteName: String) async -> Snapshot {
        @Dependency(\.date.now)
        var now

        @Shared(.tipAskFirstActiveAt)
        var firstActiveAt

        @Shared(.tipAskActiveDays)
        var activeDays

        @Shared(.tipAskLastActiveDay)
        var lastActiveDay

        @Shared(.tipAskSettled)
        var settled

        @Shared(.reviewRequestedAt)
        var reviewRequestedAt

        return Snapshot(
            isAppGroupStore: isAppGroupStore(expectedSuiteName: expectedSuiteName),
            firstActiveAt: firstActiveAt.map(Date.init(timeIntervalSince1970:)),
            activeDays: activeDays,
            lastActiveDay: lastActiveDay,
            isSettled: settled,
            reviewRequestedAt: reviewRequestedAt.map(Date.init(timeIntervalSince1970:)),
            isEligible: await TipInvitation.liveValue.isEligible(),
            tenureDays: firstActiveAt.map { days(between: $0, and: now.timeIntervalSince1970) },
            tenureDaysRequired: TipInvitation.debugTenureDaysBeforeAsking,
            activeDaysRequired: TipInvitation.debugActiveDaysBeforeAsking,
            daysSinceReviewPrompt: reviewRequestedAt.map {
                days(between: $0, and: now.timeIntervalSince1970)
            },
            daysClearOfReviewPromptRequired: TipInvitation.debugDaysClearOfReviewPrompt
        )
    }

    // Satisfies every condition at once: tenure one day past the threshold, exactly the active days
    // required, no answer recorded, and no recent review prompt to stand down for.
    public static func makeEligible() {
        @Dependency(\.date.now)
        var now

        @Shared(.tipAskFirstActiveAt)
        var firstActiveAt

        @Shared(.tipAskActiveDays)
        var activeDays

        @Shared(.tipAskSettled)
        var settled

        @Shared(.reviewRequestedAt)
        var reviewRequestedAt

        let tenure = TimeInterval(TipInvitation.debugTenureDaysBeforeAsking + 1) * 24 * 60 * 60

        $firstActiveAt.withLock { $0 = now.timeIntervalSince1970 - tenure }
        $activeDays.withLock { $0 = TipInvitation.debugActiveDaysBeforeAsking }
        $settled.withLock { $0 = false }
        $reviewRequestedAt.withLock { $0 = nil }
    }

    // What a fresh install looks like to the gate.
    public static func reset() {
        @Shared(.tipAskFirstActiveAt)
        var firstActiveAt

        @Shared(.tipAskActiveDays)
        var activeDays

        @Shared(.tipAskLastActiveDay)
        var lastActiveDay

        @Shared(.tipAskSettled)
        var settled

        $firstActiveAt.withLock { $0 = nil }
        $activeDays.withLock { $0 = 0 }
        $lastActiveDay.withLock { $0 = nil }
        $settled.withLock { $0 = false }
    }

    public static func clearSettled() {
        @Shared(.tipAskSettled)
        var settled

        $settled.withLock { $0 = false }
    }

    private static func isAppGroupStore(expectedSuiteName: String) -> Bool {
        @Dependency(\.defaultAppStorage)
        var store

        guard let expected = UserDefaults(suiteName: expectedSuiteName) else {
            return false
        }

        let key = "tip-invitation-debug-probe"
        store.set(true, forKey: key)
        defer { store.removeObject(forKey: key) }

        return expected.bool(forKey: key)
    }

    private static func days(between earlier: TimeInterval, and later: TimeInterval) -> Int {
        Int((later - earlier) / (24 * 60 * 60))
    }
}
#endif
