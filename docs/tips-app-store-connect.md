# The tips in App Store Connect

Four consumables, **created on 2026-08-29** by a throwaway script (not committed) and verified
afterwards by reading them back: each is `CONSUMABLE`, carries both localizations, and has a price
schedule. **Product ids can never be renamed or reused**, so they are recorded here rather than left
to be rediscovered.

| Product id | Apple's internal id |
|---|---|
| `com.aptumtek.app.Paperless.tip.tiny` | TBC — read back from App Store Connect |
| `com.aptumtek.app.Paperless.tip.small` | 6806529459 |
| `com.aptumtek.app.Paperless.tip.medium` | 6806529928 |
| `com.aptumtek.app.Paperless.tip.large` | 6806529936 |

The tiny product's internal id and German localization still need to be filled in from App Store
Connect — nobody has read them back yet.

All four currently read `MISSING_METADATA`, which is expected and means only that the review
screenshot below has not been uploaded yet.

## Precondition: the Paid Apps agreement

No in-app purchase can be created, let alone sold, until the account holder has accepted the
**Paid Apps agreement** in App Store Connect's Agreements, Tax and Banking, with the tax and
banking forms completed. This is the hard blocker the spec calls out as its first risk — the
creation script fails outright while it is unaccepted. **The account holder accepted it before the
products were created.** If a future creation attempt fails, this agreement is the first thing to
check in Agreements, Tax and Banking.

| Product id | en-US | de-DE | Price (base: Germany) |
|---|---|---|---|
| `com.aptumtek.app.Paperless.tip.tiny` | Tiny tip | TBC — read back from App Store Connect | €1 |
| `com.aptumtek.app.Paperless.tip.small` | Small tip | Kleines Trinkgeld | €5 |
| `com.aptumtek.app.Paperless.tip.medium` | Medium tip | Mittleres Trinkgeld | €10 |
| `com.aptumtek.app.Paperless.tip.large` | Large tip | Großes Trinkgeld | €25 |

They unlock nothing, leave no entitlement, and can be bought repeatedly. The description in both
languages says so, because App Review reads it and a tip that sounds like it buys something invites
a rejection:

- en-US: "Supports development. Unlocks nothing."
- de-DE: "Unterstützt die Entwicklung. Schaltet nichts frei."

**An in-app purchase description is capped at 55 characters.** The first live run was rejected with
"The field (description) is too long" on a 92-character sentence, after the first product had
already been created — which is how `tip.small` briefly existed with no localizations at all. Keep
any future copy inside that limit.

Prices are editable in App Store Connect at any time. The ids are not, which is why they name a rank
rather than an amount.

## What still has to be done by hand

- **A review screenshot per product.** Apple requires one before a product can be submitted. A
  capture of the tip screen (Settings → Tips) is enough; the same image serves all four.
- **Submission for review.** Apple has historically required a first in-app purchase to be reviewed
  alongside an app version rather than on its own; newer App Store Connect flows may allow
  submitting products independently. Check which applies when submitting — it changes the release
  order, not the app.

## If these ever have to be recreated

A product id that already has a record cannot be created again, so the script completes an existing
product rather than skipping it: it reuses the id, lists the localizations already present and adds
only the missing ones, then prices it. That path is not theoretical — it is how `tip.small` was
finished after the first run failed mid-way. Two API details cost time and are worth keeping:
localizations are **listed** through `v2/inAppPurchases/{id}/inAppPurchaseLocalizations` but
**created** through `v1/inAppPurchaseLocalizations`, and `v2/inAppPurchases` refuses a collection
GET for this key, so existing products have to be listed through `v1/apps/{id}/inAppPurchasesV2`.

## Testing without them

`Tuist/Tips.storekit` is wired into the "Less Paper" scheme's run action, so the simulator serves
these four products locally and the purchase sheet works with no App Store Connect involvement at
all. Purchases made against it are fake and cost nothing.
