# UI testing rework — entity lifecycles

Second slice of [2026-08-24-ui-testing-rework-design.md](2026-08-24-ui-testing-rework-design.md).
That spec stands; this one narrows it to the next shippable piece and records the decisions the
first slice deferred.

## Where the rework stands

[Plan 1](../plans/2026-08-24-ui-testing-rework.md) scoped itself to spec sequence steps 1–3 plus
journeys 1, 3 and 4, and landed whole in `21e8dc9`. `TagsApp` and `TagsAppTests` are gone.
`DocumentCustomFieldJourneyTests` arrived later in `e1b3dff` as a regression guard for #192 — it is
not the spec's journey 12, which still wants its own uploaded document.

Plan 1 deliberately deferred journeys 2 and 5–12 and the remaining eight harness deletions to a
"Plan 2" that was never written. This is the first half of it.

| | Today |
|---|---|
| Journeys in `AppUITests` | 4 — onboarding, settings, tag lifecycle, document custom field |
| Harness pairs remaining | 9 — Correspondents, CustomFields, Documents, DocumentTypes, SavedViews, Servers, Settings, StoragePaths, **Share** |
| Harness tests remaining | 31, of which `ShareAppTests.testImport` is permanent |
| Journeys unwritten | 2, 5, 6, 7, 8, 9, 10, 11, 12 |

**The risk that justified the split is measured and gone.** Plan 1's execution notes record that
across all three journeys not one accessibility identifier had to be added; every element matched on
an existing label. The screens still ahead — the custom-field matrix and document browsing — remain
the ones most likely to be ambiguous in an assembled navigation stack, so the risk is reduced rather
than retired. It does not apply to the four entity lists in this slice, which are shaped exactly
like the tag list that already passes.

## Scope

Journeys 5–8 and 10, and the retirement of **five** harness pairs — ten targets.

`SettingsApp` is the fifth and needs no new test. Plan 1 Task 7 replaced `testSettingsList` with
`SettingsJourneyTests`, but Plan 1 only deleted the *Tags* harness, so the settings pair has been
duplicate coverage since `21e8dc9`. It goes first, on its own.

Left standing afterwards: `CustomFieldsApp`, `DocumentsApp` and `ServersApp` — journeys 2, 9, 11 and
12, a later slice — plus `ShareApp`, which is permanent for the reason the parent spec gives.

## `EntityListScreen`

`TagListScreen` is already entirely label-driven. Its only entity-specific strings are `Add tag`,
`Edit tag` and `Delete tag`; `Name`, `Save`, `Confirm`, the cell lookup and the swipe mechanics are
shared. The string catalog makes the generalisation mechanical — every entity carries the same three
keys:

| Entity | `create*` | `edit*` | `delete*` |
|---|---|---|---|
| Tag | Add tag | Edit tag | Delete tag |
| Correspondent | Add correspondent | Edit correspondent | Delete correspondent |
| Document type | Add document type | Edit document type | Delete document type |
| Storage path | Add storage path | Edit storage path | Delete storage path |
| Saved view | Add saved view | Edit saved view | Delete saved view |

So one driver replaces five, parameterised by an `Entity` value holding those three strings:

```swift
public struct EntityListScreen {

    public struct Entity: Sendable {
        let add: String
        let delete: String
        let edit: String

        public static let correspondent: Self
        public static let documentType: Self
        public static let savedView: Self
        public static let storagePath: Self
        public static let tag: Self
    }

    public func create(named name: String, extras: () -> Void = {}) -> Bool
    public func delete(named name: String) -> Bool
    public func edit(named name: String, appending suffix: String) -> Bool
}
```

`TagListScreen` folds into it and is deleted — five entities sharing one implementation is the whole
point, and leaving the tag driver behind would mean a changed `Save` label needs fixing twice.

**Per-entity extras ride a trailing closure** rather than widening the signature. Two entities need
one: storage paths type a `Path`, saved views tap `Show in sidebar` and `Show on dashboard`. A
closure keeps `create` honest for the three entities that need nothing, and the two that do read as
what they are. `TagListScreen`'s private `type(_:into:)` becomes public and takes a field label, so
a closure can reach it without re-deriving the wait-then-tap-then-type dance:

```swift
list.create(named: name) {
    list.type("/home/paperless/\(name)", into: "Path")
}
```

`SettingsScreen` needs no change. `openSection(_ name: String)` already takes the row label.

## `EntityLifecycleJourneyTests`

One file, one method per entity over a shared private helper, plus journey 10:

```swift
final class EntityLifecycleJourneyTests: UITestCase {

    func testCorrespondentLifecycle() async throws
    func testDocumentTypeLifecycle() async throws
    func testSavedViewLifecycle() async throws
    func testStoragePathLifecycle() async throws
    func testTagLifecycle() async throws

    func testDeletingATagRemovedServerSide() async throws

    private func runLifecycle(
        for entity: EntityListScreen.Entity,
        section: String,
        extras: () -> Void = {}
    ) { ... }
}
```

`TagLifecycleJourneyTests.swift` is deleted; its body becomes `testTagLifecycle`. One file mirrors
the one driver, and each entity method is a call site rather than a copy. `runLifecycle` threads
launch → Settings tab → section → create → assert in list → edit → assert renamed → delete, which is
the sequence the landed tag journey already runs.

The per-test user is what makes this safe to share: each method's list opens empty, so no method can
see another's rows and there is no ordering between them.

## Journey 10

The parent spec collapses five `testDeleteFailure` tests into one journey on the grounds that they
are one mechanism repeated five times: delete the entity behind the app's back, confirm the delete
in the UI, expect the conflict surface. All five have the same body today, differing only in labels
and the empty-state string.

**It runs on tags.** That is the entity whose `testDeleteFailure` is *already* gone — Plan 1 Task 8
retired `TagsApp` without replacing it, naming journey 10 as the replacement. Running journey 10 on
tags closes an open gap rather than picking arbitrarily among four that are about to close.

The per-test user improves on the harness version. The old test called `deleteAllTags()` and
asserted the empty state, which passed for two reasons at once — the delete failed *and* the list
had been emptied out from under it. Here the test creates exactly one tag through the UI, so when
the list ends up empty it is because the row the user tried to delete was already gone:

1. Create a tag through the UI, named `<namespace>-tag`.
2. `Fixtures.deleteTag(named:)` removes it server-side as admin.
3. Swipe-delete the row in the UI and confirm.
4. Expect `No Tag matches the given query.`

That is one new fixture helper, not five. `Fixtures` already holds the admin-scoped pattern for
custom fields and `withAdminDependencies` is already public; admin is a superuser and can delete an
object the test user owns.

## Sequence

The parent spec's one-commit-per-entity rule, so `main` is never less covered than it is today.

1. Delete `SettingsApp` / `SettingsAppTests` and prune the Tuist helpers. No new test — journey 3
   has covered this since `21e8dc9`.
2. `EntityListScreen`; `TagLifecycleJourneyTests` becomes `EntityLifecycleJourneyTests`. Green, with
   the tag journey behaving exactly as before, prior to anything else moving.
3. Journey 5 (correspondent), then delete the `CorrespondentsApp` pair.
4. Journey 6 (document type), then delete the `DocumentTypesApp` pair.
5. Journey 7 (storage path), then delete the `StoragePathsApp` pair.
6. Journey 8 (saved view), then delete the `SavedViewsApp` pair.
7. Journey 10 and `Fixtures.deleteTag(named:)`.
8. Measure suite runtime and record it, as Plan 1 recorded 29s / 11s / 44s for its three journeys.

Each deletion touches the same five places Plan 1 Task 8 documented: the enum cases and their
`codeCoverageTarget` and `product` entries in `Module.swift`; the dependency blocks in
`Module+Dependencies.swift`; the scheme lists and the `featureAppTestTargets` branch in
`Module+Schemes.swift`; the Info.plist entry and its `PAPERLESS_TEST_URL` injection in
`Module+InfoPlists.swift`. Regenerate after each: `mise exec -- tuist install && mise exec -- tuist
generate --no-open`.

## Out of scope

- **Journeys 2, 9, 11 and 12**, and the `CustomFieldsApp`, `DocumentsApp` and `ServersApp`
  deletions that depend on them.
- **The CustomFields blank-option and cancel assertions** that the parent spec moves down to
  `CustomFieldsFeatureTests`. They must be written before `CustomFieldsApp` dies, which is the next
  slice, not this one.
- **Revisiting the `CI_UI_TESTS` gate** (parent spec sequence step 7). That decision wants the
  number step 8 produces, and it wants it after the remaining harnesses are gone rather than at the
  halfway mark.

## Risks

**Journey 10 pins one entity.** If the conflict surface turns out to be entity-specific, four
entities lose coverage they have today. The parent spec accepted this explicitly — "If it turns out
to be entity-specific, that is a reducer concern" — and it is the one real coverage risk in the
slice. Accepted, and recorded here so the next failure of that shape is recognised rather than
re-diagnosed.

**Folding five journeys into one file makes a shared-helper regression a five-test failure.** That
is the intended trade: the alternative is five files that drift. Step 2 lands the refactor with the
tag journey unchanged, so a break there is attributable before any new entity is added.

**The orphan sweep is still serial-only.** `OrphanSweep` deletes every `uit-*` user regardless of
age, which the comment in `UITestCase.swift` already flags as safe only while tests run serially.
This slice adds five journeys to a serial suite and does not change that; enabling parallel workers
remains blocked on teaching the sweep to skip in-flight users.
