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
- `Tip.allCases` is both the list handed to `Product.products(for:)` and the on-screen order.
- Display names and prices come from StoreKit at runtime, never from the app's own strings. No
  localization key names a tip, and none is needed for a new one.
- `AppReducer.runTipObserver` forwards whatever `Tip` the transaction yields without enumerating
  cases.

So the app does not have a place where "the tips" are listed a second time. Adding one is adding a
case.

**One thing that came up while designing this, and widened it slightly.** The list looks
price-sorted, but it is not: `TipJar+Live.products` orders by `Tip.allCases`, and the ascending
prices are a coincidence of the enum being declared small-first and App Store Connect happening to
agree. Nothing enforces the agreement, and `TipProduct` carries `displayPrice` as a preformatted
string — there is no number to sort on.

That has been fine for three fixed rungs. It is worth fixing now rather than later because App Store
prices are per-storefront: Apple's tiers usually preserve relative order, but a custom price in one
storefront can invert two rungs for those users while every other storefront looks right — a bug
that would never reproduce locally. Adding a fourth rung is the moment the ladder stops being three
hardcoded values and starts being a list, so this design sorts by the price actually charged.

## Decisions

**The list is sorted by the price actually charged.** `TipProduct` gains `price: Decimal` — StoreKit's
`Product.price`, the number behind the `displayPrice` string — and `TipJar+Live.products` sorts
ascending on it. What a user sees can then never disagree with what they are charged, in any
storefront, without anyone having to remember to keep an enum in step with App Store Connect.

**Ties break on `Tip.allCases` order.** Swift's `sorted(by:)` is not a stable sort, so two products
at the same price could otherwise swap between launches — a list that reshuffles while you look at
it. Two rungs priced the same is not a state worth supporting, but it is a state that can happen
transiently while a price change propagates, and "sometimes reorders itself" is a much worse
symptom than "shows two rows in a fixed order".

**`tiny` is still the first case.** It no longer decides the display order, but it is the tie-break,
and the declaration order is now documentation of intended rank rather than a mechanism. Declaring
it last while calling it the smallest would be a lie waiting to be read.

**Currencies are not mixed.** Every product in one `Product.products(for:)` answer comes from the
same storefront and so shares a currency, which is what makes comparing the `Decimal`s meaningful.
Comparing prices across storefronts would be nonsense, and the app never has two storefronts at once.

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

The type's comment opens "The three tips, in the order they are shown" — the count becomes four, and
"in the order they are shown" goes, because they are now shown in price order. What the declaration
order still does is break ties and record intent. The rest of that comment — why the cases name a
rank rather than an amount — is still exactly right and stays.

### `Modules/TipsFeature/TipList/TipJar.swift`

`TipProduct` gains a stored `price: Decimal` and a matching initialiser parameter. It sits beside
`displayPrice`, which stays: the string is what the row renders, formatted by StoreKit for the
user's locale and currency, and reconstructing it from the `Decimal` would mean reimplementing that
formatting badly.

### `Modules/TipsFeature/TipList/TipJar+Live.swift`

`products()` keeps building from `Tip.allCases` — that is the fetch list and the tie-break — and
gains the price and the sort:

```swift
        return Tip.allCases
            .compactMap { tip -> TipProduct? in
                guard let product = products.first(where: { $0.id == tip.rawValue }) else {
                    return nil
                }

                return TipProduct(
                    displayName: product.displayName,
                    displayPrice: product.displayPrice,
                    price: product.price,
                    tip: tip
                )
            }
            .sorted { left, right in
                guard left.price == right.price else {
                    return left.price < right.price
                }
                return Tip.allCases.firstIndex(of: left.tip)! < Tip.allCases.firstIndex(of: right.tip)!
            }
```

The existing comment above the method says "Ordered by `Tip.allCases` rather than by what StoreKit
returns: the ladder is the point, and StoreKit promises no order." That is now wrong in its first
clause and right in its second, and is rewritten to say the list is ordered by price, that StoreKit
promises no order of its own, and that `allCases` breaks ties so the order cannot wobble.

The force-unwrapped `firstIndex(of:)` is safe by construction — `left.tip` and `right.tip` came from
iterating `Tip.allCases` a few lines above — but a `compactMap`-shaped alternative that avoids the
`!` is acceptable if the implementer prefers one; the requirement is a total, deterministic order,
not a particular spelling.

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

Every `TipProduct(...)` in the codebase gains a `price:`, since the initialiser changed. The tiny tip
— `TipProduct(displayName: "Tiny tip", displayPrice: "€1.00", price: 1, tip: .tiny)` — goes first in
each list that enumerates the ladder:

- `Modules/TipsFeature/TipList/TipJar.swift` — `previewValue`
- `Modules/TipsFeatureTests/TipList/TipListViewTests.swift` — the shared `products` fixture

`Modules/TipsFeatureTests/TipList/TipListReducerTests.swift` keeps its **two-product** fixture — it
gains the `price:` argument the initialiser now requires, and nothing else. That test asserts what
the client returns reaches the state, not what the ladder contains, and two is enough to show it.
Growing it to four would imply the reducer knows about the ladder, which it does not. The other
reducer tests name individual cases (`.small`, `.medium`) as arbitrary representatives of "a tip"
and are unaffected beyond the same mechanical argument.

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

The second test's name, `casesAreOrderedSmallestFirst`, and its comment, "The order is the ladder
shown on screen", both become inaccurate once price decides the display. The test still earns its
place — declaration order is the tie-break and the record of intent — so it stays, renamed
`casesAreDeclaredSmallestFirst`, with a comment saying it is the tie-break and the intended rank
rather than the rendered order.

`TipJar+Live`'s new sort needs its own coverage, and it is the only genuinely new behaviour here:

- products returned by StoreKit in a scrambled order come back ascending by price
- two products at the same price come back in `Tip.allCases` order, and do so on repeated calls
- a product missing from StoreKit's answer is still dropped rather than faked

These test `products()` against a stubbed StoreKit rather than the live one. If the existing test
setup cannot stub `Product.products(for:)` — StoreKit's type is not injectable and the module has no
seam for it today — then the sort is extracted to a small internal function over `[TipProduct]` that
can be tested directly, and `products()` calls it. Prefer the seam that already exists; do not build
a StoreKit abstraction for this.

### Snapshots

`Snapshots/TipsFeatureTests/TipListViewTests/` holds four references. `testSnapshot_loaded` and
`testSnapshot_purchasing` render the product list and must be re-recorded. `testSnapshot_loading`
and `testSnapshot_unavailable` render a spinner and an empty state respectively and must **not**
change — if either does, something rendered that should not have, and that is worth understanding
rather than re-recording.

## Testing

`mise exec -- tuist test TipsFeature -d "iPhone 17 Pro"` and `mise run ci:lint`.

The four-row ladder is covered by the re-recorded `testSnapshot_loaded`, the product id by
`TipTests`, and the ordering by the sort tests above. The purchase path needs nothing new: it does
not vary by tip, and `TipListReducerTests` already exercises tapping a row, a failed purchase, a
pending purchase and a cancelled one, none of which is per-product.

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

**Sorting by price is a scope increase over "add a tip",** taken deliberately after the question was
raised, and it touches a type (`TipProduct`) that the reducer and the view both use. The blast
radius is one initialiser and one sort, both inside `TipsFeature`, and the alternative — leaving a
list that only looks sorted — is a bug that reproduces in one storefront and nowhere else. If it
turns out to want more than that, it should become its own change rather than growing this one.
