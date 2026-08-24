# Document-Link Custom Field Picker Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make `documentlink` custom fields filterable by giving the `contains` operator a searchable, multi-select document picker.

**Architecture:** The condition editor is promoted from a plain view driven by parent state into `CustomFieldQueryAtomEditorReducer` with its own store, so the picker — which debounces, fetches and can fail — hangs off it as a `@Presents` destination instead of putting network state in the tree reducer. Search reuses `GetDocumentsUseCase` with `FilterRuleType.title`, adding no API surface.

**Tech Stack:** Swift 6.1, SwiftUI, ComposableArchitecture (`@Reducer`, `@ObservableState`, `@Presents`, `@ViewAction`), Tagged, Swift Testing, swift-snapshot-testing, Tuist.

## Global Constraints

- **Comments:** only `//`, never `///` or `/** */`, and only when a future reader would otherwise stop and wonder why. See `AGENTS.md`.
- **`@ViewAction` views call `send(…)`, never `store.send(…)`.** Views without the macro use `store.send(.view(…))`.
- **Confirmations use `PopupPresenter` + `ConfirmationPopupView`.** Not expected to arise here.
- **No blank line between an attribute and its declaration** (`mise/scripts/attribute_blank_lines.py --check`).
- **Lint gate:** `mise ci:lint`. Max line width 140.
- **Localized strings** are keys in `Shared/Framework/Resources/Localizable.xcstrings` with `en` and `de` units, both `"state": "translated"`, `"extractionState": "manual"`, inserted in case-insensitive alphabetical order. Xcode generates the symbol; there is no Swift file to edit.
- **Search sends `title__icontains`, not `title_search`.** Verified identical with `ordering=-created`; `FilterRuleType.title` already produces it.
- **Document ids serialize as JSON numbers** inside the `contains` array. A bare int is a 400.
- **Run tests with** `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`. Selective testing skips unchanged targets and will silently not run your new tests.
- **Snapshots:** `record: .environment` defaults to `.missing`. The **first** run after adding a snapshot test records the reference and fails; the **second** passes. Both runs are steps. To re-record an existing snapshot, delete the `.png` and run twice — `SNAPSHOT_RECORD` is a scheme variable and does not pick up a shell export.

---

### Task 1: Thread `server` into the cards reducer

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/CustomFieldQueryCardsReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/CustomFieldQueryCardsReducer+TestValue.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift:190-193`

**Interfaces:**
- Produces: `CustomFieldQueryCardsReducer.State.server: Server`, set from `DocumentFilterReducer.State.server`. `testValue(…)` gains `server: Server = .testValue()`.

`CustomFieldQueryCardsReducer.State` has no `server` today. The picker needs one to call `getDocuments`, and it can only come from the filter sheet.

- [ ] **Step 1: Add `let server: Server` to `State`**, as the last stored property, and add it to the memberwise `init` after `query`.

- [ ] **Step 2: Pass it at the call site**

```swift
state.destination = .customFieldQuery(CustomFieldQueryCardsReducer.State(
    fields: state.customFields,
    query: state.input.customFieldQuery,
    server: state.server
))
```

- [ ] **Step 3: Add `server: Server = .testValue()` to `CustomFieldQueryCardsReducer.State.testValue`** and forward it.

- [ ] **Step 4: Run the tests**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`
Expected: PASS with no snapshot changes — `server` is not rendered.

- [ ] **Step 5: Commit** — `git commit -m "refactor: give the custom field query sheet its server"`

### Task 2: Extract `CustomFieldQueryAtomEditorReducer`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentFilter/CustomField/Cards/AtomEditor/CustomFieldQueryAtomEditorReducer.swift`
- Create: `…/AtomEditor/CustomFieldQueryAtomEditorReducer+Effect.swift`
- Create: `…/AtomEditor/CustomFieldQueryAtomEditorReducer+TestValue.swift`
- Move: `…/Cards/CustomFieldQueryAtomEditorView.swift` → `…/Cards/AtomEditor/`
- Move: `…/Cards/CustomFieldQuerySelectOptionsView.swift` → `…/Cards/AtomEditor/`
- Modify: `…/Cards/CustomFieldQueryCardsReducer.swift`, `…/Cards/CustomFieldQueryCardsView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/CustomField/Cards/AtomEditor/CustomFieldQueryAtomEditorReducerTests.swift`
- Modify: `…/Cards/CustomFieldQueryCardsReducerTests.swift`, `…/Cards/CustomFieldQueryAtomEditorViewTests.swift`

**Interfaces:**
- Consumes: `State.server` from Task 1.
- Produces:

```swift
@Reducer
public struct CustomFieldQueryAtomEditorReducer: Sendable {
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case destination(PresentationAction<Destination.Action>)
        case view(View)

        @CasePathable
        public enum Delegate: Equatable {
            case atomChanged(CustomFieldQuery.Atom)
        }

        public enum View: Equatable {
            case closeButtonTapped
            case fieldChanged(CustomField.Id)
            case operatorChanged(CustomFieldQueryOperator)
            case optionsTapped
            case optionToggled(String)
            case valueChanged(JSONValue)
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable, Sendable {
        var atom: CustomFieldQuery.Atom
        var isSelectingOptions = false
        let fields: IdentifiedArrayOf<CustomField>
        let path: CustomFieldQuery.Path
        let server: Server

        public var id: CustomFieldQuery.Path { path }

        var field: CustomField? { fields[id: atom.field] }
    }
}
```

`CustomFieldQueryCardsReducer` loses `editorFieldChanged`, `editorOperatorChanged`, `editorValueChanged`, `editorOptionToggled`, `editorOptionsTapped`, `editorOptionsDismissed` and its `State.Editor` type; `editor` becomes `@Presents var editor: CustomFieldQueryAtomEditorReducer.State?`. `editorDismissed` goes too — dismissal is `.editor(.dismiss)`.

It keeps `rowTapped`, which now builds the child state, and handles one new case:

```swift
case let .editor(.presented(.delegate(.atomChanged(atom)))):
    guard let path = state.editor?.path else {
        return .none
    }
    state.query[path] = .atom(atom)
    return .send(.delegate(.filterUpdated(state.query.pruned)))
```

The atom is still addressed by path rather than bound into the tree, for the reason already commented there: the sheet outlives a delete of the row that opened it.

- [ ] **Step 1: Write the failing editor-reducer test**

```swift
@MainActor
@Suite(.dependencies())
struct CustomFieldQueryAtomEditorReducerTests {

    private static let fields = IdentifiedArray(uniqueElements: [CustomField].previewValue)

    private static let store = { (state: CustomFieldQueryAtomEditorReducer.State) in
        TestStore(initialState: state) { CustomFieldQueryAtomEditorReducer() }
    }

    private static func editing(_ atom: CustomFieldQuery.Atom) -> CustomFieldQueryAtomEditorReducer.State {
        .testValue(atom: atom, fields: fields)
    }

    @Test
    func changingTheFieldResetsAnOperatorTheNewTypeRejects() async {
        let store = Self.store(Self.editing(.init(field: 1, op: .icontains, value: .string("a"))))

        await store.send(.view(.fieldChanged(3))) {
            $0.atom = .init(field: 3, op: .exists, value: .bool(true))
        }
        await store.receive(\.delegate.atomChanged, .init(field: 3, op: .exists, value: .bool(true)))
    }

    @Test
    func switchingASelectFieldToEqualToSeedsTheFirstOption() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .exists, value: .bool(true))))

        await store.send(.view(.operatorChanged(.exact))) {
            $0.atom = .init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou"))
        }
        await store.receive(\.delegate.atomChanged, .init(field: 5, op: .exact, value: .string("aqgT3m4XZw8aw3Ou")))
    }

    @Test
    func togglingAnOptionAddsAndRemovesIt() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .in, value: .array([]))))

        await store.send(.view(.optionToggled("aqgT3m4XZw8aw3Ou"))) {
            $0.atom = .init(field: 5, op: .in, value: .array([.string("aqgT3m4XZw8aw3Ou")]))
        }
        await store.receive(
            \.delegate.atomChanged,
            .init(field: 5, op: .in, value: .array([.string("aqgT3m4XZw8aw3Ou")]))
        )
    }

    @Test
    func openingTheOptionSheet() async {
        let store = Self.store(Self.editing(.init(field: 5, op: .in, value: .array([]))))

        await store.send(.view(.optionsTapped)) {
            $0.isSelectingOptions = true
        }
    }
}
```

- [ ] **Step 2: Run and confirm it fails to compile.** `cannot find 'CustomFieldQueryAtomEditorReducer' in scope`.

- [ ] **Step 3: Create the editor reducer.** Move the six action bodies from `CustomFieldQueryCardsReducer` verbatim, replacing `state.editor?.atom` with `state.atom` and `.applyEditor(&state)` with `.send(.delegate(.atomChanged(state.atom)))`. Keep the `setField` / `setOperator(_:field:)` calls exactly as they are — the seeding behaviour is not being changed here.

- [ ] **Step 4: Rewire the cards reducer and view.** `editor` becomes `@Presents`; add `.ifLet(\.$editor, action: \.editor) { CustomFieldQueryAtomEditorReducer() }`; the view presents it with `$store.scope(state: \.editor, action: \.editor)` instead of the hand-rolled `editorBinding`.

- [ ] **Step 5: Move the cards-reducer tests that no longer belong.** `CustomFieldQueryCardsSelectOptionTests` moves wholesale into the editor test file, restated against the editor's own actions. What stays in the cards tests: the tree operations, and `rowTapped` now asserting `$0.editor = CustomFieldQueryAtomEditorReducer.State(...)`.

- [ ] **Step 6: Update the editor view.** It gains `@ViewAction(for: CustomFieldQueryAtomEditorReducer.self)` and a `store`, replacing `editor:`/`fields:`/`onViewAction:`. `CustomFieldQuerySelectOptionsView` keeps taking plain values but its `onViewAction` closure now takes `CustomFieldQueryAtomEditorReducer.Action.View`.

- [ ] **Step 7: Update the editor snapshot tests** to build a store rather than passing `editor:`, then run twice.

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing`
Expected: PASS, and **the existing editor snapshots must be byte-identical** — this task is a move, not a redesign. If any `.png` changes, that is a bug in the move.

- [ ] **Step 8: Commit** — `git commit -m "refactor: give the condition editor its own reducer"`

### Task 3: The document picker reducer

**Files:**
- Create: `…/Cards/AtomEditor/DocumentPicker/CustomFieldQueryDocumentPickerReducer.swift`
- Create: `…/DocumentPicker/CustomFieldQueryDocumentPickerReducer+Effect.swift`
- Create: `…/DocumentPicker/CustomFieldQueryDocumentPickerReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/CustomField/Cards/AtomEditor/DocumentPicker/CustomFieldQueryDocumentPickerReducerTests.swift`

**Interfaces:**
- Produces:

```swift
@ObservableState
public struct State: Equatable, Sendable {
    var documents: IdentifiedArrayOf<Document> = []
    var isLoading = false
    var searchText = ""
    var selection: IdentifiedArrayOf<Document> = []
    let server: Server

    // Selected documents pin above the results: without this, selecting a document and then
    // searching for something else makes it vanish from the list — still in the query, but no
    // longer visible or removable.
    var rows: IdentifiedArrayOf<Document> {
        var rows = selection
        for document in documents where rows[id: document.id] == nil {
            rows.append(document)
        }
        return rows
    }
}
```
Delegate: `case selectionChanged([Document.Id])`. View actions: `closeButtonTapped`, `documentTapped(Document.Id)`. Internal: `searchDebounced`, `documentsLoaded(IdentifiedArrayOf<Document>)`, `error(Error)`. Binding on `searchText`.

- [ ] **Step 1: Write the failing tests**

```swift
@MainActor
@Suite(.dependencies())
struct CustomFieldQueryDocumentPickerReducerTests {

    private static let puky = Document.testValue(id: 10, title: "Puky-Locked")
    private static let invoice = Document.testValue(id: 11, title: "Invoice")

    // One request for a burst of keystrokes.
    @Test
    func searchIsDebounced() async {
        let clock = TestClock()
        let store = TestStore(initialState: .testValue()) {
            CustomFieldQueryDocumentPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { @Sendable _, _ in .testValue(count: 1, results: [Self.puky]) }
        }

        await store.send(.binding(.set(\.searchText, "pu"))) { $0.searchText = "pu" }
        await store.send(.binding(.set(\.searchText, "puk"))) { $0.searchText = "puk" }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced) { $0.isLoading = true }
        await store.receive(\.documentsLoaded) {
            $0.documents = [Self.puky]
            $0.isLoading = false
        }
    }

    @Test
    func tappingADocumentSelectsAndDeselectsIt() async {
        let store = TestStore(initialState: .testValue(documents: [Self.puky])) {
            CustomFieldQueryDocumentPickerReducer()
        }

        await store.send(.view(.documentTapped(10))) { $0.selection = [Self.puky] }
        await store.receive(\.delegate.selectionChanged, [10])

        await store.send(.view(.documentTapped(10))) { $0.selection = [] }
        await store.receive(\.delegate.selectionChanged, [])
    }

    // The whole reason `selection` holds documents rather than ids.
    @Test
    func aSelectedDocumentStaysListedWhenTheQueryNoLongerMatchesIt() async {
        let state = CustomFieldQueryDocumentPickerReducer.State.testValue(
            documents: [Self.invoice],
            selection: [Self.puky]
        )

        #expect(state.rows.map(\.id) == [10, 11])
    }

    @Test
    func aSelectedDocumentIsNotListedTwice() async {
        let state = CustomFieldQueryDocumentPickerReducer.State.testValue(
            documents: [Self.puky, Self.invoice],
            selection: [Self.puky]
        )

        #expect(state.rows.map(\.id) == [10, 11])
    }

    @Test
    func selectionIsEmittedSorted() async {
        let store = TestStore(initialState: .testValue(documents: [Self.invoice], selection: [Self.puky])) {
            CustomFieldQueryDocumentPickerReducer()
        }

        await store.send(.view(.documentTapped(11))) { $0.selection = [Self.puky, Self.invoice] }
        await store.receive(\.delegate.selectionChanged, [10, 11])
    }

    // A failed search must not throw away what the user already picked.
    @Test
    func aFailedSearchToastsAndKeepsTheSelection() async {
        struct Failure: Error {}
        let clock = TestClock()
        let store = TestStore(initialState: .testValue(selection: [Self.puky])) {
            CustomFieldQueryDocumentPickerReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.getDocuments.execute = { @Sendable _, _ in throw Failure() }
        }

        await store.send(.binding(.set(\.searchText, "x"))) { $0.searchText = "x" }
        await clock.advance(by: .milliseconds(400))
        await store.receive(\.searchDebounced) { $0.isLoading = true }
        await store.receive(\.error) { $0.isLoading = false }
        #expect(store.state.selection == [Self.puky])
    }
}
```

- [ ] **Step 2: Run and confirm failure.**

- [ ] **Step 3: Implement.** The search effect mirrors `DocumentFilterReducer+Effect.runSearchDebounce`:

```swift
static func runSearch(_ state: State) -> Self {
    @Dependency(\.getDocuments) var getDocuments

    let searchText = state.searchText
    let server = state.server

    return .run { send in
        let output = try await getDocuments.execute(
            GetDocumentsInput(
                // `title__icontains`, which is what the web's `title_search` resolves to.
                filterRules: searchText.isEmpty ? [] : [.init(ruleType: .title, value: searchText)],
                sortDirection: .descending,
                sortField: .created
            ),
            server
        )
        await send(.documentsLoaded(IdentifiedArray(uniqueElements: output.results)))
    } catch: { error, send in
        await send(.error(error))
    }
    .cancellable(id: CancelID.search, cancelInFlight: true)
}
```

An empty query lists recent documents rather than nothing. `.error` returns `.toast(error)` and clears `isLoading`. The debounce effect sleeps 400ms then sends `.searchDebounced`, `.cancellable(id: CancelID.searchDebounce, cancelInFlight: true)`.

- [ ] **Step 4: Run and confirm pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat: search documents for a document-link condition"`

### Task 4: The picker view, wired into the editor

**Files:**
- Create: `…/DocumentPicker/CustomFieldQueryDocumentPickerView.swift`
- Modify: `…/AtomEditor/CustomFieldQueryAtomEditorReducer.swift` (add the destination)
- Modify: `…/AtomEditor/CustomFieldQueryAtomEditorView.swift`
- Test: `…/DocumentPicker/CustomFieldQueryDocumentPickerViewTests.swift`

**Interfaces:**
- Consumes: Task 3's reducer, Task 2's editor.
- Produces: `CustomFieldQueryAtomEditorReducer.Destination` with `case documentPicker(CustomFieldQueryDocumentPickerReducer)`, and view action `documentPickerTapped`.

The editor routes `.array` by data type now — `documentlink` opens the picker, everything else keeps the option sheet:

```swift
case .array:
    switch field?.dataType {
    case .documentLink:
        documentLinkValue()
    default:
        selectOptions()
    }
```

`documentLinkValue()` is a `Field(.value)` showing one capsule per resolved title, `Any` when empty, tapping sends `.documentPickerTapped`. Opening the picker seeds its `selection` from the atom's ids by resolving them (Task 5). On `selectionChanged`, the editor writes `.array(ids.map { .number(Double($0.rawValue)) })` into the atom and emits `atomChanged`.

- [ ] **Step 1: Write the failing snapshot tests** — arguments `("empty", [], []), ("results", [puky, invoice], []), ("selectedPinned", [invoice], [puky]), ("noResults", [], []) with searchText "zzz", ("loading", [], [])`, each asserting `CustomFieldQueryDocumentPickerView` at `.iPhone12`. Declare the fixtures at **file scope**, not as statics on the `@MainActor` suite — a `@Test` `arguments:` expression is evaluated outside that isolation.
- [ ] **Step 2: Run twice** — first records, second passes.
- [ ] **Step 3: Implement the view.** `Sheet(isScrollingEnabled: false, padding: .x0)` + `SheetHeader(title: .documents, left: closeButton)`, then `Searchable { List(store.rows) { … } … .searchable(text: $store.searchText) }`, rows carrying `checkmark.circle.fill`/`circle` and `Text(document.title)` over the created date in `.caption`, styled exactly like `DocumentFilterGenericValueListView`. `ContentUnavailableView { EmptyListView(systemImage: "tray") }` when `rows` is empty.
- [ ] **Step 4: Run and confirm pass. Inspect the snapshots** — particularly `selectedPinned`, which is the behaviour this variant turns on.
- [ ] **Step 5: Commit** — `git commit -m "feat: pick documents for a document-link condition"`

### Task 5: Resolve ids to titles, and summarise as a count

**Files:**
- Modify: `…/AtomEditor/CustomFieldQueryAtomEditorReducer.swift` and `+Effect.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/CustomField/CustomFieldQuery+Summary.swift`
- Test: `…/AtomEditor/CustomFieldQueryAtomEditorReducerTests.swift`, `…/CustomField/CustomFieldQuerySummaryTests.swift`

**Interfaces:**
- Produces: `State.linkedDocuments: IdentifiedArrayOf<Document>` on the editor, plus action `linkedDocumentsLoaded(IdentifiedArrayOf<Document>)`.

- [ ] **Step 1: Write the failing summary tests**

```swift
@Test
func aDocumentLinkConditionSummarisesAsACount() {
    let fields: IdentifiedArrayOf<CustomField> = [.testValue(dataType: .documentLink, id: 6, name: "Link")]
    let query = CustomFieldQuery.atom(.init(field: 6, op: .contains, value: .array([.number(10), .number(11)])))

    expectNoDifference(query.summary(fields: fields), "Link contains 2 documents")
}

@Test
func aSingleLinkedDocumentReadsInTheSingular() {
    let fields: IdentifiedArrayOf<CustomField> = [.testValue(dataType: .documentLink, id: 6, name: "Link")]
    let query = CustomFieldQuery.atom(.init(field: 6, op: .contains, value: .array([.number(10)])))

    expectNoDifference(query.summary(fields: fields), "Link contains 1 document")
}
```

- [ ] **Step 2: Run and confirm failure** — it currently renders `Link contains 10, 11`.

- [ ] **Step 3: Implement** in `valueSummary(field:)`: when the field's `dataType` is `.documentLink` and the value is an array, return `String(localized: .numberOfDocuments(elements.count))`. That key already exists and is pluralised (`%ld document` / `%ld documents`), so no catalogue change is needed.

- [ ] **Step 4: Write the failing resolution test**

```swift
@Test
func openingALinkConditionResolvesItsDocumentTitles() async {
    let puky = Document.testValue(id: 10, title: "Puky-Locked")
    let store = TestStore(
        initialState: .testValue(atom: .init(field: 6, op: .contains, value: .array([.number(10)])))
    ) {
        CustomFieldQueryAtomEditorReducer()
    } withDependencies: {
        $0.getDocumentsByIds.execute = { @Sendable _, _ in .testValue(count: 1, results: [puky]) }
    }

    await store.send(.view(.onAppear))
    await store.receive(\.linkedDocumentsLoaded) { $0.linkedDocuments = [puky] }
}
```

- [ ] **Step 5: Implement.** `.onAppear` fires `runResolveLinkedDocuments` when the atom is a documentlink with a non-empty array; it calls `getDocumentsByIds` with the ids. An id that does not come back has no entry, and the capsule renders `#10` for it.

- [ ] **Step 6: Run and confirm pass.**
- [ ] **Step 7: Commit** — `git commit -m "feat: show linked document titles on a document-link condition"`

### Task 6: Verify end to end and open the PR

- [ ] **Step 1:** `mise ci:lint` — expect clean.
- [ ] **Step 2:** `tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing` and `tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing` — expect PASS.
- [ ] **Step 3: Exercise it against the live server.** Create a documentlink custom field on the dev instance, build a `Link contains <documents>` condition in the simulator, and confirm the request carries `custom_field_query=["AND",[[<id>,"contains",[<docIds>]]]]` and returns 200. Delete the field afterwards.
- [ ] **Step 4:** Push and open the PR against `main` with the `TestFlight` label. Base it on `feat/custom-field-filter-ui-cards` conceptually but target `main`, since CI only triggers on PRs to `main`.

---

## Self-Review

**Spec coverage.** `title_search` → `title__icontains` decision → Task 3 Step 3. Value shape as numbers → Task 4. Editor extraction → Task 2. Picker with debounce, empty-query-lists-recent, failures toasting → Task 3. Selection pinning → Task 3 (`rows`) and Task 4's `selectedPinned` snapshot. Id→title resolution and the `#10` fallback → Task 5. Count summary → Task 5. `server` threading, which the spec's architecture implies but does not call out → Task 1.

**Placeholders.** None: every code step carries code, and the two view tasks name the exact components and fixtures.

**Type consistency.** `CustomFieldQueryAtomEditorReducer.State` uses `atom`/`fields`/`path`/`server`/`isSelectingOptions`/`linkedDocuments` throughout; the picker uses `documents`/`selection`/`rows`/`searchText`/`isLoading`. `atomChanged(CustomFieldQuery.Atom)` is defined in Task 2 and consumed in Tasks 4 and 5. `selectionChanged([Document.Id])` is defined in Task 3 and consumed in Task 4.
