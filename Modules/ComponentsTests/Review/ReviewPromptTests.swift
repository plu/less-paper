@testable import Components

import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct ReviewPromptTests {

    // The first couple of imports are someone still finding out whether the app works at all. Only
    // a third says filing things here has become a habit.
    @Test
    func documentImported_beforeTheThirdImport_doesNotAsk() async {
        let asked = LockIsolated(0)

        await withDependencies {
            $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return true }
            $0.defaultAppStorage = .inMemory
        } operation: {
            await ReviewPrompt.liveValue.record(.documentImported)
            await ReviewPrompt.liveValue.record(.documentImported)
        }

        #expect(asked.value == 0)
    }

    @Test
    func documentImported_onTheThirdImport_asks() async {
        let asked = LockIsolated(0)
        let store = UserDefaults.inMemory

        await withDependencies {
            $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return true }
            $0.defaultAppStorage = store
        } operation: {
            await ReviewPrompt.liveValue.record(.documentImported)
            await ReviewPrompt.liveValue.record(.documentImported)
            await ReviewPrompt.liveValue.record(.documentImported)
        }

        #expect(asked.value == 1)
    }

    // The count outlives the process that made it - three imports across three launches are still
    // three imports.
    @Test
    func documentImported_countsAcrossSessions() async {
        let asked = LockIsolated(0)
        let store = UserDefaults.inMemory

        for _ in 1 ... 3 {
            await withDependencies {
                $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return true }
                $0.defaultAppStorage = store
            } operation: {
                await ReviewPrompt.liveValue.record(.documentImported)
            }
        }

        #expect(asked.value == 1)
    }

    // A tip is the strongest signal the app has: someone paid for nothing in return. It needs no
    // run-up.
    @Test
    func tipReceived_asksOnTheFirstOne() async {
        let asked = LockIsolated(0)

        await withDependencies {
            $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return true }
            $0.defaultAppStorage = .inMemory
        } operation: {
            await ReviewPrompt.liveValue.record(.tipReceived)
        }

        #expect(asked.value == 1)
    }

    // The gate is shared, which is the whole point of having one: a tip and a run of imports in the
    // same month must not spend two of the three prompts iOS allows in a year.
    @Test
    func withinTheCooldown_asksOnlyOnce() async {
        let asked = LockIsolated(0)
        let store = UserDefaults.inMemory
        let firstAsk = Date(timeIntervalSince1970: 1234567890)

        await record(.tipReceived, at: firstAsk, store: store, asked: asked)
        await record(.tipReceived, at: firstAsk.addingTimeInterval(119 * .day), store: store, asked: asked)

        #expect(asked.value == 1)
    }

    @Test
    func afterTheCooldown_asksAgain() async {
        let asked = LockIsolated(0)
        let store = UserDefaults.inMemory
        let firstAsk = Date(timeIntervalSince1970: 1234567890)

        await record(.tipReceived, at: firstAsk, store: store, asked: asked)
        await record(.tipReceived, at: firstAsk.addingTimeInterval(121 * .day), store: store, asked: asked)

        #expect(asked.value == 2)
    }

    // The app can go to the background while the prompt waits for its moment to settle, and
    // StoreKit then has no scene to show anything in. Spending four months of cooldown on a prompt
    // nobody saw is the one failure this gate cannot afford.
    @Test
    func whenTheRequestNeverReachesTheScreen_theCooldownIsNotSpent() async {
        let asked = LockIsolated(0)
        let store = UserDefaults.inMemory

        await withDependencies {
            $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return false }
            $0.defaultAppStorage = store
        } operation: {
            await ReviewPrompt.liveValue.record(.tipReceived)
        }

        await withDependencies {
            $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return true }
            $0.defaultAppStorage = store
        } operation: {
            await ReviewPrompt.liveValue.record(.tipReceived)
        }

        #expect(asked.value == 2)
    }

    private func record(
        _ moment: ReviewMoment,
        at now: Date,
        store: UserDefaults,
        asked: LockIsolated<Int>
    ) async {
        await withDependencies {
            $0.appStoreReviewRequester.request = { asked.withValue { $0 += 1 }; return true }
            $0.date = .constant(now)
            $0.defaultAppStorage = store
        } operation: {
            await ReviewPrompt.liveValue.record(moment)
        }
    }
}

private extension TimeInterval {

    static let day: Self = 60 * 60 * 24
}
