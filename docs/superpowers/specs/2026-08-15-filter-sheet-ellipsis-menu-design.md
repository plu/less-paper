# Filter sheet ellipsis menu

## Context

`DocumentFilterView` presents the documents filter in a `Sheet` with three regions: a
`SheetHeader` whose title is the saved-view picker and whose right slot is a save menu
(`square.and.arrow.down`, holding "Save as…" and a conditional "Save"), the filter fields, and a
bottom bar with "Reset" and "Apply" buttons.

The bottom bar is close to vestigial. `DocumentListReducer` listens to exactly one delegate from
this sheet — `filterUpdated` — and answers it by unconditionally reloading the list
(`DocumentListReducer.swift:262-270`). Almost every control in the sheet already emits it:

| Control | Emits `filterUpdated` |
|---|---|
| Search type / ASN type menu | yes — `.searchTypeButtonTapped` / `.asnTypeButtonTapped` |
| Correspondent, document type, storage path | yes — the sub-sheet's delegate fires per toggle |
| Tags | yes — same |
| Date (including its reset-from / reset-to buttons) | yes — same |
| Sort field / direction | yes |
| Saved-view picker in the title | yes |
| **Search text field** | **no** |

The search field is the single exception. `searchValue` is bound straight to state through
`$store.input.searchValue` (`DocumentFilterView.swift:147`) and `.binding` falls into the reducer's
catch-all `return .none` (`DocumentFilterReducer.swift:249`), so today only `applyButtonTapped`
picks typed text up. Removing "Apply" without addressing this would leave the search box silently
dead.

## Goal

Move "Save", "Save as…" and a new "Reset" into an ellipsis menu in the header, drop the bottom bar
entirely, and make the search field commit on its own so nothing needs an explicit apply.

## Design

### The ellipsis menu

`saveMenu()` becomes `optionsMenu()`. The label changes from `square.and.arrow.down` to `ellipsis`;
the existing `.accessibilityLabel(.moreOptions)` already describes it correctly and stays.

```swift
@ViewBuilder
private func optionsMenu() -> some View {
    Menu {
        if store.savedView != nil {
            Button {
                send(.saveButtonTapped)
            } label: {
                Text(.save)
            }
            .disabled(!store.isModified)
        }

        Button {
            send(.saveAsButtonTapped)
        } label: {
            Text(.saveAs)
        }

        Divider()

        Button(role: .destructive) {
            send(.resetButtonTapped)
        } label: {
            Text(.reset)
        }
        .disabled(!store.isModified)
    } label: {
        Image(systemName: "ellipsis")
            .accessibilityLabel(.moreOptions)
    }
}
```

"Save" moves above "Save as…" so the two saving actions read in order of specificity and the
divider separates them cleanly from the discarding one.

Reset takes `role: .destructive` — its German string is already "Verwerfen" (discard) — and is
disabled when `!isModified`, since resetting an unmodified filter changes nothing but would still
fire a reload. `isModified` already means the right thing in both modes: measured against the saved
view's rules when one is selected, against a default `DocumentFilterInput()` otherwise.

No string changes. `reset`, `save`, `saveAs` and `moreOptions` all exist in
`Shared/Framework/Resources/Localizable.xcstrings`.

### The bottom bar

`buttons()` and the `bottom:` closure are deleted. `Sheet` already has a `top:content:` overload
(`Sheet.swift:103-120`), so the call site simply loses its third trailing closure.

`applyButtonTapped` is removed from `DocumentFilterReducer.Action.View` and from the reducer.
`resetButtonTapped` is untouched — it already rebuilds `input` from the saved view's rules (or an
empty filter for "All documents") and returns `.runFilterUpdated(state)`. Its behaviour is
unchanged; only its trigger moves.

The `apply` string stays in the catalog: `DocumentBulkEditTagsView` and
`DocumentBulkEditGenericValueView` still use it.

### The search field commits on a debounce

The search field reloads as the user types, 400ms after the last keystroke, matching the
live-update behaviour of every other control in the sheet.

`DocumentFilterReducer.Action` gains one internal case, `searchDebounced`, and the reducer gains two
cases ahead of the existing `.binding` catch-all:

```swift
case .binding(\.input.searchValue):
    return .runSearchDebounce()
case .searchDebounced:
    return .runFilterUpdated(state)
```

**The debounce effect only sleeps; it does not carry the filter.** It sends `searchDebounced`, and
the reducer builds the delegate from state as it is when that action lands:

```swift
static func runSearchDebounce() -> Self {
    @Dependency(\.continuousClock)
    var clock

    return .run { send in
        try await clock.sleep(for: .milliseconds(400))
        await send(.searchDebounced)
    }
    .cancellable(id: CancelID.searchDebounce, cancelInFlight: true)
}
```

Capturing `state` in the effect instead would let a keystroke emit a filter that has since changed —
type "Lego", switch the search type to Title within the debounce window, and the sleeping effect
would send the *old* search type. Reading state at delivery time makes that impossible.
`cancelInFlight: true` collapses a run of keystrokes into one reload.

**`runFilterUpdated` cancels any pending debounce**, so a deliberate change supersedes typing that
is still in flight:

```swift
static func runFilterUpdated(_ state: DocumentFilterReducer.State) -> Self {
    .merge(
        .cancel(id: CancelID.searchDebounce),
        .send(.delegate(.filterUpdated(.init(
            input: state.input,
            savedView: state.savedView
        ))))
    )
}
```

Without it, typing and then immediately tapping a sort field would reload twice — once for the tap,
once 400ms later for the keystroke — with identical results. Cancelling from inside
`runFilterUpdated` covers every such path at once, including the `searchDebounced` path itself,
where the cancel is a harmless no-op against an effect that has already finished.

`CancelID` in `DocumentFilterReducer+Effect.swift` gains a `searchDebounce` case alongside
`saveView`.

**`@Dependency(\.continuousClock)` is new to this codebase** — nothing currently uses a clock or a
scheduler. Its `testValue` is an unimplemented clock, so the tests below supply a `TestClock`.
TCA's own `Effect.debounce(id:for:scheduler:)` is deprecated in 1.22.3
(`Internal/Deprecations.swift:381`), which is why this uses the clock idiom rather than that
operator.

## Out of scope

- **Debouncing anything else.** The other controls are discrete taps, not keystrokes; they keep
  firing immediately.
- **`onSubmit` on the search field.** Redundant once typing commits on its own, and the ASN search
  uses a number pad, which has no return key.
- **The saved-view picker in the title.** Unchanged.

## Testing

- **`DocumentFilterReducerTests`** — delete `test_view_applyButtonTapped`. Add, with
  `$0.continuousClock = TestClock()`:
  - typing sends `.binding`, and only after advancing the clock past 400ms does one
    `filterUpdated` arrive carrying the typed value;
  - two keystrokes inside the window coalesce into a single `filterUpdated`;
  - a keystroke followed by `sortFieldButtonTapped` produces exactly one `filterUpdated` — the tap's
    — with no second one after the clock advances, proving the cancel in `runFilterUpdated`;
  - a keystroke followed by `searchTypeButtonTapped` emits the *new* search type, proving state is
    read at delivery rather than captured.
  The existing `test_view_resetButtonTapped` and `test_view_resetButtonTapped_savedView` cover the
  reducer side of Reset and need no change — only its trigger moved.
- **`DocumentFilterViewTests`** — the four snapshots (`allDocuments`, `modified`, `savedView`,
  `savedView_modified`) all change: the bottom bar is gone and the header icon differs. Re-record.
- **No new view test for the menu contents.** The snapshot tests render the sheet, not an open
  `Menu`, and the codebase has no precedent for asserting menu contents.

## Files

Changed:

- `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift` — `saveMenu()` →
  `optionsMenu()` with Reset and the `ellipsis` label; `buttons()` and the `bottom:` closure removed
- `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift` — `applyButtonTapped`
  removed; `searchDebounced` added; the two new cases ahead of the `.binding` catch-all
- `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer+Effect.swift` —
  `runSearchDebounce()`; the cancel merged into `runFilterUpdated`; `CancelID.searchDebounce`
- `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift`
- `Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/` — re-recorded
