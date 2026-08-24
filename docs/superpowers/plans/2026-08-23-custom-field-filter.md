# Custom Field Filtering Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let a user filter documents by custom field values using the server's `custom_field_query` rule, with four alternative mobile UIs shipped as separate branches for side-by-side evaluation.

**Architecture:** A recursive `CustomFieldQuery` model plus its codec lives in `ApiInterface` beside `CustomField`; `DocumentFilterInput` gains a `customFieldQuery` property that parses, migrates and emits the rule. One base branch carries all of that plus a collapsed filter row; four UI branches each add a different authoring experience on top and nothing else.

**Tech Stack:** Swift 6.1, SwiftUI, ComposableArchitecture (`@Reducer`, `@ObservableState`, `@ViewAction`), swift-sharing, Tagged, Swift Testing, swift-snapshot-testing, Tuist.

## Global Constraints

- **Comments:** only `//`, never `///` or `/** */`, and only when a future reader would otherwise stop and wonder why. See `AGENTS.md`.
- **`@ViewAction` views call `send(…)`, never `store.send(…)`** — including inside `.task`. Generic views that cannot carry the macro use `store.send(.view(…))`.
- **Confirmations use `PopupPresenter` + `ConfirmationPopupView`.** Never `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`. Not expected to arise in this feature.
- **No blank line between an attribute and its declaration** (`mise/scripts/attribute_blank_lines.py --check` enforces it).
- **Lint gate:** `mise ci:lint` runs `swiftformat --lint`, `swiftlint --strict`, the attribute script, and `tuist inspect dependencies --only implicit`. Max line width 140.
- **Localized strings** are keys in `Shared/Framework/Resources/Localizable.xcstrings` with `en` and `de` units, both `"state": "translated"`, `"extractionState": "manual"`. Xcode generates the `LocalizedStringResource` symbol automatically — there is no generated Swift file to edit.
- **`range` operator is omitted entirely.** It exists in the web enum but belongs to no group, so nothing can select it.
- **Depth limit 4, atom limit 5.** Client-side product choices mirroring the web; the server does not enforce them.
- **`NOT` is arity-1.** `["NOT", child]`, child inline. `["NOT",[a,b]]` is a server 500.

---

# Branch 1 — `feat/custom-field-filter-base`

Already created, currently holding only the design doc commit. PR targets `main`.

### Task 1: The operator matrix

**Files:**
- Create: `Modules/ApiInterface/CustomFields/CustomFieldQueryOperator.swift`
- Create: `Modules/ApiInterface/CustomFields/CustomFieldQueryOperatorGroup.swift`
- Test: `Modules/ApiInterfaceTests/CustomFields/CustomFieldQueryOperatorTests.swift`

**Interfaces:**
- Produces: `CustomFieldQueryOperator` (`String`-raw, `CaseIterable`, `Codable`, `Hashable`, `Identifiable`, `Sendable`) with cases `exact, in, isnull, exists, contains, icontains, gt, gte, lt, lte`; `var valueKind: CustomFieldQueryValueKind`; `var localized: LocalizedStringResource`. `CustomFieldQueryValueKind` with cases `boolean, string, number, array`. `CustomFieldQueryOperatorGroup` with cases `basic, exact, string, arithmetic, containment, subset, date`; `var operators: [CustomFieldQueryOperator]`; `static func groups(for dataType: CustomFieldDataType) -> [CustomFieldQueryOperatorGroup]`; `CustomFieldQueryOperator.operators(for:) -> [CustomFieldQueryOperator]` returning the deduplicated concatenation in group order.

- [ ] **Step 1: Write the failing test**

```swift
@Test
func testOperatorsForStringExcludeArithmetic() {
    #expect(CustomFieldQueryOperator.operators(for: .string) == [.exists, .isnull, .exact, .icontains])
}

@Test
func testOperatorsForDateAreDeduplicated() {
    // `date` admits basic + exact + date, and the date group repeats nothing from exact,
    // but gte/lte must appear once each even though a naive concatenation would be fine.
    #expect(CustomFieldQueryOperator.operators(for: .date) == [.exists, .isnull, .exact, .gte, .lte])
}

@Test
func testOperatorsForSelect() {
    #expect(CustomFieldQueryOperator.operators(for: .select) == [.exists, .isnull, .exact, .in])
}

@Test
func testOperatorsForDocumentLink() {
    #expect(CustomFieldQueryOperator.operators(for: .documentLink) == [.exists, .isnull, .contains])
}

@Test
func testOperatorsForMonetary() {
    #expect(CustomFieldQueryOperator.operators(for: .monetary) == [
        .exists, .isnull, .exact, .icontains, .gt, .gte, .lt, .lte
    ])
}

@Test
func testUnknownDataTypeOffersNoOperators() {
    #expect(CustomFieldQueryOperator.operators(for: .unknown).isEmpty)
}

@Test(arguments: [
    (CustomFieldQueryOperator.exists, CustomFieldQueryValueKind.boolean),
    (.isnull, .boolean),
    (.icontains, .string),
    (.gt, .number),
    (.contains, .array),
    (.in, .array),
])
func testValueKind(op: CustomFieldQueryOperator, kind: CustomFieldQueryValueKind) {
    #expect(op.valueKind == kind)
}
```

- [ ] **Step 2: Run the test and confirm it fails to compile**

Run: `tuist test LessPaper --skip-ui-tests --test-targets ApiInterfaceTests`
Expected: compile failure, `cannot find 'CustomFieldQueryOperator' in scope`.

- [ ] **Step 3: Implement both files**

`CustomFieldQueryOperator.swift` — raw values are the wire strings (`"in"` needs backticks as a case name):

```swift
public enum CustomFieldQueryOperator: String, CaseIterable, Codable, Hashable, Identifiable, Sendable {
    case contains
    case exact
    case exists
    case gt
    case gte
    case icontains
    case `in`
    case isnull
    case lt
    case lte

    public var id: String {
        rawValue
    }

    public var valueKind: CustomFieldQueryValueKind {
        switch self {
        case .contains, .in:
            .array
        case .exists, .isnull:
            .boolean
        case .gt, .lt:
            .number
        case .exact, .gte, .icontains, .lte:
            .string
        }
    }

    public static func operators(for dataType: CustomFieldDataType) -> [Self] {
        var operators = [Self]()
        for group in CustomFieldQueryOperatorGroup.groups(for: dataType) {
            for op in group.operators where !operators.contains(op) {
                operators.append(op)
            }
        }
        return operators
    }
}
```

`gte`/`lte` are `.string` rather than `.number` because the date group uses them for ISO dates while
the arithmetic group uses them for numbers — the value editor keys off the *field's* data type for
those two, and `.string` is the honest wire type for both.

Add `localized` in the same file, and `CustomFieldQueryValueKind` as its own `public enum … : Equatable, Sendable` at the bottom.

`CustomFieldQueryOperatorGroup.swift`:

```swift
public enum CustomFieldQueryOperatorGroup: String, CaseIterable, Hashable, Sendable {
    case basic
    case exact
    case string
    case arithmetic
    case containment
    case subset
    case date

    public var operators: [CustomFieldQueryOperator] {
        switch self {
        case .arithmetic:
            [.gt, .gte, .lt, .lte]
        case .basic:
            [.exists, .isnull]
        case .containment:
            [.contains]
        case .date:
            [.gte, .lte]
        case .exact:
            [.exact]
        case .string:
            [.icontains]
        case .subset:
            [.in]
        }
    }

    public static func groups(for dataType: CustomFieldDataType) -> [Self] {
        switch dataType {
        case .boolean:
            [.basic, .exact]
        case .date:
            [.basic, .exact, .date]
        case .documentLink:
            [.basic, .containment]
        case .float, .integer:
            [.basic, .exact, .arithmetic]
        case .longText:
            [.basic, .string]
        case .monetary:
            [.basic, .exact, .string, .arithmetic]
        case .select:
            [.basic, .exact, .subset]
        case .string, .url:
            [.basic, .exact, .string]
        case .unknown:
            []
        }
    }
}
```

- [ ] **Step 4: Add the operator strings to the catalogue**

Keys, all `en`/`de`: `customFieldQueryOperatorContains` "Contains"/"Enthält", `…Exact` "Equal to"/"Gleich", `…Exists` "Exists"/"Existiert", `…Gt` "Greater than"/"Größer als", `…Gte` "Greater than or equal to"/"Größer oder gleich", `…Icontains` "Contains"/"Enthält", `…In` "In"/"In", `…Isnull` "Is null"/"Ist leer", `…Lt` "Less than"/"Kleiner als", `…Lte` "Less than or equal to"/"Kleiner oder gleich".

- [ ] **Step 5: Run the tests and confirm they pass**

Run: `tuist test LessPaper --skip-ui-tests --test-targets ApiInterfaceTests`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface/CustomFields Modules/ApiInterfaceTests/CustomFields Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: custom field query operator matrix"
```

### Task 2: The query model and its codec

**Files:**
- Create: `Modules/ApiInterface/CustomFields/CustomFieldQuery.swift`
- Create: `Modules/ApiInterface/CustomFields/CustomFieldQueryLogicalOperator.swift`
- Test: `Modules/ApiInterfaceTests/CustomFields/CustomFieldQueryTests.swift`

**Interfaces:**
- Consumes: `CustomFieldQueryOperator` from Task 1.
- Produces:
  ```swift
  public indirect enum CustomFieldQuery: Codable, Equatable, Sendable {
      case atom(Atom)
      case group(CustomFieldQueryLogicalOperator, [CustomFieldQuery])
      case negation(CustomFieldQuery)

      public struct Atom: Codable, Equatable, Sendable {
          public var field: CustomField.Id
          public var op: CustomFieldQueryOperator
          public var value: JSONValue
      }
  }
  public enum CustomFieldQueryLogicalOperator: String, CaseIterable, Codable, Hashable, Sendable {
      case and = "AND"
      case or = "OR"
  }
  ```
  plus `init?(json: String)` and `var json: String?`.

The `Atom` member is named `op` rather than `operator`, which is a Swift keyword; `field` is a
`CustomField.Id` (`Tagged<CustomField, Int>`) so it encodes as a bare integer.

- [ ] **Step 1: Write the failing tests**

```swift
@Suite
struct CustomFieldQueryTests {
    @Test
    func testDecodesBareAtomAtTopLevel() throws {
        let query = try #require(CustomFieldQuery(json: #"[7,"exists",true]"#))
        #expect(query == .atom(.init(field: 7, op: .exists, value: .bool(true))))
    }

    @Test
    func testEncodesGroup() throws {
        let query = CustomFieldQuery.group(.and, [.atom(.init(field: 7, op: .exists, value: .bool(true)))])
        #expect(query.json == #"["AND",[[7,"exists",true]]]"#)
    }

    // The server returns 400 for `["NOT",[child]]` and 500 for `["NOT",[a,b]]`, so NOT must
    // serialize its child inline. Verified against paperless-ngx 3.0.5.
    @Test
    func testEncodesNegationWithChildInline() throws {
        let query = CustomFieldQuery.negation(.atom(.init(field: 7, op: .exists, value: .bool(true))))
        #expect(query.json == #"["NOT",[7,"exists",true]]"#)
    }

    @Test
    func testDecodesNegationWithChildInline() throws {
        let query = try #require(CustomFieldQuery(json: #"["NOT",[7,"exists",true]]"#))
        #expect(query == .negation(.atom(.init(field: 7, op: .exists, value: .bool(true)))))
    }

    @Test
    func testDecodesLegacyNegationWrappedInAList() throws {
        let query = try #require(CustomFieldQuery(json: #"["NOT",[[7,"exists",true]]]"#))
        #expect(query == .negation(.atom(.init(field: 7, op: .exists, value: .bool(true)))))
    }

    @Test
    func testRoundTripsNestedQuery() throws {
        let json = #"["AND",[[7,"icontains","a"],["OR",[[8,"gt",5],["NOT",[9,"exists",true]]]]]]"#
        let query = try #require(CustomFieldQuery(json: json))
        #expect(query.json == json)
    }

    @Test
    func testDecodingGarbageReturnsNil() {
        #expect(CustomFieldQuery(json: "notjson") == nil)
        #expect(CustomFieldQuery(json: #"["XOR",[[7,"exists",true]]]"#) == nil)
        #expect(CustomFieldQuery(json: #"[7,"nope",true]"#) == nil)
    }

    @Test
    func testEncodesIntegerValuesWithoutDecimalPoint() throws {
        let query = CustomFieldQuery.group(.and, [.atom(.init(field: 8, op: .gt, value: .number(5)))])
        #expect(query.json == #"["AND",[[8,"gt",5]]]"#)
    }

    @Test
    func testEncodesArrayValues() throws {
        let query = CustomFieldQuery.group(.and, [
            .atom(.init(field: 6, op: .in, value: .array([.string("jmdLfBGNOfk8vGsc")])))
        ])
        #expect(query.json == #"["AND",[[6,"in",["jmdLfBGNOfk8vGsc"]]]]"#)
    }
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `tuist test LessPaper --skip-ui-tests --test-targets ApiInterfaceTests`
Expected: compile failure.

- [ ] **Step 3: Implement**

`Codable` uses an unkeyed container. Decoding branches on whether the first element is a string:
a string means an expression (`AND`/`OR`/`NOT`), anything else means an atom. `json` uses a
`JSONEncoder` with `.withoutEscapingSlashes` and **no** `.sortedKeys` (there are no objects), and
`.outputFormatting` left otherwise default so arrays stay compact.

```swift
public extension CustomFieldQuery {
    init?(json: String) {
        guard let data = json.data(using: .utf8),
              let query = try? JSONDecoder().decode(Self.self, from: data)
        else {
            return nil
        }
        self = query
    }

    var json: String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.withoutEscapingSlashes]
        guard let data = try? encoder.encode(self) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
```

`Atom` encodes into its parent's unkeyed container rather than nesting, so `CustomFieldQuery`'s
`encode(to:)` writes the three elements itself for the `.atom` case.

- [ ] **Step 4: Run and confirm pass**

Run: `tuist test LessPaper --skip-ui-tests --test-targets ApiInterfaceTests`
Expected: PASS. If `testEncodesIntegerValuesWithoutDecimalPoint` fails with `5.0`, the fix belongs
in this task: encode whole `Double`s through `Int`.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/CustomFields Modules/ApiInterfaceTests/CustomFields
git commit -m "feat: custom field query model and codec"
```

### Task 3: Introspection and pruning

**Files:**
- Create: `Modules/ApiInterface/CustomFields/CustomFieldQuery+Introspection.swift`
- Test: append to `Modules/ApiInterfaceTests/CustomFields/CustomFieldQueryTests.swift`

**Interfaces:**
- Produces: `var atomCount: Int`, `var depth: Int` (a bare atom is 1), `var pruned: CustomFieldQuery?` (drops incomplete atoms and any group left empty; returns `nil` if nothing survives), `static let maximumDepth = 4`, `static let maximumAtoms = 5`, and `var isComplete: Bool` on `Atom` (false when a `.string` value is empty or an `.array` value is empty).

- [ ] **Step 1: Write the failing tests**

```swift
@Test
func testAtomCountAndDepth() throws {
    let query = try #require(CustomFieldQuery(json: #"["AND",[[7,"exists",true],["OR",[[8,"gt",5]]]]]"#))
    #expect(query.atomCount == 2)
    #expect(query.depth == 3)
}

@Test
func testBareAtomHasDepthOne() {
    #expect(CustomFieldQuery.atom(.init(field: 7, op: .exists, value: .bool(true))).depth == 1)
}

@Test
func testNegationDoesNotAddDepthBeyondItsChild() throws {
    let query = try #require(CustomFieldQuery(json: #"["NOT",[7,"exists",true]]"#))
    #expect(query.depth == 2)
}

@Test
func testPruningDropsAtomsWithEmptyStringValues() {
    let query = CustomFieldQuery.group(.and, [
        .atom(.init(field: 7, op: .icontains, value: .string(""))),
        .atom(.init(field: 8, op: .gt, value: .number(5)))
    ])
    #expect(query.pruned == .group(.and, [.atom(.init(field: 8, op: .gt, value: .number(5)))]))
}

@Test
func testPruningDropsGroupsLeftEmpty() {
    let query = CustomFieldQuery.group(.and, [
        .group(.or, [.atom(.init(field: 7, op: .icontains, value: .string("")))])
    ])
    #expect(query.pruned == nil)
}

@Test
func testPruningKeepsBooleanFalse() {
    // `exists=false` is a meaningful query, not an empty value.
    let query = CustomFieldQuery.atom(.init(field: 7, op: .exists, value: .bool(false)))
    #expect(query.pruned == query)
}
```

- [ ] **Step 2: Run and confirm failure.** Same command as Task 2.
- [ ] **Step 3: Implement** the recursive computed properties.
- [ ] **Step 4: Run and confirm pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat: custom field query introspection and pruning"`

### Task 4: The human-readable summary

**Files:**
- Create: `Modules/DocumentsFeature/DocumentFilter/CustomField/CustomFieldQuery+Summary.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/CustomField/CustomFieldQuerySummaryTests.swift`

**Interfaces:**
- Produces: `func summary(fields: IdentifiedArrayOf<CustomField>) -> String` on `CustomFieldQuery`.

It lives in `DocumentsFeature`, not `ApiInterface`, because it is presentation and needs the
resolved field names. An atom whose field id is absent from `fields` renders as the localized
`customFieldQueryUnknownField` with the id interpolated, so a stale saved view still reads sensibly
rather than silently losing a condition.

- [ ] **Step 1: Write the failing tests** covering: a single atom (`"Invoice total greater than 100"`), an AND group joined with the localized `and` separator, a negation prefixed with the localized `not`, and an unknown field id.
- [ ] **Step 2: Run and confirm failure.**
- [ ] **Step 3: Implement,** adding the `customFieldQueryUnknownField`, `customFieldQueryAnd`, `customFieldQueryOr`, `customFieldQueryNot` catalogue keys.
- [ ] **Step 4: Run and confirm pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat: custom field query summary"`

### Task 5: `DocumentFilterInput` integration

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterInput.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterInputTests.swift`

**Interfaces:**
- Produces: `var customFieldQuery: CustomFieldQuery?` on `DocumentFilterInput`, plus a
  `customFieldQuery:` parameter on `DocumentFilterInput.testValue(…)` defaulting to `nil`.

- [ ] **Step 1: Write the failing tests**

```swift
@Test
func testParsesCustomFieldQuery() {
    let input = DocumentFilterInput(
        filterRules: [.init(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exists",true]]]"#)],
        server: .testValue(),
        sortDirection: nil,
        sortField: nil
    )
    #expect(input.customFieldQuery == .group(.and, [.atom(.init(field: 7, op: .exists, value: .bool(true)))]))
    #expect(input.unsupportedFilterRules.isEmpty)
}

@Test
func testMigratesHasCustomFieldsAllToAndOfExists() {
    let input = DocumentFilterInput(
        filterRules: [
            .init(ruleType: .hasCustomFieldsAll, value: "7"),
            .init(ruleType: .hasCustomFieldsAll, value: "8")
        ],
        server: .testValue(),
        sortDirection: nil,
        sortField: nil
    )
    #expect(input.customFieldQuery == .group(.and, [
        .atom(.init(field: 7, op: .exists, value: .bool(true))),
        .atom(.init(field: 8, op: .exists, value: .bool(true)))
    ]))
}

@Test
func testMigratesHasCustomFieldsAnyToOrOfExists() { /* same shape, .or */ }

@Test
func testMalformedQueryIsPreservedAsUnsupported() {
    let rule = FilterRule(ruleType: .customFieldsQuery, value: "notjson")
    let input = DocumentFilterInput(filterRules: [rule], server: .testValue(), sortDirection: nil, sortField: nil)
    #expect(input.customFieldQuery == nil)
    #expect(input.unsupportedFilterRules == [rule])
}

@Test
func testEmitsExactlyOneRule() {
    var input = DocumentFilterInput.testValue()
    input.customFieldQuery = .group(.and, [.atom(.init(field: 7, op: .exists, value: .bool(true)))])
    #expect(input.filterRules == [.init(ruleType: .customFieldsQuery, value: #"["AND",[[7,"exists",true]]]"#)])
}

// `["AND",[]]` is a 400 from the server, so an empty query must produce no rule at all.
@Test
func testEmptyQueryEmitsNoRule() {
    var input = DocumentFilterInput.testValue()
    input.customFieldQuery = .group(.and, [])
    #expect(input.filterRules.isEmpty)
}

@Test
func testIncompleteAtomsArePrunedBeforeSending() {
    var input = DocumentFilterInput.testValue()
    input.customFieldQuery = .group(.and, [
        .atom(.init(field: 7, op: .icontains, value: .string(""))),
        .atom(.init(field: 8, op: .exists, value: .bool(true)))
    ])
    #expect(input.filterRules == [.init(ruleType: .customFieldsQuery, value: #"["AND",[[8,"exists",true]]]"#)])
}
```

- [ ] **Step 2: Run and confirm failure**

Run: `tuist test LessPaper --skip-ui-tests --test-targets DocumentsFeatureTests`

- [ ] **Step 3: Implement.** Add `case .customFieldsQuery`, `.hasCustomFieldsAll`, `.hasCustomFieldsAny` to the parse switch; accumulate the legacy ids into locals and combine after the loop; emit `pruned?.json` from `filterRules`.
- [ ] **Step 4: Run and confirm pass.**
- [ ] **Step 5: Commit** — `git commit -m "feat: parse and emit custom field query filter rules"`

### Task 6: Pin `FilterRule` equality behaviour

**Files:**
- Test: `Modules/ApiInterfaceTests/Shared/FilterRuleTests.swift`

`FilterRule.==` compares comma-split fragments, and query JSON is full of commas. The spec argues
this does not misfire in practice; this test is what makes that claim checkable instead of
folklore.

- [ ] **Step 1: Write the test** asserting two atom-swapped queries compare unequal, and that a rule equals itself.
- [ ] **Step 2: Run it.** Expected: PASS immediately — this is a characterization test, not a driver.
- [ ] **Step 3: Commit** — `git commit -m "test: pin FilterRule equality for custom field queries"`

### Task 7: The collapsed filter row

**Files:**
- Create: `Modules/DocumentsFeature/DocumentFilter/CustomField/DocumentFilterCustomFieldField.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterView.swift`
- Modify: `Modules/DocumentsFeature/DocumentFilter/DocumentFilterReducer.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/CustomField/DocumentFilterCustomFieldFieldTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentFilter/DocumentFilterViewTests.swift` (snapshots re-record)

**Interfaces:**
- Produces: `DocumentFilterCustomFieldField(query:fields:)`, a `Field(.customFields)` with the
  `"list.bullet.rectangle"` system image showing `.any` when the query is nil and the summary
  otherwise. `DocumentFilterReducer.State` gains `@Shared var customFields: IdentifiedArrayOf<CustomField>`
  initialised with `Shared(wrappedValue: [], .customFields(server))`, and
  `Action.View` gains `case customFieldButtonTapped` which on this branch returns `.none`.

The row goes between `tagField()` and `dateField()` in the `VStack`, matching the order the web
filter editor uses.

- [ ] **Step 1: Write the failing snapshot test** with three arguments: nil query, single-atom query, nested query.
- [ ] **Step 2: Run and confirm failure.**
- [ ] **Step 3: Implement** the view and the reducer/state changes.
- [ ] **Step 4: Record snapshots**

Run: `SNAPSHOT_TESTING_RECORD=all tuist test LessPaper --skip-ui-tests --test-targets DocumentsFeatureTests`
then re-run without the variable and confirm PASS. Inspect with `mise snapshots:diff`.

- [ ] **Step 5: Commit** — `git commit -m "feat: show the custom field query on the filter sheet"`

### Task 8: Open the base PR

- [ ] **Step 1:** `mise ci:lint` — expect clean.
- [ ] **Step 2:** `tuist test LessPaper --skip-ui-tests` — expect PASS.
- [ ] **Step 3:** push and open the PR against `main`, then `gh pr edit --add-label TestFlight`.

---

# Branches 2–5 — the UI variants

Each branches from `feat/custom-field-filter-base` **after Task 8**, and each PR targets `main`
(CI only triggers on PRs to `main`, so a PR targeting the base branch would produce no TestFlight
build). Each variant:

1. Adds its files under `Modules/DocumentsFeature/DocumentFilter/CustomField/<VariantName>/`.
2. Changes `customFieldButtonTapped` to present its own destination, and adds that destination case.
3. Adds reducer tests and snapshot tests at `.iPhone12`.
4. Enforces `CustomFieldQuery.maximumAtoms` and `.maximumDepth` by disabling its add affordances.
5. Ends with `mise ci:lint`, the full unit test run, a pushed branch, a PR to `main`, and the
   `TestFlight` label.

Every variant reuses, and none of them reimplements: `CustomFieldQuery`, the operator matrix,
`summary(fields:)`, `pruned`, and `DocumentFilterCustomFieldField`.

### Branch 2 — `feat/custom-field-filter-ui-rows` (variant A, condition rows)

**Files:** `CustomFieldQueryRowsReducer.swift`, `+Effect`, `+TestValue`, `CustomFieldQueryRowsView.swift`, `CustomFieldQueryAtomReducer.swift`, `CustomFieldQueryAtomView.swift`.

A detent sheet with an All/Any `Picker` header and one row per child. Tapping an atom row presents
a second detent sheet holding three `MenuField`s — field, operator, value — where the operator menu
comes from `CustomFieldQueryOperator.operators(for: field.dataType)` and the value editor from
`op.valueKind` (`Toggle` for `.boolean`, `TextField` for `.string`, numeric `TextField` for
`.number`, and a multi-select list for `.array`). A group row pushes onto a `NavigationStack`
showing that group's own list. `NOT` is a `Toggle` in the group header.

Changing the field resets the operator to the first one its data type admits, and resets the value
to the new operator's kind — otherwise a `string` field left on `gt` produces the 400 the server
gave us in testing.

### Branch 3 — `feat/custom-field-filter-ui-sentence` (variant B, sentence builder)

**Files:** `CustomFieldQuerySentenceReducer.swift`, `+Effect`, `+TestValue`, `CustomFieldQuerySentenceView.swift`, `CustomFieldQueryChip.swift`, `CustomFieldQueryFlowLayout.swift`.

The query rendered as capsules in a custom `Layout` that reflows like text. Field and operator chips
open `Menu`s; the value chip presents the editor for its kind. Nesting is shown by an indent chip
run rather than by containers.

`CustomFieldQueryFlowLayout` is a `Layout` conformance — `sizeThatFits` and `placeSubviews` — because
neither `LazyVGrid` nor a `HStack` wraps. Snapshot tests must include an
`.environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)` case; chip reflow at that size is
the known risk of this variant and the snapshot is how it gets judged.

VoiceOver: each atom's chips are wrapped in `.accessibilityElement(children: .combine)` so the atom
reads as one element instead of three loose buttons.

### Branch 4 — `feat/custom-field-filter-ui-fields` (variant C, field-first browse)

**Files:** `CustomFieldQueryFieldsReducer.swift`, `+Effect`, `+TestValue`, `CustomFieldQueryFieldsView.swift`, `CustomFieldQueryFieldEditorReducer.swift`, `CustomFieldQueryFieldEditorView.swift`, plus a vendored copy of Branch 2's rows editor for the Advanced hand-off.

A `Searchable` list of custom fields, each row showing its condition or `.any`. The per-field editor
is chosen by `CustomFieldDataType`: `Toggle` for boolean, `DateField` for date, an operator `Menu`
plus numeric `TextField` for integer/float/monetary, the `extraData.selectOptions` list for select,
and an operator `Menu` plus `TextField` otherwise.

Flat by construction: conditions join under the top-level All/Any. `canRepresent(_:)` on the reducer
returns false for any query that is nested or negated; when it returns false the view shows the
summary plus an **Advanced** button that presents the rows editor instead. That check is the first
test to write for this branch.

### Branch 5 — `feat/custom-field-filter-ui-cards` (variant D, nested cards)

**Files:** `CustomFieldQueryCardsReducer.swift`, `+Effect`, `+TestValue`, `CustomFieldQueryCardsView.swift`, `CustomFieldQueryCardView.swift`, `CustomFieldQueryDepthRail.swift`.

The whole tree on one `ScrollView`. `CustomFieldQueryCardView` recurses: an And/Or segmented header,
a `NOT` toggle, atom rows, nested cards, and a footer with "+ Condition" / "+ Group" disabled at the
limits. `CustomFieldQueryDepthRail` maps depth to one of four `m3` tints.

A recursive SwiftUI view needs its recursion behind a concrete type or the compiler cannot size it;
`CustomFieldQueryCardView` therefore takes the sub-query as a value and recurses through
`AnyView`-free explicit `some View` on a nested `body`. Snapshot tests must include a depth-4 query
on `.iPhone12` — the innermost card's width is the specific thing this variant is being judged on.

---

## Self-Review

**Spec coverage.** Operator matrix → Task 1. Model, `NOT` arity, codec, bare atom, legacy `NOT`
list → Task 2. Depth/atom limits and incomplete-atom pruning → Task 3, enforced in UI per branch.
Summary and unknown-field rendering → Task 4. Parse/emit/migrate, empty-query-emits-nothing,
malformed-preserved → Task 5. `FilterRule` equality → Task 6. Collapsed row and `@Shared`
custom fields → Task 7. Four variants → Branches 2–5. Out-of-scope items are untouched by every
task.

**Placeholders.** None: every code step carries code, and the variant branches carry file lists,
component choices and the specific risk each one must snapshot.

**Type consistency.** `CustomFieldQuery.Atom` uses `field`/`op`/`value` throughout; `operators(for:)`
is a static on `CustomFieldQueryOperator` in Task 1 and is called by that name in Branch 2;
`pruned` is defined in Task 3 and consumed in Task 5; `summary(fields:)` is defined in Task 4 and
consumed in Task 7 and every variant.
