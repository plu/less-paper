@testable import Components

import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct TipInvitationTests {

    @Test
    func recordActiveDay_onTheFirstCall_storesTheFirstActiveDate() async {
        let store = UserDefaults.inMemory
        let now = Date(timeIntervalSince1970: 1_600_000_000)

        await record(at: now, store: store)

        await withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @Shared(.tipAskFirstActiveAt) var firstActiveAt
            @Shared(.tipAskActiveDays) var activeDays

            #expect(firstActiveAt == now.timeIntervalSince1970)
            #expect(activeDays == 1)
        }
    }

    // The first active date is the start of the tenure window, so a later call must not move it -
    // otherwise tenure resets every time the app is opened and nobody is ever eligible.
    @Test
    func recordActiveDay_onALaterDay_keepsTheFirstActiveDate() async {
        let store = UserDefaults.inMemory
        let first = Date(timeIntervalSince1970: 1_600_000_000)

        await record(at: first, store: store)
        await record(at: first.addingTimeInterval(5 * .day), store: store)

        await withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @Shared(.tipAskFirstActiveAt) var firstActiveAt
            #expect(firstActiveAt == first.timeIntervalSince1970)
        }
    }

    // Foregrounding the app six times before lunch is one day of use, not six. The fixture sits at
    // midday UTC deliberately: a timestamp near the UTC midnight boundary would make "+1 hour" a
    // different day and this test would be measuring the fixture rather than the code.
    @Test
    func recordActiveDay_twiceInOneDay_countsOnce() async {
        let store = UserDefaults.inMemory
        let morning = Date(timeIntervalSince1970: 1_600_000_000)

        await record(at: morning, store: store)
        await record(at: morning.addingTimeInterval(60 * 60), store: store)

        #expect(await activeDays(in: store) == 1)
    }

    @Test
    func recordActiveDay_onTheNextDay_countsAgain() async {
        let store = UserDefaults.inMemory
        let day = Date(timeIntervalSince1970: 1_600_000_000)

        await record(at: day, store: store)
        await record(at: day.addingTimeInterval(.day), store: store)

        #expect(await activeDays(in: store) == 2)
    }

    // A clock set backwards, or a flight east across the date line, must not stall the counter
    // forever. Comparing for difference rather than for increase costs at most one extra day counted
    // and cannot wedge it.
    @Test
    func recordActiveDay_afterTheClockGoesBackwards_stillCounts() async {
        let store = UserDefaults.inMemory
        let day = Date(timeIntervalSince1970: 1_600_000_000)

        await record(at: day, store: store)
        await record(at: day.addingTimeInterval(-2 * .day), store: store)

        #expect(await activeDays(in: store) == 2)
    }

    // The count outlives the process that made it, which is the only reason it is in appStorage.
    @Test
    func recordActiveDay_countsAcrossSessions() async {
        let store = UserDefaults.inMemory
        let day = Date(timeIntervalSince1970: 1_600_000_000)

        for offset in 0 ..< 4 {
            await record(at: day.addingTimeInterval(Double(offset) * .day), store: store)
        }

        #expect(await activeDays(in: store) == 4)
    }

    // The flip side of UTC day numbers, asserted so it is a known property rather than a surprise:
    // two activations an hour apart that straddle UTC midnight count as two days. Accepted - over
    // the fifteen days this gate needs, one extra day either way changes nothing, and Calendar
    // would drag time zones and DST into a counter that has no use for either.
    @Test
    func recordActiveDay_straddlingUtcMidnight_countsTwice() async {
        let store = UserDefaults.inMemory
        let beforeMidnight = Date(timeIntervalSince1970: 1_234_567_890)

        await record(at: beforeMidnight, store: store)
        await record(at: beforeMidnight.addingTimeInterval(60 * 60), store: store)

        #expect(await activeDays(in: store) == 2)
    }

    private func record(at now: Date, store: UserDefaults) async {
        await withDependencies {
            $0.date = .constant(now)
            $0.defaultAppStorage = store
        } operation: {
            await TipInvitation.liveValue.recordActiveDay()
        }
    }

    private func activeDays(in store: UserDefaults) async -> Int {
        await withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @Shared(.tipAskActiveDays) var activeDays
            return activeDays
        }
    }
}

private extension TimeInterval {

    static let day: Self = 60 * 60 * 24
}
