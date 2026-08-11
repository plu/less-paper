# Bulk Edit Tags UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the tags button in `DocumentListBottomToolbar` a working bulk-edit sheet, with independent add/remove sets and a confirmation popup that previews the tags being changed.

**Architecture:** A non-generic TCA reducer `DocumentBulkEditTagsReducer` living beside `DocumentBulkEditGenericValueReducer<Value>`, not folded into it — tags carry a *set* of pending changes (`[Tag.Id: Operation]`) rather than the single `Operation?` the generic reducer models. Presented as a fourth `Destination` case on `DocumentListReducer`. The confirmation popup gains a second entry point on the existing `DocumentBulkEditConfirmationPresenter` dependency that takes tag values instead of a pre-rendered message.

**Tech Stack:** Swift, SwiftUI, The Composable Architecture, `swift-dependencies`, Swift Testing, swift-snapshot-testing, Tuist-generated Xcode project.

**Full design context:** See `docs/plans/2026-08-09-bulk-edit-tags-ui.md` for the investigation and rationale — this plan implements that design directly. The preceding phase is `docs/plans/2026-08-08-bulk-edit-ui.md` / `-plan.md`; every pattern below is lifted from what it shipped.

## Global Constraints

- **Test command:** `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`.

  Every part of that command matters. **`--no-selective-testing` is required** — plain `tuist test` can silently report "no tests to run, finishing early" due to Tuist's test-impact cache, giving false confidence that a new test ran when it didn't.

  **`-d "iPhone 17 Pro" --os 26.4` and `-- -testLanguage en -testRegion DE` are equally required.** The committed snapshot references were recorded in that exact environment (it is what `mise/tasks/ci/test` uses). On any other simulator or locale, every snapshot suite in this module fails wholesale — a misleading red that has nothing to do with your change. Worse, Tasks 1 and 5 *record* new references: recording them on the wrong simulator or locale commits references that then fail in CI forever.

  **Known flake:** the first `tuist test` run after files change often dies with `error: clang importer creation failed` / `unable to handle compilation, expected exactly one compiler job`. It is transient and unrelated to your code — run the same command again. Do not go debugging it, and do not treat it as a test failure.
- Tuist globs sources from `Modules/<TargetName>/**`, so new files are picked up automatically — but `tuist test` regenerates the project, so always run the full command rather than building in an already-open Xcode.
- **Before every commit** run `mise run format` (swiftlint --fix + swiftformat). Commit the formatted result.
- Doc comments follow `.claude/CLAUDE.md`: `///` for single-line, `/** */` with `- Parameters:` for multiline. Match the surrounding files — most types in `DocumentsFeature` carry no doc comments at all, so don't add them where neighbours have none. The one exception in this plan is `DocumentBulkEditConfirmationPresenter`, whose existing `present` property carries a `///` comment; the new `presentTags` gets one too.
- Property and case declarations are alphabetically ordered within their visibility group, and stored properties are separated by blank lines. Follow the exact layout of `DocumentBulkEditGenericValueReducer` when in doubt. This applies to function parameter lists too — hence `presentTags(addTags:documentCount:removeTags:)`.
- Use `Tagged` id types (`Tag.Id`, `Document.Id`) throughout — never raw `Int`.
- **`Tag` is ambiguous in test files.** `DocumentsFeatureTests` imports both `ApiInterface` (which has `Tag`) and `Testing` (which also has `Tag`, used by the `.tags(.snapshotTests)` trait). Member lookup resolves fine — `Tag.testValue(id: 1)` compiles — but every *type position* must be spelled `ApiInterface.Tag`: `IdentifiedArrayOf<ApiInterface.Tag>`, `[ApiInterface.Tag]`, `LockIsolated<[ApiInterface.Tag]>`. `DocumentFilterInputTests.swift:742-745` shows both spellings side by side.
- New localized strings go in `Shared/Framework/Resources/Localizable.xcstrings` with `"extractionState" : "manual"` and both `de` and `en` localizations, in Xcode's formatting style (2-space indent steps, `" : "` key separator). Keys are stored alphabetically.
- Integer specifiers in new strings are `%ld`, never `%d`. `%d` generates an `Int32` parameter and forces casts at the call site; `%ld` generates `Int`, matching the `documentCount: Int` signatures and every existing bulk-edit string in the catalog.
- Snapshot tests use `record: .environment`, which defaults to `.missing` — the **first** run after adding a new snapshot test records the reference and *fails* with "No reference was found on disk"; the **second** run passes. Both runs are steps in this plan. Never set `SNAPSHOT_RECORD` to re-record existing snapshots unless a step says to.
- Scope: tags only. Title bulk edit and `Method.delete` stay unimplemented, and the `documents.isEmpty` hole in `DocumentBulkEditGenericValueReducer.systemImage(for:)` stays untouched.

---

## Task 1: Localization and the confirmation popup body

**Files:**
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsConfirmationView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsConfirmationViewTests.swift`

**Interfaces:**
- Consumes: `Tag` and `Tag.testValue(…)` (`Modules/ApiInterface/Tags/Tag.swift`), `ConfirmationPopupView`'s content-taking initializer and the `.capsule(backgroundColor:font:foregroundColor:)` view modifier (`Modules/Components/`), `Color(hex:)`.
- Produces: `struct DocumentBulkEditTagsConfirmationView: View` with stored `addTags: [Tag]`, `documentCount: Int`, `removeTags: [Tag]` and the synthesized memberwise `init(addTags:documentCount:removeTags:)`. Task 4's `DocumentBulkEditConfirmationPresenter.presentTags` renders it. Also produces the string symbols `.tagBulkEditConfirmation(_:)`, `.tagBulkEditConfirmationAdd(_:)`, `.tagBulkEditConfirmationRemove(_:)`, each taking one `Int`.

- [ ] **Step 1: Add the three new localized strings**

In `Shared/Framework/Resources/Localizable.xcstrings`, insert the block below into the `"strings"` object between the existing `"suggestions"` and `"tags"` entries — that is where all three keys sort alphabetically.

The values are ported from the shipped old app (`../paperless-ios/PaperlessKit/Sources/PaperlessAssets/Resources/Localizable.xcstrings`, keys `Global.bulkEditConfirmation`, `Type.Tag.bulkEditConfirmationAdd`, `Type.Tag.bulkEditConfirmationRemove`), with `%d` respelled `%ld` per the global constraints.

```json
    "tagBulkEditConfirmation" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird das ausgewählte Dokument verändern."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird die ausgewählten %ld Dokumente verändern."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will modify the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will modify the selected %ld documents."
                }
              }
            }
          }
        }
      }
    },
    "tagBulkEditConfirmationAdd" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Folgender Tag wird hinzugefügt:"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Folgende %ld Tags werden hinzugefügt:"
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Following tag will be added:"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Following %ld tags will be added:"
                }
              }
            }
          }
        }
      }
    },
    "tagBulkEditConfirmationRemove" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Folgender Tag wird entfernt:"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Folgende %ld Tags werden entfernt:"
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Following tag will be removed:"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Following %ld tags will be removed:"
                }
              }
            }
          }
        }
      }
    },
```

Note the `"one"` variants take no argument while the `"other"` variants take `%ld`. That is the shape the catalog already uses for `correspondentBulkEditConfirmationRemove`, and xcstrings-tool generates a single one-`Int` symbol from it.

- [ ] **Step 2: Write the failing snapshot tests**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsConfirmationViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Components
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentBulkEditTagsConfirmationViewTests {

    @Test
    func testSnapshot_add() async throws {
        assertSnapshot(
            of: popup(
                addTags: [
                    .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
                    .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000")
                ],
                removeTags: []
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "add"
        )
    }

    @Test
    func testSnapshot_remove() async throws {
        assertSnapshot(
            of: popup(
                addTags: [],
                removeTags: [
                    .testValue(color: "#FB9A99", id: 3, name: "Draft", textColor: "#000000")
                ]
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "remove"
        )
    }

    @Test
    func testSnapshot_addAndRemove() async throws {
        assertSnapshot(
            of: popup(
                addTags: [
                    .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
                    .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000")
                ],
                removeTags: [
                    .testValue(color: "#FB9A99", id: 3, name: "Draft", textColor: "#000000")
                ]
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "addAndRemove"
        )
    }

    private func popup(
        addTags: [ApiInterface.Tag],
        removeTags: [ApiInterface.Tag]
    ) -> some View {
        ScrollView {
            ConfirmationPopupView(
                title: .confirmAssignment,
                cancel: {},
                confirm: {}
            ) {
                DocumentBulkEditTagsConfirmationView(
                    addTags: addTags,
                    documentCount: 5,
                    removeTags: removeTags
                )
            }
        }
    }
}
```

Snapshotting the whole `ConfirmationPopupView` rather than the bare body is deliberate — it is what the user sees, and it is the pattern `ComponentsTests/Popup/ConfirmationPopupViewTests.swift` already uses.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL — compile error, `cannot find 'DocumentBulkEditTagsConfirmationView' in scope`.

- [ ] **Step 4: Write the view**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsConfirmationView.swift`:

```swift
import ApiInterface
import Components
import SwiftUI

struct DocumentBulkEditTagsConfirmationView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: .x4) {
            Text(.tagBulkEditConfirmation(documentCount))

            if !addTags.isEmpty {
                section(
                    tags: addTags,
                    title: .tagBulkEditConfirmationAdd(addTags.count)
                )
            }

            if !removeTags.isEmpty {
                section(
                    tags: removeTags,
                    title: .tagBulkEditConfirmationRemove(removeTags.count)
                )
            }
        }
    }

    let addTags: [Tag]

    let documentCount: Int

    let removeTags: [Tag]

    @ViewBuilder
    private func section(
        tags: [Tag],
        title: LocalizedStringResource
    ) -> some View {
        VStack(alignment: .leading, spacing: .x3) {
            Text(title)

            ScrollView(.horizontal) {
                HStack(spacing: .x3) {
                    ForEach(tags) { tag in
                        Text(tag.description)
                            .capsule(
                                backgroundColor: Color(hex: tag.color),
                                font: .body,
                                foregroundColor: Color(hex: tag.textColor)
                            )
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }
}
```

`Tag: CustomStringConvertible` returns `name`, and `DocumentFilterTagListView` renders tags as `Text(value.description).capsule(…)` — this matches it exactly.

- [ ] **Step 5: Run the tests to record the references**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL, three times, each with "No reference was found on disk. Automatically recorded snapshot". This is the expected first-run behaviour of `record: .environment`. New PNGs appear under `Snapshots/DocumentsFeatureTests/DocumentBulkEditTagsConfirmationViewTests/`.

- [ ] **Step 6: Inspect the recorded snapshots**

Open the three new PNGs. Confirm: the document-count sentence reads "This operation will modify the selected 5 documents.", the add section lists Invoice and 2026 as coloured capsules, the remove section lists Draft, and neither section renders when its array is empty. If a section is missing or the capsules are unstyled, fix the view and delete the wrong references before re-recording.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS.

- [ ] **Step 8: Format and commit**

```bash
mise run format
git add Shared/Framework/Resources/Localizable.xcstrings \
        Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsConfirmationView.swift \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsConfirmationViewTests.swift \
        Snapshots/DocumentsFeatureTests/DocumentBulkEditTagsConfirmationViewTests
git commit -m "feat: add bulk edit tags confirmation popup body"
```

---

## Task 2: Reducer core — state, tap logic, reset

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`

**Interfaces:**
- Consumes: `Tag`, `Document.Id`, `Server` (`ApiInterface`); `@Dependency(\.dismiss)`.
- Produces: `DocumentBulkEditTagsReducer` with nested `Operation` (`.add` / `.remove`), `State` (stored: `documentCounts: [Tag.Id: Int]`, `documents: Set<Document.Id>`, `isLoading: Bool`, `isSaving: Bool`, `operations: [Tag.Id: Operation]`, `searchText: String`, `server: Server`, `values: IdentifiedArrayOf<Tag>`; derived: `addTags: [Tag.Id]`, `filteredValues`, `isEdited`, `removeTags: [Tag.Id]`, `isAssignedToAll(_:)`, `isAssignedToAny(_:)`, `systemImage(for:)`), and `Action` with `.binding`, `.view(.closeButtonTapped)`, `.view(.resetButtonTapped)`, `.view(.valueTapped(Tag))`. Task 3 adds `.error`, `.selectionDataLoaded`, `.view(.onAppear)`; Task 4 adds `.applyConfirmed`, `.delegate`, `.view(.applyButtonTapped)`. Also produces `State.testValue(…)` used by Tasks 3–5.

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentBulkEditTagsReducerTests {

    @Test
    func test_filteredValues() async throws {
        let store = TestStore(initialState: .testValue(
            searchText: "voi",
            values: [
                .testValue(id: 1, name: "Invoice"),
                .testValue(id: 2, name: "Receipt")
            ]
        )) {
            DocumentBulkEditTagsReducer()
        }

        #expect(store.state.filteredValues == [.testValue(id: 1, name: "Invoice")])
    }

    @Test
    func test_isEdited() async throws {
        #expect(DocumentBulkEditTagsReducer.State.testValue().isEdited == false)
        #expect(DocumentBulkEditTagsReducer.State.testValue(operations: [1: .add]).isEdited == true)
        #expect(DocumentBulkEditTagsReducer.State.testValue(operations: [1: .remove]).isEdited == true)
    }

    @Test
    func test_addTags_removeTags_areSorted() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            operations: [3: .add, 1: .add, 4: .remove, 2: .remove]
        )

        #expect(state.addTags == [1, 3])
        #expect(state.removeTags == [2, 4])
    }

    @Test
    func test_systemImage() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11]
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "checkmark.circle.fill")
        #expect(state.systemImage(for: .testValue(id: 2)) == "minus.circle")
        #expect(state.systemImage(for: .testValue(id: 3)) == "circle")
    }

    @Test
    func test_systemImage_whenEdited() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11],
            operations: [1: .remove, 2: .add]
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "circle")
        #expect(state.systemImage(for: .testValue(id: 2)) == "checkmark.circle.fill")
    }

    @Test
    func test_systemImage_withEmptySelection() async throws {
        let state = DocumentBulkEditTagsReducer.State.testValue(
            documentCounts: [:],
            documents: []
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "circle")
    }

    @Test
    func test_view_valueTapped_cyclesWhenUnassigned() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [:],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .add]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_valueTapped_cyclesWhenPartiallyAssigned() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .add]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .remove]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_valueTapped_cyclesWhenAssignedToAll() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 2],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .remove]
        }
        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_valueTapped_tracksTagsIndependently() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 2],
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operations = [1: .remove]
        }
        await store.send(.view(.valueTapped(.testValue(id: 2)))) {
            $0.operations = [1: .remove, 2: .add]
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            operations: [1: .add, 2: .remove]
        )) {
            DocumentBulkEditTagsReducer()
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.operations = [:]
        }
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }
}
```

`test_view_valueTapped_cyclesWhen*` drive each cycle all the way round rather than asserting one step, because the wrap-around is where the reference implementation's four-branch conditional is easiest to get wrong. `test_systemImage_withEmptySelection` pins the `!documents.isEmpty` guard — without it, `0 == 0` would make every unassigned tag render as assigned-to-all.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL — compile error, `cannot find 'DocumentBulkEditTagsReducer' in scope`.

- [ ] **Step 3: Write the reducer**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentBulkEditTagsReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case view(View)

        public enum View {
            case closeButtonTapped
            case resetButtonTapped
            case valueTapped(Tag)
        }
    }

    public enum Operation: Equatable, Sendable {
        case add
        case remove
    }

    @ObservableState
    public struct State: Equatable {

        var addTags: [Tag.Id] {
            operations.filter { $0.value == .add }.keys.sorted()
        }

        var documentCounts: [Tag.Id: Int] = [:]

        let documents: Set<Document.Id>

        var filteredValues: IdentifiedArrayOf<Tag> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        func isAssignedToAll(_ value: Tag) -> Bool {
            !documents.isEmpty && documentCounts[value.id, default: 0] == documents.count
        }

        func isAssignedToAny(_ value: Tag) -> Bool {
            documentCounts[value.id, default: 0] > 0
        }

        var isEdited: Bool {
            !operations.isEmpty
        }

        var isLoading = false

        var isSaving = false

        var operations: [Tag.Id: Operation] = [:]

        var removeTags: [Tag.Id] {
            operations.filter { $0.value == .remove }.keys.sorted()
        }

        var searchText = ""

        let server: Server

        func systemImage(for value: Tag) -> String {
            switch operations[value.id] {
            case .add:
                return "checkmark.circle.fill"
            case .remove:
                return "circle"
            case nil:
                if isAssignedToAll(value) {
                    return "checkmark.circle.fill"
                }
                if isAssignedToAny(value) {
                    return "minus.circle"
                }
                return "circle"
            }
        }

        let values: IdentifiedArrayOf<Tag>
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .run { _ in
                        @Dependency(\.dismiss)
                        var dismiss

                        await dismiss()
                    }
                case .resetButtonTapped:
                    state.operations = [:]
                    return .none
                case let .valueTapped(value):
                    let isAssignedToAll = state.isAssignedToAll(value)
                    let isAssignedToAny = state.isAssignedToAny(value)
                    switch state.operations[value.id] {
                    case .remove where isAssignedToAll:
                        state.operations[value.id] = nil
                    case .add where isAssignedToAny:
                        state.operations[value.id] = .remove
                    case nil where isAssignedToAll:
                        state.operations[value.id] = .remove
                    case nil:
                        state.operations[value.id] = .add
                    default:
                        state.operations[value.id] = nil
                    }
                    return .none
                }
            case .binding:
                return .none
            }
        }
    }

    public init() {}
}
```

The case order matters. Each guarded case must precede the unguarded case for the same pattern, and every `nil` case must precede `default` — a `default` reached with `operations[value.id] == nil` would clear an operation that was never set, breaking the "no document has it" cycle. The `default` arm exists only to catch `.add` when the tag is assigned to nothing and `.remove` when it is not assigned to all; both mean "undo the pending change".

- [ ] **Step 4: Write the test value**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+TestValue.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension DocumentBulkEditTagsReducer.State {

    static func testValue(
        documentCounts: [Tag.Id: Int] = [:],
        documents: Set<Document.Id> = [10, 11],
        isLoading: Bool = false,
        isSaving: Bool = false,
        operations: [Tag.Id: DocumentBulkEditTagsReducer.Operation] = [:],
        searchText: String = "",
        server: Server = .testValue(),
        values: IdentifiedArrayOf<Tag> = [
            .testValue(id: 1, name: "T1"),
            .testValue(id: 2, name: "T2")
        ]
    ) -> Self {
        .init(
            documentCounts: documentCounts,
            documents: documents,
            isLoading: isLoading,
            isSaving: isSaving,
            operations: operations,
            searchText: searchText,
            server: server,
            values: values
        )
    }
}
```

This mirrors `DocumentBulkEditGenericValueReducer+TestValue.swift`. It is in the feature target, not the test target, exactly as the generic one is — the memberwise initialiser it calls is internal, so it cannot live in `DocumentsFeatureTests`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS — 12 new tests in `DocumentBulkEditTagsReducerTests`.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift \
        Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+TestValue.swift \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift
git commit -m "feat: add bulk edit tags reducer state and tap logic"
```

---

## Task 3: Load selection data

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`

**Interfaces:**
- Consumes: Task 2's `DocumentBulkEditTagsReducer.State` and `Action`; `@Dependency(\.getSelectionData.execute)`, `GetSelectionDataInput(documents:)`, `GetSelectionDataOutput.selectedTags: [SelectionDataItem<Tag.Id>]` (all already shipped); `Effect.toast(_:)`.
- Produces: `Action.error(Error)`, `Action.selectionDataLoaded(GetSelectionDataOutput)`, `Action.View.onAppear`, and `Effect.runGetSelectionData(documents:server:)` constrained to this reducer's `Action`. Task 4 adds two more effects to the same file and reuses the private `CancelID` enum.

- [ ] **Step 1: Write the failing tests**

Append to `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`, inside the struct:

```swift
    @Test
    func test_view_onAppear() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                .testValue(selectedTags: [
                    .init(documentCount: 2, id: 1),
                    .init(documentCount: 1, id: 2)
                ])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.selectionDataLoaded) {
            $0.documentCounts = [1: 2, 2: 1]
            $0.isLoading = false
        }
    }

    @Test
    func test_view_onAppear_sendsSelectedDocuments() async throws {
        let input = LockIsolated<GetSelectionDataInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.getSelectionData.execute = { selectionDataInput, _ in
                input.setValue(selectionDataInput)
                return .testValue(selectedTags: [])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.selectionDataLoaded) {
            $0.documentCounts = [:]
            $0.isLoading = false
        }

        #expect(input.value?.documents.sorted() == [10, 11])
    }

    @Test
    func test_view_onAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.error) {
            $0.isLoading = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL — compile error, `type 'DocumentBulkEditTagsReducer.Action.View' has no member 'onAppear'`.

- [ ] **Step 3: Create the effect file**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentBulkEditTagsReducer.Action {

    static func runGetSelectionData(
        documents: Set<Document.Id>,
        server: Server
    ) -> Self {
        @Dependency(\.getSelectionData.execute)
        var getSelectionData

        let input = GetSelectionDataInput(documents: Array(documents))

        return .run { send in
            await send(.selectionDataLoaded(try await getSelectionData(input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getSelectionData)
    }
}

private enum CancelID {
    case getSelectionData
}
```

Unlike `DocumentBulkEditGenericValueReducer+Effect.swift`, `Action` binds concretely here, so this is a plain constrained extension rather than a set of generic statics.

- [ ] **Step 4: Extend the reducer**

In `DocumentBulkEditTagsReducer.swift`, add the two new cases to `Action` (alphabetically) and `onAppear` to `Action.View`:

```swift
    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case error(Error)
        case selectionDataLoaded(GetSelectionDataOutput)
        case view(View)

        public enum View {
            case closeButtonTapped
            case onAppear
            case resetButtonTapped
            case valueTapped(Tag)
        }
    }
```

Then add the handlers to `Reduce`. `.error` and `.selectionDataLoaded` go before `.view` (alphabetical order of cases in the switch, matching the generic reducer):

```swift
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case let .selectionDataLoaded(output):
                state.documentCounts = Dictionary(
                    uniqueKeysWithValues: output.selectedTags.map { ($0.id, $0.documentCount) }
                )
                state.isLoading = false
                return .none
```

and the new view case, between `closeButtonTapped` and `resetButtonTapped`:

```swift
                case .onAppear:
                    state.isLoading = true
                    return .runGetSelectionData(
                        documents: state.documents,
                        server: state.server
                    )
```

`.error` clears both `isLoading` and `isSaving` unconditionally rather than per-source: only one request can be in flight at a time, and it keeps the handler a single case regardless of which effect failed. This is exactly what the generic reducer does.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS — 15 tests in `DocumentBulkEditTagsReducerTests`.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit/Tags/ \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift
git commit -m "feat: load selection data into the bulk edit tags sheet"
```

---

## Task 4: Apply flow — confirmation popup and bulk edit request

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationPresenter.swift`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`

**Interfaces:**
- Consumes: Task 1's `DocumentBulkEditTagsConfirmationView(addTags:documentCount:removeTags:)`; Tasks 2–3's reducer; `@Dependency(\.bulkEditDocuments.execute)`, `BulkEditDocumentsInput(documents:method:)` and `.modifyTags(.init(addTags:removeTags:))` (already shipped); `@Dependency(\.popupPresenter)` and `ConfirmationPopupView(title:cancel:confirm:content:)`.
- Produces: `DocumentBulkEditConfirmationPresenter.presentTags: @Sendable ([Tag], Int, [Tag]) async -> Bool`, generated call form `presentTags(addTags:documentCount:removeTags:)`; `Action.applyConfirmed`, `Action.Delegate.documentsUpdated`, `Action.View.applyButtonTapped`; effects `runBulkEdit(addTags:documents:removeTags:server:)` and `runConfirmApply(addTags:documentCount:removeTags:)`. Task 6 consumes `.delegate(.documentsUpdated)`.

**Note on parameter order:** the design doc sketched `presentTags(documentCount:addTags:removeTags:)`. This plan uses alphabetical order (`addTags:documentCount:removeTags:`) to match the codebase convention that applies everywhere else, including `DocumentBulkEditTagsConfirmationView`'s own property order from Task 1.

- [ ] **Step 1: Write the failing tests**

Append to `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift`, inside the struct:

```swift
    @Test
    func test_view_applyButtonTapped_confirmed() async throws {
        let addTags = LockIsolated<[ApiInterface.Tag]>([])
        let documentCount = LockIsolated(0)
        let removeTags = LockIsolated<[ApiInterface.Tag]>([])
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operations: [2: .add, 1: .remove],
            values: [
                .testValue(id: 1, name: "Zebra"),
                .testValue(id: 2, name: "Apple")
            ]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { add, count, remove in
                addTags.setValue(add)
                documentCount.setValue(count)
                removeTags.setValue(remove)
                return true
            }
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.view(.applyButtonTapped))
        await store.receive(\.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        #expect(addTags.value.map(\.id) == [2])
        #expect(documentCount.value == 2)
        #expect(removeTags.value.map(\.id) == [1])

        let sent = try #require(input.value)
        #expect(sent.documents.sorted() == [10, 11])
        #expect(sent.method == .modifyTags(.init(addTags: [2], removeTags: [1])))
    }

    @Test
    func test_view_applyButtonTapped_sortsTagsByName() async throws {
        let addTags = LockIsolated<[ApiInterface.Tag]>([])
        let store = TestStore(initialState: .testValue(
            operations: [1: .add, 2: .add],
            values: [
                .testValue(id: 1, name: "Zebra"),
                .testValue(id: 2, name: "Apple")
            ]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { add, _, _ in
                addTags.setValue(add)
                return false
            }
        }

        await store.send(.view(.applyButtonTapped))

        #expect(addTags.value.map(\.name) == ["Apple", "Zebra"])
    }

    @Test
    func test_view_applyButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: .testValue(
            operations: [1: .add]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { _, _, _ in false }
        }

        await store.send(.view(.applyButtonTapped))
    }

    @Test
    func test_view_applyButtonTapped_doesNothingWhenUnedited() async throws {
        let presentationCount = LockIsolated(0)
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.documentBulkEditConfirmation.presentTags = { _, _, _ in
                presentationCount.setValue(presentationCount.value + 1)
                return false
            }
        }

        await store.send(.view(.applyButtonTapped))
        #expect(presentationCount.value == 0)
    }

    @Test
    func test_applyConfirmed_addOnly() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operations: [2: .add, 1: .add]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        let sent = try #require(input.value)
        #expect(sent.method == .modifyTags(.init(addTags: [1, 2], removeTags: [])))
    }

    @Test
    func test_applyConfirmed_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            operations: [1: .add]
        )) {
            DocumentBulkEditTagsReducer()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }
```

`test_applyConfirmed_addOnly` seeds `operations` out of id order to prove `addTags` sorts before it reaches the request — the API takes arrays, and an unsorted one would make these assertions flaky.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL — compile error, `value of type 'DocumentBulkEditConfirmationPresenter' has no member 'presentTags'`.

- [ ] **Step 3: Extend the confirmation presenter**

In `Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationPresenter.swift`, add the new closure to the client, a default to `previewValue`, the live wiring, and the private implementation. The file becomes:

```swift
import ApiInterface
import Components
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct DocumentBulkEditConfirmationPresenter: Sendable {

    /// Presents the confirmation popup and suspends until the user confirms or cancels
    var present: @Sendable (_ message: LocalizedStringResource) async -> Bool = { _ in false }

    /// Presents the tag confirmation popup and suspends until the user confirms or cancels
    var presentTags: @Sendable (
        _ addTags: [Tag],
        _ documentCount: Int,
        _ removeTags: [Tag]
    ) async -> Bool = { _, _, _ in false }
}

extension DocumentBulkEditConfirmationPresenter: TestDependencyKey {

    static let previewValue = Self(
        present: { _ in false },
        presentTags: { _, _, _ in false }
    )

    static let testValue = Self()
}

extension DocumentBulkEditConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: present(message:),
        presentTags: presentTags(addTags:documentCount:removeTags:)
    )
}

private extension DocumentBulkEditConfirmationPresenter {

    static func present(message: LocalizedStringResource) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmAssignment,
                message: message,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            )
        } ?? false
    }

    static func presentTags(
        addTags: [Tag],
        documentCount: Int,
        removeTags: [Tag]
    ) async -> Bool {
        @Dependency(\.popupPresenter)
        var popupPresenter

        return await popupPresenter.present { resolve in
            ConfirmationPopupView(
                title: .confirmAssignment,
                cancel: { resolve(false) },
                confirm: { resolve(true) }
            ) {
                DocumentBulkEditTagsConfirmationView(
                    addTags: addTags,
                    documentCount: documentCount,
                    removeTags: removeTags
                )
            }
        } ?? false
    }
}

extension DependencyValues {

    var documentBulkEditConfirmation: DocumentBulkEditConfirmationPresenter {
        get { self[DocumentBulkEditConfirmationPresenter.self] }
        set { self[DocumentBulkEditConfirmationPresenter.self] = newValue }
    }
}
```

Two changes beyond the addition itself: the file now needs `import ApiInterface` for `Tag`, and `previewValue` gets an explicit `presentTags` so it does not fall back to the unimplemented default.

The closure takes plain data — `[Tag]`, `Int` — rather than a `View`, which is what keeps it `Sendable` and lets `TestStore` assert on the arguments.

- [ ] **Step 4: Add the two effects**

In `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducer+Effect.swift`, add both methods (alphabetically, before `runGetSelectionData`) and extend `CancelID`:

```swift
    static func runBulkEdit(
        addTags: [Tag.Id],
        documents: Set<Document.Id>,
        removeTags: [Tag.Id],
        server: Server
    ) -> Self {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: Array(documents),
            method: .modifyTags(.init(addTags: addTags, removeTags: removeTags))
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.delegate(.documentsUpdated))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.bulkEdit)
    }

    static func runConfirmApply(
        addTags: [Tag],
        documentCount: Int,
        removeTags: [Tag]
    ) -> Self {
        @Dependency(\.documentBulkEditConfirmation.presentTags)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(addTags, documentCount, removeTags) else {
                return
            }
            await send(.applyConfirmed)
        }
        .cancellable(id: CancelID.confirmApply)
    }
```

```swift
private enum CancelID {
    case bulkEdit
    case confirmApply
    case getSelectionData
}
```

`presentConfirmation(addTags, documentCount, removeTags)` is called **without** argument labels. `@DependencyClient` generates a labelled *method* on the struct, but `@Dependency(\.documentBulkEditConfirmation.presentTags)` binds the underlying closure, whose parameters are declared `_ addTags:` etc. and therefore take no labels. The existing `runConfirmApply` in `DocumentBulkEditGenericValueReducer+Effect.swift` calls `presentConfirmation(message)` the same way.

- [ ] **Step 5: Extend the reducer**

In `DocumentBulkEditTagsReducer.swift`, `Action` becomes:

```swift
    public enum Action: BindableAction, ViewAction {
        case applyConfirmed
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case selectionDataLoaded(GetSelectionDataOutput)
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsUpdated
        }

        public enum View {
            case applyButtonTapped
            case closeButtonTapped
            case onAppear
            case resetButtonTapped
            case valueTapped(Tag)
        }
    }
```

Add a `confirmationTags` helper to `State`, alphabetically between `addTags` and `documentCounts`:

```swift
        func confirmationTags(_ ids: [Tag.Id]) -> [Tag] {
            ids.compactMap { values[id: $0] }.sorted { $0.name < $1.name }
        }
```

Add the `applyConfirmed` handler to `Reduce`, first in the switch:

```swift
            case .applyConfirmed:
                guard state.isEdited else {
                    return .none
                }
                state.isSaving = true
                return .runBulkEdit(
                    addTags: state.addTags,
                    documents: state.documents,
                    removeTags: state.removeTags,
                    server: state.server
                )
```

Add the `applyButtonTapped` view case, first inside the view switch:

```swift
                case .applyButtonTapped:
                    guard state.isEdited else {
                        return .none
                    }
                    return .runConfirmApply(
                        addTags: state.confirmationTags(state.addTags),
                        documentCount: state.documents.count,
                        removeTags: state.confirmationTags(state.removeTags)
                    )
```

Finally add `.delegate` to the catch-all at the bottom:

```swift
            case .binding, .delegate:
                return .none
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS — 21 tests in `DocumentBulkEditTagsReducerTests`.

- [ ] **Step 7: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit/ \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsReducerTests.swift
git commit -m "feat: apply bulk tag changes behind a confirmation popup"
```

---

## Task 5: The bulk edit tags sheet view

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsViewTests.swift`

**Interfaces:**
- Consumes: the full reducer from Tasks 2–4; `Sheet`, `SheetHeader`, `Searchable`, `AdaptiveStack`, `EmptyListView`, `.buttonStyle(.primary(isLoading:))` / `.secondary()`, `.capsule(backgroundColor:font:foregroundColor:)`, `Color(hex:)` (all `Components`); the existing string keys `.apply`, `.close`, `.editTags`, `.reset`.
- Produces: `struct DocumentBulkEditTagsView: View` taking `store: StoreOf<DocumentBulkEditTagsReducer>`. Task 6 presents it from `DocumentListBottomToolbar`.

- [ ] **Step 1: Write the failing snapshot tests**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentBulkEditTagsViewTests {

    @Test
    func testSnapshot_unedited() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documentCounts: [1: 2, 2: 1],
                documents: [10, 11],
                values: values
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "unedited"
        )
    }

    @Test
    func testSnapshot_edited() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documentCounts: [1: 2, 2: 1],
                documents: [10, 11],
                operations: [1: .remove, 3: .add],
                values: values
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "edited"
        )
    }

    @Test
    func testSnapshot_loading() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                isLoading: true,
                values: []
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "loading"
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                searchText: "nothing matches",
                values: values
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    private var values: IdentifiedArrayOf<ApiInterface.Tag> {
        [
            .testValue(color: "#A6CEE3", id: 1, name: "Invoice", textColor: "#000000"),
            .testValue(color: "#B2DF8A", id: 2, name: "2026", textColor: "#000000"),
            .testValue(color: "#FB9A99", id: 3, name: "Draft", textColor: "#000000")
        ]
    }

    private func view(state: DocumentBulkEditTagsReducer.State) -> some View {
        DocumentBulkEditTagsView(
            store: Store(initialState: state) {
                EmptyReducer<
                    DocumentBulkEditTagsReducer.State,
                    DocumentBulkEditTagsReducer.Action
                >()
            }
        )
    }
}
```

`EmptyReducer` is what keeps `.task { … onAppear }` from firing a real request during the snapshot — the same trick `DocumentBulkEditGenericValueViewTests` uses.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL — compile error, `cannot find 'DocumentBulkEditTagsView' in scope`.

- [ ] **Step 3: Write the view**

Create `Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentBulkEditTagsReducer.self)
struct DocumentBulkEditTagsView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .editTags,
                left: leftHeader
            )
        } content: {
            list()
        } bottom: {
            buttons()
        }
        .task { await send(.onAppear).finish() }
    }

    @Bindable
    var store: StoreOf<DocumentBulkEditTagsReducer>

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
            .disabled(!store.isEdited)

            Button {
                send(.applyButtonTapped)
            } label: {
                Text(.apply)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
            .disabled(!store.isEdited)
        }
    }

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.filteredValues.isEmpty, !store.isLoading {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
        }
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        Button {
            send(.closeButtonTapped)
        } label: {
            Image(systemName: "xmark")
                .accessibilityLabel(.close)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        Searchable {
            List(store.filteredValues) { value in
                Button {
                    send(.valueTapped(value))
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: store.state.systemImage(for: value))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.m3Outline)
                        Text(value.description)
                            .capsule(
                                backgroundColor: Color(hex: value.color),
                                font: .body,
                                foregroundColor: Color(hex: value.textColor)
                            )
                        Spacer()
                        Text(String(store.documentCounts[value.id] ?? 0))
                            .font(.caption2)
                            .foregroundStyle(Color.m3OnSurface)
                    }
                }
                .foregroundStyle(Color.m3OnSurface)
                .id(value.id)
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                .listRowSeparator(.hidden)
            }
            .background(Color.m3Surface)
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .navigationBarHidden(true)
            .overlay(emptyListView())
            .overlay(loadingView())
            .presentationDetents([.sheet])
            .scrollContentBackground(.hidden)
            .searchable(text: $store.searchText)
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if store.isLoading {
            ProgressView()
                .controlSize(.large)
        }
    }
}
```

This is `DocumentBulkEditGenericValueView` with two substitutions: the header title is `.editTags`, and the row label is a capsule instead of plain `Text`. Everything else is identical, deliberately.

`@ViewAction(for:)` generates the `send(_:)` used throughout, so the calls are `send(.onAppear)` rather than `store.send(.view(.onAppear))`. It works here because `DocumentBulkEditTagsView` is **not** generic.

`DocumentBulkEditGenericValueView<Value>` deliberately does not carry the macro: applying it to a generic view fails to compile with `type 'Value' does not conform to protocol 'DocumentBulkEditGenericValue'`, because the macro-generated conformance extension drops the generic parameter's constraint. `DocumentFilterGenericValueListView<Value>` is unmacroed for the same reason. Both were tried and reverted on 2026-08-09; don't re-attempt.

The failure mode is worth recognising, because it is deeply unobvious: once the macro fails, the bare `send(…)` calls resolve to Darwin's C `send()` socket function, and the compiler reports a cascade of `type 'Int32' has no member 'onAppear'` and `missing arguments for parameters #2, #3, #4 in call` rather than anything about macros.

- [ ] **Step 4: Run the tests to record the references**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL, four times, each with "No reference was found on disk. Automatically recorded snapshot".

- [ ] **Step 5: Inspect the recorded snapshots**

Open the four new PNGs under `Snapshots/DocumentsFeatureTests/DocumentBulkEditTagsViewTests/`. Confirm:

- **unedited** — Invoice shows `checkmark.circle.fill` with count 2, 2026 shows `minus.circle` with count 1, Draft shows `circle` with count 0; all three names render as coloured capsules; Reset and Apply are disabled.
- **edited** — Invoice now shows `circle` (pending remove), Draft shows `checkmark.circle.fill` (pending add), 2026 is unchanged at `minus.circle`; Reset and Apply are enabled.
- **loading** — a large spinner, no rows, and no "no results" placeholder.
- **empty** — the search field contains the query and the tray placeholder shows.

If any of these is wrong, fix the view and delete the wrong references before re-recording.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit/Tags/DocumentBulkEditTagsView.swift \
        Modules/DocumentsFeatureTests/DocumentBulkEdit/Tags/DocumentBulkEditTagsViewTests.swift \
        Snapshots/DocumentsFeatureTests/DocumentBulkEditTagsViewTests
git commit -m "feat: add the bulk edit tags sheet"
```

---

## Task 6: Wire the sheet into the document list

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentBulkEditTagsReducer` and `DocumentBulkEditTagsView` from Tasks 2–5; the existing `SharedReaderKey.tags(_ server:)` (`Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift:114`).
- Produces: `DocumentListReducer.Destination.bulkEditTags`, `DocumentListReducer.State.tags`, `DocumentListReducer.Action.View.editTagsButtonTapped`. Nothing downstream consumes these — this is the last task.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`, next to the three existing `test_view_edit*ButtonTapped` tests (around line 479) and the three `test_destination_bulkEdit*_documentsUpdated` tests (around line 539):

```swift
    @Test
    func test_view_editTagsButtonTapped() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editTagsButtonTapped)) {
            $0.destination = .bulkEditTags(DocumentBulkEditTagsReducer.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.tags
            ))
        }
    }

    @Test
    func test_destination_bulkEditTags_documentsUpdated() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .bulkEditTags(DocumentBulkEditTagsReducer.State(
                documents: [1, 2],
                server: .testValue(),
                values: []
            )),
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.destination(.presented(.bulkEditTags(.delegate(.documentsUpdated))))) {
            $0.destination = nil
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        #expect(store.state.documentSelection.isActive == true)
        #expect(store.state.documentSelection.selectedDocuments == [1, 2])
    }
```

The trailing `binding` receive and the two `#expect`s matter: the refetch flips `isLoaded`, and the selection must survive so a second bulk edit can be chained. This block is copied from the neighbouring `test_destination_bulkEditCorrespondent_documentsUpdated` — if it has drifted since this plan was written, match the file, not this snippet.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: FAIL — compile error, `type 'DocumentListReducer.Action.View' has no member 'editTagsButtonTapped'`.

- [ ] **Step 3: Extend `DocumentListReducer`**

Four edits to `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`.

Add the view action alphabetically to `Action.View` (after `editStoragePathButtonTapped`):

```swift
            case editTagsButtonTapped
```

Add the destination case alphabetically (after `bulkEditStoragePath`):

```swift
        case bulkEditTags(DocumentBulkEditTagsReducer)
```

Add the shared collection. Declare the property alphabetically among the other `@Shared` properties — `savedViews`, `storagePaths`, then:

```swift
        @Shared

        var tags: IdentifiedArrayOf<Tag>
```

and initialise it at the end of the `_`-prefixed block in `init`:

```swift
            self._tags = Shared(wrappedValue: [], .tags(server))
```

Add the fourth pattern to the existing delegate handler:

```swift
            case .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditTags(.delegate(.documentsUpdated)))):
```

And add the view handler after `editStoragePathButtonTapped`:

```swift
                case .editTagsButtonTapped:
                    state.destination = .bulkEditTags(DocumentBulkEditTagsReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.tags
                    ))
                    return .none
```

- [ ] **Step 4: Run the reducer tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS.

- [ ] **Step 5: Wire the toolbar button and sheet**

In `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`, replace the empty tag button action (currently `Button {} label: { Label(.editTags, systemImage: "tag") }`):

```swift
            Button {
                send(.editTagsButtonTapped)
            } label: {
                Label(.editTags, systemImage: "tag")
            }
```

and add a fourth sheet after the `bulkEditStoragePath` one:

```swift
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditTags,
                    action: \.destination.bulkEditTags
                )
            ) { store in
                DocumentBulkEditTagsView(store: store)
                    .presentationDetents([.sheet])
            }
```

The enclosing `HStack` already carries `.disabled(store.documentSelection.selectedDocuments.isEmpty)`, so the new button inherits it.

- [ ] **Step 6: Run the full module test suite**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`

Expected: PASS, whole module. Any `DocumentListView` snapshot that renders the bottom toolbar is unaffected — the button was already there, only its action changed.

- [ ] **Step 7: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift
git commit -m "feat: wire the bulk edit tags sheet into the document list"
```

- [ ] **Step 8: Verify against a real server**

Run `mise run docker:start` and `mise run docker:seed` if the dev Paperless container is not already up (see `docs/plans/2026-08-09-docker-seed-data.md`), launch the app against it, enter selection mode, select several documents whose tags differ, and open the tags sheet. Confirm the three icon states match the seeded data, that a partially-applied tag cycles add → remove → neutral, that the confirmation popup lists the right capsules, and that the list refreshes with the new tags after confirming.
