# Filter sheet match count Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Float a capsule at the bottom of the document filter sheet showing how many documents match
the filter being edited, updating live as it changes.

**Architecture:** The list behind the sheet already re-queries on every filter change, so no new
request is added. `DocumentListReducer` writes the count and a recalculating flag into the sheet's
`@Presents` state at three points it already handles; the sheet only displays them.
Spec: `docs/superpowers/specs/2026-08-16-filter-match-count-design.md`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture 1.22, swift-dependencies, Swift Testing,
swift-snapshot-testing, Tuist 4.203.

## Global Constraints

- **Comments:** only `//`, never `///` or `/** */`, anywhere — including tests. Comment only when a
  reader would otherwise stop and wonder *why*. See `AGENTS.md`.
- **Members are alphabetically ordered** within a type — properties, then `init`, then methods, then a
  `// MARK: - Private` section.
- **Attributes go on their own line with no blank line after them.**
  `mise/scripts/attribute_blank_lines.py --check` enforces this.
- **Line width 140**, 4-space indent. Run `swiftformat .` before committing.
- **swiftlint runs through mise:** `mise exec -- swiftlint --strict --quiet` (it is not on `PATH`).
- **All user-facing text** lives in `Shared/Framework/Resources/Localizable.xcstrings` with **both**
  `en` and `de` translated. Integer format specifier is `%lld`, never `%d`.
- **In a `@ViewAction` view, call `send(...)` — never `store.send(...)`.** The macro emits a warning
  for the latter.
- Run tests with
  `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`.
  `--no-selective-testing` matters: without it a re-run of an unchanged target is skipped and reports
  success without executing anything.
- Commit after every task. Branch is `filter_match_count`; do not merge to `main`.

---

### Task 1: The count reaches the sheet

State, the string, and the three writes in `DocumentListReducer`. No view yet — this task is fully
covered by reducer tests.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift` — two `State` fields
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer+TestValue.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` — three write sites
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `DocumentFilterReducer.State.matchCount: Int?` and
  `DocumentFilterReducer.State.isRecalculating: Bool`, plus the string symbol
  `.numberOfMatchingDocuments(_ count: Int)`. Task 2 renders both fields.

- [ ] **Step 1: Add the string**

Open `Shared/Framework/Resources/Localizable.xcstrings` and insert this entry between
`"numberOfLoadedDocuments"` and `"numberOfSelectedDocuments"`, which are already adjacent. Match the
file's formatting exactly: 2-space indent and a space before every colon (`"key" : {`).

```json
    "numberOfMatchingDocuments" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "%lld Dokument"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "%lld Dokumente"
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
                  "value" : "%lld document"
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "%lld documents"
                }
              }
            }
          }
        }
      }
    },
```

Verify the file is still valid JSON and the key landed:

```bash
python3 -c "
import json
d = json.load(open('Shared/Framework/Resources/Localizable.xcstrings'))
e = d['strings']['numberOfMatchingDocuments']['localizations']
for lang in ('en', 'de'):
    v = e[lang]['variations']['plural']
    print(lang, {k: v[k]['stringUnit']['value'] for k in v})
"
```

Expected: `en {'one': '%lld document', 'other': '%lld documents'}` and the German equivalent.

- [ ] **Step 2: Write the failing tests**

Append these four tests to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`,
inside the existing `DocumentListReducerTests` suite (before its closing brace).

Note the existing `test_view_filterButtonTapped` above them already asserts the destination it opens —
these extend that with the seeded count rather than replacing it.

```swift
    @Test
    func test_view_filterButtonTapped_seedsMatchCount() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: true,
            totalNumberOfDocuments: 77
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.filterButtonTapped)) {
            $0.destination = .documentFilter(.testValue(
                input: $0.filter.input,
                matchCount: 77,
                savedView: $0.filter.savedView
            ))
        }
    }

    @Test
    func test_view_filterButtonTapped_seedsNoMatchCountBeforeTheListHasLoaded() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            isLoaded: false,
            totalNumberOfDocuments: 0
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.filterButtonTapped)) {
            $0.destination = .documentFilter(.testValue(
                input: $0.filter.input,
                matchCount: nil,
                savedView: $0.filter.savedView
            ))
        }

        #expect(store.state.destination?.documentFilter?.matchCount == nil)
    }

    @Test
    func test_destination_documentFilter_filterUpdated_recalculatesTheMatchCount() async throws {
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .documentFilter(.testValue(
                input: .testValue(searchValue: "Lego"),
                matchCount: 77
            )),
            filter: .testValue(input: .testValue(searchValue: "Lego"))
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 2,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.destination(.presented(.documentFilter(.delegate(.filterUpdated(.testValue(
            input: .testValue(searchValue: "Invoice")
        ))))))) {
            $0.filter.input = .testValue(searchValue: "Invoice")
            $0.destination?.documentFilter?.isRecalculating = true
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 2,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 2
            $0.$documentCache.withLock { $0 = [.testValue()] }
            $0.destination?.documentFilter?.isRecalculating = false
            $0.destination?.documentFilter?.matchCount = 2
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }

    @Test
    func test_error_stopsRecalculatingTheMatchCount() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            destination: .documentFilter(.testValue(
                isRecalculating: true,
                matchCount: 77
            )),
            documents: [.testValue()]
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.error(ApiError.testValue())) {
            $0.error = "Something went wrong"
            $0.destination?.documentFilter?.isRecalculating = false
        }

        // The stale count survives a failed refetch — it is the last number that was true, and
        // blanking it would tell the user the filter matches nothing.
        #expect(store.state.destination?.documentFilter?.matchCount == 77)
        #expect(toasts.value == [.error("Something went wrong")])
    }
```

The action ordering inside `test_destination_documentFilter_filterUpdated_recalculatesTheMatchCount`
mirrors the existing `test_destination_documentFilter_delegate_filterUpdated` directly above it —
`replaceDocuments`, then the `isLoaded` binding. If a run disagrees, match what the failure prints
rather than guessing.

- [ ] **Step 3: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — `extra argument 'matchCount' in call` from the `.testValue(…)` calls.

- [ ] **Step 4: Add the two state fields**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift`, add both to `State` in
alphabetical position — `isRecalculating` after `isModified`, `matchCount` after `input`:

```swift
        var isRecalculating = false
```

```swift
        var matchCount: Int?
```

Neither is written by `DocumentFilterReducer`. Add this comment above `matchCount`, because a reader
will otherwise look for the reducer case that sets it:

```swift
        // Both written by `DocumentListReducer`, which owns this state and is already re-querying on
        // every filter change. The sheet has no query of its own.
        var matchCount: Int?
```

- [ ] **Step 5: Extend the test value**

Replace the body of `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer+TestValue.swift`:

```swift
import ApiInterface
import Foundation

extension DocumentFilterReducer.State {

    static func testValue(
        destination: DocumentFilterReducer.Destination.State? = nil,
        input: DocumentFilterInput = .testValue(),
        isRecalculating: Bool = false,
        matchCount: Int? = nil,
        savedView: SavedView? = nil,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            destination: destination,
            input: input,
            savedView: savedView,
            server: server
        )
        state.isRecalculating = isRecalculating
        state.matchCount = matchCount
        return state
    }
}
```

- [ ] **Step 6: Write the three sites in `DocumentListReducer`**

All three are in `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`.

In `case .view(.filterButtonTapped)`, the destination is currently built with three arguments. Replace
the assignment with:

```swift
                case .filterButtonTapped:
                    var filterState = DocumentFilterReducer.State(
                        input: state.filter.input,
                        savedView: state.filter.savedView,
                        server: state.server
                    )
                    filterState.matchCount = state.isLoaded ? state.totalNumberOfDocuments : nil
                    state.destination = .documentFilter(filterState)
                    return .none
```

In the existing `case let .destination(.presented(.documentFilter(.delegate(delegateAction))))`, add
the flag inside the `.filterUpdated` branch, before the effect is returned:

```swift
                case let .filterUpdated(filter):
                    state.error = nil
                    state.filter = filter
                    state.destination?.documentFilter?.isRecalculating = true
                    return .runGetDocuments(
                        filterRules: state.filter.input.filterRules,
                        server: state.server,
                        sortDirection: state.filter.input.sort.direction,
                        sortField: state.filter.input.sort.field
                    )
```

In `case let .replaceDocuments(output)`, add both writes before `return .none`:

```swift
                state.destination?.documentFilter?.isRecalculating = false
                state.destination?.documentFilter?.matchCount = output.count
```

In `case let .error(error)`, add the flag clear before `return .toast(error)`:

```swift
                state.destination?.documentFilter?.isRecalculating = false
```

`matchCount` is deliberately left alone in the error case — see the comment in the test.

- [ ] **Step 7: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS — the whole module, including the four new tests and the pre-existing
`test_view_filterButtonTapped` and `test_destination_documentFilter_delegate_filterUpdated`, which
both now see the extra state writes.

- [ ] **Step 8: Format, lint and commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: carry the filter match count into the filter sheet"
```

---

### Task 2: The capsule

The view, its snapshots, and the keyboard question the spec insists on answering rather than assuming.

**Files:**
- Create: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterMatchCountView.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterViewTests.swift`
- Temporary: `Modules/DocumentsAppTests/TemporaryFilterKeyboardTests.swift` (deleted in Step 7)

**Interfaces:**
- Consumes: `matchCount` and `isRecalculating` from Task 1.
- Produces: nothing downstream.

- [ ] **Step 1: Write the failing snapshot tests**

Append to `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterViewTests.swift`, inside the
suite. The existing tests build the store inline with the real reducer; these follow that shape.

```swift
    @Test
    func testSnapshot_matchCount() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(searchValue: "Lego"),
                        matchCount: 77
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCount"
        )
    }

    @Test
    func testSnapshot_matchCountRecalculating() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(searchValue: "Lego"),
                        isRecalculating: true,
                        matchCount: 77
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCountRecalculating"
        )
    }

    @Test
    func testSnapshot_matchCountSingular() async throws {
        assertSnapshot(
            of: DocumentFilterView(
                store: Store(
                    initialState: DocumentFilterReducer.State.testValue(
                        input: .testValue(searchValue: "Lego"),
                        matchCount: 1
                    ),
                    reducer: {
                        DocumentFilterReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "matchCountSingular"
        )
    }
```

The existing `testSnapshot_allDocuments` covers the `nil` case — its state leaves `matchCount` at the
`nil` default, so it must come back showing **no** capsule. If that snapshot changes, the hidden case
is broken.

- [ ] **Step 2: Run to verify it fails**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — the three new snapshots are recorded for the first time ("snapshot was recorded"),
and they show no capsule because the view does not exist yet.

Delete the three PNGs that were just recorded so they cannot be mistaken for approved output:

```bash
rm Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/testSnapshot_matchCount*.png
```

- [ ] **Step 3: Write the capsule view**

Create `Modules/DocumentsFeature/DocumentFilter/DocumentFilterMatchCountView.swift`:

```swift
import ComposableArchitecture
import SwiftUI

struct DocumentFilterMatchCountView: View {

    var body: some View {
        if let matchCount = store.matchCount {
            Text(.numberOfMatchingDocuments(matchCount))
                .capsule(
                    backgroundColor: .m3Primary,
                    font: .footnote,
                    foregroundColor: .m3OnPrimary
                )
                // Dimmed rather than hidden while the list re-queries: the number on screen belongs
                // to the previous filter for the ~600ms a debounced keystroke takes, and hiding it
                // would flicker on every change.
                .opacity(store.isRecalculating ? 0.5 : 1)
                .animation(.default, value: store.isRecalculating)
                .padding(.x3)
        }
    }

    let store: StoreOf<DocumentFilterReducer>
}
```

The two imports are all that is needed: `DocumentListStatusBarView.swift` uses the same `.capsule` and
`.x3` with exactly these two, so `Components` reaches this file transitively. Do not add a third.

- [ ] **Step 4: Attach it to the sheet**

In `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift`, add the overlay to the `Sheet`
in `body`, immediately after the closing brace of the `content:` block and before the existing
`.sheet(item:)` modifier:

```swift
        .overlay(alignment: .bottom) {
            DocumentFilterMatchCountView(store: store)
        }
```

This is the same attachment `DocumentListView` and `InboxView` use for `DocumentListStatusBarView`.

- [ ] **Step 5: Record and inspect the snapshots**

Run the tests twice — the first run records, the second verifies:

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
tuist test DocumentsFeature -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing -- -testLanguage en -testRegion DE
```

Expected: first run fails with "snapshot was recorded", second passes.

Then **open the four PNGs** in `Snapshots/DocumentsFeatureTests/DocumentFilterViewTests/` and confirm:

- `testSnapshot_matchCount` — teal capsule at the bottom centre reading "77 documents"
- `testSnapshot_matchCountSingular` — reads "1 document", not "1 documents"
- `testSnapshot_matchCountRecalculating` — visibly faded next to the first
- `testSnapshot_allDocuments` — **unchanged, no capsule**

If `testSnapshot_allDocuments` now differs, the `nil` case is rendering something and must be fixed
rather than re-recorded.

- [ ] **Step 6: Answer the keyboard question**

Create `Modules/DocumentsAppTests/TemporaryFilterKeyboardTests.swift`:

```swift
import XCTest

@MainActor
final class TemporaryFilterKeyboardTests: XCTestCase {

    func testCapsuleStaysAboveTheKeyboard() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        app.buttons["Filter"].firstMatch.tap()

        let capsule = app.staticTexts.matching(
            NSPredicate(format: "label ENDSWITH 'documents' OR label ENDSWITH 'document'")
        ).firstMatch
        XCTAssertTrue(capsule.waitForExistence(timeout: timeout))

        let before = capsule.frame
        print("CAPSULE before=\(before) screen=\(app.frame)")

        app.textFields["Title & content"].firstMatch.tap()
        app.textFields["Title & content"].firstMatch.typeText("Lego")
        try await Task.sleep(for: .seconds(2))

        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists, "keyboard did not come up")

        let after = capsule.frame
        print("CAPSULE after=\(after) keyboardTop=\(keyboard.frame.minY)")

        XCTAssertLessThanOrEqual(
            after.maxY,
            keyboard.frame.minY,
            "capsule is behind the keyboard"
        )
    }

    private let timeout = 10.0
}
```

Run it — this one needs the docker container up (`mise run docker:start`), because `DocumentsApp`
talks to the **ci** instance on port 9000:

```bash
tuist generate --no-open
xcodebuild test -scheme DocumentsApp -workspace LessPaper.xcworkspace \
  -destination "platform=iOS Simulator,name=iPhone 17 Pro" \
  -only-testing:DocumentsAppTests/TemporaryFilterKeyboardTests \
  -testLanguage en -testRegion DE 2>&1 | grep -E "CAPSULE|XCTAssert|Test Case.*(passed|failed)"
```

Expected: PASS, with the printed `after` frame sitting higher than `before` — the overlay rode up
with the keyboard, which is what the spec predicts.

**If it fails** because the capsule is behind the keyboard, apply the spec's fallback: in
`DocumentFilterView`, stop the scroll content consuming the inset by adding
`.ignoresSafeArea(.keyboard, edges: .bottom)` to the `Sheet`'s `content:` block, leaving the overlay
outside it to take the inset. Re-run until the assertion holds, then re-record the snapshots from
Step 5 if the layout shifted.

- [ ] **Step 7: Delete the temporary test**

```bash
rm Modules/DocumentsAppTests/TemporaryFilterKeyboardTests.swift
```

It has answered its question; it is not worth the ~30s of simulator time on every CI run, and
`DocumentsAppTests` is one of the XCUITest targets the CI script skips by default anyway.

- [ ] **Step 8: Format, lint, full test run and commit**

```bash
swiftformat . && mise exec -- swiftlint --strict --quiet && mise/scripts/attribute_blank_lines.py --check
tuist test --skip-ui-tests --no-selective-testing -d "iPhone 17 Pro" -- -testLanguage en -testRegion DE
```

Expected: the whole workspace passes — the string catalog is embedded in every module, so this is
worth running once at the end rather than trusting the `DocumentsFeature` run alone.

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots
git commit -m "feat: show the match count in the filter sheet"
```
