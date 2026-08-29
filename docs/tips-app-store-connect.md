# The tips in App Store Connect

Three consumables, **not yet created** — dry-run only, verified against a live read of App Store
Connect on 2026-08-29. A throwaway script (not committed) authenticates, reads the app and its
existing in-app purchases, and resolves the DEU price point for each price below; it creates
nothing until it is run with `DRY_RUN=0`, which has not happened yet. **Product ids can never be
renamed or reused**, so they are recorded here ahead of that run rather than left to be
rediscovered afterwards.

| Product id | en-US | de-DE | Price (base: Germany) |
|---|---|---|---|
| `com.aptumtek.app.Paperless.tip.small` | Small tip | Kleines Trinkgeld | €5 |
| `com.aptumtek.app.Paperless.tip.medium` | Medium tip | Mittleres Trinkgeld | €10 |
| `com.aptumtek.app.Paperless.tip.large` | Large tip | Großes Trinkgeld | €25 |

All three are `CONSUMABLE`: they unlock nothing, leave no entitlement, and can be bought repeatedly.
The description in both languages says so, because App Review reads it and a tip that sounds like it
buys something invites a rejection.

Prices are editable in App Store Connect at any time. The ids are not, which is why they name a rank
rather than an amount.

## What still has to be done by hand

- **Run the live script (`DRY_RUN=0`).** This creates the three products, their localizations, and
  their price schedules for real. Everything below depends on this having happened first.
- **A review screenshot per product.** Apple requires one before a product can be submitted. A
  capture of the tip screen (Settings → Tips) is enough; the same image serves all three.
- **Submission for review.** Apple has historically required a first in-app purchase to be reviewed
  alongside an app version rather than on its own; newer App Store Connect flows may allow
  submitting products independently. Check which applies when submitting — it changes the release
  order, not the app.

## Testing without them

`Tuist/Tips.storekit` is wired into the "Less Paper" scheme's run action, so the simulator serves
these three products locally and the purchase sheet works with no App Store Connect involvement at
all. Purchases made against it are fake and cost nothing.
