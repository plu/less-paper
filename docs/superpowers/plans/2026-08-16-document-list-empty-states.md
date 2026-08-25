# Document list empty states Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the one-size-fits-all "No documents found" empty state with five states that each say
what is actually true, and offer a button only where one can help.

**Architecture:** All five cases live in `DocumentListEmptyView`, chosen by an ordered chain of
conditions on `DocumentListReducer.State`. One new computed property, three new strings, no new
components. Spec: `docs/superpowers/specs/2026-08-16-document-list-empty-states-design.md`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture 1.22, Swift Testing,
swift-snapshot-testing, Tuist 4.203.

## Global Constraints

- **Comments:** only `//`, never `///` or `/** */`, anywhere — including tests. Comment only when a
  reader would otherwise stop and wonder *why*. See `AGENTS.md`.
- **In a `@ViewAction` view, call `send(...)` — never `store.send(...)`.** The macro warns otherwise.
  `DocumentListEmptyView` is `@ViewAction(for: DocumentListReducer.self)`.
- **Members are alphabetically ordered** within a type — properties, then `init`, then methods, then a
  `// MARK: - Private` section.
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
- **If a run fails with `Library not loaded: @rpath/…framework`**, that is stale DerivedData, not your
  change. Re-run with `--clean`.
- Commit after every task. Branch is `inbox_empty_state`; do not merge to `main`.

---

### Task 1: The state the view will branch on

`hasActiveFilter`, and the test-value knob the snapshots need. No visible change yet.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` — one computed property
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilter.swift` — `testValue` gains `isInbox`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DocumentListReducer.State.hasActiveFilter: Bool` and
  `DocumentFilter.testValue(input:isInbox:savedView:)`. Task 2 branches on the former and builds
  snapshot states with the latter. `State.isInboxWithoutInboxTags` already exists and is unchanged.

- [ ] **Step 1: Write the failing tests**

Append to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`, inside the
existing `DocumentListReducerTests` suite (before its closing brace).

The third test is the important one: `DocumentListReducer.State.testValue()` builds its filter from
`DocumentFilter.testValue()`, whose input is `DocumentFilterInput.testValue()`. That has to equal a
plain `DocumentFilterInput()`, or every existing empty-state snapshot silently becomes the
"no matching documents" case.

```swift
    @Test
    func test_hasActiveFilter_withSearchValue() async throws {
        let state = DocumentListReducer.State.testValue(
            filter: .testValue(input: .testValue(searchValue: "Lego"))
        )

        #expect(state.hasActiveFilter == true)
    }

    @Test
    func test_hasActiveFilter_withSavedView() async throws {
        let state = DocumentListReducer.State.testValue(
            filter: .testValue(savedView: .testValue())
        )

        #expect(state.hasActiveFilter == true)
    }

    @Test
    func test_hasActiveFilter_isFalseForTheDefaultFilter() async throws {
        #expect(DocumentListReducer.State.testValue().hasActiveFilter == false)
    }

    @Test
    func test_isInboxWithoutInboxTags() async throws {
        let withoutTags = DocumentListReducer.State.testValue(
            filter: .testValue(isInbox: true)
        )
        let withTags = DocumentListReducer.State.testValue(
            filter: .testValue(
                input: .testValue(tag: .init(rule: .any, selection: .init(any: [.testValue()]))),
                isInbox: true
            )
        )

        #expect(withoutTags.isInboxWithoutInboxTags == true)
        #expect(withTags.isInboxWithoutInboxTags == false)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — `value of type 'DocumentListReducer.State' has no member 'hasActiveFilter'` and
`extra argument 'isInbox' in call`.

- [ ] **Step 3: Add `hasActiveFilter`**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, add to `State` between
`var filter` and `var isLoaded`. Computed properties sit inline among the stored ones in alphabetical
order here — `navigationTitle` is the existing precedent:

```swift
        var hasActiveFilter: Bool {
            filter.input != DocumentFilterInput() || filter.savedView != nil
        }
```

- [ ] **Step 4: Add the `isInbox` test-value knob**

Replace the `DocumentFilter.testValue` extension at the bottom of
`Modules/DocumentsFeature/DocumentFilter/DocumentFilter.swift`:

```swift
extension DocumentFilter {
    static func testValue(
        input: DocumentFilterInput = .testValue(),
        isInbox: Bool = false,
        savedView: SavedView? = nil
    ) -> Self {
        var filter = Self(
            input: input,
            savedView: savedView
        )
        filter.isInbox = isInbox
        return filter
    }
}
```

The real `DocumentFilter.inbox(server:)` is not usable here: it reads `@Shared(.inboxTags(server))`
and `@Shared(.tags(server))`, so a test using it would depend on shared storage rather than on the
state it is trying to describe.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS — the whole module, including the four new tests.

If `test_hasActiveFilter_isFalseForTheDefaultFilter` fails, stop: `DocumentFilterInput.testValue()`
has drifted from `DocumentFilterInput()`. Do not change the assertion — reconcile the two, because
every empty-state snapshot depends on them matching.

- [ ] **Step 6: Format, lint and commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: add hasActiveFilter to the document list state"
```

---

### Task 2: The five empty states

The strings, the view, and a snapshot per state.

**Files:**
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListEmptyView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListEmptyViewTests.swift` (create)

**Interfaces:**
- Consumes: `State.hasActiveFilter` and `DocumentFilter.testValue(isInbox:)` from Task 1.
- Produces: nothing downstream.

- [ ] **Step 1: Add the three strings**

Open `Shared/Framework/Resources/Localizable.xcstrings`. It is a JSON file with 2-space indent and a
space before every colon (`"key" : {`) — match that exactly. Insert each entry in alphabetical
position among the existing keys.

`allCaughtUp` goes after `all`:

```json
    "allCaughtUp" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Alles erledigt"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "All caught up"
          }
        }
      }
    },
```

`noInboxTagConfigured` and `noMatchingDocuments` go next to `noDocumentsFound`:

```json
    "noInboxTagConfigured" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Kein Posteingang-Tag konfiguriert"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "No inbox tag configured"
          }
        }
      }
    },
    "noMatchingDocuments" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Keine passenden Dokumente"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "No matching documents"
          }
        }
      }
    },
```

Verify the file is still valid JSON and all three landed:

```bash
python3 -c "
import json
d = json.load(open('Shared/Framework/Resources/Localizable.xcstrings'))
for k in ('allCaughtUp', 'noInboxTagConfigured', 'noMatchingDocuments'):
    print(k, {l: e['stringUnit']['value'] for l, e in d['strings'][k]['localizations'].items()})
"
```

Expected: all three print with English and German values.

- [ ] **Step 2: Write the failing snapshot tests**

Create `Modules/DocumentsFeatureTests/DocumentList/DocumentListEmptyViewTests.swift`:

```swift
@testable import DocumentsFeature

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
struct DocumentListEmptyViewTests {

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                error: "Something went wrong",
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    @Test
    func testSnapshot_inboxWithoutInboxTag() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                filter: .testValue(isInbox: true),
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "inboxWithoutInboxTag"
        )
    }

    @Test
    func testSnapshot_inboxAllCaughtUp() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                filter: .testValue(
                    input: .testValue(tag: .init(rule: .any, selection: .init(any: [.testValue()]))),
                    isInbox: true
                ),
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "inboxAllCaughtUp"
        )
    }

    @Test
    func testSnapshot_noMatchingDocuments() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                filter: .testValue(input: .testValue(searchValue: "Lego")),
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "noMatchingDocuments"
        )
    }

    @Test
    func testSnapshot_noDocuments() async throws {
        assertSnapshot(
            of: view(state: .testValue(
                documents: [],
                isLoaded: true
            )),
            as: .image(layout: .device(config: .iPhone12)),
            named: "noDocuments"
        )
    }

    private func view(state: DocumentListReducer.State) -> some View {
        DocumentListEmptyView(
            store: Store(initialState: state) {
                EmptyReducer<DocumentListReducer.State, DocumentListReducer.Action>()
            }
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.m3Surface)
    }
}
```

`EmptyReducer` rather than the real reducer: these are snapshots of five layouts, and the real
reducer would start network effects on any action.

- [ ] **Step 3: Run to verify it fails**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: the five snapshots record for the first time and report "snapshot was recorded".

Delete them, so images of the *old* single-state view are never mistaken for approved output:

```bash
rm Snapshots/DocumentsFeatureTests/DocumentListEmptyViewTests/*.png
```

- [ ] **Step 4: Rewrite the view**

Replace the body of `Modules/DocumentsFeature/DocumentList/DocumentListEmptyView.swift`:

```swift
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentListReducer.self)
struct DocumentListEmptyView: View {
    var body: some View {
        if store.documents.isEmpty && store.isLoaded {
            ContentUnavailableView {
                emptyListView()
            }
        }
    }

    @Bindable
    var store: StoreOf<DocumentListReducer>

    // The order is the logic. `isInboxWithoutInboxTags` has to be tested before the inbox is called
    // empty, or an inbox that can never hold anything is reported as an achievement; both inbox
    // cases have to be tested before `hasActiveFilter`, because the inbox filter is itself a tag
    // filter and would otherwise swallow them.
    @ViewBuilder
    private func emptyListView() -> some View {
        if let error = store.error {
            EmptyListView(
                systemImage: "exclamationmark.triangle",
                title: LocalizedStringResource(stringLiteral: error),
                content: reloadButton
            )
        } else if store.isInboxWithoutInboxTags {
            EmptyListView(
                systemImage: "tag.slash",
                title: .noInboxTagConfigured,
                content: reloadButton
            )
        } else if store.filter.isInbox {
            EmptyListView(
                systemImage: "checkmark.circle",
                title: .allCaughtUp
            )
        } else if store.hasActiveFilter {
            EmptyListView(
                systemImage: "magnifyingglass",
                title: .noMatchingDocuments,
                content: filterButton
            )
        } else {
            EmptyListView(
                systemImage: "tray",
                title: .noDocumentsFound,
                content: reloadButton
            )
        }
    }

    @ViewBuilder
    private func filterButton() -> some View {
        Button {
            send(.filterButtonTapped)
        } label: {
            Label(.filter, systemImage: "magnifyingglass")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
    }

    @ViewBuilder
    private func reloadButton() -> some View {
        Button {
            send(.reloadButtonTapped)
        } label: {
            Label(.reload, systemImage: "arrow.clockwise")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.primary())
    }
}
```

The "all caught up" branch passes no `content:`, which resolves to `EmptyListView`'s
`@ViewBuilder content: () -> Content = EmptyView.init` default and renders no button.

- [ ] **Step 5: Record and verify the snapshots**

Run the tests twice — the first run records, the second verifies:

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
```

Expected: first run fails with "snapshot was recorded", second passes.

- [ ] **Step 6: Look at all five images**

Open every PNG in `Snapshots/DocumentsFeatureTests/DocumentListEmptyViewTests/` and confirm:

| File | Icon | Text | Button |
|---|---|---|---|
| `error` | warning triangle | "Something went wrong" | Reload |
| `inboxWithoutInboxTag` | crossed-out tag | "No inbox tag configured" | Reload |
| `inboxAllCaughtUp` | check in a circle | "All caught up" | **none** |
| `noMatchingDocuments` | magnifying glass | "No matching documents" | Filter |
| `noDocuments` | tray | "No documents found" | Reload |

A green run is not enough on its own here: the five images *are* the specification of this change, and
a wrong-but-consistent rendering would pass. In particular check that `inboxAllCaughtUp` has no
button and that the two inbox states are not identical.

- [ ] **Step 7: Confirm the existing snapshots are untouched**

```bash
git status --short Snapshots/
```

Expected: only the five new `DocumentListEmptyViewTests` files. `DocumentListViewTests`'
`testSnapshot_emptyResult` and `testSnapshot_errorResult` must **not** appear as modified — neither
uses an inbox filter or a non-default filter, so both still resolve to the states they always did.

If either shows as modified, stop and diff it: something in the ordering chain is matching a case it
should not.

- [ ] **Step 8: Format, lint, full test run and commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
tuist test --skip-ui-tests --no-selective-testing -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: the whole workspace passes — the string catalog is embedded in every module, so this is
worth running once at the end rather than trusting the `DocumentsFeature` run alone.

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Shared/Framework/Resources/Localizable.xcstrings Snapshots
git commit -m "feat: give the document list an empty state per situation"
```
