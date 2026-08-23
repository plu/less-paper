# Manage custom fields

## Context

Paperless lets a user define **custom fields** — named, typed slots that documents can carry values
in. The app has no notion of them: no model, no repository, no use case, no UI. The web UI manages
them under Settings; here they belong next to Correspondents, Document types, Storage paths and
Tags, which are the four things Settings already manages.

This change is the full vertical slice for the *field definitions* — list, create, update, delete —
built as a new `CustomFieldsFeature` module with its own standalone app and UI test targets, in the
shape `StoragePaths` already has.

**Out of scope, deliberately:** custom-field *values* on documents (reading, editing, showing them
in the document form or viewer) and filtering documents by custom field. This spec delivers the
manager only. The cache work in [The cache](#the-cache) is the one place where that future feature
is anticipated ahead of need, at the user's explicit request.

### What the endpoint returns

Verified against the local instance (paperless-ngx 3.0.5, `docker/`) by creating one field of each
interesting shape, reading the list, and deleting them again.

`OPTIONS /api/custom_fields/` gives the writable surface — `name`, `data_type`, `extra_data` — with
`id` and `document_count` read-only. **There is no `owner`, no `permissions`, no `user_can_change`,
no `slug`, no `match`/`matching_algorithm`.** Custom fields are a flatter model than every other
entity Settings manages, and the form is correspondingly simpler.

`data_type` has ten choices:

```
string  longtext  url  date  boolean  integer  float  monetary  documentlink  select
```

`GET /api/custom_fields/` — note `extra_data` is `null` for types that don't use it, and that the
server assigns an opaque string `id` to each select option:

```json
{
  "count": 3,
  "results": [
    { "id": 2, "name": "ZZTmpMoney",  "data_type": "monetary",
      "extra_data": { "default_currency": "EUR" }, "document_count": 0 },
    { "id": 1, "name": "ZZTmpSelect", "data_type": "select",
      "extra_data": { "select_options": [
          { "label": "Open",   "id": "aqgT3m4XZw8aw3Ou" },
          { "label": "Closed", "id": "MOddUdj2nhfCEsqp" } ] },
      "document_count": 0 },
    { "id": 3, "name": "ZZTmpString", "data_type": "string",
      "extra_data": null, "document_count": 0 }
  ]
}
```

Two behaviours worth recording because they contradict what you'd assume:

- **The POST response omits `document_count`.** It is present on list and on PATCH, absent on
  create. `SaveCustomFieldOutput` must therefore default it rather than require it.
- **The server accepts a `data_type` change via PATCH.** `PATCH {"data_type":"integer"}` on a
  `string` field returned 200. The paperless web UI locks the control; the API does not enforce it.
  We lock it anyway — see below.

### Why the edit form locks `data_type`

Changing the type of a field that already holds values on documents reinterprets or discards them
server-side, and the app cannot undo that. Since the server won't refuse, the app has to. The edit
form renders the type as read-only text; only create offers the picker. A user who genuinely wants
to change a type can delete the field and make a new one, which makes the data loss explicit.

## Architecture

`StoragePaths` is the template end to end, minus the permissions layer.

```
CustomFieldListReducer ── getCustomFields ─┐
    ├── forEach ── CustomFieldRowReducer   ├── CustomFieldsRepository ── /api/custom_fields/
    │                  └── deleteCustomField                            │
    └── destination ── CustomFieldFormReducer ── saveCustomField ───────┘
                                                        │
                                            @Shared(.customFields(server))
                                                        │
                                                   ApiCache.customField
```

## The API layer

### `Modules/ApiInterface/CustomFields/`

`CustomField.swift` — `Codable, Equatable, Hashable, Identifiable, Sendable`, with
`typealias Id = Tagged<CustomField, Int>`:

| Property | Type | Decoding |
| --- | --- | --- |
| `dataType` | `CustomFieldDataType` | required |
| `documentCount` | `Int` | `decodeIfPresent ?? 0` |
| `extraData` | `CustomFieldExtraData?` | `decodeIfPresent` |
| `id` | `Id` | required |
| `name` | `String` | required |

Explicit `CodingKeys` and hand-written `init(from:)` / `encode(to:)`, as `StoragePath` has.
Conforms to `Comparable` (by `name`) and `CustomStringConvertible` (returns `name`). Carries
`testValue(…)` with per-property defaults and an `Array<CustomField>.previewValue` of five fields
spanning several data types.

`CustomFieldDataType.swift` — `String`-raw enum, `Codable, CaseIterable, Hashable, Sendable`:

```
boolean, date, documentLink = "documentlink", float, integer,
longText = "longtext", monetary, select, string, url, unknown
```

`init(from:)` decodes the raw string and falls back to `.unknown` for anything unrecognised, so a
data type added by a future paperless release cannot break the list.

The original raw string is *not* preserved on `.unknown` — a `String`-raw enum cannot carry it, and
nothing needs it. A field of unknown type is only ever listed, renamed or deleted: its type control
is read-only in edit, and it is absent from the create picker, so the app never writes `data_type`
back for one. Update sends `data_type` at its existing value, which for an unknown type means
omitting the key from the PATCH body rather than sending `"unknown"`.

**`allCases` is hand-written to exclude `.unknown`**, listing only the ten real types. This is not
cosmetic: `Components.MenuField` requires `CaseIterable & CustomStringConvertible & Hashable &
Identifiable` and iterates `SelectionValue.allCases` itself, so a separate `creatableCases` static
could not drive it and the form would need a bespoke picker. Excluding `.unknown` from `allCases`
lets the create form reuse `MenuField` as every other menu in the app does. It needs a `//` comment
saying so, since a hand-written `allCases` that omits a case looks like an oversight otherwise.

`Identifiable` is satisfied with `var id: String { rawValue }`.

`CustomStringConvertible` returns the localized display name — Text, Long text, URL, Date, Boolean,
Integer, Number, Monetary, Document link, Select — and for `.unknown`, a localized
`customFieldDataTypeUnknown` placeholder.

`CustomFieldExtraData.swift` — `defaultCurrency: String?` and `selectOptions:
[CustomFieldSelectOption]?`, both optional, encoding only what is set so a string field sends
`extra_data: null`.

`CustomFieldSelectOption.swift` — `id: String?` (server-assigned, absent when creating) and
`label: String`.

Inputs, outputs and use cases mirror `StoragePaths/` one-for-one:

- `GetCustomFieldsInput` (just `url: URL?`, for pagination) / `GetCustomFieldsOutput`
- `SaveCustomFieldInput` (`name`, `dataType: CustomFieldDataType?`, `extraData`) /
  `SaveCustomFieldOutput`
- `DeleteCustomFieldOutput`
- `GetCustomFieldsUseCase`, `SaveCustomFieldUseCase`, `DeleteCustomFieldUseCase`,
  `DeleteAllCustomFieldsUseCase`

`SaveCustomFieldInput` gains an `init(customField: CustomField?)` convenience, as
`SaveStoragePathInput` has. `dataType` is optional and encoded with `encodeIfPresent`: create
always sends it, update sends it at its existing value (the server accepts the no-op) and omits it
entirely when the existing value is `.unknown`.

### `Modules/ApiImplementation/CustomFields/`

`CustomFieldsRepository.swift` — `@DependencyClient` with `createCustomField`, `deleteCustomField`,
`getCustomFields`, `updateCustomField`, `liveValue` hitting `/api/custom_fields/` and
`/api/custom_fields/{id}/` via `APIClient.client(server:)`, plus `previewValue` and `testValue`.

`GetCustomFieldsUseCase.swift` follows the `next`-link pagination loop and writes the full result
into `@Shared(.customFields(server))`. `SaveCustomFieldUseCase.swift` and
`DeleteCustomFieldUseCase.swift` complete the set.

### `Modules/ApiTestSupport/`

`CustomFields/DeleteAllCustomFieldsUseCase.swift` and
`Extensions/CustomFieldsRepository+Extensions.swift` (`deleteAll()`), both copied from their
`StoragePaths` counterparts. These exist for UI-test setup.

### The cache

Custom fields join the cache **now**, ahead of a consumer, so that the future
custom-field-values-on-documents work has ids resolving to names on day one:

- `SharedReaderKey+Extensions.swift` gains `customFields(_ server: Server)`, a
  `FileStorageKey<IdentifiedArrayOf<CustomField>>.Default` writing
  `"\(server.id)-custom-fields.json"`.
- `ApiCache` gains `customField: @Sendable (CustomField.Id?, Server) -> CustomField?`, its
  `liveValue` / `previewValue` entries, the backing `LockIsolated` dictionary and the static
  lookup, all shaped exactly like `storagePath`.
- `CustomField.Id` gains `func get(_ server: Server) -> CustomField?`.
- `UpdateCacheUseCase.execute` gains `getCustomFields` in its `async let` fan-out.

## The feature module

`Modules/CustomFieldsFeature/` in three folders, each with `Reducer`, `Reducer+Effect`,
`Reducer+TestValue` and `View`:

**`CustomFieldList/`** — mirrors `StoragePathList` exactly: `onAppear`/`onRefresh` fetch, add
button in the toolbar, form presented as a `.sheet` at `.large`, row delegates for edit and delete,
`isUpdating` per row, an `EmptyListView` under `ContentUnavailableView` when loaded and empty, and
the trailing `Reduce` that keeps the list sorted by name with
`[.caseInsensitive, .numeric, .forcedOrdering]`.

**`CustomFieldRow/`** — name over a caption combining data type and document count
(`Select · 4 documents`), with the same `accessibilityValue` join, opacity-on-updating, and edit /
delete swipe actions. Delete routes through the shared `DeleteConfirmationPresenter` with
`.deleteCustomField` and the field's name — never a system dialog.

**`CustomFieldForm/`** — the one place this feature diverges from `StoragePathForm`. There is **no
`PermissionsFeature` dependency, no section picker and no `FormSection` enum**, because custom
fields have nothing to put in a permissions tab. One flat form:

```
Create                              Edit "Status"
  Name       [ Status          ]      Name       [ Status          ]
  Data type  [ Select        ▾ ]      Data type    Select              ← read-only
  Options                             Options
    [ Open                ] [x]         [ Open                ] [x]
    [ Closed              ] [x]         [ Closed              ] [x]
    [ + Add option ]                    [ + Add option ]
```

- Name is always shown and focused on open.
- Data type is a `MenuField` over `creatableCases` when creating, read-only text when editing.
- The default-currency field appears only for `.monetary`.
- The options editor appears only for `.select`: add, inline rename, delete. **No reordering** —
  array order is preserved as received and as entered.

`CustomFieldFormInput` holds `name: FieldState<String>`, `dataType`, `defaultCurrency:
FieldState<String>` and `selectOptions: IdentifiedArrayOf<CustomFieldSelectOptionInput>`. That last
type carries a client-side `UUID` as its `Identifiable` id alongside the server's `id: String?`, so
an option the user has just added but not yet saved still has a stable identity for `ForEach`.
`apiValue` assembles `SaveCustomFieldInput`, emitting `extraData` only for `.monetary` and
`.select`. `applyFieldErrors(from:)` and `CustomFieldFormField` follow the existing pattern for
server-side field errors.

## Settings wiring

`SettingListReducer.Path` gains `case customFieldList(CustomFieldListReducer)`. `SettingListView`
gains a matching `NavigationLink` and destination case, placed alphabetically between Correspondents
and Document types, labelled `.customFields` with system image `list.bullet.rectangle` and the
standard `.listRowBackground(Color.m3SurfaceContainer)`.

## Targets

Four new modules, each needing entries in `Module.swift` (the enum case, `codeCoverageTarget` and
`product`), `Module+Dependencies.swift` and `Module+Schemes.swift`:

| Module | Product | Coverage |
| --- | --- | --- |
| `CustomFieldsFeature` | framework | yes |
| `CustomFieldsFeatureTests` | unitTests | no |
| `CustomFieldsApp` | app | no |
| `CustomFieldsAppTests` | uiTests | no |

`CustomFieldsApp` additionally needs `.customFieldsApp` in `Module+InfoPlists.swift` and its
`testableTarget` entry in `Module+Schemes.swift`. `.target(.customFieldsFeature)` is added to the
dependency lists of `settingsFeature` and `settingsApp`.

`Modules/CustomFieldsApp/CustomFieldsApp.swift` copies `StoragePathsApp` verbatim in structure:
`authenticationProvider = .integrationTest`, in-memory app and file storage, a `ProgressView` until
`updateCache(.testValue())` resolves, then `CustomFieldListView` in a `NavigationStack`.

## Testing

**`Modules/ApiImplementationTests/CustomFields/`** — repository and use-case integration tests
against the docker instance, following `StoragePathsRepositoryTests` and
`SaveStoragePathUseCaseTests`. Covers create for a plain type, create for `select` (asserting the
server assigns option ids), create for `monetary`, update, and delete.

**`Modules/CustomFieldsFeatureTests/`** — TCA reducer tests and snapshot view tests for all three
screens, matching the `StoragePathsFeatureTests` layout. The form tests specifically cover the
type-locked-on-edit branch and the add/rename/delete option transitions.

**`Modules/CustomFieldsAppTests/CustomFieldsAppTests.swift`** — XCUITest mirroring
`StoragePathsAppTests`, with `setUp` deleting all fields and seeding one known field:

| Test | Asserts |
| --- | --- |
| `testList` | seeded field's name and its `Text · 0 documents` caption are visible |
| `testCreate` | add a `string` field, it appears in the list |
| `testCreateSelect` | add a `select` field with two options, reopen it, both options persisted |
| `testUpdate` | rename, updated name appears, type control is read-only |
| `testDelete` | swipe, confirm via `ConfirmationPopupView`, row disappears |
| `testDeleteFailure` | delete out from under the app, confirm, server error surfaces as a toast |

## Localization

New `en` / `de` keys in `Shared/Framework/Resources/Localizable.xcstrings`:

`addOption`, `createCustomField`, `customField`, `customFields`, `dataType`, `defaultCurrency`,
`deleteCustomField`, `deleteOption`, `editCustomField`, `noCustomFieldsFound`, `selectOptions`

plus eleven data-type display names: `customFieldDataTypeBoolean`, `…Date`, `…DocumentLink`,
`…Float`, `…Integer`, `…LongText`, `…Monetary`, `…Select`, `…String`, `…Unknown`, `…Url`.
