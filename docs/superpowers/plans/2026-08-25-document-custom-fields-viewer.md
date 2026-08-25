# Read-only Custom Fields Viewer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a read-only Custom fields section to the document viewer, reachable from the document detail toolbar and the row context menu, with document links you can drill into and back out of.

**Architecture:** A fourth `DocumentViewerSection` case, plus a `DocumentCustomFieldsReducer`/`View` pair scoped into `DocumentViewerReducer` the way `metadata` and `notes` already are. Drilling into a link appends to a `StackState` owned by the *viewer*, so no element contains a stack and the state stays non-recursive.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing, Swift Testing, swift-snapshot-testing.

## Execution notes

Written before implementation, corrected after it.

**Task 5 is superseded.** It built an in-sheet `NavigationStack` over a `StackState` the viewer
owned, chosen to avoid a recursive reducer. That was unnecessary: a link now presents the whole
linked document as a modal `DocumentDetailView`. The recursion Swift permits; only the `Equatable`
conformance needs the hand-written `extension DocumentViewerReducer.Destination.State: Equatable {}`
that every Destination in this codebase carries, and without it the compiler blames `State` with no
note naming the cause.

The `NavigationStack` also cost what it was worth: it has no intrinsic height, so it collapsed to a
blank sheet inside the sheet's `ScrollView`, needed explicit sizing, and painted white over
`m3Surface`. All three went with it.

**Task 3's rendering changed twice after review.** Links are one `Field` per linked document with a
trailing chevron, in the same card as every other field — not capsules, and not stacked inside a
single `Field`, which collides with its border because `Field` offsets its input for one line.

**Spec:** [2026-08-25-document-custom-fields-viewer-design.md](../specs/2026-08-25-document-custom-fields-viewer-design.md)

## Global Constraints

- **Comments:** Only `//`. Never `///`, never `/** */`. Comment only when a future reader would otherwise stop and wonder why — never restate the code. (`AGENTS.md`)
- **`@ViewAction` views send with `send`, never `store.send`.** (`AGENTS.md`)
- **Confirmations go through `ConfirmationPopupView`** — not relevant here, but no `.alert`/`.confirmationDialog` may be introduced.
- **Unit tests** use Swift Testing (`@Suite`, `@Test`, `#expect`, `expectNoDifference`) with the `.dependencies()` trait from `TestSupport`.
- **Snapshot tests** follow `DocumentFormCustomFieldsViewTests`, with `.snapshots(record: .environment)` and `.tags(.snapshotTests)`. Record with `TEST_RUNNER_SNAPSHOT_RECORD=all`.
- **Localised strings** live in `Shared/Framework/Resources/Localizable.xcstrings`, `version` 1.1, `sourceLanguage` en. Every new key needs both `en` and `de` with `"state": "translated"`.
- **Run tests** with `mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro"`. After editing `Tuist/ProjectDescriptionHelpers/`, regenerate first — no such edit is expected here.
- **Definitions** come from `@Shared(.customFields(server))`. Never fetch them.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer.swift` | State, link resolution, the link-tapped delegate. |
| `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer+Effect.swift` | The `getDocumentsByIds` effect. |
| `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer+TestValue.swift` | `testValue` factory, matching the sibling reducers. |
| `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsView.swift` | Rendering: metadata-style rows plus link capsules. |
| `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldValueDisplayTests.swift` | Formatting per data type. |
| `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldsReducerTests.swift` | Resolution, delegate, push/pop. |
| `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldsViewTests.swift` | Snapshots. |

**Modified:**

| File | Change |
|---|---|
| `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift` | Add `displayValue(field:)`. |
| `Modules/DocumentsFeature/DocumentViewer/DocumentViewerSection.swift` | Add `case customFields`, its label and icon. |
| `Modules/DocumentsFeature/DocumentViewer/DocumentViewerReducer.swift` | Scope the new reducer, own the stack, handle the delegate, extend `isContentScrollable`. |
| `Modules/DocumentsFeature/DocumentViewer/DocumentViewerView.swift` | Render the section, wrap it in a `NavigationStack`, title pushed screens. |
| `Shared/Framework/Resources/Localizable.xcstrings` | Add `yes` and `no`. |

**Note on placement:** the new folder sits beside `DocumentMetadata/` and `DocumentViewer/`, not inside `DocumentForm/`. It belongs to the viewer, and the only thing it borrows from the form is `DocumentFormCustomFieldValue`, which is internal to the module.

---

## Task 1: Read-only value formatting

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift`
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldValueDisplayTests.swift`

**Interfaces:**
- Consumes: `DocumentFormCustomFieldValue` (internal to `DocumentsFeature`), `CustomField`, `CustomFieldExtraData.selectOptions`.
- Produces: `func displayValue(field: CustomField) -> String?` — `nil` for a document link, whose rendering is a row of capsules rather than a string, and `nil` for an empty value so `DocumentMetadataGroupView` drops the row.

A select stores the option's **id**; the read-only view must show its **label**. When the option no longer exists the id is shown rather than a blank, so the screen says something true.

- [ ] **Step 1: Add the two strings**

The catalog has no `yes`/`no`. Add both to `Shared/Framework/Resources/Localizable.xcstrings`, inside `"strings"`, matching the existing entry shape:

```json
"no" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Nein" } },
    "en" : { "stringUnit" : { "state" : "translated", "value" : "No" } }
  }
},
"yes" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : { "stringUnit" : { "state" : "translated", "value" : "Ja" } },
    "en" : { "stringUnit" : { "state" : "translated", "value" : "Yes" } }
  }
},
```

- [ ] **Step 2: Write the failing test**

Create `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldValueDisplayTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentCustomFieldValueDisplayTests {

    @Test
    func booleanReadsAsYesOrNo() async throws {
        let field = CustomField.testValue(dataType: .boolean, id: 1, name: "Paid")

        expectNoDifference(DocumentFormCustomFieldValue.boolean(true).displayValue(field: field), "Yes")
        expectNoDifference(DocumentFormCustomFieldValue.boolean(false).displayValue(field: field), "No")
    }

    @Test
    func selectShowsTheOptionLabelNotItsId() async throws {
        let field = CustomField.testValue(
            dataType: .select,
            extraData: .init(selectOptions: [.init(id: "abc", label: "Approved")]),
            id: 2,
            name: "Status"
        )

        expectNoDifference(DocumentFormCustomFieldValue.select("abc").displayValue(field: field), "Approved")
    }

    // A definition can lose an option while a document still stores its id. Showing the id says
    // something true; a blank would imply the field was never set.
    @Test
    func selectFallsBackToTheIdWhenTheOptionIsGone() async throws {
        let field = CustomField.testValue(
            dataType: .select,
            extraData: .init(selectOptions: []),
            id: 2,
            name: "Status"
        )

        expectNoDifference(DocumentFormCustomFieldValue.select("abc").displayValue(field: field), "abc")
    }

    @Test
    func monetaryJoinsCurrencyAndAmount() async throws {
        let field = CustomField.testValue(dataType: .monetary, id: 3, name: "Total")

        expectNoDifference(
            DocumentFormCustomFieldValue.monetary(currency: "EUR", amount: "1234.50").displayValue(field: field),
            "EUR 1234.50"
        )
    }

    @Test
    func emptyValuesReadAsNilSoTheirRowIsDropped() async throws {
        let text = CustomField.testValue(dataType: .string, id: 4, name: "Note")
        let date = CustomField.testValue(dataType: .date, id: 5, name: "Due")

        #expect(DocumentFormCustomFieldValue.text("").displayValue(field: text) == nil)
        #expect(DocumentFormCustomFieldValue.date(nil).displayValue(field: date) == nil)
        #expect(DocumentFormCustomFieldValue.number("").displayValue(field: text) == nil)
    }

    // Links are capsules, not a string, so the row renders them itself.
    @Test
    func documentLinkHasNoStringForm() async throws {
        let field = CustomField.testValue(dataType: .documentLink, id: 6, name: "Related")

        #expect(DocumentFormCustomFieldValue.documentLink([2]).displayValue(field: field) == nil)
    }
}
```

- [ ] **Step 3: Run it and watch it fail**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: FAIL — `value of type 'DocumentFormCustomFieldValue' has no member 'displayValue'`.

If `CustomField.testValue` does not accept these argument labels, read its signature in `Modules/ApiInterface/CustomFields/CustomField.swift` and match it — do not change the type to suit the test.

- [ ] **Step 4: Implement**

Append to `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift`:

```swift
extension DocumentFormCustomFieldValue {

    // nil means "render nothing": either the value is empty, so DocumentMetadataGroupView drops the
    // row, or it is a document link, which is a row of capsules rather than a string.
    func displayValue(field: CustomField) -> String? {
        switch self {
        case let .boolean(flag):
            String(localized: flag ? .yes : .no)
        case let .date(date):
            date.map { DateFormatter.customFieldDisplay.string(from: $0) }
        case .documentLink:
            nil
        case let .monetary(currency, amount):
            amount.isEmpty ? nil : "\(currency) \(amount)"
        case let .number(text):
            text.isEmpty ? nil : text
        case let .select(id):
            id.map { optionLabel(for: $0, field: field) }
        case let .text(text):
            text.isEmpty ? nil : text
        case let .unsupported(json):
            json == .null ? nil : String(describing: json)
        }
    }

    private func optionLabel(for id: String, field: CustomField) -> String {
        field.extraData?.selectOptions?.first { $0.id == id }?.label ?? id
    }
}

private extension DateFormatter {

    static let customFieldDisplay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}
```

- [ ] **Step 5: Run it and watch it pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS, 6 tests in the new suite, nothing else broken.

- [ ] **Step 6: Commit**

```bash
mise exec -- swiftformat Modules/DocumentsFeature Modules/DocumentsFeatureTests
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: format custom field values for reading"
```

---

## Task 2: `DocumentCustomFieldsReducer`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer+Effect.swift`
- Create: `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldsReducerTests.swift`

**Interfaces:**
- Consumes: `Document`, `CustomField`, `getDocumentsByIds` (`GetDocumentsByIdsInput(ids:)`), `@Shared(.customFields(server))`.
- Produces:
  - `DocumentCustomFieldsReducer.State(document:server:)` with `document: Document`, `customFields: IdentifiedArrayOf<CustomField>` (shared), `linkedDocuments: IdentifiedArrayOf<Document>`, `server: Server`
  - `Action.view(.onAppear)`, `Action.view(.documentLinkTapped(Document.Id))`
  - `Action.delegate(.openDocument(Document))` — the viewer's cue to push
  - `Action.linkedDocuments(IdentifiedArrayOf<Document>)`
  - `State.rows: [DocumentCustomFieldRow]` where `DocumentCustomFieldRow` is `{ id: CustomField.Id, name: String, value: DocumentFormCustomFieldValue }`

`rows` resolves each attached `DocumentCustomField` against the shared definitions. A field whose definition is gone keeps its id as its name — the document still carries the value, and dropping it would misreport what is on the document.

Only a link whose document has resolved emits `.delegate(.openDocument)`. An unresolved id sends nothing, which is what makes the pushed screen free of loading and error states.

- [ ] **Step 1: Write the failing test**

Create `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldsReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import CustomDump
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct DocumentCustomFieldsReducerTests {

    @Test
    func onAppearResolvesLinkedDocuments() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(
                customFields: [.init(field: 6, value: .array([.number(2)]))],
                id: 1
            )
        )

        let store = TestStore(initialState: state) {
            DocumentCustomFieldsReducer()
        } withDependencies: {
            $0.getDocumentsByIds.execute = { @Sendable _, _ in [linked] }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.linkedDocuments) {
            $0.linkedDocuments = [linked]
        }
    }

    @Test
    func tappingAResolvedLinkAsksTheViewerToOpenIt() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        var state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(
                customFields: [.init(field: 6, value: .array([.number(2)]))],
                id: 1
            )
        )
        state.linkedDocuments = [linked]

        let store = TestStore(initialState: state) {
            DocumentCustomFieldsReducer()
        }

        await store.send(.view(.documentLinkTapped(2)))
        await store.receive(\.delegate.openDocument)
    }

    // An unresolved id has no document behind it, so there is nothing to push.
    @Test
    func tappingAnUnresolvedLinkDoesNothing() async throws {
        let store = TestStore(
            initialState: DocumentCustomFieldsReducer.State.testValue(
                document: .testValue(
                    customFields: [.init(field: 6, value: .array([.number(2)]))],
                    id: 1
                )
            )
        ) {
            DocumentCustomFieldsReducer()
        }

        await store.send(.view(.documentLinkTapped(2)))
    }

    @Test
    func aDocumentWithNoFieldsHasNoRows() async throws {
        let state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(customFields: [], id: 1)
        )

        #expect(state.rows.isEmpty)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: FAIL — `cannot find 'DocumentCustomFieldsReducer' in scope`.

- [ ] **Step 3: Implement the reducer**

Create `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentCustomFieldsReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case linkedDocuments(IdentifiedArrayOf<Document>)
        case view(View)

        public enum Delegate {
            case openDocument(Document)
        }

        public enum View {
            case documentLinkTapped(Document.Id)
            case onAppear
        }
    }

    @ObservableState
    public struct State: Equatable {

        @Shared
        var customFields: IdentifiedArrayOf<CustomField>

        var document: Document

        var linkedDocuments: IdentifiedArrayOf<Document> = []

        let server: Server

        // A field whose definition has been deleted keeps its id as a name: the document still
        // carries the value, and dropping the row would misreport what is on the document.
        var rows: [DocumentCustomFieldRow] {
            document.customFields.map { attached in
                let definition = customFields[id: attached.field]
                return DocumentCustomFieldRow(
                    definition: definition,
                    id: attached.field,
                    name: definition?.name ?? "#\(attached.field.rawValue)",
                    value: definition.map {
                        DocumentFormCustomFieldValue(field: $0, json: attached.value)
                    }
                )
            }
        }

        init(
            document: Document,
            server: Server
        ) {
            self._customFields = Shared(wrappedValue: [], .customFields(server))
            self.document = document
            self.server = server
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .linkedDocuments(documents):
                state.linkedDocuments = documents
                return .none
            case .delegate:
                return .none
            case let .view(viewAction):
                switch viewAction {
                case let .documentLinkTapped(id):
                    guard let document = state.linkedDocuments[id: id] else {
                        return .none
                    }
                    return .send(.delegate(.openDocument(document)))
                case .onAppear:
                    return .runResolveLinkedDocuments(state)
                }
            }
        }
    }
}

struct DocumentCustomFieldRow: Equatable, Identifiable {

    let definition: CustomField?

    let id: CustomField.Id

    let name: String

    let value: DocumentFormCustomFieldValue?
}
```

- [ ] **Step 4: Implement the effect**

Create `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture

extension Effect where Action == DocumentCustomFieldsReducer.Action {

    static func runResolveLinkedDocuments(
        _ state: DocumentCustomFieldsReducer.State
    ) -> Self {
        let ids = state.rows.flatMap { row -> [Document.Id] in
            guard case let .documentLink(ids) = row.value else {
                return []
            }
            return ids
        }

        guard !ids.isEmpty else {
            return .none
        }

        let server = state.server

        return .run { send in
            @Dependency(\.getDocumentsByIds.execute)
            var getDocumentsByIds

            let documents = try await getDocumentsByIds(.init(ids: ids), server)
            await send(.linkedDocuments(IdentifiedArray(uniqueElements: documents)))
        } catch: { _, _ in
            // Deliberately silent, as the edit form is: these titles decorate a value the user can
            // already see, and the capsule falls back to the id.
        }
    }
}
```

- [ ] **Step 5: Implement the test value**

Create `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsReducer+TestValue.swift`:

```swift
import ApiInterface

extension DocumentCustomFieldsReducer.State {

    static func testValue(
        document: Document = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            document: document,
            server: server
        )
    }
}
```

- [ ] **Step 6: Run it and watch it pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS, 4 tests in the new suite.

If `Document.testValue` does not take `customFields:`, read its signature in `Modules/ApiInterface/Documents/Document.swift` and adapt the *tests*, not the model.

- [ ] **Step 7: Commit**

```bash
mise exec -- swiftformat Modules/DocumentsFeature Modules/DocumentsFeatureTests
git add Modules/DocumentsFeature/DocumentCustomFields Modules/DocumentsFeatureTests/DocumentCustomFields
git commit -m "feat: add a reducer for reading a document's custom fields"
```

---

## Task 3: `DocumentCustomFieldsView`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldsViewTests.swift`

**Interfaces:**
- Consumes: `DocumentCustomFieldsReducer` (Task 2), `displayValue(field:)` (Task 1), `DocumentMetadataGroupView.Row`, `EmptyListView`, `.capsule()` as used by `DocumentFormCustomFieldRow`.
- Produces: `DocumentCustomFieldsView(store:)`.

Plain fields become one `DocumentMetadataGroupView` so the section matches metadata. Links cannot go through it — that row renders a `String?` — so they follow as their own rows of capsules.

- [ ] **Step 1: Write the failing snapshot test**

Create `Modules/DocumentsFeatureTests/DocumentCustomFields/DocumentCustomFieldsViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SnapshotTesting
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentCustomFieldsViewTests {

    @Test(
        arguments: [
            ("empty", [DocumentCustomField]()),
            ("plainTypes", [
                DocumentCustomField(field: 1, value: .string("Invoice 2026-08")),
                DocumentCustomField(field: 3, value: .bool(true)),
            ]),
            ("links", [
                DocumentCustomField(field: 6, value: .array([.number(2)])),
            ]),
        ]
    )
    func snapshot(name: String, fields: [DocumentCustomField]) async throws {
        let state = DocumentCustomFieldsReducer.State.testValue(
            document: .testValue(customFields: fields, id: 1)
        )

        let view = DocumentCustomFieldsView(
            store: Store(initialState: state) {
                DocumentCustomFieldsReducer()
            }
        )
        .frame(width: 402, height: 600)

        assertSnapshot(of: view, as: .image(), named: name)
    }
}
```

- [ ] **Step 2: Run it and watch it fail**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: FAIL — `cannot find 'DocumentCustomFieldsView' in scope`.

- [ ] **Step 3: Implement the view**

Create `Modules/DocumentsFeature/DocumentCustomFields/DocumentCustomFieldsView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentCustomFieldsReducer.self)
struct DocumentCustomFieldsView: View {

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentCustomFieldsReducer>

    @ViewBuilder
    private func content() -> some View {
        if store.rows.isEmpty {
            EmptyListView(
                systemImage: "list.bullet.rectangle",
                title: .noCustomFieldsAttached
            )
        } else {
            VStack(alignment: .leading, spacing: .x4) {
                DocumentMetadataGroupView(
                    rows: plainRows(),
                    title: .customFields
                )

                ForEach(linkRows()) { row in
                    linkRow(row)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func plainRows() -> [DocumentMetadataGroupView.Row] {
        store.rows.compactMap { row in
            guard let definition = row.definition,
                  let value = row.value?.displayValue(field: definition)
            else {
                return nil
            }
            return .init(title: .init(stringLiteral: row.name), value: value)
        }
    }

    private func linkRows() -> [DocumentCustomFieldRow] {
        store.rows.filter {
            if case .documentLink = $0.value { return true }
            return false
        }
    }

    @ViewBuilder
    private func linkRow(_ row: DocumentCustomFieldRow) -> some View {
        guard case let .documentLink(ids) = row.value else {
            return
        }

        VStack(alignment: .leading, spacing: .x0) {
            Text(row.name)
                .fontWeight(.semibold)
                .padding(.horizontal)

            ScrollView(.horizontal) {
                LazyHStack(spacing: .x3) {
                    ForEach(ids, id: \.self) { id in
                        capsule(id: id)
                    }
                }
                .padding(.horizontal)
            }
            .scrollIndicators(.hidden)
        }
    }

    @ViewBuilder
    private func capsule(id: Document.Id) -> some View {
        // An unresolved link has no document to open, so it stays inert rather than pushing an
        // empty screen. It becomes tappable when the title arrives.
        if let document = store.linkedDocuments[id: id] {
            Button {
                send(.documentLinkTapped(id))
            } label: {
                Text(document.title).capsule()
            }
            .buttonStyle(.borderless)
        } else {
            Text(verbatim: "#\(id.rawValue)")
                .capsule()
                .foregroundStyle(Color.m3Outline)
        }
    }
}
```

- [ ] **Step 4: Record the snapshots and look at them**

```bash
TEST_RUNNER_SNAPSHOT_RECORD=all mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Then open the three new files under
`Snapshots/DocumentsFeatureTests/DocumentCustomFieldsViewTests/` and confirm: the empty case is centred, plain types render as a metadata-style card, and the link case shows a capsule. A snapshot that is recorded but never looked at proves nothing.

- [ ] **Step 5: Run without recording**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
mise exec -- swiftformat Modules/DocumentsFeature Modules/DocumentsFeatureTests
git add Modules/DocumentsFeature/DocumentCustomFields Modules/DocumentsFeatureTests/DocumentCustomFields Snapshots
git commit -m "feat: render a document's custom fields read-only"
```

---

## Task 4: Wire the section into the viewer

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerSection.swift`
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentViewer/DocumentViewerReducerTests.swift` (existing)

**Interfaces:**
- Consumes: `DocumentCustomFieldsReducer` (Task 2), `DocumentCustomFieldsView` (Task 3).
- Produces: `DocumentViewerSection.customFields`; `DocumentViewerReducer.State.customFields`.

After this task the section is reachable from the detail toolbar and the row context menu, because `DocumentViewerMenu` iterates `allCases`. Links render but do not navigate yet — Task 5 adds that.

- [ ] **Step 1: Add the section case**

In `Modules/DocumentsFeature/DocumentViewer/DocumentViewerSection.swift`, add `case customFields` to the enum, then to both switches:

```swift
public enum DocumentViewerSection: CaseIterable, Sendable {
    case content
    case customFields
    case metadata
    case notes
}
```

```swift
    var localized: LocalizedStringResource {
        switch self {
        case .content:
            .content
        case .customFields:
            .customFields
        case .metadata:
            .metadata
        case .notes:
            .notes
        }
    }

    var systemImage: String {
        switch self {
        case .content:
            "text.alignleft"
        case .customFields:
            "list.bullet.rectangle"
        case .metadata:
            "info.circle"
        case .notes:
            "note.text"
        }
    }
```

- [ ] **Step 2: Scope the reducer into the viewer**

In `DocumentViewerReducer`, add the action case, the state, the scope, and the scrolling rule.

Action:

```swift
        case customFields(DocumentCustomFieldsReducer.Action)
```

State, beside `metadata`:

```swift
        var customFields: DocumentCustomFieldsReducer.State
```

In `State.init`, beside the existing assignments:

```swift
            self.customFields = DocumentCustomFieldsReducer.State(
                document: document.wrappedValue,
                server: server
            )
```

In `isContentScrollable`, add the case — rows scroll, the empty state centres:

```swift
            case .customFields:
                return !customFields.rows.isEmpty
```

In `body`, beside the other scopes:

```swift
        Scope(state: \.customFields, action: \.customFields) {
            DocumentCustomFieldsReducer()
        }
```

And in the `Reduce`'s switch, so the new action is handled:

```swift
            case .customFields:
                return .none
```

- [ ] **Step 3: Render the section**

In `DocumentViewerView`, add the switch case and the store scope:

```swift
            case .customFields:
                DocumentCustomFieldsView(store: customFieldsStore)
```

```swift
    private var customFieldsStore: StoreOf<DocumentCustomFieldsReducer> {
        store.scope(state: \.customFields, action: \.customFields)
    }
```

- [ ] **Step 4: Verify it builds and the suite is green**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS. Any `DocumentViewerSection` switch that is now non-exhaustive will fail the build first — fix each by adding the `.customFields` case, never with a `default`.

- [ ] **Step 5: See it in the app**

```bash
mise exec -- tuist generate --no-open
```

Run the app, open a document, and confirm **Custom fields** appears both in the detail screen's View menu and in a document row's context menu, and that it renders.

- [ ] **Step 6: Commit**

```bash
mise exec -- swiftformat Modules/DocumentsFeature
git add Modules/DocumentsFeature
git commit -m "feat: add a Custom fields section to the document viewer"
```

---

## Task 5: Drill into document links

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentViewer/DocumentViewerReducerTests.swift` (existing)

**Interfaces:**
- Consumes: `Action.delegate(.openDocument(Document))` from Task 2.
- Produces: `DocumentViewerReducer.State.customFieldsPath: StackState<DocumentCustomFieldsReducer.State>`.

The stack lives here rather than inside `DocumentCustomFieldsReducer`, which is what keeps the state non-recursive: no element contains a stack, so drilling three deep is three flat elements.

- [ ] **Step 1: Write the failing test**

Append to `Modules/DocumentsFeatureTests/DocumentViewer/DocumentViewerReducerTests.swift`, inside the existing suite:

```swift
    @Test
    func openingALinkPushesThatDocumentsFields() async throws {
        let linked = Document.testValue(id: 2, title: "Contract")
        let store = TestStore(
            initialState: DocumentViewerReducer.State.testValue(section: .customFields)
        ) {
            DocumentViewerReducer()
        }

        await store.send(.customFields(.delegate(.openDocument(linked)))) {
            $0.customFieldsPath.append(
                DocumentCustomFieldsReducer.State(document: linked, server: $0.server)
            )
        }
    }

    @Test
    func drillingTwiceStacksTwoScreens() async throws {
        let first = Document.testValue(id: 2, title: "Contract")
        let second = Document.testValue(id: 3, title: "Appendix")
        let store = TestStore(
            initialState: DocumentViewerReducer.State.testValue(section: .customFields)
        ) {
            DocumentViewerReducer()
        }

        await store.send(.customFields(.delegate(.openDocument(first)))) {
            $0.customFieldsPath.append(
                DocumentCustomFieldsReducer.State(document: first, server: $0.server)
            )
        }
        await store.send(.customFieldsPath(.element(id: 0, action: .delegate(.openDocument(second))))) {
            $0.customFieldsPath.append(
                DocumentCustomFieldsReducer.State(document: second, server: $0.server)
            )
        }

        #expect(store.state.customFieldsPath.count == 2)
    }
```

If `DocumentViewerReducer.State.testValue` does not take `section:`, add that parameter to the existing factory in `DocumentViewerReducer+TestValue.swift` rather than constructing state by hand.

- [ ] **Step 2: Run it and watch it fail**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: FAIL — no `customFieldsPath` on the state.

- [ ] **Step 3: Add the stack**

In `DocumentViewerReducer`, add the action:

```swift
        case customFieldsPath(StackActionOf<DocumentCustomFieldsReducer>)
```

The state, beside `customFields`:

```swift
        var customFieldsPath = StackState<DocumentCustomFieldsReducer.State>()
```

Handle both the root's delegate and any pushed screen's, then attach the stack reducer in `body`:

```swift
            case let .customFields(.delegate(.openDocument(document))),
                 let .customFieldsPath(.element(_, .delegate(.openDocument(document)))):
                state.customFieldsPath.append(
                    DocumentCustomFieldsReducer.State(
                        document: document,
                        server: state.server
                    )
                )
                return .none
            case .customFields, .customFieldsPath:
                return .none
```

```swift
        .forEach(\.customFieldsPath, action: \.customFieldsPath) {
            DocumentCustomFieldsReducer()
        }
```

- [ ] **Step 4: Run it and watch it pass**

```bash
mise exec -- tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS.

- [ ] **Step 5: Wrap the section in a navigation stack**

In `DocumentViewerView`, replace the `.customFields` case so the section owns a stack, and title pushed screens with the document they show:

```swift
            case .customFields:
                NavigationStack(
                    path: $store.scope(state: \.customFieldsPath, action: \.customFieldsPath)
                ) {
                    DocumentCustomFieldsView(store: customFieldsStore)
                } destination: { store in
                    DocumentCustomFieldsView(store: store)
                        .navigationTitle(store.document.title)
                        .navigationBarTitleDisplayMode(.inline)
                }
```

- [ ] **Step 6: Drive it in the app**

```bash
mise exec -- tuist generate --no-open
```

Open a document that has a document-link field with at least one link, tap a capsule, confirm the linked document's fields appear with its title in the bar, and that back returns. Then drill twice and back out twice.

If no such document exists, create a `documentlink` custom field in Settings, attach it to a document in the edit sheet, and link a second document.

- [ ] **Step 7: Commit**

```bash
mise exec -- swiftformat Modules/DocumentsFeature Modules/DocumentsFeatureTests
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: drill into document links from the custom fields viewer"
```

---

## Self-Review

**Spec coverage.** Section case and both entry points → Task 4. Attached-fields-only and the deleted-definition fallback → Task 2's `rows`. Value formatting including select labels and unknown types → Task 1. Metadata-style rows plus link capsules → Task 3. Inert unresolved capsules → Task 2 (`documentLinkTapped` guard) and Task 3 (`capsule`). Non-recursive stack, unbounded depth, pushed-screen title → Task 5. Empty state reusing `.noCustomFieldsAttached` → Task 3. `isContentScrollable` → Task 4. Reducer and snapshot tests → Tasks 2, 3, 5.

**Placeholder scan.** No TBD/TODO. Every code step carries its code. Three steps tell the implementer to adapt *tests* to an existing signature rather than change a model — that is a real instruction with a named file, not a placeholder.

**Type consistency.** `DocumentCustomFieldRow` is defined in Task 2 and consumed in Task 3 with the same four members. `displayValue(field:)` is defined in Task 1 and called in Task 3. `Action.delegate(.openDocument(Document))` is produced in Task 2 and handled in Task 5. `State(document:server:)` is used identically in Tasks 2, 4 and 5. `customFieldsStore` is introduced in Task 4 and reused in Task 5.

**Known gap.** No UI journey. The AppUITests suite is still stabilising on #191, and adding a journey that depends on creating a link field and a second document would land in the middle of that. It belongs in the Plan 2 inventory alongside journey 12.
