# Preview and share from the document row Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add Preview and Share to the document row's long-press menu, downloading the file on
demand, and shorten every item in both document menus to a bare verb.

**Architecture:** The download-and-write-to-temp-file sequence that only `DocumentDetailReducer` has
today becomes `Document.download(server:)`, used by the detail screen and by a new row effect. The
row keeps the resulting URL so a second action reuses it, presents QuickLook or a new `ShareSheet`
component, and dims with a spinner while fetching. Spec:
`docs/superpowers/specs/2026-08-16-document-row-preview-share-design.md`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture 1.22, Swift Testing,
swift-snapshot-testing, Tuist 4.203, iOS 18 minimum.

## Global Constraints

- **Comments:** only `//`, never `///` or `/** */`, anywhere — including tests. Comment only when a
  reader would otherwise stop and wonder *why*. See `AGENTS.md`.
- **In a `@ViewAction` view, call `send(...)` — never `store.send(...)`.** The macro warns
  otherwise. Both `DocumentRowView` and `DocumentDetailView` carry the annotation.
- **Members are alphabetically ordered** within a type — properties, then `init`, then methods.
- **Attributes go on their own line with no blank line after them.**
  `mise/scripts/attribute_blank_lines.py --check` enforces this.
- **Line width 140**, 4-space indent. Run `swiftformat .` before committing.
- **swiftlint runs through mise:** `mise exec -- swiftlint --strict --quiet` (it is not on `PATH`).
- **All user-facing text** lives in `Shared/Framework/Resources/Localizable.xcstrings` with **both**
  `en` and `de` translated.
- Run tests with
  `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`.
  `--no-selective-testing` matters: without it a re-run of an unchanged target is skipped and reports
  success without executing anything.
- **If a run fails with `Library not loaded: @rpath/…framework`**, that is stale DerivedData, not
  your change. Re-run with `--clean`.
- Targets use Xcode buildable folders, so new source files need no `tuist generate`.
- Work on branch `document_row_preview_share`, off `main`. Commit after every task. Do not merge to
  `main`.

---

### Task 1: One download, two callers

Pure refactor. `DocumentDetailReducer`'s download effect currently owns the whole sequence — call the
use case, write the bytes to a temporary file named after the document, hand back both. Task 3 needs
the same sequence from a row but must not hold the `Data`. Extract it now, while the detail tests
are the only thing that can break.

**Files:**
- Create: `Modules/DocumentsFeature/Extensions/Document+Download.swift`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentDetail/DocumentDetailReducerTests.swift` (unchanged —
  it already pins the temp-file URL)

**Interfaces:**
- Consumes: nothing.
- Produces: `Document.download(server: Server) async throws -> (data: Data, url: URL)`, internal to
  `DocumentsFeature`. Task 3's row effect calls it and keeps only `url`.

- [ ] **Step 1: Create the branch and confirm a green baseline**

```bash
git switch -c document_row_preview_share
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
```

Expected: PASS. This is a refactor — if the suite is red before you start, stop and say so.

- [ ] **Step 2: Write the extension**

Create `Modules/DocumentsFeature/Extensions/Document+Download.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation

extension Document {

    func download(server: Server) async throws -> (data: Data, url: URL) {
        @Dependency(\.downloadDocument.execute)
        var downloadDocument

        let data = try await downloadDocument(id, server)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try data.write(to: url, options: .atomic)
        return (data: data, url: url)
    }
}
```

- [ ] **Step 3: Call it from the detail effect**

Replace the body of `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentDetailReducer.Action {

    static func runDownloadDocument(document: Document, server: Server) -> Self {
        .run { send in
            let file = try await document.download(server: server)
            await send(.downloadResult(.success(data: file.data, url: file.url)), animation: .default)
        } catch: { error, send in
            await send(.downloadResult(.failure(error.localizedDescription)))
        }
        .cancellable(id: CancelID.downloadDocument)
    }
}

private enum CancelID {
    case downloadDocument
}
```

- [ ] **Step 4: Run the tests**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS, with no test file edited. `test_view_onAppear_downloadSuccess` and
`test_view_retryDownloadButtonTapped_downloadSuccess` both assert
`FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")`, so they prove the
file still lands in the same place.

- [ ] **Step 5: Format, lint, commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
git add Modules/DocumentsFeature
git commit -m "refactor: extract the document download into Document.download(server:)"
```

---

### Task 2: Bare verbs in both menus

Rename the visible menu items and fix the ellipsis menu that opens empty mid-download. No new
behaviour; the row still has only Edit and Delete until Task 4.

**Files:**
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift:42-54`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift:32-54`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift` — one computed
  property
- Test: `Modules/DocumentsFeatureTests/DocumentDetail/DocumentDetailViewTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `LocalizedStringResource.delete`, `.preview`, `.share` (Xcode generates these symbols
  from the string catalog) and `DocumentDetailReducer.State.downloadedURL: URL?`. Task 4 uses the
  first three for the row's menu.

- [ ] **Step 1: Add three strings, remove two**

Open `Shared/Framework/Resources/Localizable.xcstrings`. It is a JSON file with 2-space indent and a
space before every colon (`"key" : {`) — match that exactly. Insert each entry in alphabetical
position among the existing keys.

`delete` goes immediately before the existing `deleteConfirmation`:

```json
    "delete" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Löschen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Delete"
          }
        }
      }
    },
```

`preview` goes where `previewDocument` is now:

```json
    "preview" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Vorschau"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Preview"
          }
        }
      }
    },
```

`share` goes where `shareDocument` is now:

```json
    "share" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Teilen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Share"
          }
        }
      }
    },
```

Then delete the whole `"previewDocument" : { … },` and `"shareDocument" : { … },` entries. Leave
`edit`, `editDocument` and `deleteDocument` alone: `edit` is reused as-is, and the two long ones
still title the form sheet and the delete confirmation.

Verify:

```bash
python3 -c "
import json
d = json.load(open('Shared/Framework/Resources/Localizable.xcstrings'))['strings']
for k in ('delete', 'edit', 'preview', 'share'):
    print(k, {l: e['stringUnit']['value'] for l, e in d[k]['localizations'].items()})
print('removed:', [k for k in ('previewDocument', 'shareDocument') if k in d])
"
```

Expected: four keys print with English and German values, and `removed: []`.

- [ ] **Step 2: Shorten the row's menu labels**

In `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`, change only the two `Label` titles
in `contextMenu()`:

```swift
    @ViewBuilder
    private func contextMenu() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Label(.edit, systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
            send(.deleteButtonTapped)
        } label: {
            Label(.delete, systemImage: "trash")
        }
    }
```

- [ ] **Step 3: Add the detail screen's URL accessor**

In `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift`, inside `State`, after the
`downloadResult` property:

```swift
        var downloadedURL: URL? {
            downloadResult?.value?.url
        }
```

- [ ] **Step 4: Shorten the detail menu and disable it while downloading**

Replace the `.toolbar { … }` block in
`Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift`:

```swift
        .toolbar {
            Menu {
                if let url = store.downloadedURL {
                    Button {
                        send(.previewButtonTapped)
                    } label: {
                        Label(.preview, systemImage: "eye")
                    }

                    ShareLink(item: url) {
                        Label(.share, systemImage: "square.and.arrow.up")
                    }
                }
            } label: {
                Label(.moreActions, systemImage: "ellipsis.circle")
            }
            .disabled(store.downloadedURL == nil)

            Button(action: {
                send(.editDocumentButtonTapped)
            }) {
                Label(.edit, systemImage: "square.and.pencil")
            }
        }
```

- [ ] **Step 5: Add the disabled-menu snapshot**

Append to `Modules/DocumentsFeatureTests/DocumentDetail/DocumentDetailViewTests.swift`, inside the
suite:

```swift
    @Test
    func testSnapshot_downloading() async throws {
        assertSnapshot(
            of: DocumentDetailView(
                store: Store(
                    initialState: DocumentDetailReducer.State.testValue(),
                    reducer: {
                        EmptyReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
```

`EmptyReducer` rather than the real one: with no `downloadResult` the view fires `onAppear`, and the
real reducer would start a download in the middle of rendering.

- [ ] **Step 6: Record and verify**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
```

Expected: the first run fails with "snapshot was recorded" for `testSnapshot_downloading`, the
second passes.

Then check what else moved:

```bash
git status --short Snapshots/
```

The renamed labels live inside closed menus, and toolbar `Label`s render icon-only, so the existing
`testSnapshot_success` and `testSnapshot_failure` are expected to be **unchanged**. If either shows
as modified, open it: the only acceptable difference is a shortened piece of toolbar text. Anything
else means a layout change you did not intend — stop and diff.

Open `Snapshots/DocumentsFeatureTests/DocumentDetailViewTests/testSnapshot_downloading.1.png` and
confirm the ellipsis button is visibly greyed out while the spinner runs.

- [ ] **Step 7: Format, lint, commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Shared/Framework/Resources/Localizable.xcstrings Snapshots
git commit -m "feat: name the document menu items with bare verbs"
```

---

### Task 3: The row can fetch its document

All the behaviour, none of the UI: the row reducer learns to download for a stated purpose, keep the
URL, present, and toast on failure. Nothing sends these actions until Task 4.

**Files:**
- Create: `Modules/Components/Share/ShareItem.swift`
- Create: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Download.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Effect.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`

**Interfaces:**
- Consumes: `Document.download(server:)` from Task 1.
- Produces, for Task 4: `ShareItem(url:)` with `var id: URL { url }`; the view actions
  `previewButtonTapped` and `shareButtonTapped`; and the state properties `isBusy: Bool`,
  `isDownloading: Bool`, `quickLookPreview: URL?`, `shareItem: ShareItem?`. `Action` gains
  `BindableAction` conformance, which is what lets Task 4 write `$store.quickLookPreview`.

- [ ] **Step 1: Add the share item type**

Create `Modules/Components/Share/ShareItem.swift`:

```swift
import Foundation

public struct ShareItem: Equatable, Identifiable, Sendable {

    public var id: URL { url }

    public let url: URL

    public init(url: URL) {
        self.url = url
    }
}
```

Identified by the URL rather than a fresh `UUID`, so two `ShareItem`s for the same file compare
equal and `TestStore` assertions stay writable.

- [ ] **Step 2: Write the failing tests**

Add `import Components` to the imports of
`Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`, then append these four
tests inside the existing suite:

```swift
    @Test
    func test_view_previewButtonTapped_downloadSuccess() async throws {
        let data = try Data.testValue()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in data }
        }

        await store.send(.view(.previewButtonTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadSucceeded) {
            $0.downloadedURL = url
            $0.isDownloading = false
            $0.quickLookPreview = url
        }
    }

    @Test
    func test_view_shareButtonTapped_downloadSuccess() async throws {
        let data = try Data.testValue()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in data }
        }

        await store.send(.view(.shareButtonTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadSucceeded) {
            $0.downloadedURL = url
            $0.isDownloading = false
            $0.shareItem = ShareItem(url: url)
        }
    }

    @Test
    func test_view_shareButtonTapped_reusesDownloadedFile() async throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("invoice.pdf")
        let store = TestStore(initialState: DocumentRowReducer.State.testValue(
            downloadedURL: url
        )) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in
                Issue.record("The file is already on disk — it must not be downloaded again")
                return try Data.testValue()
            }
        }

        await store.send(.view(.shareButtonTapped)) {
            $0.shareItem = ShareItem(url: url)
        }
    }

    @Test
    func test_view_previewButtonTapped_downloadFailure() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentRowReducer.State.testValue()) {
            DocumentRowReducer()
        } withDependencies: {
            $0.downloadDocument.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in toasts.withValue { $0.append(value) } }
        }

        await store.send(.view(.previewButtonTapped)) {
            $0.isDownloading = true
        }
        await store.receive(\.downloadFailed) {
            $0.isDownloading = false
        }

        #expect(toasts.value == [.error("Something went wrong")])
    }
```

`Document.testValue()` has `archivedFileName: "invoice.pdf"`, which is where that filename comes
from. `receive(\.downloadSucceeded)` matches on the case path rather than equality — `Action` will
carry an `Error`, so it is not `Equatable`.

- [ ] **Step 3: Run to verify it fails**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: compile failure — `previewButtonTapped`, `shareButtonTapped`, `downloadedURL`,
`isDownloading`, `quickLookPreview` and `shareItem` do not exist yet.

- [ ] **Step 4: Extend the reducer**

In `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`, replace the `Action` enum and add
the intent type:

```swift
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case destination(PresentationAction<Destination.Action>)
        case delegate(Delegate)
        case downloadFailed(Error)
        case downloadSucceeded(url: URL, intent: DownloadIntent)
        case view(View)

        public enum Delegate {
            case deleteDocument
            case presentDocumentDetail(Shared<Document>)
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
            case previewButtonTapped
            case rowTapped
            case shareButtonTapped
        }
    }

    public enum DownloadIntent: Equatable, Sendable {
        case preview
        case share
    }
```

`DownloadIntent` is `public` because a public enum case cannot carry a less visible type.

Add these to `State`, each in alphabetical position among the existing members:

```swift
        var downloadedURL: URL?

        var isBusy: Bool {
            isDownloading || isUpdating
        }

        var isDownloading = false

        var quickLookPreview: URL?

        var shareItem: ShareItem?
```

and widen `init`, keeping its parameters alphabetical:

```swift
        init(
            destination: Destination.State? = nil,
            document: Shared<Document>,
            downloadedURL: URL? = nil,
            isDownloading: Bool = false,
            isUpdating: Bool = false,
            quickLookPreview: URL? = nil,
            server: Server,
            shareItem: ShareItem? = nil
        ) {
            self.destination = destination
            self._document = document
            self.downloadedURL = downloadedURL
            self.isDownloading = isDownloading
            self.isUpdating = isUpdating
            self.quickLookPreview = quickLookPreview
            self.server = server
            self.shareItem = shareItem
        }
```

Replace `body` with:

```swift
    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case .destination(.presented(.documentForm(.delegate(.documentUpdated)))):
                state.destination = nil
                return .none
            case let .downloadFailed(error):
                state.isDownloading = false
                return .toast(error)
            case let .downloadSucceeded(url, intent):
                state.downloadedURL = url
                state.isDownloading = false
                state.present(url: url, intent: intent)
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .deleteButtonTapped:
                    return .runConfirmDelete(documentTitle: state.document.title)
                case .editButtonTapped:
                    state.destination = .documentForm(DocumentFormReducer.State(
                        document: state.$document,
                        server: state.server
                    ))
                    return .none
                case .previewButtonTapped:
                    return state.download(intent: .preview)
                case .rowTapped:
                    return .send(.delegate(.presentDocumentDetail(state.$document)))
                case .shareButtonTapped:
                    return state.download(intent: .share)
                }
            case .binding, .delegate, .destination:
                return .none
            }
        }
        .ifLet(\.$destination, action: \.destination)
    }
```

`BindingReducer` is what clears `quickLookPreview` and `shareItem` when the user dismisses either
presentation.

- [ ] **Step 5: Add the two state helpers**

Create `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Download.swift`:

```swift
import Components
import ComposableArchitecture
import Foundation

extension DocumentRowReducer.State {

    mutating func download(intent: DocumentRowReducer.DownloadIntent) -> Effect<DocumentRowReducer.Action> {
        guard let downloadedURL else {
            isDownloading = true
            return .runDownloadDocument(document: document, intent: intent, server: server)
        }
        present(url: downloadedURL, intent: intent)
        return .none
    }

    mutating func present(url: URL, intent: DocumentRowReducer.DownloadIntent) {
        switch intent {
        case .preview:
            quickLookPreview = url
        case .share:
            shareItem = ShareItem(url: url)
        }
    }
}
```

- [ ] **Step 6: Add the effect**

Replace `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentRowReducer.Action {

    static func runConfirmDelete(documentTitle: String) -> Self {
        @Dependency(\.documentDeleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(documentTitle) else {
                return
            }
            await send(.delegate(.deleteDocument))
        }
        .cancellable(id: CancelID.confirmDelete)
    }

    static func runDownloadDocument(
        document: Document,
        intent: DocumentRowReducer.DownloadIntent,
        server: Server
    ) -> Self {
        .run { send in
            let file = try await document.download(server: server)
            await send(.downloadSucceeded(url: file.url, intent: intent), animation: .default)
        } catch: { error, send in
            await send(.downloadFailed(error))
        }
        .cancellable(id: CancelID.downloadDocument(document.id))
    }
}

private enum CancelID: Hashable {
    case confirmDelete
    case downloadDocument(Document.Id)
}
```

The cancel id carries the document id: a bare case would make one row's tap cancel another row's
download.

- [ ] **Step 7: Widen the test value**

Replace `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer+TestValue.swift`:

```swift
import ApiInterface
import Components
import Foundation
import SwiftSharing

extension DocumentRowReducer.State {

    static func testValue(
        destination: DocumentRowReducer.Destination.State? = nil,
        document: Document = .testValue(),
        downloadedURL: URL? = nil,
        isDownloading: Bool = false,
        isUpdating: Bool = false,
        quickLookPreview: URL? = nil,
        server: Server = .testValue(),
        shareItem: ShareItem? = nil
    ) -> Self {
        .init(
            destination: destination,
            document: Shared(value: document),
            downloadedURL: downloadedURL,
            isDownloading: isDownloading,
            isUpdating: isUpdating,
            quickLookPreview: quickLookPreview,
            server: server,
            shareItem: shareItem
        )
    }
}
```

- [ ] **Step 8: Run the tests**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, including the four new tests and every existing `DocumentRowReducerTests` case.

- [ ] **Step 9: Format, lint, commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
git add Modules/Components Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: let a document row download its file for preview or share"
```

---

### Task 4: The menu items and what they present

**Files:**
- Create: `Modules/Components/Share/ShareSheet.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowViewTests.swift`

**Interfaces:**
- Consumes: `.preview` / `.share` / `.edit` / `.delete` from Task 2, and everything Task 3 produced.
- Produces: nothing downstream.

- [ ] **Step 1: Add the share sheet**

Create `Modules/Components/Share/ShareSheet.swift`, mirroring `PDFKitView`'s shape:

```swift
import SwiftUI
import UIKit

public struct ShareSheet: UIViewControllerRepresentable {

    public func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    public func updateUIViewController(_: UIActivityViewController, context _: Context) {}

    public init(url: URL) {
        self.url = url
    }

    private let url: URL
}
```

`ShareLink` is the better API and the detail screen keeps it, but it needs the URL when the menu is
built. A context menu item is dismissed before the download finishes, so the row needs a sheet it
can present after the fact.

- [ ] **Step 2: Write the failing snapshot test**

Append to `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowViewTests.swift`, inside the suite:

```swift
    @Test
    func testSnapshot_isDownloading() async throws {
        assertSnapshot(
            of: DocumentRowView(
                store: Store(
                    initialState: DocumentRowReducer.State.testValue(isDownloading: true),
                    reducer: {
                        DocumentRowReducer()
                    }
                )
            ).frame(width: 375).padding(),
            as: .image(layout: .sizeThatFits)
        )
    }
```

- [ ] **Step 3: Run to verify it fails**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: it records a snapshot of the row with no spinner and reports "snapshot was recorded".
Delete it — that image is of the old view:

```bash
rm Snapshots/DocumentsFeatureTests/DocumentRowViewTests/testSnapshot_isDownloading.1.png
```

- [ ] **Step 4: Wire up the view**

In `Modules/DocumentsFeature/DocumentRow/DocumentRowView.swift`, add `import QuickLook` to the
imports. Replace `body`:

```swift
    var body: some View {
        AdaptiveStack(
            breakpoint: breakpoint,
            horizontalAlignment: .center,
            horizontalSpacing: .x0,
            verticalSpacing: .x0
        ) {
            imageView()
            detailsView()
        }
        .sheet(item: $store.shareItem) { item in
            ShareSheet(url: item.url)
        }
        .frame(maxWidth: .infinity)
        .background(Color.m3SurfaceContainer)
        .buttonStyle(.borderless)
        .contentShape(Rectangle())
        .listRowSeparator(.hidden)
        .onTapGesture { send(.rowTapped) }
        .overlay(RoundedRectangle(cornerRadius: Constants.cornerRadius).stroke(Color.m3OutlineVariant, lineWidth: 1))
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .contextMenu(menuItems: contextMenu)
        .opacity(store.isBusy ? 0.5 : 1.0)
        .overlay { downloadProgressView() }
        .quickLookPreview($store.quickLookPreview)
        .sheet(
            item: $store.scope(state: \.destination?.documentForm, action: \.destination.documentForm)
        ) { store in
            DocumentFormView(store: store)
                .presentationDetents([.large])
        }
    }
```

Two things about that order are deliberate. `.opacity` stays exactly where it was, so the existing
`testSnapshot_isUpdating` image still matches; `isBusy` equals `isUpdating` whenever nothing is
downloading. And `.overlay { downloadProgressView() }` comes *after* `.opacity`, so the spinner is
not dimmed along with the row beneath it.

Replace `contextMenu()` and add the progress view, keeping the private methods alphabetical
(`contextMenu`, `detailsView`, `downloadProgressView`, `imageView`, `tagsView`):

```swift
    @ViewBuilder
    private func contextMenu() -> some View {
        Button {
            send(.previewButtonTapped)
        } label: {
            Label(.preview, systemImage: "eye")
        }

        Button {
            send(.shareButtonTapped)
        } label: {
            Label(.share, systemImage: "square.and.arrow.up")
        }

        Button {
            send(.editButtonTapped)
        } label: {
            Label(.edit, systemImage: "square.and.pencil")
        }

        Button(role: .destructive) {
            send(.deleteButtonTapped)
        } label: {
            Label(.delete, systemImage: "trash")
        }
    }
```

```swift
    @ViewBuilder
    private func downloadProgressView() -> some View {
        if store.isDownloading {
            ProgressView()
                .controlSize(.large)
        }
    }
```

- [ ] **Step 5: Record and verify the snapshot**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
```

Expected: first run fails with "snapshot was recorded", second passes.

Open `Snapshots/DocumentsFeatureTests/DocumentRowViewTests/testSnapshot_isDownloading.1.png` and
confirm the row content is dimmed while the spinner on top of it is at full strength.

```bash
git status --short Snapshots/
```

Expected: only the new file. `testSnapshot_isUpdating`, `testSnapshot_contentVariants` and
`testSnapshot_sizeCategories` must be untouched — the menu is closed in all three, and the dim
condition is unchanged when `isDownloading` is false.

- [ ] **Step 6: Drive it in the simulator**

Snapshots cannot cover presentation, and this row now owns three of them. Build and run, then on a
list with at least one document:

```bash
tuist generate --no-open && open -a Simulator
```

Or use the XcodeBuildMCP tools with scheme `LessPaper` on "iPhone 17 Pro".

Check all four, long-pressing a row each time:

| Action | Expected |
|---|---|
| Preview | row dims with a spinner, then QuickLook opens the PDF; closing it returns to the list |
| Share | row dims with a spinner, then the system share sheet appears |
| Preview, then Share on the same row | the second one appears with no spinner at all |
| Edit | the document form sheet still opens |

If Share does nothing while Edit works, the two `.sheet` modifiers are colliding — move
`.sheet(item: $store.shareItem)` out of the chain and onto the `downloadProgressView()` overlay's
content instead, then re-check.

Also pull the network down (aeroplane mode) and tap Preview: the row must stop dimming and a red
toast must appear.

- [ ] **Step 7: Format, lint, full test run, commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
tuist test --skip-ui-tests --no-selective-testing -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: the whole workspace passes. Worth running once here rather than trusting the
`DocumentsFeature` run alone — the string catalog is embedded in every module, and `Components`
gained two files.

```bash
git add Modules/Components Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots
git commit -m "feat: preview and share a document from the list context menu"
```

- [ ] **Step 8: Open the pull request**

```bash
git push -u origin document_row_preview_share
gh pr create --title "Preview and share from the document row" --body "$(cat <<'EOF'
Adds Preview and Share to the document row's context menu, downloading the file on demand, and
shortens every item in both document menus to a bare verb.

Spec: `docs/superpowers/specs/2026-08-16-document-row-preview-share-design.md`

🤖 Generated with [Claude Code](https://claude.com/claude-code)

https://claude.ai/code/session_01BWdim7BJpRRU4xhSMVKyYr
EOF
)"
```
