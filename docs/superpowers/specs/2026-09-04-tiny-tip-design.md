# A fourth tip: `tip.tiny`

Add a €1 rung below the existing ladder, so the smallest way to say thank you is not €5.

## Context

[Tips](2026-08-29-tips-design.md) shipped a consumable tip jar: three products — small, medium and
large — reached from Settings, backed by StoreKit 2, unlocking nothing. The design deliberately
named ranks rather than amounts, so repricing would not turn a product id into a lie.

The ladder starts at €5. That is a lot for a reflex. Someone who wants to acknowledge the app
without deciding what it is worth to them has no cheap option, and the gap between "nothing" and
"€5" is where most of that intent is lost. A €1 rung costs one enum case.

The product `com.aptumtek.app.Paperless.tip.tiny` already exists in App Store Connect. This work is
the app side only.

The existing shape makes this small, and it is worth saying why, because it is what keeps the change
honest:

- `Tip` is a `String` enum whose raw values *are* the App Store Connect product ids.
- `Tip.allCases` is both the list handed to `Product.products(for:)` and the on-screen order, so
  position in the enum is position on screen. There is no second ordering to keep in sync.
- Display names and prices come from StoreKit at runtime, never from the app's own strings. No
  localization key names a tip, and none is needed for a new one.
- `AppReducer.runTipObserver` forwards whatever `Tip` the transaction yields without enumerating
  cases.

So the app does not have a place where "the tips" are listed a second time. Adding one is adding a
case.

## Decisions

**`tiny` is the first case, not the last.** `Tip.allCases` drives the rendered order and the ladder
reads smallest first. Appending would put the cheapest option at the bottom, under €25, which is
the opposite of the reason for adding it: the rung exists to be the easy first step, and it should
be the first thing seen.

**The name is a rank, matching the three that exist.** `tiny` continues small/medium/large rather
than naming an amount. The original design's reasoning holds unchanged — a product id can never be
renamed or reused once the product exists, so `tip.1` would become false the moment the price moved.
It is also the id already created in App Store Connect, which settles it regardless.

**€1.00 in the local StoreKit configuration.** `Tuist/Tips.storekit` is for the simulator and for
tests; the real price is App Store Connect's. The local value matches the intended tier so that what
a developer sees locally is what a user sees, and so the recorded snapshot shows a realistic ladder.

**The fixtures gain the tiny tip, and the snapshots are re-recorded.** `TipJar.previewValue` and the
view and reducer test fixtures currently hardcode three products. Leaving them at three would mean
previews and snapshot tests showing a ladder the app no longer has, and nothing covering the
four-row layout. The cost is re-recording the snapshots that render the list.

**Nothing is added to guard against the product being absent.** `TipJar+Live.products` builds its
result with `compactMap` over what StoreKit returns, so a product that does not resolve is simply
not shown and the other rows still work. That behaviour already exists and already covers this case;
adding a check would be a second mechanism for a state the first one handles.

## Changes

### `Modules/TipsFeature/TipList/Tip.swift`

One case, first:

```swift
    case tiny = "com.aptumtek.app.Paperless.tip.tiny"
```

The type's comment opens "The three tips, in the order they are shown" and becomes four. The rest of
that comment — why the cases name a rank rather than an amount — is still exactly right and stays.

### `Tuist/Tips.storekit`

A fourth `Consumable`, first in the `products` array to match the enum:

| field | value |
|---|---|
| `productID` | `com.aptumtek.app.Paperless.tip.tiny` |
| `displayPrice` | `1.00` |
| `internalID` | `A1000004` |
| `referenceName` / `displayName` | `Tiny tip` |
| `description` | `Supports development. Unlocks nothing.` |
| `type` | `Consumable` |
| `familyShareable` | `false` |

`internalID` continues the file's own `A1000001`–`A1000003` sequence. It is local to the StoreKit
configuration file and unrelated to App Store Connect.

### Fixtures

`TipProduct(displayName: "Tiny tip", displayPrice: "€1.00", tip: .tiny)` goes first in each list
that enumerates products:

- `Modules/TipsFeature/TipList/TipJar.swift` — `previewValue`
- `Modules/TipsFeatureTests/TipList/TipListViewTests.swift` — the shared `products` fixture

`Modules/TipsFeatureTests/TipList/TipListReducerTests.swift` is **left alone**. Its
`onAppear_loadsTheProducts` builds a local two-product array, which is already fewer than the three
that shipped: it asserts that whatever the client returns reaches the state, and two is enough to
show that. Growing it to four would imply the reducer knows something about the ladder, which it
does not. The other reducer tests name individual cases (`.small`, `.medium`) as arbitrary
representatives of "a tip" and are equally unaffected.

### Tests

`Modules/TipsFeatureTests/TipList/TipTests.swift`, both existing tests:

```swift
        #expect(Tip.tiny.rawValue == "com.aptumtek.app.Paperless.tip.tiny")
```

```swift
        #expect(Tip.allCases == [.tiny, .small, .medium, .large])
```

The first of those is the one that matters. Its comment already says why: App Store Connect will not
let a product id be renamed or reused, so a typo is an id abandoned permanently. The string is
written once and checked against the id created in App Store Connect character by character.

### Snapshots

`Snapshots/TipsFeatureTests/TipListViewTests/` holds four references. `testSnapshot_loaded` and
`testSnapshot_purchasing` render the product list and must be re-recorded. `testSnapshot_loading`
and `testSnapshot_unavailable` render a spinner and an empty state respectively and must **not**
change — if either does, something rendered that should not have, and that is worth understanding
rather than re-recording.

## Testing

`mise exec -- tuist test TipsFeature -d "iPhone 17 Pro"` and `mise run ci:lint`.

The four-row ladder is covered by the re-recorded `testSnapshot_loaded`. The product id is covered by
`TipTests`. Nothing else needs a new test: no branch is added, no state is introduced, and the
purchase path does not vary by tip — `TipListReducerTests` already exercises tapping a row, a failed
purchase, a pending purchase and a cancelled one, and none of those cases is per-product.

Worth stating plainly, because it is the limit of what the automated tests prove: they show the app
asks StoreKit for four ids and renders whatever comes back. That the fourth id resolves to a real,
purchasable product is a fact about App Store Connect, and only a sandbox purchase confirms it.

## Out of scope

- **Repricing the existing three.** The ladder becomes 1 / 5 / 10 / 25. Whether €25 is still the
  right ceiling once there is a €1 floor is a product question, not this change.
- **A custom amount.** StoreKit consumables are fixed-price products; an arbitrary amount means a
  different mechanism entirely.
- **Recording or displaying what a user has tipped.** The original design deliberately kept tips
  stateless — they unlock nothing and nothing remembers them. A fourth product does not revisit that.
- **Localizing "Tiny tip".** The name shown in the app comes from StoreKit, which serves it in the
  user's own locale from App Store Connect. The string in `Tips.storekit` is only what the simulator
  shows.

## Risks

**The product id is unforgiving.** A typo cannot be corrected — the id is abandoned and a new one
must be created. Mitigated by `TipTests` asserting the exact string, and by the id in this document,
the enum, the StoreKit file and App Store Connect being compared against each other rather than
retyped.

**A €1 tier may lower average revenue** if people who would have tipped €5 now tip €1. That is a
real possibility and this design does not attempt to model it; the counter-argument is that the
gap this fills is between zero and five, not between one and five. Stated here so it is a choice
rather than an oversight.
