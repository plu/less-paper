# Document count pill overlaps the search bar in the filter list sheets

## Problem

On the correspondent, document type, storage path and tag filter sheets, the
`22 documents` count capsule sat on top of the search field.

The two views were bottom-anchored independently and neither knew about the
other:

- `DocumentFilterGenericValueListView` and `DocumentFilterTagListView` attached
  `DocumentFilterMatchCountView` with `.safeAreaInset(edge: .bottom)` on the
  outer `Sheet`.
- The `List` inside `Searchable` carries `.searchable(text:)`, and its enclosing
  `NavigationStack` places that field in the same bottom strip.

The overlap only appeared on iOS 26, where the system search field moved to the
bottom of the screen. On iOS 18 the field renders at the top and the two never
met, which is why this was not visible when the capsule was introduced.

## Decision

**The capsule now appears only on the main filter sheet.** It was removed from
the correspondent/document type/storage path sheet, the tag sheet and the date
sheet.

Two placements were built and rejected first. Both hinged on where the inset was
attached relative to the `NavigationStack` that `Searchable` wraps around the
list:

| Attached to | Capsule lands |
| --- | --- |
| the outer `Sheet` | in the search field's strip — the bug |
| the `List`, inside the stack | above the search field |
| the `Searchable` wrapper, outside the stack | below the search field |

Neither surviving position looked right on a sheet that already carries a
segmented picker, a list and a bottom-anchored search field. Rather than keep
tuning the geometry, the capsule was cut from the picker sheets entirely.

### Accepted consequence

The count no longer moves while a picker is open. Tapping a segment or a value
changes the filter and therefore the count, but that is only visible after
returning to the filter sheet. This was the original argument for showing the
capsule in the pickers, and it is knowingly given up.

## Design

`DocumentFilterView` keeps its `.safeAreaInset(edge: .bottom)` exactly as it was
— it has no search field, so nothing collides.

`DocumentFilterGenericValueListView`, `DocumentFilterTagListView` and
`DocumentFilterDateView` drop that inset. No other change: `sectionView()` keeps
its `Spacer()` branches and `list()` keeps its plain `.searchable(...)`.

`DocumentFilterMatchCountView` itself is unchanged. Three comments that justified
picker visibility were corrected, in `DocumentFilterMatchCountView`,
`DocumentFilterMatchCount` and `DocumentListReducer`.

### Tests

`DocumentFilterViewTests.testSnapshot_matchCountInTagPicker` covered the tag
picker showing the count, which is the behaviour being removed, so it and its
reference image are deleted. The remaining `testSnapshot_matchCount*` cases in
that suite cover the main filter sheet and stay.

The picker suites' existing `testSnapshot(rule:)` cases leave the shared count
`nil`, so they never rendered the capsule and pass unchanged — which is itself
confirmation that the removal is inert for every other pixel on those sheets.

## Verification

Snapshot tests cannot see the search field: `Searchable` drops the
`NavigationStack` under `isTesting`, so the strip the capsule collided with does
not exist in a test. Confirm by eye on an iOS 26 simulator that the correspondent
and tag sheets show a search field with nothing overlapping it, and that the main
filter sheet still shows the capsule.
