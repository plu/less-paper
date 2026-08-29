# Tips

Let someone who likes the app leave a tip, from Settings, and get nothing for it but thanks.

## Context

The app is free and has never sold anything: there is no StoreKit anywhere in it, no paid feature,
and no notion of a purchase. This adds one screen and the machinery behind it, and changes nothing
else about how the app behaves.

**A tip is a consumable, and that is the decision everything else follows from.** Consumables never
appear in `Transaction.currentEntitlements`, cannot be restored, and are finished the moment they
are delivered. A tip jar therefore needs no entitlement store, no restore button, and no persisted
state at all.

**`~/toe-ios` is a shipped StoreKit 2 implementation, and half of it applies.** What transfers:
fetching with `Product.products(for:)` from an enum of product ids, keeping a `Transaction.updates`
listener alive for the whole app lifetime, and distinguishing `.pending` (Ask to Buy) from
`.userCancelled` rather than treating both as failure. What does not: `currentEntitlements`,
`purchasedProducts`, `isPurchased` — that is machinery for permanent unlocks, which is a different
product type rather than a different taste. Its swallowed errors (`// AppLogger.shared.error(…)`,
commented out) and its `ObservableObject` shape do not fit a codebase with a Diagnostics log and TCA.

**App Store Connect can be driven by API, up to a point.** The `ALTOOL_*` key in fnox authenticates
and reads the app back, so the products, their localizations and their prices can be created from a
script. Three things cannot: accepting the **Paid Apps agreement** (account holder, web UI, and no
in-app purchase can exist until it is done), uploading each product's **review screenshot**, and
**submitting** the products for review alongside an app version.

## Decisions

**Tips unlock nothing, and nothing in the app knows whether you tipped.** No entitlement, no badge,
no persisted flag. Apple permits tips as long as they buy no functionality, and a tip that unlocked
something would be a purchase with a friendlier name. This is what deletes most of the code a
StoreKit feature usually needs.

**Three products, at €5, €10 and €25**, with ids `com.aptumtek.app.Paperless.tip.small`, `.medium`
and `.large`. The names in the store are neutral — "Small tip" rather than "Coffee" — because a US
storefront shows dollars and a name that promises a coffee-sized amount reads oddly at another
price. The row shows StoreKit's `displayPrice`, never a number the app formats itself.

**Product ids are permanent.** App Store Connect will not let an id be renamed or reused, so
`.small`/`.medium`/`.large` are deliberately about rank rather than amount: repricing later leaves
them true.

**`TipsFeature` is its own module.** `SettingsFeature` imports every other feature and is linked by
their test targets; StoreKit does not belong in that hub. The module holds the products, the client,
the reducer and the view, the same shape as `LicensesFeature`.

**A `TipJar` dependency client wraps StoreKit.** The reducer sees `[Tip]` and a small result enum,
never a `Product` or a `VerificationResult`, so its tests stub outcomes rather than a store. It is
also the seam that makes the screen renderable in snapshot tests, where StoreKit would otherwise
answer with nothing.

**The transaction listener lives in `AppReducer.bootstrap`, not on the screen.** An Ask to Buy
approval can arrive days after the sheet was dismissed, with the app anywhere, and an unfinished
transaction is redelivered on every launch until something finishes it. It sits beside the
certificate-approval and forward-auth observers, which are there for the same reason.

**Every transaction is finished, verified or not.** An unverified one is finished, logged to
Diagnostics and reported; leaving it open would mean StoreKit hands it back forever, and there is
nothing to protect anyway — a tip grants nothing that a forged transaction could steal.

**A tip jar that fails to load says so.** If `Product.products(for:)` returns nothing — no network,
StoreKit unavailable, products not yet approved — the screen shows a message and a retry rather than
an empty list, which reads as a broken screen.

**The store setup is a throwaway script, not a mise task.** It runs once. A committed task for
something nobody will run again is something to keep working for no reason. What is committed is the
record — ids, prices, localized names and descriptions, and the manual steps — because the ids are
permanent and unguessable a year later.

## Architecture

```
TipsFeature      Tip, TipJar, TipListReducer, TipListView   — the products, the client, the screen
SettingsFeature  one row, one Path case                     — how it is reached
AppFeature       the Transaction.updates observer           — finishing what arrives late
```

### `TipsFeature`

`Tip` is an enum over the three products: its `rawValue` is the product id, `allCases` is the fetch
list and the display order. It carries no price — that comes from StoreKit.

`TipJar` is a `@DependencyClient` with three closures:

```swift
var products: @Sendable () async throws -> [TipProduct]
var purchase: @Sendable (_ tip: Tip) async throws -> TipPurchaseResult
var updates: @Sendable () -> AsyncStream<Tip>
```

`TipProduct` is `(tip: Tip, displayName: String, displayPrice: String)` — what the row needs and
nothing more. `TipPurchaseResult` is `.success`, `.pending`, `.cancelled`, `.unverified`. The stream
yields a `Tip` only after the client has finished that transaction, so nothing outside the client
has to remember to. The live implementation is the only thing in the app that imports StoreKit.

`TipListReducer` loads on appear, holds `products`, `purchasingTip` and a `loadFailed` flag, and maps
each purchase result to its outcome: success and unverified both finish the transaction inside the
client, and differ only in what the user is told.

`TipListView` shows a short explanation, then one row per product with its name and price. The row
being bought shows a spinner and the others disable while a purchase is in flight.

### `SettingsFeature`

One `NavigationLink` in the last section, beside GitHub, Diagnostics and Licenses, and one
`Path.tipList` case. Nothing else changes.

### `AppFeature`

`AppReducer.bootstrap` gains a third observer effect, consuming `TipJar.updates()` and finishing each
transaction. A transaction arriving this way raises the same thank-you the screen does, because from
the user's point of view the purchase they authorised has just gone through.

## App Store Connect

The script creates, for each of the three products: the product itself (type `CONSUMABLE`), its
`en-US` and `de-DE` localizations, and a price. What it writes:

| id suffix | en-US name | de-DE name | Price |
|---|---|---|---|
| `tip.small` | Small tip | Kleines Trinkgeld | €5 |
| `tip.medium` | Medium tip | Mittleres Trinkgeld | €10 |
| `tip.large` | Large tip | Großes Trinkgeld | €25 |

Descriptions say what the tip does and does not do — supports development, unlocks nothing — in both
languages, because App Review reads them and a tip that sounds like it buys something invites a
rejection.

Three steps stay manual, and the first blocks everything:

1. **Agreements, Tax and Banking** — the Paid Apps agreement must be active. No in-app purchase can
   be created, let alone sold, until the account holder has accepted it and completed the tax and
   banking forms.
2. **A review screenshot per product**, showing the tip screen. Apple requires one before a product
   can be submitted.
3. **Submission for review.** Apple has historically required a first in-app purchase to be
   reviewed alongside an app version rather than on its own; newer App Store Connect flows allow
   submitting products independently. Plan for the version-coupled path and find out which applies
   when the products are actually ready — it changes the release order, not the code.

## Testing

`TipListReducer` against a stubbed `TipJar`: products load and render; a load failure shows the retry
state; each of the four purchase results produces its own outcome, and the cancelled one produces no
toast at all. Snapshot tests for the loaded list, the failure state and a purchase in flight.

A `.storekit` configuration file wired into the app scheme, because it is the only way to open a real
purchase sheet in the simulator without live products in App Store Connect.

No UI test: a journey would need StoreKit's sheet, which XCUITest drives poorly, and every decision
above is covered by the reducer tests.

## Out of scope

- **Subscriptions.** A different product type, a different review conversation, and recurring money
  from people who are giving a gift.
- **Anything a tip unlocks** — a badge, a supporter list, an ad-free mode. The moment a tip buys
  something it stops being a tip.
- **Receipt validation on a server.** There is no server, and nothing is granted to protect.
- **Tips anywhere but Settings.** No prompts after a successful scan, no banners. A tip jar that
  chases you is worse than no tip jar.

## Risks

**The Paid Apps agreement is a hard block and is not ours to accept.** Until it is active in App
Store Connect, the creation script fails, the products cannot exist, and the screen has nothing to
show. Worth confirming before any of this is built.

**App Review reads the screen, not the intent.** Tips are allowed, but a screen that implies a
purchase improves the app invites a rejection. The copy has to be plain that nothing changes.

**A pending purchase surfaces later, out of context.** Ask to Buy means a parent approves hours after
the fact; the thank-you then appears while the user is doing something unrelated. That is StoreKit's
shape rather than a bug, but it is the one moment this feature speaks without being spoken to.

**StoreKit does nothing useful in the simulator without a configuration file**, and snapshot tests
must never depend on it — hence the client seam, and hence the `.storekit` file for hands-on work.

**Prices are a ladder, and the top of it is unusual.** €25 is far above the impulse range most tip
jars use. Prices can be changed later; the ids cannot, which is why they name rank rather than
amount.
