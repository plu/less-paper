import Dependencies
import Foundation
import SwiftSharing

extension TipInvitation: DependencyKey {

    public static let liveValue = Self(
        recordActiveDay: recordActiveDay,
        isEligible: { false },
        settle: {}
    )
}

private extension TipInvitation {

    static func recordActiveDay() async {
        @Dependency(\.date.now)
        var now

        @Shared(.tipAskFirstActiveAt)
        var firstActiveAt

        @Shared(.tipAskActiveDays)
        var activeDays

        @Shared(.tipAskLastActiveDay)
        var lastActiveDay

        if firstActiveAt == nil {
            $firstActiveAt.withLock { $0 = now.timeIntervalSince1970 }
        }

        let today = dayNumber(of: now)

        // Compared for difference rather than for increase: a clock set backwards or a flight east
        // would otherwise leave `lastActiveDay` in the future and stop the counter permanently. The
        // cost of `!=` is at most one extra day counted, which is nothing against a wedged gate.
        guard lastActiveDay != today else {
            return
        }

        $lastActiveDay.withLock { $0 = today }
        $activeDays.withLock { $0 += 1 }
    }

    // UTC days, not Calendar days. Over a fifteen-day span it makes no difference where the
    // boundary falls in local time, and Calendar would drag time zones and DST into a counter that
    // has no use for either.
    static func dayNumber(of date: Date) -> Int {
        Int((date.timeIntervalSince1970 / (24 * 60 * 60)).rounded(.down))
    }
}

extension SharedReaderKey where Self == AppStorageKey<Double?> {

    // Seconds since 1970 rather than a Date, as AppStorage stores no Date. Absent means the app has
    // never been foregrounded, which only happens before the very first activation.
    static var tipAskFirstActiveAt: Self {
        .appStorage("tip-ask-first-active-at")
    }
}

extension SharedReaderKey where Self == AppStorageKey<Int?> {

    // A UTC day number, kept only to recognise a second foreground on the same day.
    static var tipAskLastActiveDay: Self {
        .appStorage("tip-ask-last-active-day")
    }
}

extension SharedReaderKey where Self == AppStorageKey<Int>.Default {

    static var tipAskActiveDays: Self {
        Self[.appStorage("tip-ask-active-days"), default: 0]
    }
}

extension SharedReaderKey where Self == AppStorageKey<Bool>.Default {

    static var tipAskSettled: Self {
        Self[.appStorage("tip-ask-settled"), default: false]
    }
}
