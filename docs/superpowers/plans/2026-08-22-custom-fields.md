# CustomFieldsFeature Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a `CustomFieldsFeature` module that lets a user list, create, update and delete paperless custom field definitions, wired into Settings, with its own standalone app and UI test targets.

**Architecture:** A full vertical slice in the shape `StoragePaths` already has — `ApiInterface` models and use-case contracts, an `ApiImplementation` repository against `/api/custom_fields/`, and a TCA feature module of three screens (List, Row, Form). Custom fields have no owner or permissions, so the form is flatter than `StoragePathForm`: one section, no `PermissionsFeature`. They do have a `data_type` and an `extra_data` blob, so the form grows a type picker (create only), a currency field for `.monetary` and an options editor for `.select`.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-dependencies, swift-sharing, Tagged, Tuist, Swift Testing, swift-snapshot-testing, XCTest (UI tests).

**Spec:** `docs/superpowers/specs/2026-08-22-custom-fields-design.md`

## Global Constraints

- **Comments: only `//`. Never `///`, never `/** */`.** Everywhere — types, properties, methods, initialisers, test helpers, including in files that still contain old-style doc comments. Comment only when a future reader would otherwise stop and wonder why the code is the way it is.
- **`@ViewAction` views call `send(…)`, never `store.send(…)`.** `store.send` compiles but emits a warning. All three views in this plan carry the macro.
- **Confirmations go through `ConfirmationPopupView` via a `@DependencyClient` presenter.** Never `.confirmationDialog`, `.alert` or `ConfirmationDialogState`. This feature uses the shared `DeleteConfirmationPresenter` (`@Dependency(\.deleteConfirmation.present)`).
- **Run `mise run format` before every commit.** It runs `swiftlint --fix`, `swiftformat` and `mise/scripts/attribute_blank_lines.py`. CI lints with `--strict`.
- **Run `tuist generate --no-open` after any change under `Tuist/ProjectDescriptionHelpers/`,** otherwise the new targets do not exist in the Xcode project.
- **Properties inside a type are ordered alphabetically,** matching every existing model and reducer.
- **JSON is snake_case on the wire, camelCase in Swift,** converted by `JSONDecoder.apiDecoder` / `JSONEncoder.apiEncoder`. Never write explicit snake_case `CodingKeys` string values.
- **Integration tests (`.tags(.integrationTests)`) and UI tests need the docker instance:** `mise run docker:start`, and `mise run docker:seed` if documents are wanted.
- **Data type is locked on edit.** The server accepts a `data_type` change via PATCH; the app must not offer one. Only the create form shows the picker.

---

## File Structure

**`Modules/ApiInterface/CustomFields/`** (new) — `CustomField.swift`, `CustomFieldDataType.swift`, `CustomFieldExtraData.swift`, `CustomFieldSelectOption.swift`, `GetCustomFieldsInput.swift`, `GetCustomFieldsOutput.swift`, `GetCustomFieldsUseCase.swift`, `SaveCustomFieldInput.swift`, `SaveCustomFieldOutput.swift`, `SaveCustomFieldUseCase.swift`, `DeleteCustomFieldOutput.swift`, `DeleteCustomFieldUseCase.swift`, `DeleteAllCustomFieldsUseCase.swift`

**`Modules/ApiImplementation/CustomFields/`** (new) — `CustomFieldsRepository.swift`, `GetCustomFieldsUseCase.swift`, `SaveCustomFieldUseCase.swift`, `DeleteCustomFieldUseCase.swift`

**`Modules/ApiTestSupport/`** — `CustomFields/DeleteAllCustomFieldsUseCase.swift`, `Extensions/CustomFieldsRepository+Extensions.swift`

**Modified** — `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, `Modules/ApiInterface/Shared/ApiCache.swift`, `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`, `Modules/SettingsFeature/SettingList/SettingListReducer.swift`, `Modules/SettingsFeature/SettingList/SettingListView.swift`, `Shared/Framework/Resources/Localizable.xcstrings`, and the five files under `Tuist/ProjectDescriptionHelpers/`.

**`Modules/CustomFieldsFeature/`** (new) — `CustomFieldList/{CustomFieldListReducer,CustomFieldListReducer+Effect,CustomFieldListReducer+TestValue,CustomFieldListView}.swift`, `CustomFieldRow/{…}.swift`, `CustomFieldForm/{CustomFieldFormReducer,CustomFieldFormReducer+Effect,CustomFieldFormReducer+TestValue,CustomFieldFormField,CustomFieldFormInput,CustomFieldSelectOptionInput,CustomFieldFormView}.swift`

**`Modules/CustomFieldsApp/CustomFieldsApp.swift`**, **`Modules/CustomFieldsAppTests/CustomFieldsAppTests.swift`** (new)

**Tests** — `Modules/ApiInterfaceTests/CustomFields/`, `Modules/ApiImplementationTests/CustomFields/`, `Modules/CustomFieldsFeatureTests/{CustomFieldList,CustomFieldRow,CustomFieldForm}/`

---

## Task 1: The `CustomField` model and its supporting types

**Files:**
- Create: `Modules/ApiInterface/CustomFields/CustomField.swift`
- Create: `Modules/ApiInterface/CustomFields/CustomFieldDataType.swift`
- Create: `Modules/ApiInterface/CustomFields/CustomFieldExtraData.swift`
- Create: `Modules/ApiInterface/CustomFields/CustomFieldSelectOption.swift`
- Test: `Modules/ApiInterfaceTests/CustomFields/CustomFieldTests.swift`

**Interfaces:**
- Consumes: `ListOutput`, `Server`, `Tagged` — all existing.
- Produces: `CustomField` (`dataType`, `documentCount`, `extraData`, `id`, `name`; `CustomField.Id = Tagged<CustomField, Int>`; `static func testValue(…) -> Self`; `Array<CustomField>.previewValue`). `CustomFieldDataType` (cases `boolean, date, documentLink, float, integer, longText, monetary, select, string, unknown, url`; `allCases` excludes `.unknown`). `CustomFieldExtraData(defaultCurrency:selectOptions:)`. `CustomFieldSelectOption(id:label:)`.

`CustomField.Id.get(_:)` is deliberately **not** in this task — it needs the cache, which lands in Task 5.

- [ ] **Step 1: Write the failing test**

`Modules/ApiInterfaceTests/CustomFields/CustomFieldTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct CustomFieldTests {

    @Test
    func decode_select() async throws {
        let json = """
        {
          "id": 1,
          "name": "Status",
          "data_type": "select",
          "extra_data": {
            "select_options": [
              { "label": "Open", "id": "aqgT3m4XZw8aw3Ou" },
              { "label": "Closed", "id": "MOddUdj2nhfCEsqp" }
            ]
          },
          "document_count": 4
        }
        """

        let customField = try JSONDecoder.apiDecoder.decode(CustomField.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(customField, .testValue(
            dataType: .select,
            documentCount: 4,
            extraData: .init(selectOptions: [
                .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
                .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
            ]),
            name: "Status"
        ))
    }

    // The POST response omits document_count entirely — it is present on list and PATCH only.
    @Test
    func decode_withoutDocumentCount() async throws {
        let json = """
        { "id": 3, "name": "Reference", "data_type": "string", "extra_data": null }
        """

        let customField = try JSONDecoder.apiDecoder.decode(CustomField.self, from: #require(json.data(using: .utf8)))

        #expect(customField.documentCount == 0)
        #expect(customField.extraData == nil)
    }

    // A data type added by a future paperless release must not fail the whole list.
    @Test
    func decode_unknownDataType() async throws {
        let json = """
        { "id": 4, "name": "Future", "data_type": "somethingnew", "document_count": 0 }
        """

        let customField = try JSONDecoder.apiDecoder.decode(CustomField.self, from: #require(json.data(using: .utf8)))

        #expect(customField.dataType == .unknown)
    }

    @Test
    func allCases_excludesUnknown() async throws {
        #expect(!CustomFieldDataType.allCases.contains(.unknown))
        #expect(CustomFieldDataType.allCases.count == 10)
    }

    @Test
    func comparable_sortsByName() async throws {
        let sorted = [CustomField.testValue(id: 2, name: "Beta"), .testValue(id: 1, name: "Alpha")].sorted()

        #expect(sorted.map(\.name) == ["Alpha", "Beta"])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `tuist test ApiInterface -d "iPhone 17 Pro"`
Expected: FAIL — `cannot find 'CustomField' in scope`.

- [ ] **Step 3: Write `CustomFieldSelectOption.swift`**

```swift
import Foundation

public struct CustomFieldSelectOption: Codable, Equatable, Hashable, Sendable {

    public let id: String?

    public let label: String

    public init(
        id: String? = nil,
        label: String
    ) {
        self.id = id
        self.label = label
    }
}

public extension CustomFieldSelectOption {

    static func testValue(
        id: String? = "aqgT3m4XZw8aw3Ou",
        label: String = "Open"
    ) -> Self {
        .init(
            id: id,
            label: label
        )
    }
}
```

- [ ] **Step 4: Write `CustomFieldExtraData.swift`**

The synthesized `encode(to:)` uses `encodeIfPresent` for optional properties, so a field with neither a currency nor options encodes as `{}` and a field with no `extraData` at all omits the key entirely.

```swift
import Foundation

public struct CustomFieldExtraData: Codable, Equatable, Hashable, Sendable {

    public let defaultCurrency: String?

    public let selectOptions: [CustomFieldSelectOption]?

    public init(
        defaultCurrency: String? = nil,
        selectOptions: [CustomFieldSelectOption]? = nil
    ) {
        self.defaultCurrency = defaultCurrency
        self.selectOptions = selectOptions
    }
}

public extension CustomFieldExtraData {

    static func testValue(
        defaultCurrency: String? = nil,
        selectOptions: [CustomFieldSelectOption]? = nil
    ) -> Self {
        .init(
            defaultCurrency: defaultCurrency,
            selectOptions: selectOptions
        )
    }
}
```

- [ ] **Step 5: Write `CustomFieldDataType.swift`**

The localized descriptions reference string keys that do not exist yet — Task 8 adds them. Until then this file will not compile against the string catalog. To keep the build green, write `description` in this task returning `rawValue`, and Task 8 replaces the body with the localized switch. That swap is an explicit step in Task 8; do not leave it as-is.

```swift
import Foundation

public enum CustomFieldDataType: String, Codable, Hashable, Sendable {
    case boolean
    case date
    case documentLink = "documentlink"
    case float
    case integer
    case longText = "longtext"
    case monetary
    case select
    case string
    case unknown
    case url
}

public extension CustomFieldDataType {

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self = try CustomFieldDataType(rawValue: container.decode(String.self)) ?? .unknown
    }
}

extension CustomFieldDataType: CaseIterable {

    // Hand-written, in the order the server lists its choices, and deliberately without `unknown`:
    // `MenuField` builds its picker straight from `allCases`, so a case in here is a case the user
    // can pick, and `unknown` is only ever a decoding fallback.
    public static let allCases: [CustomFieldDataType] = [
        .string,
        .url,
        .date,
        .boolean,
        .integer,
        .float,
        .monetary,
        .documentLink,
        .select,
        .longText
    ]
}

extension CustomFieldDataType: Identifiable {
    public var id: String {
        rawValue
    }
}

extension CustomFieldDataType: CustomStringConvertible {
    public var description: String {
        rawValue
    }
}
```

- [ ] **Step 6: Write `CustomField.swift`**

```swift
import Dependencies
import Foundation
import Tagged

public struct CustomField: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<CustomField, Int>

    public let dataType: CustomFieldDataType

    public let documentCount: Int

    public let extraData: CustomFieldExtraData?

    public let id: Id

    public let name: String

    public init(
        dataType: CustomFieldDataType,
        documentCount: Int,
        extraData: CustomFieldExtraData?,
        id: Id,
        name: String
    ) {
        self.dataType = dataType
        self.documentCount = documentCount
        self.extraData = extraData
        self.id = id
        self.name = name
    }
}

public extension CustomField {

    private enum CodingKeys: String, CodingKey {
        case dataType, documentCount, extraData, id, name
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dataType = try container.decode(CustomFieldDataType.self, forKey: .dataType)
        documentCount = try container.decodeIfPresent(Int.self, forKey: .documentCount) ?? 0
        extraData = try container.decodeIfPresent(CustomFieldExtraData.self, forKey: .extraData)
        id = try container.decode(Id.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dataType, forKey: .dataType)
        try container.encode(documentCount, forKey: .documentCount)
        try container.encodeIfPresent(extraData, forKey: .extraData)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
    }
}

public extension CustomField {

    static func testValue(
        dataType: CustomFieldDataType = .string,
        documentCount: Int = 0,
        extraData: CustomFieldExtraData? = nil,
        id: Id = 1,
        name: String = "Test CustomField"
    ) -> Self {
        .init(
            dataType: dataType,
            documentCount: documentCount,
            extraData: extraData,
            id: id,
            name: name
        )
    }
}

public extension Array where Element == CustomField {

    static var previewValue: Self {
        [
            .testValue(dataType: .string, documentCount: 3, id: 1, name: "Reference"),
            .testValue(dataType: .date, documentCount: 6, id: 2, name: "Due date"),
            .testValue(dataType: .boolean, documentCount: 9, id: 3, name: "Paid"),
            .testValue(
                dataType: .monetary,
                documentCount: 12,
                extraData: .init(defaultCurrency: "EUR"),
                id: 4,
                name: "Invoice total"
            ),
            .testValue(
                dataType: .select,
                documentCount: 15,
                extraData: .init(selectOptions: [
                    .init(id: "aqgT3m4XZw8aw3Ou", label: "Open"),
                    .init(id: "MOddUdj2nhfCEsqp", label: "Closed")
                ]),
                id: 5,
                name: "Status"
            )
        ]
    }
}

extension CustomField: Comparable {
    public static func < (lhs: CustomField, rhs: CustomField) -> Bool {
        lhs.name < rhs.name
    }
}

extension CustomField: CustomStringConvertible {
    public var description: String {
        name
    }
}
```

- [ ] **Step 7: Run the test to verify it passes**

Run: `tuist test ApiInterface -d "iPhone 17 Pro"`
Expected: PASS — all five tests in `CustomFieldTests`.

- [ ] **Step 8: Format and commit**

```bash
mise run format
git add Modules/ApiInterface/CustomFields Modules/ApiInterfaceTests/CustomFields
git commit -m "feat: add CustomField model"
```

---

## Task 2: Inputs, outputs and use-case contracts

**Files:**
- Create: `Modules/ApiInterface/CustomFields/GetCustomFieldsInput.swift`
- Create: `Modules/ApiInterface/CustomFields/GetCustomFieldsOutput.swift`
- Create: `Modules/ApiInterface/CustomFields/GetCustomFieldsUseCase.swift`
- Create: `Modules/ApiInterface/CustomFields/SaveCustomFieldInput.swift`
- Create: `Modules/ApiInterface/CustomFields/SaveCustomFieldOutput.swift`
- Create: `Modules/ApiInterface/CustomFields/SaveCustomFieldUseCase.swift`
- Create: `Modules/ApiInterface/CustomFields/DeleteCustomFieldOutput.swift`
- Create: `Modules/ApiInterface/CustomFields/DeleteCustomFieldUseCase.swift`
- Create: `Modules/ApiInterface/CustomFields/DeleteAllCustomFieldsUseCase.swift`
- Test: `Modules/ApiInterfaceTests/CustomFields/GetCustomFieldsOutputTests.swift`
- Test: `Modules/ApiInterfaceTests/CustomFields/SaveCustomFieldInputTests.swift`

**Interfaces:**
- Consumes: `CustomField`, `CustomFieldDataType`, `CustomFieldExtraData` from Task 1.
- Produces: `GetCustomFieldsInput(url:)`; `GetCustomFieldsOutput = ListOutput<CustomField, CustomField.Id>` with `.testValue(count:next:results:)`; `SaveCustomFieldInput(dataType:extraData:name:)` and `init(customField:)`; `SaveCustomFieldOutput = CustomField`; `DeleteCustomFieldOutput = Void`; dependency keys `\.getCustomFields`, `\.saveCustomField`, `\.deleteCustomField`, `\.deleteAllCustomFields`, each a `@DependencyClient` with a single `execute` closure.

Signatures later tasks rely on:

```swift
GetCustomFieldsUseCase.execute:    (_ server: Server) async throws -> [CustomField]
SaveCustomFieldUseCase.execute:    (_ id: CustomField.Id?, _ input: SaveCustomFieldInput, _ server: Server) async throws -> SaveCustomFieldOutput
DeleteCustomFieldUseCase.execute:  (_ id: CustomField.Id, _ server: Server) async throws -> DeleteCustomFieldOutput
DeleteAllCustomFieldsUseCase.execute: (_ server: Server) async throws -> Void
```

- [ ] **Step 1: Write the failing tests**

`Modules/ApiInterfaceTests/CustomFields/GetCustomFieldsOutputTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct GetCustomFieldsOutputTests {

    @Test
    func decode() async throws {
        let json = """
        {
          "all": [
            1
          ],
          "count": 1,
          "next": null,
          "previous": null,
          "results": [
            {
              "data_type": "string",
              "document_count": 0,
              "extra_data": null,
              "id": 1,
              "name": "Test CustomField"
            }
          ]
        }
        """

        let output = try JSONDecoder.apiDecoder.decode(GetCustomFieldsOutput.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(output, .testValue(
            count: 1,
            results: [.testValue()]
        ))
    }
}
```

`Modules/ApiInterfaceTests/CustomFields/SaveCustomFieldInputTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct SaveCustomFieldInputTests {

    @Test
    func encode_plainType_omitsExtraData() async throws {
        let data = try JSONEncoder.apiEncoder.encode(SaveCustomFieldInput(dataType: .string, name: "Reference"))
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"data_type\":\"string\""))
        #expect(json.contains("\"name\":\"Reference\""))
        #expect(!json.contains("extra_data"))
    }

    @Test
    func encode_select_includesOptions() async throws {
        let input = SaveCustomFieldInput(
            dataType: .select,
            extraData: .init(selectOptions: [.init(label: "Open")]),
            name: "Status"
        )

        let data = try JSONEncoder.apiEncoder.encode(input)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(json.contains("\"select_options\""))
        #expect(json.contains("\"label\":\"Open\""))
    }

    // An unknown data type must never be written back — the server would reject "unknown", and the
    // app has no business changing a type it does not understand.
    @Test
    func init_customField_unknownDataType_omitsDataType() async throws {
        let input = SaveCustomFieldInput(customField: .testValue(dataType: .unknown, name: "Future"))

        #expect(input.dataType == nil)
        #expect(input.name == "Future")

        let data = try JSONEncoder.apiEncoder.encode(input)
        let json = try #require(String(data: data, encoding: .utf8))

        #expect(!json.contains("data_type"))
    }

    @Test
    func init_customField_nil_defaultsToString() async throws {
        let input = SaveCustomFieldInput(customField: nil)

        #expect(input.dataType == .string)
        #expect(input.extraData == nil)
        #expect(input.name == "")
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test ApiInterface -d "iPhone 17 Pro"`
Expected: FAIL — `cannot find 'GetCustomFieldsOutput' in scope`.

- [ ] **Step 3: Write the inputs and outputs**

`GetCustomFieldsInput.swift`:

```swift
import Foundation

public struct GetCustomFieldsInput: Codable, Equatable, Sendable {

    public let url: URL?

    public init(
        url: URL? = nil
    ) {
        self.url = url
    }
}

public extension GetCustomFieldsInput {

    static func testValue(
        url: URL? = nil
    ) -> Self {
        .init(
            url: url
        )
    }
}
```

`GetCustomFieldsOutput.swift`:

```swift
import Foundation
import Tagged

public typealias GetCustomFieldsOutput = ListOutput<CustomField, CustomField.Id>

public extension ListOutput where Element == CustomField, Id == CustomField.Id {

    static func testValue(
        count: Int = 0,
        next: URL? = nil,
        results: [Element] = []
    ) -> Self {
        .init(
            count: count,
            next: next,
            results: results
        )
    }
}
```

`SaveCustomFieldOutput.swift`:

```swift
import Foundation

public typealias SaveCustomFieldOutput = CustomField
```

`DeleteCustomFieldOutput.swift`:

```swift
import Foundation

public typealias DeleteCustomFieldOutput = Void
```

`SaveCustomFieldInput.swift`:

```swift
import Foundation
import Tagged

public struct SaveCustomFieldInput: Codable, Equatable, Sendable {

    public var dataType: CustomFieldDataType?

    public var extraData: CustomFieldExtraData?

    public var name: String

    public init(
        dataType: CustomFieldDataType? = nil,
        extraData: CustomFieldExtraData? = nil,
        name: String
    ) {
        self.dataType = dataType
        self.extraData = extraData
        self.name = name
    }
}

public extension SaveCustomFieldInput {

    init(customField: CustomField?) {
        guard let customField else {
            self.init(
                dataType: .string,
                extraData: nil,
                name: ""
            )
            return
        }
        self.init(
            dataType: customField.dataType == .unknown ? nil : customField.dataType,
            extraData: customField.extraData,
            name: customField.name
        )
    }
}

public extension SaveCustomFieldInput {

    static func testValue(
        dataType: CustomFieldDataType? = .string,
        extraData: CustomFieldExtraData? = nil,
        name: String = "Test CustomField"
    ) -> Self {
        .init(
            dataType: dataType,
            extraData: extraData,
            name: name
        )
    }
}
```

- [ ] **Step 4: Write the four use-case contracts**

`GetCustomFieldsUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetCustomFieldsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> [CustomField]
}

extension GetCustomFieldsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _ in [.testValue()] }
    )
}

public extension DependencyValues {
    var getCustomFields: GetCustomFieldsUseCase {
        get { self[GetCustomFieldsUseCase.self] }
        set { self[GetCustomFieldsUseCase.self] = newValue }
    }
}
```

`SaveCustomFieldUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SaveCustomFieldUseCase: Sendable {

    public var execute: @Sendable (
        _ id: CustomField.Id?,
        _ input: SaveCustomFieldInput,
        _ server: Server
    ) async throws -> SaveCustomFieldOutput
}

extension SaveCustomFieldUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {
    var saveCustomField: SaveCustomFieldUseCase {
        get { self[SaveCustomFieldUseCase.self] }
        set { self[SaveCustomFieldUseCase.self] = newValue }
    }
}
```

`DeleteCustomFieldUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteCustomFieldUseCase: Sendable {

    public var execute: @Sendable (
        _ id: CustomField.Id,
        _ server: Server
    ) async throws -> DeleteCustomFieldOutput
}

extension DeleteCustomFieldUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {
    var deleteCustomField: DeleteCustomFieldUseCase {
        get { self[DeleteCustomFieldUseCase.self] }
        set { self[DeleteCustomFieldUseCase.self] = newValue }
    }
}
```

`DeleteAllCustomFieldsUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeleteAllCustomFieldsUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension DeleteAllCustomFieldsUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deleteAllCustomFields: DeleteAllCustomFieldsUseCase {
        get { self[DeleteAllCustomFieldsUseCase.self] }
        set { self[DeleteAllCustomFieldsUseCase.self] = newValue }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test ApiInterface -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/ApiInterface/CustomFields Modules/ApiInterfaceTests/CustomFields
git commit -m "feat: add custom field inputs, outputs and use case contracts"
```

---

## Task 3: The repository

**Files:**
- Create: `Modules/ApiImplementation/CustomFields/CustomFieldsRepository.swift`
- Create: `Modules/ApiTestSupport/Extensions/CustomFieldsRepository+Extensions.swift`
- Test: `Modules/ApiImplementationTests/CustomFields/CustomFieldsRepositoryTests.swift`

**Interfaces:**
- Consumes: everything from Task 2.
- Produces: `@Dependency(\.customFieldsRepository)` with `createCustomField(input:server:)`, `deleteCustomField(id:server:)`, `getCustomFields(input:server:)`, `updateCustomField(id:input:server:)`. Internal to `ApiImplementation` (not `public`), reachable from tests via `@testable import`. Also `CustomFieldsRepository.deleteAll()` in `ApiTestSupport`.

**The `crud` test needs docker:** `mise run docker:start` before running it.

- [ ] **Step 1: Write the failing test**

`Modules/ApiImplementationTests/CustomFields/CustomFieldsRepositoryTests.swift`:

```swift
@testable import ApiImplementation
@testable import ApiTestSupport

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct CustomFieldsRepositoryTests {

    @Test
    func createCustomField_returnsTestValue() async throws {
        let output = try await repository.createCustomField(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func deleteCustomField_returnsVoid() async throws {
        try await repository.deleteCustomField(
            id: 1,
            server: .testValue()
        )
    }

    @Test
    func getCustomFields_returnsTestValue() async throws {
        let output = try await repository.getCustomFields(
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test
    func updateCustomField_returnsTestValue() async throws {
        let output = try await repository.updateCustomField(
            id: 1,
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud() async throws {
        var customField = try await createCustomField()
        #expect(customField.dataType == .string)
        #expect(customField.documentCount == 0)
        #expect(customField.id > 0)
        #expect(customField.name == "Test CustomField")

        var customFields = try await getCustomFields()
        #expect(customFields.results.map(\.id) == [customField.id])
        #expect(customFields.count == 1)
        #expect(customFields.next == nil)

        var updateInput = SaveCustomFieldInput(customField: customField)
        updateInput.name = "Updated Name"
        customField = try await repository.updateCustomField(
            id: customField.id,
            input: updateInput,
            server: .testValue()
        )
        #expect(customField.name == "Updated Name")
        #expect(customField.dataType == .string)

        try await deleteCustomField(customField.id)
        customFields = try await getCustomFields()
        #expect(customFields.results == [])
        #expect(customFields.next == nil)
    }

    // The server assigns each select option an opaque string id on create. Nothing else in the app
    // generates those, so this pins the behaviour the form depends on.
    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud_select_serverAssignsOptionIds() async throws {
        let customField = try await repository.createCustomField(
            input: .init(
                dataType: .select,
                extraData: .init(selectOptions: [.init(label: "Open"), .init(label: "Closed")]),
                name: "Status"
            ),
            server: .testValue()
        )

        let options = try #require(customField.extraData?.selectOptions)
        #expect(options.map(\.label) == ["Open", "Closed"])
        #expect(options.allSatisfy { ($0.id?.isEmpty == false) })

        try await deleteCustomField(customField.id)
    }

    @Test(
        .dependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func crud_monetary_roundTripsDefaultCurrency() async throws {
        let customField = try await repository.createCustomField(
            input: .init(
                dataType: .monetary,
                extraData: .init(defaultCurrency: "EUR"),
                name: "Invoice total"
            ),
            server: .testValue()
        )

        #expect(customField.extraData?.defaultCurrency == "EUR")

        try await deleteCustomField(customField.id)
    }

    init() async throws {
        try await repository.deleteAll()
    }

    private func createCustomField() async throws -> SaveCustomFieldOutput {
        try await repository.createCustomField(
            input: .init(
                dataType: .string,
                name: "Test CustomField"
            ),
            server: .testValue()
        )
    }

    private func deleteCustomField(_ id: CustomField.Id) async throws -> DeleteCustomFieldOutput {
        try await repository.deleteCustomField(
            id: id,
            server: .testValue()
        )
    }

    private func getCustomFields() async throws -> GetCustomFieldsOutput {
        try await repository.getCustomFields(
            input: .testValue(),
            server: .testValue()
        )
    }

    @Dependency(\.customFieldsRepository)
    private var repository
}
```

If `StoragePathsRepositoryTests` ends with a different `repository` declaration than the `@Dependency` above, copy that file's form exactly instead — the two must match.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise run docker:start && tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: FAIL — `value of type 'DependencyValues' has no member 'customFieldsRepository'`.

- [ ] **Step 3: Write `CustomFieldsRepository.swift`**

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct CustomFieldsRepository: Sendable {

    var createCustomField: @Sendable (
        _ input: SaveCustomFieldInput,
        _ server: Server
    ) async throws -> SaveCustomFieldOutput

    var deleteCustomField: @Sendable (
        _ id: CustomField.Id,
        _ server: Server
    ) async throws -> DeleteCustomFieldOutput

    var getCustomFields: @Sendable (
        _ input: GetCustomFieldsInput,
        _ server: Server
    ) async throws -> GetCustomFieldsOutput

    var updateCustomField: @Sendable (
        _ id: CustomField.Id,
        _ input: SaveCustomFieldInput,
        _ server: Server
    ) async throws -> SaveCustomFieldOutput
}

extension CustomFieldsRepository: TestDependencyKey {

    static let previewValue = Self(
        createCustomField: { _, _ in .testValue() },
        deleteCustomField: { _, _ in },
        getCustomFields: { _, _ in .testValue(results: .previewValue) },
        updateCustomField: { _, _, _ in .testValue() }
    )

    static let testValue = Self(
        createCustomField: { _, _ in .testValue() },
        deleteCustomField: { _, _ in },
        getCustomFields: { _, _ in .testValue() },
        updateCustomField: { _, _, _ in .testValue() }
    )
}

extension DependencyValues {

    var customFieldsRepository: CustomFieldsRepository {
        get { self[CustomFieldsRepository.self] }
        set { self[CustomFieldsRepository.self] = newValue }
    }
}

extension CustomFieldsRepository: DependencyKey {
    static let liveValue = Self(
        createCustomField: createCustomField(input:server:),
        deleteCustomField: deleteCustomField(id:server:),
        getCustomFields: getCustomFields(input:server:),
        updateCustomField: updateCustomField(id:input:server:)
    )
}

private extension CustomFieldsRepository {

    static func createCustomField(
        input: SaveCustomFieldInput,
        server: Server
    ) async throws -> SaveCustomFieldOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/custom_fields/",
                method: .post,
                body: input
            ))
            .value
    }

    static func deleteCustomField(
        id: CustomField.Id,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/custom_fields/\(id)/",
                method: .delete
            ))
            .value
    }

    static func getCustomFields(
        input: GetCustomFieldsInput,
        server: Server
    ) async throws -> GetCustomFieldsOutput {
        try await APIClient
            .client(server: server)
            .send(.init(input: input))
            .value
    }

    static func updateCustomField(
        id: CustomField.Id,
        input: SaveCustomFieldInput,
        server: Server
    ) async throws -> SaveCustomFieldOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/custom_fields/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
}

private extension Request where Response == GetCustomFieldsOutput {

    init(input: GetCustomFieldsInput) {
        if let url = input.url {
            self.init(
                url: url,
                method: .get
            )
            return
        }
        self.init(
            path: "/api/custom_fields/",
            method: .get
        )
    }
}
```

- [ ] **Step 4: Write the test-support extension**

`Modules/ApiTestSupport/Extensions/CustomFieldsRepository+Extensions.swift`:

```swift
@testable import ApiImplementation

import ApiInterface

extension CustomFieldsRepository {

    func deleteAll() async throws {
        let customFields = try await getCustomFields(
            input: .testValue(),
            server: .testValue()
        ).results.map(\.id)
        for customField in customFields {
            try await deleteCustomField(
                id: customField,
                server: .testValue()
            )
        }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: PASS, including the three `.integrationTests` cases against the docker instance.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/ApiImplementation/CustomFields Modules/ApiTestSupport/Extensions Modules/ApiImplementationTests/CustomFields
git commit -m "feat: add custom fields repository"
```

---

## Task 4: The use-case implementations

**Files:**
- Create: `Modules/ApiImplementation/CustomFields/GetCustomFieldsUseCase.swift`
- Create: `Modules/ApiImplementation/CustomFields/SaveCustomFieldUseCase.swift`
- Create: `Modules/ApiImplementation/CustomFields/DeleteCustomFieldUseCase.swift`
- Create: `Modules/ApiTestSupport/CustomFields/DeleteAllCustomFieldsUseCase.swift`
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`
- Test: `Modules/ApiImplementationTests/CustomFields/GetCustomFieldsUseCaseTests.swift`
- Test: `Modules/ApiImplementationTests/CustomFields/SaveCustomFieldUseCaseTests.swift`

**Interfaces:**
- Consumes: `CustomFieldsRepository` from Task 3.
- Produces: `liveValue` for `GetCustomFieldsUseCase`, `SaveCustomFieldUseCase`, `DeleteCustomFieldUseCase`, `DeleteAllCustomFieldsUseCase`, and the shared-storage key `SharedReaderKey.customFields(_ server: Server)` backed by `"\(server.id)-custom-fields.json"`.

- [ ] **Step 1: Write the failing tests**

`Modules/ApiImplementationTests/CustomFields/GetCustomFieldsUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import ComposableArchitecture
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct GetCustomFieldsUseCaseTests {

    @Test
    func execute_followsPaginationAndFillsCache() async throws {
        @Shared(.customFields(.testValue()))
        var cache: IdentifiedArrayOf<CustomField> = []

        let secondPage = URL(string: "http://localhost:8000/api/custom_fields/?page=2")
        let result = try await withDependencies {
            $0.customFieldsRepository.getCustomFields = { input, _ in
                if input.url == nil {
                    return .testValue(count: 2, next: secondPage, results: [.testValue(id: 1, name: "Alpha")])
                }
                return .testValue(count: 2, results: [.testValue(id: 2, name: "Beta")])
            }
        } operation: {
            @Dependency(\.getCustomFields.execute)
            var getCustomFields

            return try await getCustomFields(.testValue())
        }

        #expect(result.map(\.name) == ["Alpha", "Beta"])
        #expect(cache.map(\.id) == [1, 2])
    }
}
```

`Modules/ApiImplementationTests/CustomFields/SaveCustomFieldUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import ComposableArchitecture
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite
struct SaveCustomFieldUseCaseTests {

    @Test
    func execute_createCustomField() async throws {
        @Shared(.customFields(.testValue()))
        var cache: IdentifiedArrayOf<CustomField> = []

        let createReceived = LockIsolated<SaveCustomFieldInput?>(nil)
        let output = try await withDependencies {
            $0.customFieldsRepository.createCustomField = { input, _ in
                createReceived.setValue(input)
                return .testValue(id: 7, name: "Created")
            }
        } operation: {
            @Dependency(\.saveCustomField.execute)
            var saveCustomField

            return try await saveCustomField(nil, .testValue(name: "Created"), .testValue())
        }

        #expect(output.name == "Created")
        #expect(createReceived.value?.name == "Created")
        #expect(cache.map(\.id) == [7])
    }

    @Test
    func execute_updateCustomField_sortsCacheByName() async throws {
        @Shared(.customFields(.testValue()))
        var cache: IdentifiedArrayOf<CustomField> = .init(uniqueElements: [.testValue(id: 1, name: "Zulu")])

        let updateReceived = LockIsolated<CustomField.Id?>(nil)
        _ = try await withDependencies {
            $0.customFieldsRepository.updateCustomField = { id, _, _ in
                updateReceived.setValue(id)
                return .testValue(id: 2, name: "Alpha")
            }
        } operation: {
            @Dependency(\.saveCustomField.execute)
            var saveCustomField

            return try await saveCustomField(2, .testValue(name: "Alpha"), .testValue())
        }

        #expect(updateReceived.value == 2)
        #expect(cache.map(\.name) == ["Alpha", "Zulu"])
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: FAIL — `reference to member 'customFields' cannot be resolved`.

- [ ] **Step 3: Add the shared-storage key**

In `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, insert alphabetically — after the `correspondents(_:)` block, before `documentTypes(_:)`:

```swift
public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<CustomField>>.Default {

    static func customFields(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-custom-fields.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}
```

- [ ] **Step 4: Write `GetCustomFieldsUseCase.swift`**

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension GetCustomFieldsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetCustomFieldsUseCase {

    static func execute(
        server: Server
    ) async throws -> [CustomField] {
        @Shared(.customFields(server))
        var cache: IdentifiedArrayOf<CustomField> = []

        @Dependency(\.customFieldsRepository)
        var repository

        var output = try await repository.getCustomFields(
            input: .init(),
            server: server
        )
        var result = output.results

        while let url = output.next {
            output = try await repository.getCustomFields(
                input: .init(url: url),
                server: server
            )
            result.append(contentsOf: output.results)
        }

        $cache.withLock { $0 = IdentifiedArray(uniqueElements: result) }

        return result
    }
}
```

- [ ] **Step 5: Write `SaveCustomFieldUseCase.swift`**

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension SaveCustomFieldUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:input:server:)
    )
}

private extension SaveCustomFieldUseCase {

    static func execute(
        id: CustomField.Id?,
        input: SaveCustomFieldInput,
        server: Server
    ) async throws -> SaveCustomFieldOutput {
        @Shared(.customFields(server))
        var cache: IdentifiedArrayOf<CustomField> = []

        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        let result: SaveCustomFieldOutput

        if let id {
            result = try await customFieldsRepository.updateCustomField(
                id: id,
                input: input,
                server: server
            )
        } else {
            result = try await customFieldsRepository.createCustomField(
                input: input,
                server: server
            )
        }

        $cache.withLock { cache in
            cache.updateOrAppend(result)
            cache.sort {
                $0.name.compare(
                    $1.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
        }

        return result
    }
}
```

- [ ] **Step 6: Write `DeleteCustomFieldUseCase.swift`**

Mirror `Modules/ApiImplementation/StoragePaths/DeleteStoragePathUseCase.swift` exactly — read it first and substitute the names. It removes the id from `@Shared(.customFields(server))` after the repository call succeeds.

- [ ] **Step 7: Write `Modules/ApiTestSupport/CustomFields/DeleteAllCustomFieldsUseCase.swift`**

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections

extension DeleteAllCustomFieldsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension DeleteAllCustomFieldsUseCase {

    static func execute(
        server: Server
    ) async throws {
        @Dependency(\.getCustomFields.execute)
        var getCustomFields

        @Dependency(\.deleteCustomField.execute)
        var deleteCustomField

        let customFields = try await getCustomFields(server)

        for customField in customFields {
            try await deleteCustomField(customField.id, server)
        }
    }
}
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
mise run format
git add Modules/ApiImplementation/CustomFields Modules/ApiTestSupport/CustomFields Modules/ApiInterface/Extensions Modules/ApiImplementationTests/CustomFields
git commit -m "feat: add custom fields use cases"
```

---

## Task 5: Cache wiring

Custom fields join the cache ahead of a consumer, so the future custom-field-values-on-documents work has ids resolving to names from day one.

**Files:**
- Modify: `Modules/ApiInterface/Shared/ApiCache.swift`
- Modify: `Modules/ApiInterface/CustomFields/CustomField.swift`
- Modify: `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`
- Test: `Modules/ApiInterfaceTests/Shared/ApiCacheTests.swift` (extend)

**Interfaces:**
- Consumes: `.customFields(server)` from Task 4.
- Produces: `ApiCache.customField(_ id: CustomField.Id?, _ server: Server) -> CustomField?` and `CustomField.Id.get(_ server: Server) -> CustomField?`.

- [ ] **Step 1: Write the failing test**

Read `Modules/ApiInterfaceTests/Shared/ApiCacheTests.swift` first and follow its existing per-entity test shape. Add a case matching it, along these lines:

```swift
@Test
func customField_returnsCachedValue() async throws {
    @Shared(.customFields(.testValue()))
    var cache: IdentifiedArrayOf<CustomField> = .init(uniqueElements: [.testValue(id: 1, name: "Status")])

    @Dependency(\.apiCache)
    var apiCache

    #expect(apiCache.customField(id: 1, server: .testValue())?.name == "Status")
    #expect(apiCache.customField(id: nil, server: .testValue()) == nil)
}
```

If the existing tests in that file drive `liveValue` differently (for example via `withDependencies { $0.apiCache = .liveValue }`), copy that form instead.

- [ ] **Step 2: Run the test to verify it fails**

Run: `tuist test ApiInterface -d "iPhone 17 Pro"`
Expected: FAIL — `value of type 'ApiCache' has no member 'customField'`.

- [ ] **Step 3: Add `customField` to `ApiCache`**

Four edits in `Modules/ApiInterface/Shared/ApiCache.swift`, each placed alphabetically (after `correspondent`, before `documentType`):

The client property:

```swift
    public var customField: @Sendable (
        _ id: CustomField.Id?,
        _ server: Server
    ) -> CustomField?
```

In `liveValue`: `customField: customField(id:server:),`
In `previewValue`: `customField: { _, _ in .testValue() },`

The static lookup:

```swift
    static func customField(
        id: CustomField.Id?,
        server: Server
    ) -> CustomField? {
        guard let id else {
            return nil
        }

        if let cache = customFields[server] {
            return cache.wrappedValue[id: id]
        }

        let cache = Shared(.customFields(server))

        customFields.withValue { $0[server] = cache }

        return cache.wrappedValue[id: id]
    }
```

And the backing store, alphabetically among the other `private static let` lines:

```swift
    private static let customFields: LockIsolated<[Server: Shared<IdentifiedArrayOf<CustomField>>]> = .init([:])
```

- [ ] **Step 4: Add `CustomField.Id.get`**

Append to `Modules/ApiInterface/CustomFields/CustomField.swift`:

```swift
public extension CustomField.Id {

    func get(_ server: Server) -> CustomField? {
        @Dependency(\.apiCache)
        var apiCache

        return apiCache.customField(id: self, server: server)
    }
}
```

- [ ] **Step 5: Add custom fields to `UpdateCacheUseCase`**

In `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`, three insertions, each alphabetical — after the `getCorrespondents` dependency, after the `correspondents` `async let`, and after the `_ = try await correspondents` line:

```swift
        @Dependency(\.getCustomFields.execute)
        var getCustomFields
```

```swift
        async let customFields = try await getCustomFields(server)
```

```swift
        _ = try await customFields
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `tuist test ApiInterface -d "iPhone 17 Pro" && tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 7: Format and commit**

```bash
mise run format
git add Modules/ApiInterface Modules/ApiImplementation/Cache Modules/ApiInterfaceTests
git commit -m "feat: cache custom fields"
```

---

## Task 6: Localization

All keys the feature module needs, added before any view references them.

**Files:**
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Modify: `Modules/ApiInterface/CustomFields/CustomFieldDataType.swift`

**Interfaces:**
- Produces: `LocalizedStringResource` members auto-generated by Xcode from the catalog keys — `.addOption`, `.createCustomField`, `.customField`, `.customFields`, `.dataType`, `.defaultCurrency`, `.deleteCustomField`, `.deleteOption`, `.editCustomField`, `.noCustomFieldsFound`, `.selectOptions`, and eleven `.customFieldDataType*` members.

- [ ] **Step 1: Add the keys with a script**

The catalog is large, hand-editing JSON is error-prone, and key order does not matter to Xcode. Run this from the repo root:

```bash
python3 - <<'PY'
import json, collections

path = "Shared/Framework/Resources/Localizable.xcstrings"
with open(path) as handle:
    catalog = json.load(handle, object_pairs_hook=collections.OrderedDict)

entries = {
    "addOption": ("Add option", "Option hinzufügen"),
    "createCustomField": ("Add custom field", "Benutzerdefiniertes Feld erstellen"),
    "customField": ("Custom field", "Benutzerdefiniertes Feld"),
    "customFieldDataTypeBoolean": ("Boolean", "Boolean"),
    "customFieldDataTypeDate": ("Date", "Datum"),
    "customFieldDataTypeDocumentLink": ("Document link", "Dokumentverknüpfung"),
    "customFieldDataTypeFloat": ("Number", "Zahl"),
    "customFieldDataTypeInteger": ("Integer", "Ganzzahl"),
    "customFieldDataTypeLongText": ("Long text", "Langer Text"),
    "customFieldDataTypeMonetary": ("Monetary", "Währung"),
    "customFieldDataTypeSelect": ("Select", "Auswahl"),
    "customFieldDataTypeString": ("Text", "Text"),
    "customFieldDataTypeUnknown": ("Unknown", "Unbekannt"),
    "customFieldDataTypeUrl": ("URL", "URL"),
    "customFields": ("Custom fields", "Benutzerdefinierte Felder"),
    "dataType": ("Data type", "Datentyp"),
    "defaultCurrency": ("Default currency", "Standardwährung"),
    "deleteCustomField": ("Delete custom field", "Benutzerdefiniertes Feld löschen"),
    "deleteOption": ("Delete option", "Option löschen"),
    "editCustomField": ("Edit custom field", "Benutzerdefiniertes Feld bearbeiten"),
    "noCustomFieldsFound": ("No custom fields found", "Keine benutzerdefinierten Felder gefunden"),
    "selectOptions": ("Options", "Optionen"),
}

for key, (english, german) in entries.items():
    if key in catalog["strings"]:
        raise SystemExit(f"{key} already exists — reconcile by hand")
    catalog["strings"][key] = collections.OrderedDict([
        ("extractionState", "manual"),
        ("localizations", collections.OrderedDict([
            ("de", {"stringUnit": {"state": "translated", "value": german}}),
            ("en", {"stringUnit": {"state": "translated", "value": english}}),
        ])),
    ])

catalog["strings"] = collections.OrderedDict(sorted(catalog["strings"].items()))

with open(path, "w") as handle:
    json.dump(catalog, handle, ensure_ascii=False, indent=2)
    handle.write("\n")
PY
```

- [ ] **Step 2: Verify the catalog still parses and the keys landed**

```bash
python3 -c "
import json
catalog = json.load(open('Shared/Framework/Resources/Localizable.xcstrings'))
keys = [k for k in catalog['strings'] if 'ustomField' in k or k in ('addOption','dataType','defaultCurrency','deleteOption','selectOptions')]
print(len(keys), 'keys added')
assert len(keys) == 22, keys
"
```

Expected: `22 keys added`.

- [ ] **Step 3: Replace `CustomFieldDataType.description` with the localized switch**

This replaces the `rawValue` placeholder left in Task 1:

```swift
extension CustomFieldDataType: CustomStringConvertible {
    public var description: String {
        switch self {
        case .boolean:
            String(localized: .customFieldDataTypeBoolean)
        case .date:
            String(localized: .customFieldDataTypeDate)
        case .documentLink:
            String(localized: .customFieldDataTypeDocumentLink)
        case .float:
            String(localized: .customFieldDataTypeFloat)
        case .integer:
            String(localized: .customFieldDataTypeInteger)
        case .longText:
            String(localized: .customFieldDataTypeLongText)
        case .monetary:
            String(localized: .customFieldDataTypeMonetary)
        case .select:
            String(localized: .customFieldDataTypeSelect)
        case .string:
            String(localized: .customFieldDataTypeString)
        case .unknown:
            String(localized: .customFieldDataTypeUnknown)
        case .url:
            String(localized: .customFieldDataTypeUrl)
        }
    }
}
```

- [ ] **Step 4: Build to confirm the generated symbols resolve**

Run: `tuist test ApiInterface -d "iPhone 17 Pro"`
Expected: PASS. A failure here means Xcode has not regenerated the string symbols — run `tuist generate --no-open` and retry.

- [ ] **Step 5: Format and commit**

```bash
mise run format
git add Shared/Framework/Resources/Localizable.xcstrings Modules/ApiInterface/CustomFields/CustomFieldDataType.swift
git commit -m "feat: add custom field strings"
```

---

## Task 7: Register the feature module and build `CustomFieldRow`

Tuist derives targets from the `Module` enum, and `buildableFolders` points at a directory that must exist. So the module registration and its first real screen land together.

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldRow/CustomFieldRowReducer.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldRow/CustomFieldRowReducer+Effect.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldRow/CustomFieldRowReducer+TestValue.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldRow/CustomFieldRowView.swift`
- Test: `Modules/CustomFieldsFeatureTests/CustomFieldRow/CustomFieldRowReducerTests.swift`

**Interfaces:**
- Consumes: `CustomField`, `Server`, `DeleteConfirmationPresenter` (`\.deleteConfirmation`).
- Produces: `CustomFieldRowReducer` with `State(customField: CustomField, isUpdating: Bool = false, server: Server)`, `id: CustomField.Id`; `Action.view` = `deleteButtonTapped | editButtonTapped`; `Action.delegate` = `deleteCustomField | editCustomField`. `CustomFieldRowView(store:)` — internal, not public.

- [ ] **Step 1: Register the four Tuist entries**

`Module.swift` — add the enum cases alphabetically (after `.correspondentsFeatureTests`, before `.documentTypesApp`):

```swift
    case customFieldsApp = "CustomFieldsApp"
    case customFieldsAppTests = "CustomFieldsAppTests"
    case customFieldsFeature = "CustomFieldsFeature"
    case customFieldsFeatureTests = "CustomFieldsFeatureTests"
```

In `codeCoverageTarget`: add `.customFieldsFeature` to the `true` branch; add `.customFieldsApp`, `.customFieldsAppTests`, `.customFieldsFeatureTests` to the `false` branch.

In `product`: add `.customFieldsApp` to the `.app` branch; `.customFieldsFeature` to the framework branch; `.customFieldsFeatureTests` to the `.unitTests` branch; `.customFieldsAppTests` to the `.uiTests` branch.

`Module+Schemes.swift` — add `.customFieldsFeature` to the feature-scheme case list; `.customFieldsApp` to the app-scheme case list; `.customFieldsAppTests` and `.customFieldsFeatureTests` to the empty-scheme case list; and in `featureAppTestTargets`:

```swift
        case .customFieldsApp:
            [.testableTarget(target: .target(.customFieldsAppTests))]
```

`Module+InfoPlists.swift` — add `.customFieldsApp` to the app case list.

`Module+Dependencies.swift` — add all four cases alphabetically:

```swift
        case .customFieldsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.customFieldsFeature)
            ]
        case .customFieldsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.customFieldsApp),
                .target(.customFieldsFeature),
                .target(.uiTestSupport),
            ]
        case .customFieldsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
            ]
        case .customFieldsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.customFieldsFeature),
                .target(.testSupport),
            ]
```

`customFieldsFeature` has **no** `.target(.permissionsFeature)` — custom fields have no owner or permissions.

- [ ] **Step 2: Create the module directories**

```bash
mkdir -p Modules/CustomFieldsFeature/CustomFieldRow \
         Modules/CustomFieldsFeature/CustomFieldList \
         Modules/CustomFieldsFeature/CustomFieldForm \
         Modules/CustomFieldsFeatureTests/CustomFieldRow \
         Modules/CustomFieldsFeatureTests/CustomFieldList \
         Modules/CustomFieldsFeatureTests/CustomFieldForm \
         Modules/CustomFieldsApp \
         Modules/CustomFieldsAppTests
```

- [ ] **Step 3: Write the failing test**

`Modules/CustomFieldsFeatureTests/CustomFieldRow/CustomFieldRowReducerTests.swift`:

```swift
@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct CustomFieldRowReducerTests {

    @Test
    func test_view_deleteButtonTapped_confirmed() async throws {
        let confirmationReceived = LockIsolated<String?>(nil)
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            customField: .testValue(name: "Status"),
            server: .testValue()
        )) {
            CustomFieldRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, name in
                confirmationReceived.setValue(name)
                return true
            }
        }

        await store.send(.view(.deleteButtonTapped))
        await store.receive(\.delegate.deleteCustomField)
        #expect(confirmationReceived.value == "Status")
    }

    @Test
    func test_view_deleteButtonTapped_cancelled() async throws {
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            customField: .testValue(),
            server: .testValue()
        )) {
            CustomFieldRowReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
        }

        await store.send(.view(.deleteButtonTapped))
    }

    @Test
    func test_view_editButtonTapped() async throws {
        let store = TestStore(initialState: CustomFieldRowReducer.State(
            customField: .testValue(),
            server: .testValue()
        )) {
            CustomFieldRowReducer()
        }

        await store.send(.view(.editButtonTapped))
        await store.receive(\.delegate.editCustomField)
    }
}
```

- [ ] **Step 4: Regenerate and run the test to verify it fails**

Run: `tuist generate --no-open && tuist test CustomFieldsFeature -d "iPhone 17 Pro"`
Expected: FAIL — `no such module 'CustomFieldsFeature'` or `cannot find 'CustomFieldRowReducer' in scope`.

- [ ] **Step 5: Write `CustomFieldRowReducer.swift`**

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Tagged

@Reducer
public struct CustomFieldRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deleteCustomField
            case editCustomField
        }

        public enum View {
            case deleteButtonTapped
            case editButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: CustomField.Id { customField.id }

        let customField: CustomField

        var isUpdating = false

        let server: Server
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .editButtonTapped:
                    return .send(.delegate(.editCustomField))
                case .deleteButtonTapped:
                    return .runConfirmDelete(name: state.customField.name)
                }
            case .delegate:
                return .none
            }
        }
    }
}
```

- [ ] **Step 5b: Write `CustomFieldRowReducer+TestValue.swift`**

Task 9's list tests build row states through this, so it lands here with the reducer:

```swift
import ApiInterface
import Foundation

public extension CustomFieldRowReducer.State {

    static func testValue(
        customField: CustomField = .testValue(),
        isUpdating: Bool = false,
        server: Server = .testValue()
    ) -> Self {
        .init(
            customField: customField,
            isUpdating: isUpdating,
            server: server
        )
    }
}
```

Compare against `Modules/StoragePathsFeature/StoragePathRow/StoragePathRowReducer+TestValue.swift` and match whatever parameter set it uses — `State`'s memberwise initialiser is synthesized, so the argument labels must line up with the property order in Step 5.

- [ ] **Step 6: Write `CustomFieldRowReducer+Effect.swift`**

```swift
import Components
import ComposableArchitecture
import Foundation

extension Effect where Action == CustomFieldRowReducer.Action {

    static func runConfirmDelete(name: String) -> Self {
        @Dependency(\.deleteConfirmation.present)
        var presentConfirmation

        return .run { send in
            guard await presentConfirmation(.deleteCustomField, name) else {
                return
            }
            await send(.delegate(.deleteCustomField))
        }
        .cancellable(id: CancelID.confirmDelete)
    }
}

private enum CancelID {
    case confirmDelete
}
```

- [ ] **Step 7: Write `CustomFieldRowView.swift`**

The caption joins the data type and the document count, so `Select · 4 documents`.

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftUI

@ViewAction(for: CustomFieldRowReducer.self)
struct CustomFieldRowView: View {

    var body: some View {
        VStack(alignment: .leading) {
            Text(store.customField.name).foregroundColor(Color.m3OnSurface)
                .clipShape(Rectangle())
            Text(caption)
                .font(.caption)
                .foregroundColor(.m3Outline)
        }
        .accessibilityElement()
        .accessibilityValue([
            store.customField.name,
            caption
        ].joined(separator: ", "))
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(store.isUpdating ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    var store: StoreOf<CustomFieldRowReducer>

    private var caption: String {
        [
            store.customField.dataType.description,
            String(localized: .numberOfDocuments(store.customField.documentCount))
        ].joined(separator: " · ")
    }

    @ViewBuilder
    private func swipeActions() -> some View {
        Button {
            send(.editButtonTapped)
        } label: {
            Image(systemName: "square.and.pencil")
        }
        .accessibilityLabel(.editCustomField)
        .tint(.m3Primary)

        Button {
            send(.deleteButtonTapped)
        } label: {
            Image(systemName: "trash")
        }
        .accessibilityLabel(.deleteCustomField)
        .tint(.m3Error)
    }
}

#Preview {
    List {
        CustomFieldRowView(
            store: Store(
                initialState: CustomFieldRowReducer.State(
                    customField: .testValue(),
                    server: .testValue()
                ),
                reducer: {
                    CustomFieldRowReducer()
                }
            )
        )
    }
}
```

- [ ] **Step 8: Run the tests to verify they pass**

Run: `tuist test CustomFieldsFeature -d "iPhone 17 Pro"`
Expected: PASS — three tests.

- [ ] **Step 9: Format and commit**

```bash
mise run format
git add Tuist Modules/CustomFieldsFeature Modules/CustomFieldsFeatureTests
git commit -m "feat: add CustomFieldsFeature module and custom field row"
```

---

## Task 8: `CustomFieldForm`

The one screen that diverges from the `StoragePaths` template.

**Files:**
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldSelectOptionInput.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldFormInput.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldFormField.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldFormReducer.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldFormReducer+Effect.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldFormReducer+TestValue.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldForm/CustomFieldFormView.swift`
- Test: `Modules/CustomFieldsFeatureTests/CustomFieldForm/CustomFieldFormReducerTests.swift`

**Interfaces:**
- Consumes: `SaveCustomFieldInput`, `\.saveCustomField`, `Components.FieldState`, `Components.Field`, `Components.MenuField`, `Components.Sheet`, `Components.SheetHeader`, `Components.SheetCloseButton`, `Components.AdaptiveStack`.
- Produces: `CustomFieldFormReducer.State(customField: CustomField? = nil, server: Server)` exposing `customFieldId: CustomField.Id?`, `input: CustomFieldFormInput`, `isSaving: Bool`, `server: Server`, and computed `isDataTypeLocked: Bool` (true whenever `customFieldId != nil`). `Action.delegate` = `customFieldSaved(CustomField)`. `Action.view` = `addOptionButtonTapped | cancelButtonTapped | closeButtonTapped | deleteOptionButtonTapped(id: UUID) | saveButtonTapped`. `CustomFieldFormView(store:)` — public. `.testValue(customField:server:)`.

- [ ] **Step 1: Write the failing test**

`Modules/CustomFieldsFeatureTests/CustomFieldForm/CustomFieldFormReducerTests.swift`:

```swift
@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct CustomFieldFormReducerTests {

    @Test
    func test_init_create_defaultsToString() async throws {
        let state = CustomFieldFormReducer.State(server: .testValue())

        #expect(state.customFieldId == nil)
        #expect(state.input.dataType == .string)
        #expect(state.input.name.value == "")
        #expect(state.isDataTypeLocked == false)
    }

    @Test
    func test_init_edit_locksDataTypeAndLoadsOptions() async throws {
        let state = CustomFieldFormReducer.State(
            customField: .testValue(
                dataType: .select,
                extraData: .init(selectOptions: [
                    .init(id: "a", label: "Open"),
                    .init(id: "b", label: "Closed")
                ]),
                name: "Status"
            ),
            server: .testValue()
        )

        #expect(state.isDataTypeLocked == true)
        #expect(state.input.dataType == .select)
        #expect(state.input.name.value == "Status")
        #expect(state.input.selectOptions.map(\.label.value) == ["Open", "Closed"])
        #expect(state.input.selectOptions.map(\.serverId) == ["a", "b"])
    }

    @Test
    func test_view_addOptionButtonTapped() async throws {
        let store = TestStore(initialState: CustomFieldFormReducer.State(server: .testValue())) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.uuid = .incrementing
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.addOptionButtonTapped)) {
            $0.input.selectOptions = [
                CustomFieldSelectOptionInput(id: UUID(0), label: .init(value: ""), serverId: nil)
            ]
        }
    }

    @Test
    func test_view_deleteOptionButtonTapped() async throws {
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(0), label: .init(value: "Open"), serverId: "a"),
            CustomFieldSelectOptionInput(id: UUID(1), label: .init(value: "Closed"), serverId: "b")
        ]

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        }

        await store.send(.view(.deleteOptionButtonTapped(id: UUID(0)))) {
            $0.input.selectOptions = [
                CustomFieldSelectOptionInput(id: UUID(1), label: .init(value: "Closed"), serverId: "b")
            ]
        }
    }

    @Test
    func test_view_saveButtonTapped_create_success() async throws {
        let saved = LockIsolated<(CustomField.Id?, SaveCustomFieldInput)?>(nil)
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.name.value = "Reference"

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { id, input, _ in
                saved.setValue((id, input))
                return .testValue(id: 9, name: "Reference")
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.customFieldSaved)
        await store.receive(\.binding) {
            $0.isSaving = false
        }

        #expect(saved.value?.0 == nil)
        #expect(saved.value?.1.name == "Reference")
        #expect(saved.value?.1.dataType == .string)
        #expect(saved.value?.1.extraData == nil)
    }

    // A select field must send its options; a plain field must send no extra_data at all.
    @Test
    func test_view_saveButtonTapped_select_sendsOptions() async throws {
        let saved = LockIsolated<SaveCustomFieldInput?>(nil)
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.dataType = .select
        state.input.name.value = "Status"
        state.input.selectOptions = [
            CustomFieldSelectOptionInput(id: UUID(0), label: .init(value: "Open"), serverId: "a"),
            CustomFieldSelectOptionInput(id: UUID(1), label: .init(value: ""), serverId: nil)
        ]

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { _, input, _ in
                saved.setValue(input)
                return .testValue()
            }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.delegate.customFieldSaved)

        // The blank option the user added but never filled in is dropped rather than sent.
        #expect(saved.value?.extraData?.selectOptions?.map(\.label) == ["Open"])
        #expect(saved.value?.extraData?.selectOptions?.map(\.id) == ["a"])
    }

    @Test
    func test_view_saveButtonTapped_monetary_sendsCurrency() async throws {
        let saved = LockIsolated<SaveCustomFieldInput?>(nil)
        var state = CustomFieldFormReducer.State(server: .testValue())
        state.input.dataType = .monetary
        state.input.defaultCurrency.value = "EUR"
        state.input.name.value = "Invoice total"

        let store = TestStore(initialState: state) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { _, input, _ in
                saved.setValue(input)
                return .testValue()
            }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.delegate.customFieldSaved)

        #expect(saved.value?.extraData?.defaultCurrency == "EUR")
        #expect(saved.value?.extraData?.selectOptions == nil)
    }

    @Test
    func test_error_appliesFieldErrors() async throws {
        let store = TestStore(initialState: CustomFieldFormReducer.State(server: .testValue())) {
            CustomFieldFormReducer()
        } withDependencies: {
            $0.saveCustomField.execute = { _, _, _ in
                throw ApiError.testValue(fieldErrors: ["name": ["This field must be unique."]])
            }
        }

        store.exhaustivity = .off(showSkippedAssertions: false)
        await store.send(.view(.saveButtonTapped))
        await store.receive(\.error) {
            $0.input.name.error = "This field must be unique."
        }
    }
}
```

Before writing the implementation, open `Modules/ApiInterface/Shared/ApiError.swift` and confirm the exact `testValue` signature for field errors and the `errorForField(_:)` accessor. If `testValue(fieldErrors:)` does not exist in that form, adjust the last test to construct the error the way `StoragePathFormReducerTests` does.

- [ ] **Step 2: Run the test to verify it fails**

Run: `tuist test CustomFieldsFeature -d "iPhone 17 Pro"`
Expected: FAIL — `cannot find 'CustomFieldFormReducer' in scope`.

- [ ] **Step 3: Write `CustomFieldSelectOptionInput.swift`**

```swift
import ApiInterface
import Components
import Foundation

struct CustomFieldSelectOptionInput: Equatable, Identifiable, Sendable {

    // `id` is client-side and exists only so SwiftUI can identify a row the user has just added:
    // the server assigns `serverId` on save, so a brand new option has nothing else to be keyed by.
    let id: UUID

    var label: FieldState<String>

    let serverId: String?
}

extension CustomFieldSelectOptionInput {

    var apiValue: CustomFieldSelectOption {
        .init(
            id: serverId,
            label: label.value
        )
    }
}
```

- [ ] **Step 4: Write `CustomFieldFormInput.swift`**

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

public struct CustomFieldFormInput: Equatable, Sendable {

    var dataType: CustomFieldDataType = .string

    var defaultCurrency = FieldState(value: "")

    var name = FieldState(focused: true, value: "")

    var selectOptions: IdentifiedArrayOf<CustomFieldSelectOptionInput> = []
}

extension CustomFieldFormInput {

    init(customField: CustomField?) {
        guard let customField else {
            self.init()
            return
        }
        self.init(
            dataType: customField.dataType,
            defaultCurrency: .init(value: customField.extraData?.defaultCurrency ?? ""),
            name: .init(value: customField.name),
            selectOptions: IdentifiedArray(
                uniqueElements: (customField.extraData?.selectOptions ?? []).map {
                    CustomFieldSelectOptionInput(
                        id: UUID(),
                        label: .init(value: $0.label),
                        serverId: $0.id
                    )
                }
            )
        )
    }

    var apiValue: SaveCustomFieldInput {
        .init(
            dataType: dataType == .unknown ? nil : dataType,
            extraData: extraDataApiValue,
            name: name.value
        )
    }

    mutating func applyFieldErrors(from apiError: ApiError) {
        for (fieldName, keyPath) in CustomFieldFormField.fieldStateKeyPaths {
            if let error = apiError.errorForField(fieldName.rawValue) {
                self[keyPath: keyPath] = error
            }
        }
    }

    private var extraDataApiValue: CustomFieldExtraData? {
        switch dataType {
        case .monetary:
            guard !defaultCurrency.value.isEmpty else {
                return nil
            }
            return .init(defaultCurrency: defaultCurrency.value)
        case .select:
            // An option the user added but left blank is dropped rather than sent: the server would
            // store an unlabelled choice that can never be picked meaningfully.
            let options = selectOptions
                .filter { !$0.label.value.isEmpty }
                .map(\.apiValue)
            return options.isEmpty ? nil : .init(selectOptions: options)
        case .boolean, .date, .documentLink, .float, .integer, .longText, .string, .unknown, .url:
            return nil
        }
    }
}
```

`CustomFieldFormInput.init(customField:)` calls `UUID()` directly rather than the `\.uuid` dependency because it runs inside `State.init`, which has no dependency scope. The reducer, which does, uses `\.uuid` when adding an option.

- [ ] **Step 5: Write `CustomFieldFormField.swift`**

Only `name` is listed. `dataType` is a plain enum on the input rather than a `FieldState`, so it has no `.error` to write into, and `name` is the only field this endpoint reports errors against anyway.

```swift
import Components
import Foundation

enum CustomFieldFormField: String, CaseIterable, Hashable {
    case name
}

extension CustomFieldFormField {

    static var fieldStateKeyPaths: [CustomFieldFormField: WritableKeyPath<CustomFieldFormInput, String?>] {
        [
            .name: \.name.error
        ]
    }
}
```

- [ ] **Step 6: Write `CustomFieldFormReducer.swift`**

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import SwiftUI

@Reducer
public struct CustomFieldFormReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case error(Error)
        case view(View)

        @CasePathable
        public enum Delegate {
            case customFieldSaved(CustomField)
        }

        public enum View {
            case addOptionButtonTapped
            case cancelButtonTapped
            case closeButtonTapped
            case deleteOptionButtonTapped(id: UUID)
            case saveButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        public let customFieldId: CustomField.Id?

        public let server: Server

        public var input: CustomFieldFormInput

        public var isSaving = false

        // The server accepts a data_type change via PATCH, but changing the type of a field that
        // already holds values reinterprets or discards them and the app cannot undo that. So the
        // app refuses what the API allows.
        public var isDataTypeLocked: Bool {
            customFieldId != nil
        }

        public init(
            customField: CustomField? = nil,
            server: Server
        ) {
            self.customFieldId = customField?.id
            self.server = server
            input = CustomFieldFormInput(customField: customField)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .error(error):
                if let apiError = error as? ApiError, !apiError.fieldErrors.isEmpty {
                    state.input.applyFieldErrors(from: apiError)
                    return .toast(.error(String(localized: .formHasFieldErrors)))
                }
                return .toast(error)
            case let .view(viewAction):
                switch viewAction {
                case .addOptionButtonTapped:
                    state.input.selectOptions.append(
                        CustomFieldSelectOptionInput(
                            id: uuid(),
                            label: .init(focused: true, value: ""),
                            serverId: nil
                        )
                    )
                    return .none
                case .cancelButtonTapped, .closeButtonTapped:
                    return .run { _ in
                        await dismiss()
                    }
                case let .deleteOptionButtonTapped(id):
                    state.input.selectOptions.remove(id: id)
                    return .none
                case .saveButtonTapped:
                    return .runSaveCustomField(
                        id: state.customFieldId,
                        input: state.input.apiValue,
                        server: state.server
                    )
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}

    @Dependency(\.dismiss)
    private var dismiss

    @Dependency(\.uuid)
    private var uuid
}
```

- [ ] **Step 7: Write `CustomFieldFormReducer+Effect.swift`**

```swift
import ApiInterface
import ComposableArchitecture

extension Effect where Action == CustomFieldFormReducer.Action {

    static func runSaveCustomField(
        id: CustomField.Id?,
        input: SaveCustomFieldInput,
        server: Server
    ) -> Self {
        @Dependency(\.saveCustomField.execute)
        var saveCustomField

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            let customField = try await saveCustomField(id, input, server)
            await send(.delegate(.customFieldSaved(customField)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            await send(.error(error), animation: .snappy)
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveCustomField)
    }
}

private enum CancelID {
    case saveCustomField
}
```

- [ ] **Step 8: Write `CustomFieldFormReducer+TestValue.swift`**

```swift
import ApiInterface
import Foundation

public extension CustomFieldFormReducer.State {

    static func testValue(
        customField: CustomField? = .testValue(),
        server: Server = .testValue()
    ) -> Self {
        .init(
            customField: customField,
            server: server
        )
    }
}
```

- [ ] **Step 9: Write `CustomFieldFormView.swift`**

```swift
import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: CustomFieldFormReducer.self)
public struct CustomFieldFormView: View {

    public var body: some View {
        Sheet {
            SheetHeader(
                title: store.customFieldId == nil ? .createCustomField : .editCustomField,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                }
            )
        } content: {
            VStack(spacing: .x4) {
                nameField()
                dataTypeField()

                switch store.input.dataType {
                case .monetary:
                    defaultCurrencyField()
                case .select:
                    selectOptionsSection()
                case .boolean, .date, .documentLink, .float, .integer, .longText, .string, .unknown, .url:
                    EmptyView()
                }
            }
        } bottom: {
            buttons()
        }
    }

    public init(store: StoreOf<CustomFieldFormReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<CustomFieldFormReducer>

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                send(.cancelButtonTapped)
            } label: {
                Text(.cancel)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .frame(maxWidth: .infinity)

            Button {
                send(.saveButtonTapped)
            } label: {
                Text(.save)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
        }
    }

    @ViewBuilder
    private func dataTypeField() -> some View {
        if store.isDataTypeLocked {
            Field(.dataType) {
                HStack {
                    Text(store.input.dataType.description)
                        .foregroundStyle(Color.m3Outline)
                    Spacer()
                }
            }
        } else {
            MenuField(
                title: .dataType,
                value: $store.input.dataType
            )
        }
    }

    @ViewBuilder
    private func defaultCurrencyField() -> some View {
        Field(.defaultCurrency) {
            TextField(String(localized: .defaultCurrency), text: $store.input.defaultCurrency.value)
                .autocorrectionDisabled()
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.characters)
        }
        .state($store.input.defaultCurrency)
    }

    @ViewBuilder
    private func nameField() -> some View {
        Field(.name) {
            TextField(String(localized: .name), text: $store.input.name.value)
                .textFieldStyle(.plain)
        }
        .state($store.input.name)
    }

    @ViewBuilder
    private func selectOptionsSection() -> some View {
        VStack(alignment: .leading, spacing: .x4) {
            ForEach($store.input.selectOptions) { $option in
                HStack {
                    Field {
                        TextField(String(localized: .selectOptions), text: $option.label.value)
                            .textFieldStyle(.plain)
                    }

                    Button {
                        send(.deleteOptionButtonTapped(id: option.id))
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(Color.m3Error)
                    }
                    .accessibilityLabel(.deleteOption)
                }
            }

            Button {
                send(.addOptionButtonTapped)
            } label: {
                Label(.addOption, systemImage: "plus.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
        }
    }
}

#Preview {
    CustomFieldFormView(
        store: Store(
            initialState: .testValue(
                customField: .testValue(
                    dataType: .select,
                    extraData: .init(selectOptions: [
                        .init(id: "a", label: "Open"),
                        .init(id: "b", label: "Closed")
                    ]),
                    name: "Status"
                )
            ),
            reducer: {
                CustomFieldFormReducer()
            }
        )
    )
}
```

`Field` takes its title as the first unlabelled argument (`Field(.name) { … }`) and can be called with no title at all (`Field { … }`). Check `Modules/Components/Field/Generic/Field.swift` if the compiler disagrees.

- [ ] **Step 10: Run the tests to verify they pass**

Run: `tuist test CustomFieldsFeature -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 11: Format and commit**

```bash
mise run format
git add Modules/CustomFieldsFeature/CustomFieldForm Modules/CustomFieldsFeatureTests/CustomFieldForm
git commit -m "feat: add custom field form"
```

---

## Task 9: `CustomFieldList`

**Files:**
- Create: `Modules/CustomFieldsFeature/CustomFieldList/CustomFieldListReducer.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldList/CustomFieldListReducer+Effect.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldList/CustomFieldListReducer+TestValue.swift`
- Create: `Modules/CustomFieldsFeature/CustomFieldList/CustomFieldListView.swift`
- Test: `Modules/CustomFieldsFeatureTests/CustomFieldList/CustomFieldListReducerTests.swift`
- Test: `Modules/CustomFieldsFeatureTests/CustomFieldList/CustomFieldListViewTests.swift`
- Test: `Modules/CustomFieldsFeatureTests/CustomFieldForm/CustomFieldFormViewTests.swift`

**Interfaces:**
- Consumes: `CustomFieldRowReducer` (Task 7), `CustomFieldFormReducer` (Task 8), `\.getCustomFields`, `\.deleteCustomField`.
- Produces: `CustomFieldListReducer.State(customFields:destination:isLoaded:server:)` and `CustomFieldListView(store:)` — both public, the module's entry point. `.testValue(customFields:)`.

- [ ] **Step 1: Write the failing reducer test**

`Modules/CustomFieldsFeatureTests/CustomFieldList/CustomFieldListReducerTests.swift` — mirror `Modules/StoragePathsFeatureTests/StoragePathList/StoragePathListReducerTests.swift` case for case, substituting names. The seven cases:

```swift
@testable import CustomFieldsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing

@MainActor
@Suite
struct CustomFieldListReducerTests {

    @Test
    func test_destination_presented_customFieldForm_delegate_customFieldSaved_insert() async throws {
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            destination: .customFieldForm(CustomFieldFormReducer.State(server: .testValue())),
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.destination(.presented(.customFieldForm(.delegate(.customFieldSaved(.testValue(
            id: 2,
            name: "New name"
        ))))))) {
            $0.destination = nil
            $0.customFields = [
                .testValue(customField: .testValue(id: 2, name: "New name")),
                .testValue()
            ]
        }
    }

    @Test
    func test_destination_presented_customFieldForm_delegate_customFieldSaved_update() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init()

        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            destination: .customFieldForm(CustomFieldFormReducer.State(customField: .testValue(), server: .testValue())),
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.destination(.presented(.customFieldForm(.delegate(.customFieldSaved(.testValue(name: "New name"))))))) {
            $0.destination = nil
            $0.customFields = [.testValue(customField: .testValue(name: "New name"))]
        }
    }

    @Test
    func test_customFields_element_delegate_deleteCustomField_error() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init(uniqueElements: [CustomField.testValue()])

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        } withDependencies: {
            $0.deleteCustomField.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.customFields(.element(id: 1, action: .delegate(.deleteCustomField))))
        await store.receive(\.isUpdating) {
            $0.customFields[id: 1]?.isUpdating = true
        }
        await store.receive(\.error)
        await store.receive(\.isUpdating) {
            $0.customFields[id: 1]?.isUpdating = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_customFields_element_delegate_deleteCustomField_success() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init()

        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        } withDependencies: {
            $0.deleteCustomField.execute = { _, _ in }
        }

        await store.send(.customFields(.element(id: 1, action: .delegate(.deleteCustomField))))
        await store.receive(\.isUpdating) {
            $0.customFields[id: 1]?.isUpdating = true
        }
        await store.receive(\.customFieldDeleted) {
            $0.customFields = []
        }
    }

    @Test
    func test_customFields_element_delegate_editCustomField() async throws {
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.customFields(.element(id: 1, action: .delegate(.editCustomField)))) {
            $0.destination = .customFieldForm(CustomFieldFormReducer.State(
                customField: .testValue(),
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_createButtonTapped() async throws {
        let store = TestStore(initialState: CustomFieldListReducer.State(
            customFields: [.testValue()],
            server: .testValue()
        )) {
            CustomFieldListReducer()
        }

        await store.send(.view(.createCustomFieldButtonTapped)) {
            $0.destination = .customFieldForm(CustomFieldFormReducer.State(
                server: .testValue()
            ))
        }
    }

    @Test
    func test_view_onAppear_success() async throws {
        @Shared(.customFields(.testValue()))
        var cachedCustomFields = .init()

        let getCustomFieldsResult = [CustomField.testValue()]
        let store = TestStore(initialState: CustomFieldListReducer.State(server: .testValue())) {
            CustomFieldListReducer()
        } withDependencies: {
            $0.getCustomFields.execute = { _ in getCustomFieldsResult }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getCustomFieldsResult, getCustomFieldsResult) {
            $0.customFields = IdentifiedArray(
                uniqueElements: getCustomFieldsResult.map {
                    CustomFieldRowReducer.State(
                        customField: $0,
                        server: .testValue()
                    )
                }
            )
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }
    }
}
```

`CustomFieldRowReducer.State.testValue(customField:)` used above landed in Task 7, Step 5b.

- [ ] **Step 2: Run the test to verify it fails**

Run: `tuist test CustomFieldsFeature -d "iPhone 17 Pro"`
Expected: FAIL — `cannot find 'CustomFieldListReducer' in scope`.

- [ ] **Step 3: Write `CustomFieldListReducer.swift`**

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct CustomFieldListReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case customFieldDeleted(CustomField.Id)
        case customFields(IdentifiedActionOf<CustomFieldRowReducer>)
        case destination(PresentationAction<Destination.Action>)
        case error(Error)
        case getCustomFieldsResult([CustomField])
        case isUpdating(id: CustomField.Id, isUpdating: Bool)
        case view(View)

        public enum View {
            case createCustomFieldButtonTapped
            case onAppear
            case onRefresh
        }
    }

    @Reducer
    public enum Destination {
        case customFieldForm(CustomFieldFormReducer)
    }

    @ObservableState
    public struct State: Equatable {

        var customFields: IdentifiedArrayOf<CustomFieldRowReducer.State>

        @Presents
        var destination: Destination.State?

        var isLoaded: Bool

        let server: Server

        public init(
            customFields: IdentifiedArrayOf<CustomFieldRowReducer.State> = [],
            destination: Destination.State? = nil,
            isLoaded: Bool = false,
            server: Server
        ) {
            self.customFields = customFields
            self.destination = destination
            self.isLoaded = isLoaded
            self.server = server
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case let .customFieldDeleted(id):
                state.customFields.remove(id: id)
                return .none
            case let .customFields(.element(id: id, action: .delegate(delegateAction))):
                switch delegateAction {
                case .deleteCustomField:
                    return .runDeleteCustomField(
                        id: id,
                        server: state.server
                    )
                case .editCustomField:
                    state.destination = .customFieldForm(CustomFieldFormReducer.State(
                        customField: state.customFields[id: id]?.customField,
                        server: state.server
                    ))
                    return .none
                }
            case let .destination(.presented(.customFieldForm(.delegate(.customFieldSaved(customField))))):
                state.destination = nil
                state.customFields.updateOrAppend(CustomFieldRowReducer.State(customField: customField, server: state.server))
                return .none
            case let .error(error):
                return .toast(error)
            case let .getCustomFieldsResult(customFields):
                state.customFields = IdentifiedArray(
                    uniqueElements: customFields.map {
                        CustomFieldRowReducer.State(
                            customField: $0,
                            server: state.server
                        )
                    }
                )
                return .none
            case let .isUpdating(id: id, isUpdating: isUpdating):
                state.customFields[id: id]?.isUpdating = isUpdating
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .createCustomFieldButtonTapped:
                    state.destination = .customFieldForm(CustomFieldFormReducer.State(
                        server: state.server
                    ))
                    return .none
                case .onAppear, .onRefresh:
                    return .runGetCustomFields(server: state.server)
                }
            case .binding, .customFields, .destination:
                return .none
            }
        }
        .forEach(\.customFields, action: \.customFields) { CustomFieldRowReducer() }
        .ifLet(\.$destination, action: \.destination)

        Reduce { state, _ in
            state.customFields.sort {
                $0.customField.name.compare(
                    $1.customField.name,
                    options: [
                        .caseInsensitive,
                        .numeric,
                        .forcedOrdering
                    ]
                ) == .orderedAscending
            }
            return .none
        }
    }

    public init() {}
}

extension CustomFieldListReducer.Destination.State: Equatable {}
```

- [ ] **Step 4: Write `CustomFieldListReducer+Effect.swift`**

```swift
import ApiInterface
import ComposableArchitecture

extension Effect where Action == CustomFieldListReducer.Action {

    static func runDeleteCustomField(
        id: CustomField.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteCustomField.execute)
        var deleteCustomField

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteCustomField(id, server)
            await send(.customFieldDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteCustomField)
    }

    static func runGetCustomFields(server: Server) -> Self {
        @Dependency(\.getCustomFields.execute)
        var getCustomFields

        return .run { send in
            try await send(.getCustomFieldsResult(getCustomFields(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getCustomFields)
    }
}

private enum CancelID {
    case deleteCustomField
    case getCustomFields
}
```

- [ ] **Step 5: Write `CustomFieldListReducer+TestValue.swift`**

Copy `Modules/StoragePathsFeature/StoragePathList/StoragePathListReducer+TestValue.swift`, substituting names, so `.testValue(customFields:)` maps a `[CustomField]` into row states.

- [ ] **Step 6: Write `CustomFieldListView.swift`**

```swift
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: CustomFieldListReducer.self)
public struct CustomFieldListView: View {

    public var body: some View {
        List {
            ForEach(Array(store.scope(state: \.customFields, action: \.customFields))) { store in
                CustomFieldRowView(store: store)
            }
        }
        .overlay(emptyListView())
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.customFields)
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .sheet(
            item: $store.scope(state: \.destination?.customFieldForm, action: \.destination.customFieldForm)
        ) { store in
            CustomFieldFormView(store: store)
                .presentationDetents([.large])
        }
        .task { await send(.onAppear).finish() }
        .toolbar {
            Button(action: {
                send(.createCustomFieldButtonTapped)
            }) {
                Label(.createCustomField, systemImage: "plus")
            }
        }
    }

    public init(store: StoreOf<CustomFieldListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<CustomFieldListReducer>

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.customFields.isEmpty && store.isLoaded {
            ContentUnavailableView {
                EmptyListView(
                    systemImage: "list.bullet.rectangle",
                    title: .noCustomFieldsFound
                ) {
                    Button {
                        send(.createCustomFieldButtonTapped)
                    } label: {
                        Label(.createCustomField, systemImage: "plus.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary())
                }
            }
        }
    }
}

#Preview {
    CustomFieldListView(
        store: Store(
            initialState: .testValue(customFields: .previewValue),
            reducer: {
                CustomFieldListReducer()
            }
        )
    )
}
```

- [ ] **Step 7: Write the snapshot tests**

`Modules/CustomFieldsFeatureTests/CustomFieldList/CustomFieldListViewTests.swift` — copy `StoragePathListViewTests.swift` verbatim, substituting names and `$0.getCustomFields.execute = { _ in [] }`. Keep all three snapshots (populated, empty, dark mode) and keep the comment explaining why the dark-mode one exists.

`Modules/CustomFieldsFeatureTests/CustomFieldForm/CustomFieldFormViewTests.swift` — same shape, with four snapshots covering the branches that actually differ: create (`customField: nil`), edit of a `.string` field (locked type), a `.select` field with two options, and a `.monetary` field.

- [ ] **Step 8: Record the snapshots, then run the tests**

```bash
mise run snapshots
tuist test CustomFieldsFeature -d "iPhone 17 Pro"
```

Read `mise/tasks/snapshots` first to confirm how it records; if it takes arguments, pass the `CustomFieldsFeature` scheme. Inspect each recorded PNG under `Snapshots/` before committing — a snapshot test only pins whatever it recorded, including a broken layout.

Expected: PASS.

- [ ] **Step 9: Format and commit**

```bash
mise run format
git add Modules/CustomFieldsFeature Modules/CustomFieldsFeatureTests Snapshots
git commit -m "feat: add custom field list"
```

---

## Task 10: Settings wiring

**Files:**
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift`
- Modify: `Modules/SettingsFeature/SettingList/SettingListView.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`

**Interfaces:**
- Consumes: `CustomFieldListReducer`, `CustomFieldListView` from Task 9.
- Produces: `SettingListReducer.Path.customFieldList(CustomFieldListReducer)`.

- [ ] **Step 1: Add the dependency**

In `Module+Dependencies.swift`, add `.target(.customFieldsFeature)` alphabetically to both the `.settingsFeature` and `.settingsApp` dependency lists (after `.correspondentsFeature`, before `.documentTypesFeature` in each).

Then: `tuist generate --no-open`

- [ ] **Step 2: Add the path case to the reducer**

In `SettingListReducer.swift`, add `import CustomFieldsFeature` alphabetically to the import block, then add to `enum Path`:

```swift
        case customFieldList(CustomFieldListReducer)
```

placed alphabetically after `correspondentList`.

- [ ] **Step 3: Add the navigation link and destination to the view**

In `SettingListView.swift`, add `import CustomFieldsFeature` alphabetically, then insert this between the Correspondents and Document types links in the second `Section`:

```swift
                    NavigationLink(
                        state: SettingListReducer.Path.State.customFieldList(CustomFieldListReducer.State(server: store.server))
                    ) {
                        Label(.customFields, systemImage: "list.bullet.rectangle")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
```

And in the `destination:` switch, after the `correspondentList` case:

```swift
            case let .customFieldList(store):
                CustomFieldListView(store: store)
```

- [ ] **Step 4: Build and run the settings tests**

Run: `tuist test SettingsFeature -d "iPhone 17 Pro"`
Expected: PASS. If `SettingListViewTests` has a snapshot of the settings list, it will fail on the new row — re-record it with `mise run snapshots`, inspect the diff to confirm only the new row appears, and commit the updated PNG.

- [ ] **Step 5: Format and commit**

```bash
mise run format
git add Modules/SettingsFeature Tuist Snapshots
git commit -m "feat: manage custom fields from settings"
```

---

## Task 11: The standalone app and its UI tests

**Files:**
- Create: `Modules/CustomFieldsApp/CustomFieldsApp.swift`
- Create: `Modules/CustomFieldsAppTests/CustomFieldsAppTests.swift`

The Tuist registration for both targets already landed in Task 7.

**Interfaces:**
- Consumes: `CustomFieldListReducer`, `CustomFieldListView`, `\.customFieldsRepository`, `UITestSupport`'s `tapSwipeAction(_:in:timeout:)`.

- [ ] **Step 1: Write `CustomFieldsApp.swift`**

```swift
import ApiImplementation
import ApiInterface
import ComposableArchitecture
import CustomFieldsFeature
import Dependencies
import SwiftUI

@main
struct CustomFieldsApp: App {
    var body: some Scene {
        WindowGroup {
            if isInitialised {
                NavigationStack {
                    CustomFieldListView(
                        store: Self.store
                    )
                }
            } else {
                ProgressView()
                    .task {
                        do {
                            try await updateCache(.testValue())
                            isInitialised = true
                        } catch {
                            debugPrint(error)
                        }
                    }
            }
        }
    }

    init() {
        prepareDependencies {
            $0.authenticationProvider = .integrationTest
            $0.defaultAppStorage = .inMemory
            $0.defaultFileStorage = .inMemory
        }
    }

    private static let store = Store(
        initialState: CustomFieldListReducer.State(
            server: .testValue()
        ),
        reducer: {
            CustomFieldListReducer()
        }
    )

    @Dependency(\.updateCache.execute)
    private var updateCache

    @State
    private var isInitialised = false
}
```

- [ ] **Step 2: Write `CustomFieldsAppTests.swift`**

```swift
@testable import ApiImplementation

import ApiInterface
import CustomFieldsFeature
import Dependencies
import UITestSupport
import XCTest

@MainActor
final class CustomFieldsAppTests: XCTestCase {

    func testCreate() async throws {
        try await withTestDependencies {
            try await deleteAllCustomFields()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add custom field"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("New Custom Field")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["New Custom Field"].waitForExistence(timeout: timeout))
    }

    func testCreateSelect() async throws {
        try await withTestDependencies {
            try await deleteAllCustomFields()
        }

        let app = XCUIApplication()
        app.launch()

        app.buttons["Add custom field"].firstMatch.tap()
        app.textFields["Name"].tap()
        app.typeText("Status")

        app.buttons["Data type"].firstMatch.tap()
        app.buttons["Select"].firstMatch.tap()

        app.buttons["Add option"].firstMatch.tap()
        app.textFields["Options"].firstMatch.tap()
        app.typeText("Open")

        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Status"].waitForExistence(timeout: timeout))

        app.tapSwipeAction("Edit custom field", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.textFields["Options"].firstMatch.waitForExistence(timeout: timeout))
        XCTAssertEqual(app.textFields["Options"].firstMatch.value as? String, "Open")
    }

    func testDelete() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Delete custom field", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Custom Field\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        app.cells.firstMatch.waitForNonExistence(timeout: timeout)
    }

    func testDeleteFailure() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))

        try await withTestDependencies {
            try await deleteAllCustomFields()
        }

        app.tapSwipeAction("Delete custom field", in: app.cells.firstMatch, timeout: timeout)
        XCTAssertTrue(app.staticTexts["Do you really want to delete \"Test Custom Field\"?"].waitForExistence(timeout: timeout))
        app.buttons["Confirm"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No CustomField matches the given query."].waitForExistence(timeout: timeout))
    }

    func testList() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.cells.firstMatch.waitForExistence(timeout: timeout))
        XCTAssertTrue(app.staticTexts["Test Custom Field"].exists)
        XCTAssertTrue(app.staticTexts["Text · 0 documents"].exists)
    }

    func testUpdate() async throws {
        let app = XCUIApplication()
        app.launch()

        app.tapSwipeAction("Edit custom field", in: app.cells.firstMatch, timeout: timeout)
        app.textFields["Name"].tap()
        app.typeText(" Updated")
        app.buttons["Save"].tap()
        app.buttons["Save"].waitForNonExistence(timeout: timeout)
        XCTAssertTrue(app.staticTexts["Test Custom Field Updated"].waitForExistence(timeout: timeout))
    }

    override func setUp() async throws {
        try await super.setUp()

        try await withTestDependencies {
            try await deleteAllCustomFields()
            try await createTestCustomField()
        }

        continueAfterFailure = false
    }

    private func createTestCustomField() async throws {
        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        _ = try await customFieldsRepository.createCustomField(
            input: .init(
                dataType: .string,
                name: "Test Custom Field"
            ),
            server: server
        )
    }

    private func deleteAllCustomFields() async throws {
        @Dependency(\.customFieldsRepository)
        var customFieldsRepository

        let customFields = try await customFieldsRepository.getCustomFields(
            input: .testValue(),
            server: server
        ).results.map(\.id)
        for customField in customFields {
            try await customFieldsRepository.deleteCustomField(
                id: customField,
                server: server
            )
        }
    }

    @discardableResult
    public func withTestDependencies<R>(
        isolation: isolated (any Actor)? = #isolation,
        operation: () async throws -> R
    ) async rethrows -> R {
        try await withDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        } operation: {
            try await operation()
        }
    }

    private let server = Server.testValue()
    private let timeout = 5.0
}
```

Two assertions in here are guesses that must be checked against the running app rather than assumed:

- `testDeleteFailure` expects the server's 404 body to read `No CustomField matches the given query.` — `StoragePathsAppTests` relies on the equivalent string for storage paths. Run the test, read the toast the app actually shows, and correct the literal.
- `testCreateSelect` drives the data-type `Picker` by tapping `app.buttons["Data type"]` then `app.buttons["Select"]`. A SwiftUI `.menu` picker's accessibility identifiers vary; if the tap does not land, run `snapshot_ui` against the simulator to read the real element tree and fix the queries.

- [ ] **Step 3: Run the UI tests**

```bash
mise run docker:start
tuist test CustomFieldsApp -d "iPhone 17 Pro"
```

Expected: all six tests PASS. Fix the two literals flagged above from the real output rather than by guessing again.

- [ ] **Step 4: Format and commit**

```bash
mise run format
git add Modules/CustomFieldsApp Modules/CustomFieldsAppTests
git commit -m "feat: add CustomFieldsApp and UI tests"
```

---

## Task 12: Full verification

No new code. This task exists because every prior task ran one scheme in isolation, and the `Module` enum changes touch the whole project.

- [ ] **Step 1: Lint the whole project**

Run: `mise run ci:lint`
Expected: clean. `tuist inspect dependencies --only implicit` must report nothing — an implicit dependency means a `Module+Dependencies.swift` entry is missing.

- [ ] **Step 2: Run the full unit test suite**

Run: `mise run ci:test`
Expected: PASS. This skips the `*AppTests` UI targets by default.

- [ ] **Step 3: Run the UI tests**

```bash
mise run docker:start
CI_UI_TESTS=true mise run ci:test
```

Expected: PASS, including `CustomFieldsAppTests`.

- [ ] **Step 4: Check the feature by hand in the main app**

Run the `Less Paper` scheme, open Settings, and confirm: the Custom fields row appears between Correspondents and Document types; the list loads; creating a `select` field with two options works and the options survive a reopen; editing shows the data type as read-only; deleting prompts with `ConfirmationPopupView` and removes the row.

- [ ] **Step 5: Commit anything the verification changed**

```bash
mise run format
git status
git add -A
git commit -m "chore: verify custom fields feature"
```

---

## Self-Review Notes

Checked against the spec:

- **Model, data type, extra data, select option** — Task 1. `document_count` defaulting and the `.unknown` fallback both have dedicated tests.
- **Inputs, outputs, four use-case contracts** — Task 2, including the `dataType`-omitted-when-unknown behaviour.
- **Repository against `/api/custom_fields/`** — Task 3, with integration tests covering select option ids and monetary currency round-tripping.
- **Use-case implementations, pagination, shared write** — Task 4.
- **Cache: shared key, `ApiCache.customField`, `CustomField.Id.get`, `UpdateCacheUseCase`** — Tasks 4 and 5.
- **`ApiTestSupport`** — `deleteAll()` in Task 3, `DeleteAllCustomFieldsUseCase` in Task 4.
- **Localization, eleven data-type names** — Task 6, with the `description` placeholder from Task 1 explicitly replaced.
- **Feature module: Row, Form, List** — Tasks 7, 8, 9. No `PermissionsFeature` dependency, no section picker.
- **Type locked on edit** — `isDataTypeLocked` in Task 8, asserted in both the reducer tests and a snapshot.
- **Options editor: add, rename, delete, no reorder** — Task 8.
- **Settings wiring** — Task 10.
- **App target, UI tests, Tuist registration** — Tasks 7 and 11.

Two places where the plan deliberately tells the implementer to verify rather than trust it: the `ApiError.testValue(fieldErrors:)` signature in Task 8 Step 1, and the two XCUITest literals in Task 11 Step 2. Both are facts about existing code or a running server that are cheaper to read than to guess.
