# Filter Sheet Ellipsis Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the documents filter sheet's save menu with an ellipsis menu that also holds "Reset", delete the "Reset"/"Apply" bottom bar, and make the search text field reload the document list on its own via a 400ms debounce.

**Architecture:** Every control in the filter sheet already emits `delegate(.filterUpdated)`, which `DocumentListReducer` answers with an unconditional reload — every control except the search `TextField`, whose `.binding` action falls into the reducer's catch-all `return .none`. This plan closes that one gap with a clock-based debounce, which is what makes the "Apply" button removable. The debounce effect only sleeps and sends an internal `searchDebounced` action; the reducer builds the delegate from state at delivery time, so a keystroke can never emit a stale filter.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture (TCA 1.22.3), swift-dependencies, swift-sharing, Swift Testing, swift-snapshot-testing, Tuist.

**Design doc:** `docs/superpowers/specs/2026-08-15-filter-sheet-ellipsis-menu-design.md` — read it before starting.

## Global Constraints

- **Doc comments:** single-line uses `///`; multi-line with parameters uses `/** * ... */`. See `.claude/CLAUDE.md`.
- **No blank line between an attribute and its declaration** — `mise/scripts/attribute_blank_lines.py --check` runs in lint and enforces this. Write `@Dependency(\.continuousClock)` immediately above `var clock`.
- **Test runner:** `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:<target/suite>`. Tuist targets use *buildable folders*, so new `.swift` files inside an existing module directory are picked up with no project regeneration. **`--no-selective-testing` is not optional during TDD** — without it Tuist fingerprints the target and reports "The scheme's test action has no tests to run, finishing early" on a re-run, which reads exactly like a pass.
- **Snapshot tests** use `record: .environment`, which defaults to `.missing`: a run with no reference on disk records one and *fails*; the next run passes. Task 4 deletes the four existing references on purpose and both runs are steps. Do not set `SNAPSHOT_TESTING_RECORD`.
- **Alphabetical member ordering** is enforced by convention throughout this codebase — enum cases, struct properties and switch cases are all alphabetical. Match it.
- **Lint:** `mise run ci:lint` runs `swiftformat --lint .`, `swiftlint --strict`, the blank-line script and `tuist inspect dependencies`. Run `swiftformat .` before committing if formatting drifts.
- **No string catalog changes.** `reset`, `save`, `saveAs`, `moreOptions` and `apply` all already exist in `Shared/Framework/Resources/Localizable.xcstrings`. `apply` must **stay** — `DocumentBulkEditTagsView` and `DocumentBulkEditGenericValueView` still use it.

---

### Task 1: Search field commits on a debounce

This task comes first because it is the precondition for removing the "Apply" button in Task 3. Until it lands, typing in the search field does not reload the list.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentFilterReducer.State.testValue(destination:input:savedView:server:)` and `DocumentFilterInput.testValue(...)` (existing, `DocumentFilterReducer+TestValue.swift` and `DocumentFilterInput.swift:467`), `DocumentFilter.testValue(input:savedView:)` (existing, `DocumentFilter.swift:47`).
- Produces: `DocumentFilterReducer.Action.searchDebounced` (no payload) and `Effect.runSearchDebounce()`. `runFilterUpdated(_:)` keeps its existing signature but gains a merged `.cancel`. Task 3 relies on `resetButtonTapped` and `runFilterUpdated` being unchanged in behaviour.

- [ ] **Step 1: Write the failing tests**

Add these four tests to `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift`. Place them alphabetically: `test_binding_*` go immediately after the `test_isModified_*` test and before `test_view_asnTypeButtonTapped`.

The suite's `.dependencies()` trait does **not** set `continuousClock`, whose `testValue` is an unimplemented clock that fails the test if used. Each of these tests must supply a `TestClock` and hold a reference to it so it can be advanced.

```swift
    @Test
    func test_binding_searchValue_debounces() async throws {
        let clock = TestClock()
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.input.searchValue, "Lego"))) {
            $0.input.searchValue = "Lego"
        }

        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced)
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Lego")
        ))
    }

    @Test
    func test_binding_searchValue_coalescesKeystrokes() async throws {
        let clock = TestClock()
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.input.searchValue, "Leg"))) {
            $0.input.searchValue = "Leg"
        }
        await clock.advance(by: .milliseconds(200))
        await store.send(.binding(.set(\.input.searchValue, "Lego"))) {
            $0.input.searchValue = "Lego"
        }
        await clock.advance(by: .milliseconds(400))

        await store.receive(\.searchDebounced)
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Lego")
        ))
    }

    @Test
    func test_binding_searchValue_cancelledByExplicitChange() async throws {
        let clock = TestClock()
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.input.searchValue, "Lego"))) {
            $0.input.searchValue = "Lego"
        }
        await store.send(.view(.sortFieldButtonTapped(.title))) {
            $0.input.sort.field = .title
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Lego", sort: .init(field: .title))
        ))

        await clock.advance(by: .seconds(1))
    }

    @Test
    func test_binding_searchValue_readsStateAtDelivery() async throws {
        let clock = TestClock()
        let store = TestStore(initialState: DocumentFilterReducer.State.testValue()) {
            DocumentFilterReducer()
        } withDependencies: {
            $0.continuousClock = clock
        }

        await store.send(.binding(.set(\.input.searchValue, "Lego"))) {
            $0.input.searchValue = "Lego"
        }
        await store.send(.view(.searchTypeButtonTapped(.title))) {
            $0.input.searchType = .title
        }
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchType: .title, searchValue: "Lego")
        ))

        await clock.advance(by: .seconds(1))
    }
```

One note on how the last two assert their point: `test_binding_searchValue_cancelledByExplicitChange` and `..._readsStateAtDelivery` end by advancing the clock a full second and asserting **nothing more arrives**. `TestStore` fails at the end of a test if any action went unasserted, so the absence of a second `filterUpdated` is what proves `runFilterUpdated` cancelled the pending debounce. That is the whole assertion — do not add another.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterReducerTests`

Expected: FAIL — compile error, `type 'DocumentFilterReducer.Action' has no member 'searchDebounced'`.

- [ ] **Step 3: Add the `searchDebounced` action**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift`, add the case to `Action` in alphabetical position, between `savedViewSaved` and `view`:

```swift
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case savedViewSaved(SavedView)
        case searchDebounced
        case view(View)
```

- [ ] **Step 4: Handle the two new cases in the reducer**

Still in `DocumentFilterReducer.swift`, add these two cases at the **top** of the `switch action`, above the existing `case let .destination(.presented(.correspondentList(...)))`. The specific `.binding(\.input.searchValue)` must come before the catch-all `case .binding, .delegate, .destination` at the bottom of the switch, and this position also keeps the alphabetical ordering the file already uses.

```swift
            switch action {
            case .binding(\.input.searchValue):
                return .runSearchDebounce()
            case let .destination(.presented(.correspondentList(.delegate(.filterUpdated(rule: rule, selection: selection))))):
```

and add `searchDebounced` between the existing `savedViewSaved` and `view` cases:

```swift
            case .searchDebounced:
                return .runFilterUpdated(state)
            case let .view(viewAction):
```

Leave the trailing `case .binding, .delegate, .destination: return .none` exactly as it is — it still catches every other binding.

- [ ] **Step 5: Add the debounce effect and the cancel**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer+Effect.swift`, rewrite `runFilterUpdated` and add `runSearchDebounce`. The file's members are alphabetical, so `runSearchDebounce` goes after `runSaveView`.

```swift
    /**
     * Reports the current filter upwards, superseding any keystroke still waiting to be debounced.
     *
     * The cancel is what stops a deliberate change — a tap on a sort field, a tag selection —
     * reloading the list twice: once for the tap, and again 400ms later for a keystroke that
     * produced an identical filter.
     *
     * - Parameter state: The state to report the filter from.
     */
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

```swift
    /**
     * Waits out a pause in typing before letting the search field reload the list.
     *
     * The effect carries no filter — it sends `searchDebounced` and the reducer reads state when
     * that lands. Capturing state here instead would let a keystroke emit a filter that has since
     * changed: type, switch the search type inside the window, and the sleeping effect would
     * report the old one.
     */
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

and extend `CancelID` at the bottom of the file, alphabetically:

```swift
private enum CancelID {
    case saveView
    case searchDebounce
}
```

TCA's own `Effect.debounce(id:for:scheduler:)` is deprecated in 1.22.3 (`Internal/Deprecations.swift:381`) — do not use it.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterReducerTests`

Expected: PASS, including the pre-existing tests. `test_view_applyButtonTapped` still passes at this point — it is removed in Task 3.

- [ ] **Step 7: Commit**

```bash
swiftformat .
git add Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift \
        Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer+Effect.swift \
        Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift
git commit -m "feat: reload the document list as the filter search field is typed in"
```

---

### Task 2: The ellipsis menu

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift:211-269`

**Interfaces:**
- Consumes: `store.savedView`, `store.isModified` (existing `State` members), the view actions `saveButtonTapped`, `saveAsButtonTapped`, `resetButtonTapped` (all existing and unchanged).
- Produces: nothing new. Task 3 removes `buttons()` from the same file.

There is no test step here — the snapshot tests render the sheet, not an open `Menu`, so this task's visible effect is verified in Task 4 when the references are re-recorded. Task 3's reducer change is what carries this task's test cycle.

- [ ] **Step 1: Rename `saveMenu()` to `optionsMenu()` and add Reset**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift`, replace the whole of `saveMenu()` (lines 248-269) with:

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

Three changes from the current code, all deliberate:

- The label image goes from `square.and.arrow.down` to `ellipsis`. `.accessibilityLabel(.moreOptions)` already reads correctly for an ellipsis and stays.
- "Save" moves *above* "Save as…" so the two saving actions read in order of specificity.
- Reset is new, `role: .destructive` (its German string is already "Verwerfen" — discard), below a `Divider`, and disabled when `!isModified` because resetting an unmodified filter changes nothing but would still fire a network reload.

`optionsMenu()` is alphabetically before `savedViewsMenu()`, so move it above that function to keep the file's ordering.

- [ ] **Step 2: Update the call site**

In the same file, `rightHeader()` (line 211-214) calls the old name:

```swift
    @ViewBuilder
    private func rightHeader() -> some View {
        optionsMenu()
    }
```

- [ ] **Step 3: Verify it builds**

Run: `tuist build DocumentsFeature -d "iPhone 17 Pro"`

Expected: build succeeds.

- [ ] **Step 4: Commit**

```bash
swiftformat .
git add Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift
git commit -m "feat: move the filter sheet's save actions and reset into an ellipsis menu"
```

---

### Task 3: Remove the bottom bar and `applyButtonTapped`

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift:14-34, 180-199`
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift:28, 164-165`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift:225-239`

**Interfaces:**
- Consumes: `Sheet.init(isScrollingEnabled:padding:top:content:)` — the two-closure overload at `Modules/Components/Sheet/Sheet.swift:103-120`, which requires `Bottom == EmptyView` and `ContentOverlay == EmptyView`.
- Produces: `DocumentFilterReducer.Action.View` without `applyButtonTapped`.

- [ ] **Step 1: Delete the test that covers the removed action**

In `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift`, find `test_view_applyButtonTapped` by name — Task 1 inserted tests above it, so its line number has moved — and delete it in full:

```swift
    @Test
    func test_view_applyButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        )) {
            DocumentFilterReducer()
        }

        await store.send(.view(.applyButtonTapped))
        await store.receive(\.delegate.filterUpdated, .testValue(
            input: .testValue(searchValue: "Lego"),
            savedView: .testValue()
        ))
    }
```

Leave `test_view_resetButtonTapped` and `test_view_resetButtonTapped_savedView` untouched — Reset's reducer behaviour is unchanged, only its trigger moved in Task 2.

- [ ] **Step 2: Run the tests to confirm the baseline is green**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterReducerTests`

Expected: PASS. This task inverts the usual red-first order because its "test" is the compiler: removing an enum case is what breaks the build, and it cannot break until Step 4. Confirming green here is what makes a failure in Step 5 attributable to this task.

- [ ] **Step 3: Remove the bottom bar from the view**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift`, delete the `buttons()` function in full (lines 180-199):

```swift
    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.resetButtonTapped)
            } label: {
                Text(.reset)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())

            Button {
                send(.applyButtonTapped)
            } label: {
                Text(.apply)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary())
        }
    }
```

and drop the `bottom:` closure from the `Sheet`, so `body` becomes:

```swift
    var body: some View {
        Sheet {
            SheetHeader(
                title: savedViewsMenu,
                left: leftHeader,
                right: rightHeader
            )
        } content: {
            VStack(spacing: .x3) {
                searchField()
                correspondentField()
                documentTypeField()
                storagePathField()
                tagField()
                dateField()
                sortField()
            }
            .frame(maxWidth: .infinity)
        }
        .sheet(
            item: $store.scope(
                state: \.destination?.savedViewForm,
                action: \.destination.savedViewForm
            )
        ) { store in
            SavedViewFormView(store: store)
                .presentationDetents([.large])
        }
    }
```

Check whether `Components`' `AdaptiveStack` is still referenced anywhere else in this file after the deletion — it is not, but the `import Components` line stays, since `Sheet`, `SheetHeader` and `.capsule` come from it too.

- [ ] **Step 4: Remove `applyButtonTapped` from the reducer**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift`, delete the case from `Action.View` (line 28):

```swift
        public enum View {
            case asnTypeButtonTapped(DocumentFilterASNType)
            case closeButtonTapped
```

and delete its handler from the view-action switch (lines 164-165):

```swift
                switch viewAction {
                case let .asnTypeButtonTapped(asnType):
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterReducerTests`

Expected: PASS. If the compiler reports a missing switch case anywhere, an `applyButtonTapped` reference was missed — `grep -rn "applyButtonTapped" Modules/DocumentsFeature/DocumentFilter Modules/DocumentsFeatureTests/DocumentFilter` must come back empty. Note that `DocumentBulkEditTagsReducer` and `DocumentBulkEditGenericValueReducer` have their *own* unrelated `applyButtonTapped` cases; leave those alone.

- [ ] **Step 6: Commit**

```bash
swiftformat .
git add Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift \
        Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift \
        Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterReducerTests.swift
git commit -m "feat: drop the filter sheet's reset and apply buttons"
```

---

### Task 4: Re-record the snapshots

**Files:**
- Modify: `Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_allDocuments.1.png`
- Modify: `Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_modified.1.png`
- Modify: `Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_savedView.1.png`
- Modify: `Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_savedView_modified.1.png`

**Interfaces:**
- Consumes: `DocumentFilterViewTests` (existing, unchanged — no test code is edited in this task).

All four references show a bottom bar that no longer exists and a `square.and.arrow.down` header icon that is now an `ellipsis`, so all four must change.

- [ ] **Step 1: Confirm the existing snapshots now fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterViewTests`

Expected: FAIL — all four tests report a snapshot mismatch. If any of them *passes*, the view change did not take effect and Tasks 2 and 3 need re-checking before going further.

- [ ] **Step 2: Delete the stale references**

```bash
rm Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_allDocuments.1.png \
   Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_modified.1.png \
   Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_savedView.1.png \
   Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_savedView_modified.1.png
```

- [ ] **Step 3: Record the new references**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterViewTests`

Expected: FAIL, four times, with "No reference was found on disk. Automatically recorded snapshot". The PNGs now exist.

- [ ] **Step 4: Inspect the recorded images**

Run: `mise run snapshots diff`

Open the four images and confirm, for each:

- There is **no** bar at the bottom of the sheet — the last thing on screen is the sort field, and the sheet's content extends to where the Reset/Apply buttons used to be.
- The header's right-hand icon is a horizontal ellipsis, not a downward arrow into a tray.
- The header is otherwise unchanged: an ✕ on the left, and the title capsule in the middle reading "All documents" (`allDocuments`, `modified`) or the saved view's name (`savedView`, `savedView_modified`).
- In `modified` and `savedView_modified` the small unsaved-changes dot still sits at the title capsule's top-trailing corner.

If any of these is wrong, fix the view, delete the wrong references, and repeat Steps 3-4.

- [ ] **Step 5: Verify the tests pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentFilterViewTests`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Snapshots/DocumentsFeatureTests/DocumentFilterViewTests
git commit -m "test: re-record the filter sheet snapshots"
```

---

### Task 5: Full verification

**Files:** none — this task only runs checks.

- [ ] **Step 1: Run the whole feature target**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS. This catches anything in `DocumentListReducerTests`, `DocumentFilterInboxTests` or the other filter suites that depended on the removed action or on the sheet's layout.

- [ ] **Step 2: Lint**

Run: `mise run ci:lint`

Expected: clean. The most likely complaints are a `@Dependency` attribute with a blank line under it in `runSearchDebounce` (caught by `attribute_blank_lines.py`) and swiftformat wanting to reflow the deleted regions. Fix with `swiftformat .` and re-run.

- [ ] **Step 3: Manually drive the sheet**

Build and run the app on the simulator, open the documents filter sheet and confirm:

- The header's ellipsis menu holds Save (only with a saved view selected), Save as…, a separator, and a red Reset; Save and Reset are greyed out until something is modified.
- Typing in the search field reloads the list roughly a beat after you stop typing, and typing a longer query does not fire a request per character.
- Tapping Reset restores the saved view's filter — or clears everything under "All documents" — and reloads.
- There is no bar at the bottom of the sheet.

- [ ] **Step 4: Push the branch**

```bash
git push -u origin filter-sheet-ellipsis-menu
```

---

## Notes for the reviewer

Two decisions in Task 1 are load-bearing and easy to "simplify" into bugs:

1. **`runSearchDebounce` must not capture state.** If the sleep-and-send is replaced with a single effect that captures `state` and sends `delegate(.filterUpdated(...))` directly, `test_binding_searchValue_readsStateAtDelivery` fails: the effect would report the search type as it was when the key was pressed, not as it is 400ms later.
2. **The `.cancel` inside `runFilterUpdated` is not redundant with `cancelInFlight: true`.** `cancelInFlight` only collapses successive *keystrokes*. Without the cancel, a keystroke followed by a tap on any other control reloads the list twice, which `test_binding_searchValue_cancelledByExplicitChange` catches.
