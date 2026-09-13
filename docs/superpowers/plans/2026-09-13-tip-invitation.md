# Tip Invitation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Show someone who has used the app for at least 60 days across at least 15 distinct days one
dismissible row inviting them to the tip jar, exactly once, ever.

**Architecture:** All policy lives in a `TipInvitation` dependency client in `Components`, beside the
existing `ReviewPrompt`, so it is pure logic over `appStorage` and fully unit-testable. The banner is a
store-less view in `Components`. `DocumentsFeature` renders it and emits a delegate action;
`MainReducer` turns that into a tab switch plus a push of the already-existing
`SettingListReducer.Path.tipList`. No module gains a dependency, and in particular `DocumentsFeature`
must never import `TipsFeature`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-dependencies
(`@DependencyClient`), swift-sharing (`@Shared(.appStorage)`), Swift Testing, swift-snapshot-testing,
Tuist.

**Spec:** `docs/superpowers/specs/2026-09-13-tip-invitation-design.md`

## Global Constraints

- **Comments are `//` only.** Never `///`, never `/** ... */`, even in a file that already has some
  (AGENTS.md). Comment only where a reader would otherwise stop and wonder why the code is as it is.
- **`DocumentsFeature` must not import `TipsFeature`**, and no new edge may be added to
  `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`. If a task seems to need one, the task is
  wrong — stop and report.
- **`SNAPSHOT_RECORD` stays `isEnabled: false`** in
  `Tuist/ProjectDescriptionHelpers/Extensions/Dictionary+Extensions.swift`. Never commit it as `true`.
  A snapshot test with **no existing reference** records one on its first run and fails, then passes on
  the second run — nothing needs enabling. **Look at the recorded PNG before trusting it.**
- **Every new string key exists in both `en` and `de`**, with `"extractionState": "manual"`, matching
  the catalogue's existing entry shape.
- **Test suites that touch dependencies need `@Suite(.dependencies())`.** A bare `@Suite` leaks
  dependency state between suites and makes tests pass in a full run but fail in isolation.
- **Storage tests set `$0.defaultAppStorage = .inMemory`** and, where time matters,
  `$0.date = .constant(...)`. Never let a test read the real `UserDefaults`.
- **Tips unlock nothing.** `tip-ask-settled` must be written identically whether the user tipped or
  dismissed. The app must not be able to tell which happened.
- **Run a module's tests with** `mise exec -- tuist test <Module> -d "iPhone 17 Pro" --no-selective-testing`.
  **`--no-selective-testing` is mandatory.** Without it, Tuist's remote cache can decide nothing
  changed and print *"The scheme <Module>'s test action has no tests to run, finishing early"* —
  then exit 0 having run **zero** tests, which is indistinguishable from success. **Always confirm
  the output names the tests that actually ran**; an exit code is not evidence.
  Do **not** add `--no-binary-cache`: it conflicts with already-cached DerivedData and fails the
  build outright (`no such file or directory: ... UIKitNavigationShim.framework`). It is only
  usable after clearing DerivedData, which no task here needs.
- **Lint with** `mise run ci:lint` before each commit.

---

### Task 1: Share `appStorage` between the app and the share extension

Closes a latent storage gap: nothing points `defaultAppStorage` at the app group, so each process
reads its own `UserDefaults.standard`.

**Corrected after this branch shipped.** This task was originally justified as fixing a live bug —
that `ReviewPrompt`'s counters were split across the app and the share extension. That was wrong:
`DocumentImportReducer`, the only caller of `.requestReview(.documentImported)`, never runs in the
extension (`ShareViewController` instantiates `ShareExtensionReducer`), and the reducer's own
comment says so. The review keys were never written from the extension. The change is still worth
making — it puts the storage right before anything starts relying on it — but it fixes nothing that
was broken. The spec carries the corrected reasoning.

**Files:**
- Create: `Modules/ApiInterface/Shared/UserDefaults+AppGroup.swift`
- Create: `Modules/ApiInterfaceTests/Shared/UserDefaultsAppGroupTests.swift`
- Modify: `Modules/App/LessPaperApp.swift`
- Modify: `Modules/ShareExtension/ShareViewController.swift`
- Modify: `docs/ideas.md` — remove the "`appStorage` does not use the app group" section

**Interfaces:**
- Consumes: `AppGroup.identifier` from `Modules/ApiInterface/Shared/AppGroup.swift`, which is
  `"group.com.plunien.app.Paperless"`.
- Produces: `UserDefaults.appGroup: UserDefaults` — the group suite, falling back to `.standard`.

- [ ] **Step 1: Write the failing test**

`Modules/ApiInterfaceTests/Shared/UserDefaultsAppGroupTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct UserDefaultsAppGroupTests {

    // The whole point of the accessor is that two separately opened handles land on the same
    // backing store, which is what makes the app and the share extension agree. Asserting on
    // instance identity would not do: Foundation never documents that UserDefaults(suiteName:)
    // returns a cached instance, so == could fail for a correct implementation. A round trip
    // across two handles proves the store, not the pointer.
    @Test
    func appGroup_isReadableThroughASeparatelyOpenedHandle() throws {
        let key = "app-group-round-trip-\(UUID().uuidString)"
        let other = try #require(UserDefaults(suiteName: AppGroup.identifier))

        UserDefaults.appGroup.set(7, forKey: key)
        defer { UserDefaults.appGroup.removeObject(forKey: key) }

        #expect(other.integer(forKey: key) == 7)
    }

    // The fallback is deliberate rather than a bug, but it must never be what a developer machine
    // silently gets, because it is indistinguishable from working.
    @Test
    func appGroup_isNotTheStandardSuite() {
        let key = "app-group-isolation-\(UUID().uuidString)"

        UserDefaults.appGroup.set(7, forKey: key)
        defer { UserDefaults.appGroup.removeObject(forKey: key) }

        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL to compile — `type 'UserDefaults' has no member 'appGroup'`.

- [ ] **Step 3: Add the accessor**

`Modules/ApiInterface/Shared/UserDefaults+AppGroup.swift`:

```swift
import Foundation

public extension UserDefaults {

    // The suite both the app and the share extension read, so a key written by either is seen by
    // both. Falling back to `standard` rather than trapping:
    // a missing app group entitlement is a build configuration problem, and degrading to the old
    // per-process behaviour beats crashing on launch over something that only gates a prompt.
    static let appGroup = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, 2 tests. If `appGroup_isNotTheStandardSuite` fails, the app group entitlement
is missing from the test host and `.appGroup` fell back to `.standard` — fix the entitlement
rather than the test.

- [ ] **Step 5: Point the app at the group suite**

In `Modules/App/LessPaperApp.swift`, `init()` becomes — note the new block goes **first**, so the
`#if DEBUG` blocks keep overriding it with `.inMemory`:

```swift
    init() {
        // Before the DEBUG overrides below, which replace this with an in-memory store: the app
        // and the extension would otherwise each read their own UserDefaults.standard.
        prepareDependencies {
            $0.defaultAppStorage = .appGroup
        }
        #if DEBUG
        if let configuration = UITestConfiguration.fromEnvironment() {
            prepareUITestDependencies(configuration)
        }
        if let configuration = SnapshotConfiguration.fromEnvironment() {
            prepareSnapshotDependencies(configuration)
        }
        #endif
        Self.store.send(.bootstrap)
    }
```

- [ ] **Step 6: Point the share extension at the group suite**

In `Modules/ShareExtension/ShareViewController.swift`, extend the existing `prepareDependencies`:

```swift
        prepareDependencies {
            $0.defaultAppStorage = .appGroup
            $0.popupPresentationController = self
        }
```

Add `import ApiInterface` if it is not already present.

- [ ] **Step 7: Remove the now-closed idea**

Delete the whole `## `appStorage` does not use the app group` section from `docs/ideas.md`, including
its trailing `---` separator, leaving the surrounding entries and their separators intact.

- [ ] **Step 8: Build both targets and run the suite**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing` and `mise run ci:lint`

Expected: PASS, clean lint. If `tuist` reports a missing file, run `mise exec -- tuist generate` —
a newly created source file needs the project regenerated.

- [ ] **Step 9: Commit**

```bash
git add Modules/ApiInterface/Shared/UserDefaults+AppGroup.swift \
        Modules/ApiInterfaceTests/Shared/UserDefaultsAppGroupTests.swift \
        Modules/App/LessPaperApp.swift \
        Modules/ShareExtension/ShareViewController.swift \
        docs/ideas.md
git commit -m "fix: share appStorage between the app and the share extension"
```

---

### Task 2: Count distinct active days

The habit half of the gate. Pure storage logic, no UI.

**Files:**
- Create: `Modules/Components/Review/TipInvitation.swift`
- Create: `Modules/Components/Review/TipInvitation+Live.swift`
- Create: `Modules/ComponentsTests/Review/TipInvitationTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `TipInvitation` — `@DependencyClient` with `recordActiveDay: @Sendable () async -> Void`,
    `isEligible: @Sendable () async -> Bool = { false }`, `settle: @Sendable () async -> Void`.
    `isEligible` and `settle` are declared now but left unimplemented until Task 3.
  - `DependencyValues.tipInvitation: TipInvitation`
  - `SharedReaderKey` keys `.tipAskFirstActiveAt` (`Double?`), `.tipAskActiveDays` (`Int`, default 0),
    `.tipAskLastActiveDay` (`Int?`), `.tipAskSettled` (`Bool`, default false).

- [ ] **Step 1: Write the failing tests**

`Modules/ComponentsTests/Review/TipInvitationTests.swift`:

```swift
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
        let now = Date(timeIntervalSince1970: 1_234_567_890)

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
        let first = Date(timeIntervalSince1970: 1_234_567_890)

        await record(at: first, store: store)
        await record(at: first.addingTimeInterval(5 * .day), store: store)

        await withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @Shared(.tipAskFirstActiveAt) var firstActiveAt
            #expect(firstActiveAt == first.timeIntervalSince1970)
        }
    }

    // Foregrounding the app six times before lunch is one day of use, not six.
    @Test
    func recordActiveDay_twiceInOneDay_countsOnce() async {
        let store = UserDefaults.inMemory
        let morning = Date(timeIntervalSince1970: 1_234_567_890)

        await record(at: morning, store: store)
        await record(at: morning.addingTimeInterval(60 * 60), store: store)

        #expect(await activeDays(in: store) == 1)
    }

    @Test
    func recordActiveDay_onTheNextDay_countsAgain() async {
        let store = UserDefaults.inMemory
        let day = Date(timeIntervalSince1970: 1_234_567_890)

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
        let day = Date(timeIntervalSince1970: 1_234_567_890)

        await record(at: day, store: store)
        await record(at: day.addingTimeInterval(-2 * .day), store: store)

        #expect(await activeDays(in: store) == 2)
    }

    // The count outlives the process that made it, which is the only reason it is in appStorage.
    @Test
    func recordActiveDay_countsAcrossSessions() async {
        let store = UserDefaults.inMemory
        let day = Date(timeIntervalSince1970: 1_234_567_890)

        for offset in 0 ..< 4 {
            await record(at: day.addingTimeInterval(Double(offset) * .day), store: store)
        }

        #expect(await activeDays(in: store) == 4)
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
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `mise exec -- tuist test Components -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL to compile — `cannot find 'TipInvitation' in scope`.

- [ ] **Step 3: Add the client**

`Modules/Components/Review/TipInvitation.swift`:

```swift
import Dependencies
import DependenciesMacros

@DependencyClient
public struct TipInvitation: Sendable {

    // Called on every foreground. Counts at most one day per day.
    public var recordActiveDay: @Sendable () async -> Void

    // Whether the invitation should be on screen right now.
    public var isEligible: @Sendable () async -> Bool = { false }

    // Answered, by either route. Nothing ever unsets this.
    public var settle: @Sendable () async -> Void
}

extension TipInvitation: TestDependencyKey {

    // No-ops rather than the usual unimplemented closures, for the reason ReviewPrompt gives: this
    // hangs off the document list, which a great many tests render for reasons that have nothing to
    // do with tips. The tests that care override these.
    public static let previewValue = Self(
        recordActiveDay: {},
        isEligible: { false },
        settle: {}
    )

    public static let testValue = Self(
        recordActiveDay: {},
        isEligible: { false },
        settle: {}
    )
}

public extension DependencyValues {

    var tipInvitation: TipInvitation {
        get { self[TipInvitation.self] }
        set { self[TipInvitation.self] = newValue }
    }
}
```

- [ ] **Step 4: Add the live counting and the keys**

`Modules/Components/Review/TipInvitation+Live.swift`:

```swift
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
```

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `mise exec -- tuist test Components -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, 6 new tests. Run `mise exec -- tuist generate` first if `tuist` cannot see the new
files.

- [ ] **Step 6: Commit**

```bash
git add Modules/Components/Review/TipInvitation.swift \
        Modules/Components/Review/TipInvitation+Live.swift \
        Modules/ComponentsTests/Review/TipInvitationTests.swift
git commit -m "feat: count the distinct days the app was used"
```

---

### Task 3: Decide when the invitation is eligible

The gate itself: tenure, habit, the permanent settle flag, and standing down near a review prompt.

**Files:**
- Modify: `Modules/Components/Review/TipInvitation+Live.swift`
- Modify: `Modules/ComponentsTests/Review/TipInvitationTests.swift`

**Interfaces:**
- Consumes: the keys and `recordActiveDay` from Task 2; `.reviewRequestedAt` from
  `Modules/Components/Review/ReviewPrompt+Live.swift` (already internal to `Components` — its
  extension carries no access modifier, so **no change is needed there**).
- Produces: working `TipInvitation.isEligible()` and `TipInvitation.settle()`.

- [ ] **Step 1: Write the failing tests**

Append to `TipInvitationTests.swift`, inside the suite:

```swift
    // 60 days of tenure and 15 distinct days of use. Both, because tenure alone asks someone who
    // installed the app in March and opened it twice, and use alone asks someone four days into an
    // enthusiastic migration.
    @Test
    func isEligible_withEnoughTenureAndUse_isTrue() async {
        let store = await seed(activeDays: 15, tenure: 60, store: .inMemory)

        #expect(await isEligible(store: store, tenure: 60) == true)
    }

    @Test
    func isEligible_oneDayShortOfTheTenure_isFalse() async {
        let store = await seed(activeDays: 15, tenure: 59, store: .inMemory)

        #expect(await isEligible(store: store, tenure: 59) == false)
    }

    @Test
    func isEligible_oneDayShortOfTheActiveDays_isFalse() async {
        let store = await seed(activeDays: 14, tenure: 60, store: .inMemory)

        #expect(await isEligible(store: store, tenure: 60) == false)
    }

    // Nothing ever unsets this. Dismissed and tipped are the same outcome here, deliberately: the
    // app must not be able to tell which happened.
    @Test
    func isEligible_afterSettling_isFalseForever() async {
        let store = await seed(activeDays: 99, tenure: 999, store: .inMemory)

        await withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            await TipInvitation.liveValue.settle()
        }

        #expect(await isEligible(store: store, tenure: 999) == false)
    }

    // The review prompt has a real budget and is never delayed for this; the invitation stands down
    // instead. Two different asks in one fortnight is nagging however carefully each was gated.
    @Test
    func isEligible_withinAFortnightOfAReviewPrompt_isFalse() async {
        let store = await seed(activeDays: 15, tenure: 60, store: .inMemory, reviewAskedDaysAgo: 13)

        #expect(await isEligible(store: store, tenure: 60) == false)
    }

    @Test
    func isEligible_aFortnightAfterAReviewPrompt_isTrue() async {
        let store = await seed(activeDays: 15, tenure: 60, store: .inMemory, reviewAskedDaysAgo: 14)

        #expect(await isEligible(store: store, tenure: 60) == true)
    }

    // A fresh install: no first-active date at all, because recordActiveDay has not run yet.
    @Test
    func isEligible_beforeTheFirstActivation_isFalse() async {
        #expect(await isEligible(store: .inMemory, tenure: 0) == false)
    }

    // `now` is pinned to the same instant the helpers below used, so "tenure" means exactly the
    // number of days asked for.
    private static let now = Date(timeIntervalSince1970: 1_600_000_000)

    private func seed(
        activeDays: Int,
        tenure: Double,
        store: UserDefaults,
        reviewAskedDaysAgo: Double? = nil
    ) async -> UserDefaults {
        await withDependencies {
            $0.defaultAppStorage = store
        } operation: {
            @Shared(.tipAskFirstActiveAt) var firstActiveAt
            @Shared(.tipAskActiveDays) var days
            @Shared(.reviewRequestedAt) var reviewRequestedAt

            $firstActiveAt.withLock {
                $0 = Self.now.addingTimeInterval(-tenure * .day).timeIntervalSince1970
            }
            $days.withLock { $0 = activeDays }
            if let reviewAskedDaysAgo {
                $reviewRequestedAt.withLock {
                    $0 = Self.now.addingTimeInterval(-reviewAskedDaysAgo * .day).timeIntervalSince1970
                }
            }
        }
        return store
    }

    private func isEligible(store: UserDefaults, tenure: Double) async -> Bool {
        await withDependencies {
            $0.date = .constant(Self.now)
            $0.defaultAppStorage = store
        } operation: {
            await TipInvitation.liveValue.isEligible()
        }
    }
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `mise exec -- tuist test Components -d "iPhone 17 Pro" --no-selective-testing`

Expected: the seven new tests FAIL — `isEligible` is still the `{ false }` stub, so the two that
expect `true` fail, and `settle()` writes nothing.

Note which fail. `isEligible_oneDayShortOfTheTenure_isFalse` and its siblings will pass for the wrong
reason at this point; that is expected and Step 4 re-runs them against the real implementation.

- [ ] **Step 3: Implement the gate**

In `Modules/Components/Review/TipInvitation+Live.swift`, replace the `liveValue` stubs and add the
constants and the two functions:

```swift
extension TipInvitation: DependencyKey {

    public static let liveValue = Self(
        recordActiveDay: recordActiveDay,
        isEligible: isEligible,
        settle: settle
    )
}

private extension TipInvitation {

    // Two months, so "a while" means a stretch of calendar rather than a burst of activity.
    static let tenureBeforeAsking: TimeInterval = 60 * 24 * 60 * 60

    // Distinct days the app was opened. Fifteen cannot happen in under fifteen days, which is what
    // stops one enthusiastic week of migrating paperwork from reading as a habit.
    static let activeDaysBeforeAsking = 15

    // The review prompt has a real budget and must never be delayed for this, so this stands down
    // instead. Two different asks in one fortnight is nagging however carefully each was gated.
    static let separationFromReviewAsk: TimeInterval = 14 * 24 * 60 * 60

    static func isEligible() async -> Bool {
        @Dependency(\.date.now)
        var now

        @Shared(.tipAskSettled)
        var settled

        @Shared(.tipAskFirstActiveAt)
        var firstActiveAt

        @Shared(.tipAskActiveDays)
        var activeDays

        @Shared(.reviewRequestedAt)
        var reviewRequestedAt

        guard !settled else {
            return false
        }

        guard let firstActiveAt,
              now.timeIntervalSince1970 - firstActiveAt >= tenureBeforeAsking,
              activeDays >= activeDaysBeforeAsking
        else {
            return false
        }

        if let reviewRequestedAt,
           now.timeIntervalSince1970 - reviewRequestedAt < separationFromReviewAsk {
            return false
        }

        return true
    }

    static func settle() async {
        @Shared(.tipAskSettled)
        var settled

        $settled.withLock { $0 = true }
    }
}
```

- [ ] **Step 4: Run the tests and confirm they pass**

Run: `mise exec -- tuist test Components -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, 13 tests in `TipInvitationTests`.

- [ ] **Step 5: Prove the boundary tests are not vacuous**

Temporarily change `activeDaysBeforeAsking` to `14` and re-run.

Expected: `isEligible_oneDayShortOfTheActiveDays_isFalse` FAILS. Then change
`tenureBeforeAsking` to `59 * 24 * 60 * 60` and re-run: `isEligible_oneDayShortOfTheTenure_isFalse`
FAILS. Restore both values and confirm all 13 pass again.

This step exists because a boundary test that would pass against the wrong constant proves nothing,
and these three constants are the whole feature.

- [ ] **Step 6: Commit**

```bash
git add Modules/Components/Review/TipInvitation+Live.swift \
        Modules/ComponentsTests/Review/TipInvitationTests.swift
git commit -m "feat: decide when someone has used the app long enough to ask"
```

---

### Task 4: The invitation row

**Files:**
- Create: `Modules/Components/Review/TipInvitationBanner.swift`
- Modify: `Modules/Components/Resources/Localizable.xcstrings`
- Create: `Modules/ComponentsTests/Review/TipInvitationBannerTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks — this view has no store and knows nothing about tips.
- Produces: `TipInvitationBanner(tapped: @escaping () -> Void, dismissed: @escaping () -> Void)`, and
  the keys `tipInvitationTitle`, `tipInvitationMessage`, `tipInvitationDismiss`.

- [ ] **Step 1: Add the strings**

Add three entries to `Modules/Components/Resources/Localizable.xcstrings`, keeping the file's keys in
alphabetical order and matching the existing entry shape exactly:

```json
    "tipInvitationDismiss" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Ausblenden"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Dismiss"
          }
        }
      }
    },
    "tipInvitationMessage" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Less Paper ist kostenlos und bleibt es. Es gibt ein Trinkgeldglas, falls dir danach ist – es schaltet nichts frei."
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Less Paper is free and stays free. There is a tip jar if you ever feel like it — it unlocks nothing."
          }
        }
      }
    },
    "tipInvitationTitle" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Du sortierst hier schon eine Weile"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "You have been filing things here a while"
          }
        }
      }
    },
```

The "it unlocks nothing" clause is load-bearing twice over — it is the honest framing and it is the
App Review defence that a tip buys no functionality. Do not drop it.

- [ ] **Step 2: Write the failing snapshot test**

`Modules/ComponentsTests/Review/TipInvitationBannerTests.swift`:

```swift
@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TipInvitationBannerTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: banner(),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_darkMode() async throws {
        assertSnapshot(
            of: banner(),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }

    // The message is the longest string in the module, and a row that truncates or clips its own
    // decline wording is worse than no row. German is longer still but cannot be snapshotted - no
    // unit snapshot test here renders another locale - so the largest text size stands in for it.
    @Test
    func testSnapshot_accessibilityLarge() async throws {
        assertSnapshot(
            of: banner(),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(preferredContentSizeCategory: .accessibilityLarge)
            )
        )
    }

    private func banner() -> some View {
        TipInvitationBanner(tapped: {}, dismissed: {})
            .padding(.x3)
            .background(Color.m3SurfaceContainerLowest)
    }
}
```

- [ ] **Step 3: Run the test and confirm it fails**

Run: `mise exec -- tuist test Components -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL to compile — `cannot find 'TipInvitationBanner' in scope`.

- [ ] **Step 4: Implement the row**

`Modules/Components/Review/TipInvitationBanner.swift`:

```swift
import DesignTokens
import SwiftUI

// Drawn as the same card DocumentRowView draws, because "a list row rather than a banner" only
// means anything if it is indistinguishable from the rows around it. The call site supplies the
// `.padding(.x3)` and the clear listRowBackground that the document lists give every row.
public struct TipInvitationBanner: View {

    public var body: some View {
        HStack(alignment: .top, spacing: .x4) {
            Image(systemName: "cup.and.saucer")
                .foregroundStyle(Color.m3OnSurface)

            VStack(alignment: .leading, spacing: .x2) {
                Text(.tipInvitationTitle)
                    .font(.body)
                    .foregroundStyle(Color.m3OnSurface)

                Text(.tipInvitationMessage)
                    .font(.subheadline)
                    .foregroundStyle(Color.m3Outline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                dismissed()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(Color.m3Outline)
            }
            .accessibilityLabel(.tipInvitationDismiss)
            .buttonStyle(.borderless)
        }
        .padding(.x4)
        .frame(maxWidth: .infinity)
        .background(Color.m3SurfaceContainer)
        .contentShape(Rectangle())
        .onTapGesture { tapped() }
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
    }

    public init(
        tapped: @escaping () -> Void,
        dismissed: @escaping () -> Void
    ) {
        self.tapped = tapped
        self.dismissed = dismissed
    }

    private let tapped: () -> Void
    private let dismissed: () -> Void
}
```

- [ ] **Step 5: Run the test twice and inspect what was recorded**

Run: `mise exec -- tuist test Components -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — swift-snapshot-testing writes three new references and fails on the first run
because none existed. Run it again: PASS.

**Then open all three PNGs under `Snapshots/ComponentsTests/TipInvitationBannerTests/` and look at
them.** A reference records whatever the code produced, bug included. Check specifically: the message
is fully visible and not truncated; the card's stroke and corner radius match a document row; the
close button is reachable and not overlapping the text at `accessibilityLarge`.

- [ ] **Step 6: Confirm `SNAPSHOT_RECORD` was never touched**

Run: `git diff --stat Tuist/`

Expected: empty. If `Dictionary+Extensions.swift` appears, revert it — `isEnabled` must stay `false`.

- [ ] **Step 7: Commit**

```bash
git add Modules/Components/Review/TipInvitationBanner.swift \
        Modules/Components/Resources/Localizable.xcstrings \
        Modules/ComponentsTests/Review/TipInvitationBannerTests.swift \
        Snapshots/ComponentsTests/TipInvitationBannerTests
git commit -m "feat: a tip invitation row that reads like a document row"
```

---

### Task 5: Wire the invitation into the document list reducer

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`
- Create: `Modules/DocumentsFeatureTests/DocumentList/DocumentListTipInvitationTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.tipInvitation)` — `isEligible()` and `settle()` from Tasks 2 and 3.
- Produces:
  - `DocumentListReducer.State.isTipInvitationVisible: Bool` (defaults to `false`)
  - `DocumentListReducer.Action.tipInvitationEligible(Bool)`
  - `DocumentListReducer.Action.View.tipInvitationTapped`, `.tipInvitationDismissed`
  - `DocumentListReducer.Action.Delegate.tipInvitationTapped`
  - `Effect.runCheckTipInvitation()`, `Effect.runSettleTipInvitation()`

- [ ] **Step 1: Write the failing tests**

`Modules/DocumentsFeatureTests/DocumentList/DocumentListTipInvitationTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentListTipInvitationTests {

    @Test
    func onAppear_whenEligible_showsTheInvitation() async {
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.isEligible = { true }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.tipInvitationEligible) {
            $0.isTipInvitationVisible = true
        }
    }

    @Test
    func onAppear_whenNotEligible_showsNothing() async {
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.isEligible = { false }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.tipInvitationEligible)

        #expect(store.state.isTipInvitationVisible == false)
    }

    // Tapping it is an answer, so it settles. The delegate is what MainReducer turns into a tab
    // switch - this reducer deliberately does not know where the tip jar lives.
    @Test
    func tipInvitationTapped_settlesAndDelegates() async {
        let settled = LockIsolated(0)
        let state = DocumentListReducer.State.testValue(isLoaded: true)
        let store = TestStore(initialState: state) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.settle = { settled.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off
        await store.send(.set(\.isTipInvitationVisible, true))

        await store.send(.view(.tipInvitationTapped)) {
            $0.isTipInvitationVisible = false
        }
        await store.receive(\.delegate.tipInvitationTapped)

        #expect(settled.value == 1)
    }

    // Dismissing settles identically to tipping. The app must not be able to tell which happened.
    @Test
    func tipInvitationDismissed_settlesAndEmitsNoDelegate() async {
        let settled = LockIsolated(0)
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.settle = { settled.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off
        await store.send(.set(\.isTipInvitationVisible, true))

        await store.send(.view(.tipInvitationDismissed)) {
            $0.isTipInvitationVisible = false
        }

        #expect(settled.value == 1)
    }

    // The eligibility check must survive onAppear's early return for an already-populated list,
    // which is the ordinary way this screen is revisited.
    @Test
    func onAppear_withDocumentsAlreadyLoaded_stillChecks() async {
        let asked = LockIsolated(0)
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(isLoaded: true)
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.tipInvitation.isEligible = { asked.withValue { $0 += 1 }; return true }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.receive(\.tipInvitationEligible)

        #expect(asked.value == 1)
    }
}
```

- [ ] **Step 2: Run the tests and confirm they fail**

Run: `mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL to compile — `isTipInvitationVisible` and `tipInvitationEligible` do not exist.

- [ ] **Step 3: Add the state, the actions and the effects**

In `DocumentListReducer.swift`, add to `Action`, keeping the existing alphabetical order:

```swift
        case tipInvitationEligible(Bool)
```

to `Action.Delegate`:

```swift
            case tipInvitationTapped
```

and to `Action.View`, after `toggleSelectionModeButtonTapped`:

```swift
            case tipInvitationDismissed
            case tipInvitationTapped
```

In `State`, beside the other flags:

```swift
        var isTipInvitationVisible = false
```

In `DocumentListReducer+Effect.swift`:

```swift
    static func runCheckTipInvitation() -> Self {
        @Dependency(\.tipInvitation.isEligible)
        var isEligible

        return .run { send in
            await send(.tipInvitationEligible(isEligible()), animation: .default)
        }
    }

    static func runSettleTipInvitation() -> Self {
        @Dependency(\.tipInvitation.settle)
        var settle

        return .run { _ in
            await settle()
        }
    }
```

- [ ] **Step 4: Handle the actions**

In the reducer's `switch`, add a case beside the other internal actions:

```swift
            case let .tipInvitationEligible(isEligible):
                state.isTipInvitationVisible = isEligible
                return .none
```

In the `.view` switch, beside the other view actions:

```swift
                case .tipInvitationDismissed:
                    state.isTipInvitationVisible = false
                    return .runSettleTipInvitation()
                case .tipInvitationTapped:
                    state.isTipInvitationVisible = false
                    return .runSettleTipInvitation()
                        .merge(with: .send(.delegate(.tipInvitationTapped)))
```

In `case .onAppear`, the check must run **before** the `guard state.documents.isEmpty` early return,
so revisiting a populated list still checks. Merge it into each of the three return paths the same way
`refreshFailedFileTaskCount` already is:

```swift
                case .onAppear:
                    // Refreshed on every appearance, not just the branches below that fetch: the
                    // failed-imports badge has to catch up when a document was sent in while the
                    // inbox was already loaded, which is the ordinary way this screen gets revisited.
                    // Inbox only - DocumentListView shares this reducer and renders no badge, and on
                    // a v9 server reading the count is a full unpaginated GET /api/tasks/.
                    let refreshFailedFileTaskCount: Effect<Action> = state.filter.isInbox
                        ? .runRefreshFailedFileTaskCount(server: state.server)
                        : .none
                    // Checked on every appearance too, and for the same reason: the gate can turn
                    // eligible between one visit and the next, and the usual visit finds the list
                    // already populated and returns below.
                    let onEveryAppearance = refreshFailedFileTaskCount
                        .merge(with: .runCheckTipInvitation())
                    guard state.documents.isEmpty else {
                        return onEveryAppearance
                    }
                    state.error = nil
                    state.rebuildInboxFilterIfNeeded()
                    guard !state.isInboxWithoutInboxTags else {
                        state.clearForEmptyInbox()
                        return onEveryAppearance
                    }
                    return .merge(
                        .runGetDocuments(
                            filterRules: state.filter.input.filterRules,
                            server: state.server,
                            sortDirection: state.filter.input.sort.direction,
                            sortField: state.filter.input.sort.field
                        ),
                        onEveryAppearance
                    )
```

Note: `case .onRefresh, .reloadButtonTapped` is **not** changed. A pull-to-refresh is about documents,
and re-checking there would let the row appear under the user's thumb mid-gesture.

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, 5 new tests, and every pre-existing `DocumentsFeature` test still passing —
`isTipInvitationVisible` defaults to `false` and `tipInvitation.testValue.isEligible` returns `false`,
so nothing else changes behaviour.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListTipInvitationTests.swift
git commit -m "feat: let the document list offer the tip invitation"
```

---

### Task 6: Render the row in both lists

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListView.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/InboxView.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentList/InboxViewTests.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentList/DocumentListViewTests.swift`

**Interfaces:**
- Consumes: `TipInvitationBanner` from Task 4; `isTipInvitationVisible` and the two view actions from
  Task 5.
- Produces: nothing later tasks depend on.

- [ ] **Step 1: Write the failing snapshot tests**

Add to `Modules/DocumentsFeatureTests/DocumentList/InboxViewTests.swift`:

```swift
    // The invitation is the only thing in the app that mentions the tip jar outside Settings, and it
    // has to read as one more card in the stack rather than a panel bolted above it.
    @Test
    func testSnapshot_withTipInvitation() async throws {
        var state = DocumentListReducer.State.testValue()
        state.isTipInvitationVisible = true

        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: state,
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_withTipInvitationDarkMode() async throws {
        var state = DocumentListReducer.State.testValue()
        state.isTipInvitationVisible = true

        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: state,
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }
```

Add the same `testSnapshot_withTipInvitation` (light mode only — dark is covered once above, and the
two views share every style decision) to the existing
`Modules/DocumentsFeatureTests/DocumentList/DocumentListViewTests.swift`, constructing
`DocumentListView` instead of `InboxView` and following that file's established fixture style.

- [ ] **Step 2: Run and confirm it fails**

Run: `mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: references are written for the new tests and they fail on the first run, but the recorded
images show **no banner** — the views do not render it yet. Delete the references just recorded so the
next run records the real thing:

```bash
rm -f Snapshots/DocumentsFeatureTests/InboxViewTests/testSnapshot_withTipInvitation*.png \
      Snapshots/DocumentsFeatureTests/DocumentListViewTests/testSnapshot_withTipInvitation*.png
```

- [ ] **Step 3: Render it in both views**

In both `DocumentListView.swift` and `InboxView.swift`, as the **first** element inside `List { }`,
above the `ForEach`:

```swift
                if store.isTipInvitationVisible {
                    TipInvitationBanner(
                        tapped: { send(.tipInvitationTapped) },
                        dismissed: { send(.tipInvitationDismissed) }
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.x3)
                }
```

The four modifiers are exactly what every document row in these lists already carries — the banner is
not styled specially, it is styled identically.

- [ ] **Step 4: Run twice, then inspect**

Run: `mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing` — first run records and fails,
second run passes.

**Open the three new PNGs.** Check: the banner sits above the first document; its card is
indistinguishable in stroke, radius and fill from the document card below it; the message is not
truncated; the existing references (`testSnapshot`, `testSnapshot_darkMode`,
`testSnapshot_withFailedFileTasks`, `testSnapshot_emptyResultDarkMode`,
`testSnapshot_withoutViewPaperlessTaskPermission`) are **unchanged**.

- [ ] **Step 5: Confirm no unrelated snapshot moved**

Run: `git status --short Snapshots/`

Expected: only the new `testSnapshot_withTipInvitation*` files appear, as additions. Any modified
existing reference means something rendered that should not have — investigate rather than commit it.

- [ ] **Step 6: Commit**

```bash
git add Modules/DocumentsFeature/DocumentList/DocumentListView.swift \
        Modules/DocumentsFeature/DocumentList/InboxView.swift \
        Modules/DocumentsFeatureTests/DocumentList \
        Snapshots/DocumentsFeatureTests
git commit -m "feat: show the tip invitation above the inbox and document list"
```

---

### Task 7: Open the tip list from outside Settings

**Files:**
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift`
- Create: `Modules/SettingsFeatureTests/SettingList/SettingListOpenTipListTests.swift`

**Interfaces:**
- Consumes: `SettingListReducer.Path.tipList(TipListReducer)`, which already exists.
- Produces: `SettingListReducer.Action.openTipList` — sets `state.path` to exactly
  `[.tipList(TipListReducer.State())]`.

- [ ] **Step 1: Write the failing tests**

`Modules/SettingsFeatureTests/SettingList/SettingListOpenTipListTests.swift`:

```swift
@testable import SettingsFeature

import ApiInterface
import ComposableArchitecture
import Testing
import TestSupport
import TipsFeature

@MainActor
@Suite(
    .dependencies()
)
struct SettingListOpenTipListTests {

    @Test
    func openTipList_pushesTheTipList() async {
        let store = TestStore(
            initialState: SettingListReducer.State(server: .testValue())
        ) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.openTipList)

        #expect(store.state.path.count == 1)
        #expect(store.state.path.first?.tipList != nil)
    }

    // Replaced rather than appended. The invitation is once-ever, so its one job beyond the ask is
    // to leave the user at a place whose Back button reveals the Settings row the tip jar lives
    // behind - and appending onto an already-deep stack buries exactly that.
    @Test
    func openTipList_fromADeepStack_replacesIt() async {
        var state = SettingListReducer.State(server: .testValue())
        state.path.append(.licenseList(LicenseListReducer.State()))
        state.path.append(.tagList(TagListReducer.State(server: .testValue())))

        let store = TestStore(initialState: state) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.openTipList)

        #expect(store.state.path.count == 1)
        #expect(store.state.path.first?.tipList != nil)
    }
}
```

Both initialisers are verified against the tree: `LicenseListReducer.State()` takes no arguments and
`TagListReducer.State(server:)` takes a `Server`. `SettingsFeatureTests` already links both modules.

- [ ] **Step 2: Run and confirm it fails**

Run: `mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL to compile — `type 'SettingListReducer.Action' has no member 'openTipList'`.

- [ ] **Step 3: Add the action**

In `SettingListReducer.swift`, add to `Action`:

```swift
        case openTipList
```

and handle it in the reducer's `switch`:

```swift
            case .openTipList:
                // Replaced rather than appended: someone three levels deep in Settings must still
                // land on the tip list with Back going to the root, where the Tips row is.
                state.path = [.tipList(TipListReducer.State())]
                return .none
```

- [ ] **Step 4: Run and confirm it passes**

Run: `mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, 2 new tests.

- [ ] **Step 5: Commit**

```bash
git add Modules/SettingsFeature/SettingList/SettingListReducer.swift \
        Modules/SettingsFeatureTests/SettingList/SettingListOpenTipListTests.swift
git commit -m "feat: let the tip list be opened from outside Settings"
```

---

### Task 8: Count activations and route the tap

The last wiring, and the task that makes the feature actually start working: without the
`recordActiveDay` call nothing ever becomes eligible.

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift`
- Modify: `Modules/AppFeature/AppReducer+Effect.swift`
- Modify: `Modules/AppFeature/MainReducer.swift`
- Create: `Modules/AppFeatureTests/AppReducerTipInvitationTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.tipInvitation.recordActiveDay)` from Task 2;
  `DocumentListReducer.Action.Delegate.tipInvitationTapped` from Task 5;
  `SettingListReducer.Action.openTipList` from Task 7.
- Produces: nothing — this is the top of the graph.

- [ ] **Step 1: Write the failing tests**

`Modules/AppFeatureTests/AppReducerTipInvitationTests.swift`:

```swift
@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import DocumentsFeature
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct AppReducerTipInvitationTests {

    // Every foreground counts, including one with no server selected: someone between servers is
    // still using the app, and didBecomeActive's server guard would otherwise swallow the count.
    @Test
    func didBecomeActive_withoutAServer_stillRecordsTheDay() async {
        let recorded = LockIsolated(0)
        let store = TestStore(initialState: AppReducer.State()) {
            AppReducer()
        } withDependencies: {
            $0.tipInvitation.recordActiveDay = { recorded.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off

        await store.send(.didBecomeActive).finish()

        #expect(recorded.value == 1)
    }

    @Test
    func didBecomeActive_withAServer_recordsTheDay() async {
        let recorded = LockIsolated(0)
        let store = TestStore(
            initialState: AppReducer.State(main: .testValue())
        ) {
            AppReducer()
        } withDependencies: {
            $0.tipInvitation.recordActiveDay = { recorded.withValue { $0 += 1 } }
        }
        store.exhaustivity = .off

        await store.send(.didBecomeActive).finish()

        #expect(recorded.value == 1)
    }

    // The inbox and the document list run the same reducer, so both have to route.
    @Test
    func tipInvitationTapped_fromTheInbox_opensTheTipList() async {
        let store = TestStore(
            initialState: AppReducer.State(main: .testValue(selectedTab: .inbox))
        ) {
            AppReducer()
        }
        store.exhaustivity = .off

        await store.send(.main(.inbox(.delegate(.tipInvitationTapped))))

        #expect(store.state.main?.selectedTab == .settings)
        #expect(store.state.main?.settingList.path.count == 1)
    }

    @Test
    func tipInvitationTapped_fromTheDocumentList_opensTheTipList() async {
        let store = TestStore(
            initialState: AppReducer.State(main: .testValue(selectedTab: .documents))
        ) {
            AppReducer()
        }
        store.exhaustivity = .off

        await store.send(.main(.documentList(.delegate(.tipInvitationTapped))))

        #expect(store.state.main?.selectedTab == .settings)
        #expect(store.state.main?.settingList.path.count == 1)
    }
}
```

- [ ] **Step 2: Run and confirm it fails**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — the two routing tests find `selectedTab` unchanged, and the two recording tests find
`recorded.value == 0`.

- [ ] **Step 3: Record the active day**

In `Modules/AppFeature/AppReducer+Effect.swift`:

```swift
    static func runRecordActiveDay() -> Self {
        @Dependency(\.tipInvitation.recordActiveDay)
        var recordActiveDay

        return .run { _ in
            await recordActiveDay()
        }
    }
```

In `AppReducer.swift`, `case .didBecomeActive` becomes — note the record happens **before** the
server guard:

```swift
            case .didBecomeActive:
                // Before the guard below: someone between servers is still using the app, and the
                // day they did it still counts.
                let recordActiveDay = Effect<Action>.runRecordActiveDay()
                guard let server = state.main?.server else {
                    return recordActiveDay
                }
                return recordActiveDay
                    .merge(with: .runRefreshStatistics(server: server))
                    .merge(with: .runRefreshFavorites(server: server))
                    .merge(with: .runRefreshPermissions(server: server))
```

- [ ] **Step 4: Route the tap**

In `Modules/AppFeature/MainReducer.swift`, beside the existing cross-child routing:

```swift
            case .documentList(.delegate(.tipInvitationTapped)),
                 .inbox(.delegate(.tipInvitationTapped)):
                state.selectedTab = .settings
                return .send(.settingList(.openTipList))
```

- [ ] **Step 5: Run and confirm it passes**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, 4 new tests, and every pre-existing `AppFeature` test still green — in particular
`AppReducerTests`' `didBecomeActive` coverage, which now sees one extra effect.

- [ ] **Step 6: Run every affected module**

```bash
mise exec -- tuist test Components -d "iPhone 17 Pro"
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"
mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro"
mise exec -- tuist test AppFeature -d "iPhone 17 Pro"
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro"
mise run ci:lint
```

Expected: all green.

- [ ] **Step 7: Confirm no new module dependency was added**

```bash
git diff Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift
```

Expected: **empty**. If `DocumentsFeature` gained `.target(.tipsFeature)`, the implementation took the
wrong route — the banner must stay store-less in `Components` and the routing must stay in
`MainReducer`.

- [ ] **Step 8: Commit**

```bash
git add Modules/AppFeature/AppReducer.swift \
        Modules/AppFeature/AppReducer+Effect.swift \
        Modules/AppFeature/MainReducer.swift \
        Modules/AppFeatureTests/AppReducerTipInvitationTests.swift
git commit -m "feat: count activations and route the invitation to the tip list"
```

---

## Manual verification

Neither of these can be automated, and both are named in the spec as the limits of what the tests
prove.

- [ ] **The app group suite really is shared.** Install the app and the share extension on a device.
  Share a document in through the extension, then open the app and confirm from Diagnostics or a
  debugger that `UserDefaults.appGroup` holds the same `review-import-count` the extension wrote. A
  wrong or missing entitlement falls back to `.standard` silently, which looks exactly like success
  and is today's bug.
- [ ] **The invitation looks right on a real device.** Temporarily lower `tenureBeforeAsking` and
  `activeDaysBeforeAsking` to `0`, run on a device, confirm the row renders correctly in light and
  dark, that tapping lands on the tip list with Back going to the Settings root, that the close button
  removes it, and that after either it never returns. **Restore both constants before committing.**
- [ ] **Tapping ✕ must NOT open the tip jar.** Check this on its own, deliberately, because it is the
  one defect no automated test in this plan can catch and the worst one for this feature: the card
  carries an `onTapGesture` that navigates, and the dismiss `Button` sits inside it. Standard SwiftUI
  hit-testing gives the `Button` priority within its own bounds, and `.buttonStyle(.borderless)` is
  what keeps a button independently tappable inside a `List` row — but this is the first place in
  this codebase where a `Button` sits inside a visibly tap-gestured container, so the precedent is
  reasoned rather than observed. Tap the ✕ and confirm the row disappears **and the Settings tab does
  not open**. If it navigates, the fix is to move the navigation off the container's `onTapGesture`
  and onto its own `Button` wrapping only the icon-and-text region. The chevron added in the final
  fix wave now sits directly beside the ✕, so aim for the ✕ deliberately rather than near it — and
  if the two feel crowded on a real device, widen the gap; a mis-tap here is the failure this check
  exists for.
