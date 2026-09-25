# Offline Search Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the Offline list the same search bar the Documents list uses, so the two document lists stop looking different for the same gesture.

**Architecture:** The field and the cancel button are feature-agnostic; only the TCA plumbing around them is not. They move into `Components` as `SearchField` (styling) and `SearchBar` (field + animated cancel, driven by a `Binding` and closures). `DocumentSearchBarView` becomes a thin store wrapper over `SearchBar`, and `OfflineListView` uses `SearchBar` directly. The Offline list keeps its instant local filter — only the shell is shared.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-snapshot-testing, swift-testing (`@Suite`/`@Test`/`#expect`), Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-25-offline-design.md` — §1 only. §2–§4 shipped in PR #101.

**Branch:** `feat/offline-search`, cut from `feat/offline` at `abce0fe`. PR #101 is still open, so this stacks on it and is rebased onto `main` once #101 merges.

**One deliberate departure from the spec.** §1 says `OfflineSearchBarView` is the Offline list's equivalent of `DocumentSearchBarView`. It is not worth a type: `DocumentSearchBarView` exists to hold the explicit `searchTextBinding` that keeps the debounce honest, and the Offline list has no debounce to keep — its reducer has a `BindingReducer`, so `$store.searchText` is the binding. `OfflineListView` uses `SearchBar` directly instead.

## Global Constraints

- **Comments are `//` only.** Never `///`, never `/** */`, anywhere, including test helpers. Comment only what a future reader would otherwise stop and wonder about.
- **Every module owns its strings.** A key goes in `Modules/<Name>/Resources/Localizable.xcstrings`, in both `en` and `de`, with `"extractionState": "manual"`, keys sorted alphabetically. Two modules showing the same word each get their own key — the duplication is the design.
- **`@ViewAction` views send with `send`, never `store.send`.**
- **`git push` in this repo needs an explicit refspec.** `push.default = tracking`, and a branch created with `git checkout -b <new> origin/main` has its upstream set to `main` — so `git push origin <branch>` pushes to **main**. Always `git push origin HEAD:refs/heads/<branch>`.
- **Verify against the dev instance:** `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` before both `tuist generate` and `tuist test`. It is read at generate time.
- **The unit test command, in full:**
  ```bash
  export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
    'tuist test <Scheme> -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
     -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
  ```
- **`tuist test` leaves the workspace focused on the scheme it ran.** Regenerate before any `tuist build`, or it fails with `Supported platforms ... is empty`.
- **`mise run ci:lint` before pushing**, after `rm -rf build` — `build/` is excluded from SwiftLint as of PR #101, but a stale one still slows the run.
- **Re-recording a snapshot ends in `TEST FAILED`, and that is the success case.** Look at what was recorded before trusting it; a reference records whatever the code produced, bug included.

## Review Focus

Five ways this can go wrong that the happy path never exercises. Each has a test, in the task that owns the code.

1. **Cancel on the Offline list.** Nothing else clears that query — no commit, no filter, no results screen. Cancel must empty the text *and* drop the keyboard, or the user is stuck in a field with no way out. — Task 3
2. **The bar over an empty list.** The `if` that used to hide it is gone, so it now renders above nothing. It must still be there, and still typable. — Task 3
3. **A query that matches nothing.** The list empties; the field and the typed text must survive, or the query vanishes mid-search. — Task 3
4. **The field's inline `X` versus cancel.** `X` wipes the text and deliberately leaves the keyboard up; cancel puts it away. Two different affordances that must not collapse into one. — Task 1
5. **The extraction must not move the Documents list by a pixel.** Its committed snapshot references are the pin — if they still pass untouched, the refactor was behaviour-preserving. — Task 2

---

### Task 1: `SearchField` and `SearchBar` in Components

**Files:**
- Create: `Modules/Components/Field/Search/SearchField.swift`
- Create: `Modules/Components/Field/Search/SearchBar.swift`
- Modify: `Modules/Components/Resources/Localizable.xcstrings`
- Test: `Modules/ComponentsTests/Field/Search/SearchBarTests.swift`

**Interfaces:**
- Consumes: `Field(padding:input:)` from `Modules/Components/Field/Generic/Field.swift`; `LocalizedStringResource.cancel`, already in Components' catalogue
- Produces:
  - `public struct SearchField: View` — `init(isFocused: FocusState<Bool>.Binding, submitted: @escaping () -> Void, text: Binding<String>)`
  - `public struct SearchBar: View` — `init(text: Binding<String>, cancelled: @escaping () -> Void, dismissalCount: Int = 0, submitted: @escaping () -> Void = {})`
  - `LocalizedStringResource.search`, `LocalizedStringResource.clearSearch`

- [ ] **Step 1: Add the two strings Components does not own yet**

Components already has `cancel`. Copy `search` and `clearSearch` verbatim from `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, keeping the catalogue sorted:

```json
"clearSearch" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Suche löschen" } },
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Clear search" } }
  }
},
"search" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Suchen" } },
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Search" } }
  }
}
```

- [ ] **Step 2: Write the failing snapshot tests**

Create `Modules/ComponentsTests/Field/Search/SearchBarTests.swift`. These pin Review Focus 4 — the two buttons are different affordances and both have to be visible in the right states:

```swift
@testable import Components

import SnapshotTesting
import SwiftUI
import Testing

@MainActor
@Suite
struct SearchBarTests {

    // Nothing typed and nothing focused: no cancel button, and no inline clear inside the field.
    // The cancel button is still in the hierarchy, collapsed to zero width - see the note on
    // SearchBar - so this reference is what catches it being inserted with an `if` again.
    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: SearchBar(text: .constant(""), cancelled: {})
                .padding()
                .frame(width: 390),
            as: .image
        )
    }

    // Text present, not focused. Both ways out are on screen: the inline X inside the field, which
    // wipes the text and leaves the keyboard up, and the cancel button beside it, which finishes
    // the search.
    @Test
    func testSnapshot_withText() async throws {
        assertSnapshot(
            of: SearchBar(text: .constant("Invoice"), cancelled: {})
                .padding()
                .frame(width: 390),
            as: .image
        )
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: FAIL — `cannot find 'SearchBar' in scope`.

- [ ] **Step 4: Create `SearchField`**

`Modules/Components/Field/Search/SearchField.swift` is `DocumentSearchField` made `public`, with its comment updated so it no longer names the documents list:

```swift
import DesignTokens
import SwiftUI

// A list's search field, kept apart from `SearchBar` so the styling — the `Field`, the icon, the
// placeholder and every metric — lives in one place and the bar is only about what surrounds it.
public struct SearchField: View {

    public var body: some View {
        Field(padding: .x0) {
            HStack(spacing: .x0) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.m3Primary)
                    .padding(.leading, .x2 + .x3)
                // A search field, not prose: the observed default capitalised the first letter of
                // the query, which is not what anyone means when they type a tag's name.
                TextField(String(localized: .search), text: text)
                    .autocorrectionDisabled()
                    .focused(isFocused)
                    .padding(.leading, .x2)
                    .submitLabel(.search)
                    .textFieldStyle(.plain)
                    .textInputAutocapitalization(.never)
                    .onSubmit(submitted)
                if !text.wrappedValue.isEmpty {
                    Button {
                        text.wrappedValue = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.m3OnSurfaceVariant)
                    }
                    .accessibilityLabel(.clearSearch)
                    .buttonStyle(.plain)
                    .padding(.leading, .x2)
                    .padding(.trailing, .x2 + .x3)
                }
            }
        }
    }

    public init(
        isFocused: FocusState<Bool>.Binding,
        submitted: @escaping () -> Void,
        text: Binding<String>
    ) {
        self.isFocused = isFocused
        self.submitted = submitted
        self.text = text
    }

    private let isFocused: FocusState<Bool>.Binding

    private let submitted: () -> Void

    private let text: Binding<String>
}
```

- [ ] **Step 5: Create `SearchBar`**

`Modules/Components/Field/Search/SearchBar.swift`. The cancel button's comment is carried over verbatim — it records a measurement, not an opinion — and the focus reset it used to do at the call site moves inside:

```swift
import DesignTokens
import SwiftUI

// A search field and the way out of it. The field owns its own focus, so a caller supplies only
// the text and what finishing means; `dismissalCount` is for the callers that can finish a search
// from somewhere other than this button.
public struct SearchBar: View {

    public var body: some View {
        HStack(spacing: .x0) {
            SearchField(
                isFocused: $isFocused,
                submitted: submitted,
                text: text
            )
            // The field's own `X` wipes the text and leaves the user in the field with the keyboard
            // up, which is not a way out. Shown on content as well as on focus because a query that
            // survived a push still needs one.
            //
            // An icon rather than the word, with the tap target spelled out: the glyph is about
            // 15pt on its own, and this one sits a thumb's width from a field people are typing
            // into. The label is what VoiceOver announces and what the journey looks for.
            //
            // Always in the hierarchy, collapsed and faded out when there is nothing to cancel,
            // rather than inside an `if`. A list row does not run a transition on a structural
            // change: with the `if`, the button was inserted at full opacity on the same frame the
            // field started narrowing — it arrived before the space it arrives in existed, which
            // was measured frame by frame, not assumed. Width and opacity are ordinary animatable
            // values, so the two now move together.
            Button {
                isFocused = false
                cancelled()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.medium))
                    .foregroundStyle(Color.m3Primary)
                    .frame(width: .x5 + .x3, height: .x5 + .x3)
                    .contentShape(.rect)
            }
            .accessibilityHidden(!isCancelVisible)
            .accessibilityLabel(.cancel)
            .buttonStyle(.plain)
            .disabled(!isCancelVisible)
            .frame(width: isCancelVisible ? .x5 + .x3 : .x0)
            .opacity(isCancelVisible ? 1 : 0)
            .clipped()
        }
        // Keyed on the button rather than on focus: it is the button's presence that changes the
        // field's width, and text arriving without a focus change — a query that survived a push —
        // moves the same layout.
        .animation(.default, value: isCancelVisible)
        .onChange(of: dismissalCount) { isFocused = false }
    }

    public init(
        text: Binding<String>,
        cancelled: @escaping () -> Void,
        dismissalCount: Int = 0,
        submitted: @escaping () -> Void = {}
    ) {
        self.text = text
        self.cancelled = cancelled
        self.dismissalCount = dismissalCount
        self.submitted = submitted
    }

    private var isCancelVisible: Bool {
        isFocused || !text.wrappedValue.isEmpty
    }

    // Deliberately not raised on appear: the field is a row of a list rather than the only thing in
    // a sheet, and a list that takes the keyboard the moment it is shown hides what it exists to
    // show.
    @FocusState
    private var isFocused: Bool

    private let cancelled: () -> Void

    private let dismissalCount: Int

    private let submitted: () -> Void

    private let text: Binding<String>
}
```

- [ ] **Step 6: Run the tests — they record on the first run and pass on the second**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: the first run FAILS having written two new references under `Snapshots/ComponentsTests/SearchBarTests/`, because no reference existed. **Open both PNGs and look at them** before re-running: `testSnapshot_empty` must show a capsule field with a magnifying glass, the placeholder *Search*, and **no** buttons; `testSnapshot_withText` must show the text, the inline `xmark.circle.fill` inside the capsule, and the standalone `xmark` beside it. Then run again; expected PASS.

- [ ] **Step 7: Commit**

```bash
mise exec -- swiftformat --lint Modules/Components Modules/ComponentsTests
mise exec -- swiftlint --strict --quiet Modules/Components Modules/ComponentsTests
git add Modules/Components Modules/ComponentsTests Snapshots/ComponentsTests
git commit -m "feat: a search bar any list can use

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 2: The documents list uses the shared bar

The point of this task is that **nothing changes on screen**. `Snapshots/DocumentsFeatureTests/DocumentListViewTests/` holds four references showing the bar (`testSnapshot`, `testSnapshot_emptyResult`, `testSnapshot_searching`, `testSnapshot_searchingWithAnEmptyLibrary`, plus the dark-mode pair). They must pass **untouched** — that is Review Focus 5, and it is the whole test for this task.

**Files:**
- Delete: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchField.swift`
- Modify: `Modules/DocumentsFeature/DocumentSearch/DocumentSearchBarView.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `SearchBar(text:cancelled:dismissalCount:submitted:)` from Task 1

- [ ] **Step 1: Rewrite `DocumentSearchBarView` as a wrapper**

Everything above `init` is replaced; `searchTextBinding` and the store property stay exactly as they are, because the reducer has no `BindingReducer` and a bindable write would skip the debounce:

```swift
import Components
import ComposableArchitecture
import SwiftUI

// The first row of the documents list in both modes, so the way out of search is always where the
// way in was.
@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchBarView: View {

    var body: some View {
        SearchBar(
            text: searchTextBinding,
            cancelled: { send(.cancelButtonTapped) },
            dismissalCount: store.dismissalCount,
            submitted: { send(.submitted) }
        )
    }

    init(store: StoreOf<DocumentSearchReducer>) {
        self.store = store
    }

    let store: StoreOf<DocumentSearchReducer>

    // An explicit binding rather than `$store.searchText`: the reducer has no `BindingReducer`, so
    // a bindable write would set the text straight into state and never run the debounce. Redundant
    // writes are dropped for the reason DocumentFilterView gives — SwiftUI makes one on appear and
    // one on teardown, and each would cost a 400ms debounce and a request for a search that had not
    // changed.
    var searchTextBinding: Binding<String> {
        Binding(
            get: { store.searchText },
            set: {
                guard $0 != store.searchText else {
                    return
                }
                send(.searchTextChanged($0))
            }
        )
    }
}

#Preview {
    DocumentSearchBarView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                DocumentSearchReducer()
            }
        )
    )
}
```

- [ ] **Step 2: Delete the old field and its now-dead strings**

```bash
git rm Modules/DocumentsFeature/DocumentSearch/DocumentSearchField.swift
```

`search` and `clearSearch` were used only by that file — confirm, then remove both keys from `Modules/DocumentsFeature/Resources/Localizable.xcstrings`:

```bash
grep -rn "\.search\b\|\.clearSearch\b" --include="*.swift" Modules/DocumentsFeature
```

Expected: only `CancelID.search` hits, which is an effect id and unrelated. If any `Text(.search)` or `.accessibilityLabel(.clearSearch)` remains, leave the key it needs.

- [ ] **Step 3: Run the documents tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS, and `git status --short Snapshots/` prints **nothing**. A changed reference here means the extraction moved something and is a bug in Task 1, not a reference to re-record.

- [ ] **Step 4: Commit**

```bash
mise exec -- swiftformat --lint Modules/DocumentsFeature
git add -A Modules/DocumentsFeature
git commit -m "refactor: the documents search bar is the shared one

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

---

### Task 3: The Offline list gets the bar

**Files:**
- Modify: `Modules/OfflineFeature/OfflineList/OfflineListView.swift`
- Modify: `Modules/OfflineFeature/OfflineList/OfflineListReducer.swift`
- Test: `Modules/OfflineFeatureTests/OfflineList/OfflineListReducerTests.swift`
- Test: `Modules/OfflineFeatureTests/OfflineList/OfflineListViewTests.swift`

**Interfaces:**
- Consumes: `SearchBar(text:cancelled:dismissalCount:submitted:)` from Task 1
- Produces: `OfflineListReducer.Action.View.searchCancelled`

- [ ] **Step 1: Write the failing reducer test**

Review Focus 1. Cancel is the only thing that finishes a search here — there is no commit, no filter and no results screen — so it has to empty the query and rebuild the rows. In `OfflineListReducerTests.swift`:

```swift
    // The only way a search ends on this list: there is no commit, no filter and no results screen
    // to leave behind. The keyboard half belongs to SearchBar, which drops focus before calling
    // this; the query half is the reducer's.
    @Test
    func test_cancellingTheSearchClearsTheQueryAndRestoresEveryRow() async {
        let server = Server.testValue(id: "cancelling-the-search")

        @Shared(.offlineDocuments(server))
        var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = [
            .testValue(document: .testValue(content: nil, id: 1, title: "Invoice")),
            .testValue(document: .testValue(content: nil, id: 2, title: "Warranty")),
        ]

        let store = TestStore(initialState: OfflineListReducer.State(server: server)) {
            OfflineListReducer()
        }

        await store.send(.binding(.set(\.searchText, "Invoice"))) {
            $0.searchText = "Invoice"
            $0.rows = [$0.rows[0]]
        }

        await store.send(.view(.searchCancelled)) {
            $0.searchText = ""
            $0.rebuildRows()
        }
    }
```

- [ ] **Step 2: Run it to verify it fails**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test OfflineFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: FAIL — `type 'OfflineListReducer.Action.View' has no member 'searchCancelled'`.

- [ ] **Step 3: Add the action**

In `OfflineListReducer.swift`, add `case searchCancelled` to the `View` enum (alphabetically, after `onRefresh`), and handle it in the `.view` switch beside the other view actions:

```swift
                case .searchCancelled:
                    state.searchText = ""
                    state.rebuildRows()
                    return .none
```

- [ ] **Step 4: Run it to verify it passes**

Same command as Step 2. Expected: PASS.

- [ ] **Step 5: Put the bar in the list**

In `OfflineListView.swift`, the search bar becomes the first row of the `List` and the `if`/`else` around `.searchable` goes. Replace `list` and `body` with:

```swift
    private var list: some View {
        List {
            // Outside any branch on whether there is anything to search: the Documents list keeps
            // its bar over an empty list too, and a row that comes and goes takes the query with
            // it. It scrolls with the rows rather than hiding above them, which is what `.searchable`
            // did and what made the two lists look unrelated.
            SearchBar(
                text: $store.searchText,
                cancelled: { send(.searchCancelled) }
            )
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .padding(.bottom, .x3)
            .padding(.horizontal, .x3)
            .padding(.top, .x3)
            ForEach(store.scope(state: \.rows, action: \.rows)) { store in
                OfflineRowView(store: store)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                    .listRowSeparator(.hidden)
                    .padding(.x3)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .listStyle(.plain)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.offline)
        .onDisappear { send(.onDisappear) }
        .overlay(emptyListView())
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        // Dragging the rows is as much a way of saying "let me see them" as scrolling a sheet was.
        .scrollDismissesKeyboard(.immediately)
        .task { await send(.onAppear).finish() }
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            list
        } destination: { store in
            switch store.case {
            case let .documentDetail(store):
                DocumentDetailView(store: store)
            }
        }
    }
```

The `// Its own NavigationStack rather than `Searchable`'s` comment above `body` goes with it: `Searchable` is no longer involved, so the note no longer explains anything.

- [ ] **Step 6: Check the view tests — do not add one**

Review Focus 2 and 3 are already covered by references that exist, and both will change in this task:

- `testSnapshot_empty` renders a list with no offline documents. Under the old `if` the bar was withheld there; it must now appear. That reference **is** the pin for Review Focus 2.
- `testSnapshot_noSearchResults` sets `searchText` to a query matching nothing. The bar and the typed text must survive into the reference. That is Review Focus 3.

No new test is warranted — a third snapshot of the same two states would pin nothing the existing two do not. `OfflineListReducer.State.testValue(server:)` takes only a server, so a test wanting specific documents writes them through `@Shared(.offlineDocuments(server))` the way `testSnapshot_noSearchResults` does.

Add the comment above `testSnapshot_empty` saying what it now guards, since its job has changed:

```swift
    // Also the reference that catches the search bar being withheld again: it used to be attached
    // only when there was something to search, which is exactly the state this renders.
```

- [ ] **Step 7: Re-record and look**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise run snapshots:record OfflineFeature
mise run snapshots:diff
```

The run ends in `TEST FAILED`; that is the success case. Then **open every changed reference**: the bar must be the first row, the field must read *Search*, a query with no matches must keep both the bar and the typed text, and the empty state's card must sit below the bar rather than over it.

- [ ] **Step 8: Full suite, lint, commit**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- tuist generate --no-open
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test "Less Paper" -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   --skip-ui-tests -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
rm -rf build && mise run format && mise run ci:lint
git add -A
git commit -m "feat: the documents search bar on the Offline list

Co-Authored-By: Claude Opus 5 <noreply@anthropic.com>"
```

- [ ] **Step 9: The UI journeys**

`DocumentSearchJourneyTests` drives the documents search bar, and `UITestSupport/Screens/DocumentListScreen.swift` carries a note that nothing there is `.searchable`. Neither should need changing, but both touch the code this plan moved:

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c \
  'tuist test "Less Paper" -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing \
   --skip-unit-tests -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: PASS.
