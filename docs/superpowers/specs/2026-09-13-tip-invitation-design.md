# A tip invitation for long-time users

Invite people who have actually stuck with the app to the tip jar, exactly once, in a way that
cannot nag.

## Context

Two pieces of this already exist, and most of the restraint this feature needs is already built.

[Tips](2026-08-29-tips-design.md) shipped a consumable tip jar — four rungs after
[`tip.tiny`](2026-09-04-tiny-tip-design.md) — reached from a row in Settings, unlocking nothing.
`Components/Review/ReviewPrompt` shipped the review ask: it records two moments, the third document
import and any tip, and asks StoreKit for the rating prompt behind a single 120-day cooldown shared
by both. That cooldown sits well inside iOS's silent three-per-year cap, and
`AppStoreReviewRequester` refuses to spend it when there is no foreground scene to show a prompt in.
Settings also carries a "Rate the app" row that opens the App Store write-review URL directly,
specifically so tapping it cannot spend the StoreKit budget.

What is missing is not restraint. It is that **the tip jar is undiscoverable.** It is a row in
Settings, below Licenses, and nothing in the app ever mentions it. Someone who has filed documents
here for six months has no reason to know it exists.

**This reverses a decision.** The tips design put it under Out of scope, in these words: *"Tips
anywhere but Settings. No prompts after a successful scan, no banners. A tip jar that chases you is
worse than no tip jar."* That reasoning is correct and is not abandoned here — it is the constraint
this design is built around. What changes is the conclusion that the only safe number of mentions is
zero. One mention, to someone who has used the app for months, which never returns once answered, is
not a tip jar that chases you. The mechanism below is shaped entirely by making that sentence true.

The review ask is **not** retuned. Three imports as the trigger, and the 120-day cooldown, stay
exactly as they are.

### A bug found while designing this

`ReviewPrompt` reads `review-import-count` and `review-requested-at` through `@Shared(.appStorage)`,
and **nothing points `defaultAppStorage` at the app group** in either shipping target — only the
snapshot and UI-test bootstraps set it, and they set `.inMemory`. An app extension has its own
`UserDefaults.standard`, and `DocumentImportReducer` — which fires `.requestReview(.documentImported)`
— runs in the share extension as well as in the app.

So today there are two counters and two cooldown ledgers. The import count is split, which makes the
three-import threshold take longer to reach than intended; worse, **the cooldown is not shared**, so
the share extension can ask for a review and the app can ask again days later, each reading its own
`review-requested-at`. That is the precise failure mode this feature exists to avoid, in the code
that is already shipping.

`docs/ideas.md` records the app-group gap under "`appStorage` does not use the app group" but calls
it "currently latent rather than broken", naming `inboxDocumentCount` as the only key affected. That
is wrong: the review keys are written from both processes today. This design fixes it and that entry
is removed.

## Decisions

**One ask, once, ever.** A `tip-ask-settled` flag is set permanently the first time the invitation is
either tapped or dismissed, and nothing ever clears it. Not "once per version", not "again in a
year". This is the decision every other decision here serves, and it is what makes the reversal above
defensible: the worst case for any individual user is that they saw one list row once.

**Eligibility is tenure and habit together, and habit is measured in distinct active days rather than
imports.** Import count is the wrong signal: plenty of people use this app mostly to *find* things,
and a tip gate built on imports would never reach them. Distinct days on which the app was brought to
the foreground catches every kind of user, and has a property the import count lacks — it cannot be
tripped by one heavy week, because fifteen distinct days cannot occur in fewer than fifteen days.

The gate is `daysSinceFirstActive >= 60` **and** `activeDays >= 15`. Tenure alone would ask someone
who installed the app in March and opened it twice; habit alone would ask someone four days into an
enthusiastic migration. Both together describe someone for whom this app has become part of how they
deal with paper.

**The invitation never lands within 14 days of a review prompt.** `ReviewPrompt` has no idea the
banner exists and the banner cannot ask it, so the banner reads `review-requested-at` and stands
down inside that window. Two different asks in the same fortnight is the thing that would read as
nagging regardless of how carefully each one was gated, and the asymmetry is deliberate: the review
prompt is the one that must not be delayed, because it is the one with a real budget to spend.

**It is a list row, not a banner.** It renders with `m3SurfaceContainer` like every other row, body
text, no accent colour, no icon treatment that reads as promotional. It never covers content, never
animates in, and never requires a tap to get rid of — it simply sits at the top of the list until the
user does something about it. This is why the design is a row rather than the modal popup the
`PopupPresenter` would have made easy: a modal, even once, is an interruption, and the stated priority
is that nobody is annoyed.

**The copy's job is to be easy to decline.** It says the app is free and stays free, and that tips
change nothing — both true, and the combination is what stops the row feeling like a demand. No
"support development!", no guilt, no mention of what the money is for.

**Tapping it switches to the Settings tab and pushes the tip list there, rather than presenting a
sheet.** Three reasons, the last being decisive:

- `TipListView` keeps a single presentation shape. A sheet would need a `NavigationStack` wrapper, a
  `SheetCloseButton`, and a second set of snapshot references, for a screen that already works as a
  pushed destination.
- `MainReducer` already does exactly this: it owns `selectedTab` and already routes delegate actions
  between children, and `AppReducer.applyPendingLink` already sets a tab and then sends into the
  child it just revealed. This is the established shape for "go there", not a new mechanism.
- **It teaches the route.** The invitation is once-ever, so after it is answered the only way back to
  the tip jar is Settings → Tips. Landing the user *there*, with Back going to the Settings root where
  the Tips row is visible, means the one ask leaves behind knowledge of where the tip jar lives. A
  sheet would leave nothing, and for an ask that never returns that is the difference between opening
  a door and pointing at one.

**The settings stack is replaced, not appended to.** Someone three levels deep in Settings must still
land on the tip list with Back going to the Settings root. Appending would bury the route the
previous decision exists to teach.

**No new module dependency.** This was the trap: `DocumentsFeature` → `TipsFeature` would drag
StoreKit into `DocumentsFeature` and into `DocumentsFeatureTests`, and into everything that links
them — precisely the coupling the tips design created a separate module to prevent ("`SettingsFeature`
imports every other feature and is linked by their test targets; StoreKit does not belong in that
hub"). Instead the work is split so that every module involved already depends on what it needs:

- `Components` holds the row and the eligibility client. It knows nothing about tips or StoreKit.
- `DocumentsFeature` renders the row and emits a delegate action. It already imports `Components`.
- `MainReducer` routes that delegate to the settings tab. It already imports both sides.
- `SettingsFeature` gains one public action and appends to its own path. `TipListReducer` is already
  a case of `SettingListReducer.Path`.

The StoreKit surface does not move.

**The eligibility client lives beside `ReviewPrompt` in `Components`, and is shaped like it.** Same
`@DependencyClient` pattern, same `liveValue`-holds-the-policy split, same no-op `testValue` so that
features which merely touch the path do not have to stub it. It is also what lets the 14-day
separation check read `review-requested-at` without either module reaching into the other's storage.

**`defaultAppStorage` points at the app group suite in both shipping targets, and nothing is
migrated.** `UserDefaults(suiteName: AppGroup.identifier)` in `LessPaperApp.init()` and in
`ShareViewController`, set before the DEBUG snapshot and UI-test blocks so those keep overriding it
with `.inMemory`. Existing `review-import-count` and `review-requested-at` values are left where they
are and re-read as `0` and "never asked".

The cost of not migrating is bounded and one-time: some users become eligible for a review prompt
slightly earlier than their true history warrants, once. The cost of migrating is reading two suites,
deciding how to combine two counts and two timestamps, and keeping that code forever, for a counter
whose only job is to gate one prompt. Not worth it.

**Existing users start from zero, and nobody sees this for 60 days after the update ships.** There is
no first-use date on disk to seed from, and nothing else is a trustworthy proxy — a server added
three years ago says nothing about whether the app was opened since. Inventing a tenure the app
cannot actually observe would be guessing in the direction of asking sooner, which is the wrong
direction for this feature. The delay is accepted.

**Day boundaries are UTC day numbers, and a backwards jump still counts.** The distinct-day counter
stores the last counted day as `Int(timeIntervalSince1970 / 86400)` and increments only when today's
number **differs** from it — `!=`, not `>`. A user who flies east, or sets their clock back, or
crosses a DST boundary then gets at most one extra day counted rather than a counter that stalls
forever, which is the failure that would matter. Local calendars are not used: the cost of a
boundary falling at an odd local hour is nil over a fifteen-day span, and `Calendar` brings time zone
changes and DST into a counter that does not need them.

**Tips still unlock nothing, and nothing records that you tipped.** Unchanged from the tips design,
and restated because this feature adds a flag about *the ask* and it would be easy to mistake that
for a flag about the purchase. `tip-ask-settled` is set identically whether the user tipped €25 or
hit the close button, and deliberately so: the app must not be able to tell.

## Architecture

```
DocumentListView ──renders── TipInvitationBanner          (Components)
       │                            │
       │ .delegate(.tipInvitationTapped)                  (DocumentsFeature)
       ↓
  MainReducer ── selectedTab = .settings                  (AppFeature)
       │       └─ .send(.settingList(.openTipList))
       ↓
  SettingListReducer ── path = [.tipList]                 (SettingsFeature)
       ↓
  TipListView ──► a tip ──► .requestReview(.tipReceived)  (TipsFeature, existing)
```

The last arrow is why the invitation asks only about tips and never about reviews: tipping already
fires the review moment, so the review ask arrives through the path that is already built and already
rationed. One ask, two possible outcomes, and no second place that talks to StoreKit about ratings.

## Changes

### `Modules/Components/Review/TipInvitation.swift` (new)

A `@DependencyClient` modelled on `ReviewPrompt`:

```swift
@DependencyClient
public struct TipInvitation: Sendable {

    // Called on every foreground. Counts at most one day per day.
    public var recordActiveDay: @Sendable () async -> Void

    // Whether the invitation should be on screen right now.
    public var isEligible: @Sendable () async -> Bool = { false }

    // Answered, by either route. Nothing ever unsets this.
    public var settle: @Sendable () async -> Void
}
```

`previewValue` and `testValue` both return `false` and no-op, for the same reason `ReviewPrompt`'s do:
this hangs off the document list, which many tests render for reasons unrelated to tips, and an
`unimplemented` closure would fail them. The snapshot test that wants the row overrides `isEligible`.

### `Modules/Components/Review/TipInvitation+Live.swift` (new)

Holds the whole policy, and the three constants:

```swift
    // Two months, so "a while" means a stretch of calendar rather than a burst of activity.
    static let tenureBeforeAsking: TimeInterval = 60 * 24 * 60 * 60

    // Distinct days the app was opened. Fifteen cannot happen in under fifteen days, which is what
    // stops a single enthusiastic week of migrating paperwork from reading as a habit.
    static let activeDaysBeforeAsking = 15

    // The review prompt has a real budget and must never be delayed for this; this stands down
    // instead. Two different asks in one fortnight is nagging however carefully each was gated.
    static let separationFromReviewAsk: TimeInterval = 14 * 24 * 60 * 60
```

`recordActiveDay()` writes `tip-ask-first-active-at` if absent, then compares today's UTC day number
with `tip-ask-last-active-day` and, when they differ, stores it and increments `tip-ask-active-days`.

`isEligible()` returns `false` unless all of: `tip-ask-settled` is unset; `firstActiveAt` exists and
is at least `tenureBeforeAsking` ago; `activeDays >= activeDaysBeforeAsking`; and either
`reviewRequestedAt` is absent or at least `separationFromReviewAsk` ago.

`settle()` sets `tip-ask-settled`. Four new keys, alongside the existing review ones:

| Key | Type | Default |
|---|---|---|
| `tip-ask-first-active-at` | `Double?` | absent |
| `tip-ask-active-days` | `Int` | `0` |
| `tip-ask-last-active-day` | `Int?` | absent |
| `tip-ask-settled` | `Bool` | `false` |

`reviewRequestedAt` is declared `private` to `ReviewPrompt+Live.swift` today and becomes
`internal` so the new file can read it. Same module, same folder, and the point of putting this
client there was to share that gate.

### `Modules/Components/Review/TipInvitationBanner.swift` (new)

A view with no store and no knowledge of tips: a title, a subtitle, a chevron, a close button, and
`tapped` / `dismissed` closures. Styled as a list row — `m3SurfaceContainer` via `listRowBackground`
at the call site, body font, `m3OnSurface` text, `m3Outline` for the subtitle.

### `Modules/Components/Resources/Localizable.xcstrings`

Three keys, `en` and `de`, `extractionState: manual`, matching the catalogue's existing shape.
Proposed English, with the declinability the decision above calls for:

- `tipInvitationTitle` — "You have been filing things here a while"
- `tipInvitationMessage` — "Less Paper is free and stays free. There is a tip jar if you ever feel
  like it — it unlocks nothing."
- `tipInvitationDismiss` — "Dismiss" (accessibility label for the close button)

### `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`

`State` gains `isTipInvitationVisible: Bool = false`. `Action.Delegate` gains
`tipInvitationTapped`; `Action.View` gains `tipInvitationTapped` and `tipInvitationDismissed`;
a new internal `tipInvitationEligible(Bool)` carries the client's answer back.

`onAppear` additionally runs `isEligible()`. Both view actions set `isTipInvitationVisible = false`
and call `settle()`; the tapped one also returns `.send(.delegate(.tipInvitationTapped))`.

Only the **inbox** and **documents** lists show it — `FavoriteListReducer` is a different reducer and
is untouched. Both inbox and documents run `DocumentListReducer`, so both get it; the row appearing in
whichever of the two the user opens first is correct, and `settle()` removes it from both.

### `Modules/DocumentsFeature/DocumentList/DocumentListView.swift`

The banner as the first row when `store.isTipInvitationVisible`, above the document rows. Top of the
list is the one uncontested spot: `docs/ideas.md` already records that the status capsule can cover
the last row and that the bottom toolbar is full.

### `Modules/AppFeature/MainReducer.swift`

Beside the existing cross-child routing:

```swift
            case .documentList(.delegate(.tipInvitationTapped)),
                 .inbox(.delegate(.tipInvitationTapped)):
                state.selectedTab = .settings
                return .send(.settingList(.openTipList))
```

### `Modules/AppFeature/AppReducer.swift`

`didBecomeActive` gains `recordActiveDay()`. It currently returns early when there is no server —
that guard must not swallow the counter, since someone between servers is still using the app, so the
record runs before it.

### `Modules/SettingsFeature/SettingList/SettingListReducer.swift`

One new public action:

```swift
            case .openTipList:
                state.path = [.tipList(TipListReducer.State())]
                return .none
```

Replacing rather than appending, per the decision above.

### `Modules/App/LessPaperApp.swift` and `Modules/ShareExtension/ShareViewController.swift`

```swift
        prepareDependencies {
            $0.defaultAppStorage = UserDefaults(suiteName: AppGroup.identifier) ?? .standard
        }
```

In `LessPaperApp.init()` this goes **first**, before the `#if DEBUG` UI-test and snapshot blocks, so
those continue to override it with `.inMemory`. In `ShareViewController` it joins the existing
`prepareDependencies` that sets `popupPresentationController`.

The `?? .standard` fallback rather than a force-unwrap: a missing app group entitlement is a build
configuration problem, and falling back to today's behaviour is better than a crash on launch for
something that only gates a prompt.

### `docs/ideas.md`

The "`appStorage` does not use the app group" entry is removed — this closes it.

## Testing

`ComponentsTests` is where the substance is, following `ReviewPromptTests` exactly: `.dependencies()`
on the suite, `$0.defaultAppStorage = .inMemory`, `$0.date = .constant(...)`. Every boundary is a
plain unit test with no simulator involved:

- 59 days of tenure with 15 active days does not ask; 60 days does
- 60 days with 14 active days does not ask; 15 does
- repeated foregrounds on one day count once; the next day counts again
- a backwards clock jump counts a day rather than stalling the counter
- the count and the first-active date survive across processes (the `countsAcrossSessions` pattern)
- a review prompt 13 days ago suppresses it; 14 days ago does not
- `settle()` suppresses it permanently, even with every other condition satisfied

`DocumentsFeatureTests` covers the reducer wiring: an eligible client shows the row, both view
actions hide it and settle, and the tapped one emits the delegate. `AppFeatureTests` covers the
routing — the delegate from each of `documentList` and `inbox` lands on `selectedTab == .settings`
with `settingList.path == [.tipList]`. `SettingsFeatureTests` covers `openTipList` replacing a
non-empty path rather than appending.

Snapshots: the banner in the inbox and in the document list, light and dark, plus German — the
message is long enough to wrap, and German is where it will wrap worst. Existing document list
references must **not** change, since `isTipInvitationVisible` defaults to `false`.

`mise exec -- tuist test Components -d "iPhone 17 Pro"`, the same for `DocumentsFeature`, `AppFeature`
and `SettingsFeature`, and `mise run ci:lint`.

What the tests cannot prove: that the app group suite is actually shared between the two processes at
runtime. That needs the app and the share extension on a device, one import through the extension,
and a check that the count advanced in the app. Worth doing once, because it is the whole point of the
app-group change and a wrong entitlement would fail silently into `.standard`.

## Out of scope

- **Retuning the review ask.** Three imports and 120 days stay. The only change to `ReviewPrompt` is
  that its storage becomes shared, which is a bug fix.
- **Asking for a review in the banner.** Pairing "rate us" with "tip us" in one row invites an App
  Review reading that ratings are being traded for money, and it is unnecessary: a tip already fires
  `.requestReview(.tipReceived)`.
- **A second ask, ever.** No "ask me later", no re-ask after a year, no per-version reset. The flag is
  permanent and that is the feature.
- **Measuring whether it works.** There is no analytics in this app and this does not add any. The
  only signal available is App Store Connect revenue, and that is enough.
- **The invitation anywhere else.** Not on favourites, not in the share extension, not after a
  successful import. One surface.
- **Migrating the existing review counters**, and **seeding tenure from existing data**. Both
  reasoned through in Decisions.
- **Localizing beyond `de`.** The app ships `en` and `de`.

## Risks

**This reverses a documented decision, and the reversal could be wrong.** "A tip jar that chases you
is worse than no tip jar" was right, and the argument here is only that one permanent-dismissal row
is not chasing. If that judgement is wrong the cost is paid by real users and is not recoverable by
an update — they already saw it. The mitigations are the gate, the once-ever flag and the copy; the
honest statement is that this is a judgement call, not a proof.

**App Review may read a tip prompt in the document list differently from a tip row in Settings.**
Tips are permitted, but the guidance is about not implying a purchase improves the app. The copy says
outright that it unlocks nothing, which is the same defence the tip screen itself relies on, and the
row does not block use. Still a new surface in front of a reviewer who did not see it before.

**60 days and 15 active days are guesses.** They are not derived from anything — there is no usage
data to derive them from. They are single constants in one file, and the first real information about
whether they are right will arrive only as revenue, months later.

**The no-migration reset gives some users an early review prompt.** Deliberate and bounded to once
per user, but it is a small regression in a mechanism whose whole purpose is restraint, shipped in
the change that was meant to tighten it.

**A wrong or missing app group entitlement fails silently** into `.standard`, which is exactly
today's broken behaviour and would look like success. Only the on-device check above catches it.

**The banner occupies a list row in a list that is already short on room.** Two known issues in
`docs/ideas.md` touch the document list's vertical space. Top-of-list avoids both, but it does push
the first document down, and on a small device in landscape that is a real cost for as long as the row
is there.

**`recordActiveDay` runs on every foreground, before the server guard.** It is two `UserDefaults`
reads and at most two writes, so the cost is negligible, but it is now on the critical path of every
activation and should stay that cheap.
