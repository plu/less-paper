# Editing custom fields on documents

## Context

The app knows custom fields two ways. `CustomFieldsFeature` manages the **definitions** — name, data
type, select options — and `2026-08-23-custom-field-filter-design.md` plus
`2026-08-24-custom-field-document-link-design.md` added filtering by their **values**.

Nothing reads or writes a value on a document. `Document` has no `customFields` property,
`UpdateDocumentInput` has no such key, and the document form has no such field. A user can filter
for `Status is Open` and cannot set `Status` to `Open`.

This spec closes that: the document edit sheet gains a **Custom fields** section that attaches,
edits and detaches values on one document.

Out of scope, deliberately: showing values on document rows, on the detail screen or in the metadata
tab, and the bulk `modify_custom_fields` operation. Each is a feature of its own once the model
exists.

## What the API does

Verified against the dev instance in `docker/` (paperless-ngx, port 8000, API 10) by creating one
field of every data type, PATCHing values onto document 1, and reading them back. The instance was
restored afterwards — the fields created for the probe were deleted and document 1's list emptied.

### The value shapes

Every one of these round-tripped through `PATCH /api/documents/1/` unchanged:

```json
{"custom_fields": [
  {"field": 21, "value": "1234.50"},
  {"field": 22, "value": "2026-08-24"},
  {"field": 23, "value": 7},
  {"field": 24, "value": 1.5},
  {"field": 25, "value": "https://example.com"},
  {"field": 26, "value": "line one\nline two"},
  {"field":  5, "value": true},
  {"field":  6, "value": "G1btwlUUPsE9K3ta"},
  {"field": 18, "value": [2, 3]},
  {"field": 17, "value": null}
]}
```

| `data_type`                    | JSON value                          |
| ------------------------------ | ----------------------------------- |
| `string`, `url`, `longtext`    | `"…"`                               |
| `date`                         | `"2026-08-24"` — `YYYY-MM-DD` only  |
| `boolean`                      | `true` / `false`                    |
| `integer`, `float`             | `7` / `1.5`                         |
| `monetary`                     | `"EUR1234.50"`                      |
| `select`                       | `"G1btwlUUPsE9K3ta"` — the option id |
| `documentlink`                 | `[2, 3]`                            |
| attached, no value             | `null`                              |

`select` is always the option's string id. The integer-index form predates API 6 and
`ApiVersion.minimumSupported` is 8, so no legacy branch is needed.

### The list is replaced wholesale

`PATCH` with a one-element `custom_fields` array left document 1 holding exactly that one field —
the other nine were detached, not merged:

```
PATCH {"custom_fields":[{"field":21,"value":"USD99.90"}]}
GET   -> [{"value": "USD99.90", "field": 21}]
```

So attach, edit and detach are all the same request: send the list the document should end up with.
No separate endpoint, no diffing.

### Server-side validation, and where it bites

```
{"field":22,"value":"24.08.2026"}  -> 400  Date has wrong format. Use one of these formats instead: YYYY-MM-DD.
{"field":6, "value":"nope"}        -> 400  Value must be an id of an element in [...]
{"field":23,"value":"7"}           -> 200  coerced to 7
{"field":21,"value":"abc"}         -> 400  Must be a two-decimal number with optional currency code e.g. GBP123.45
```

Monetary is the awkward one. The rule is **asymmetric**, reproduced twice:

```
"1234"        -> 200        "EUR1234"      -> 400
"1234.5"      -> 200        "EUR1234.5"    -> 200
"-5.00"       -> 200        "EUR-5.00"     -> 200
""            -> 200        "EUR1234.505"  -> 400
                            "EUR.50"       -> 400
                            "eur1234.50"   -> 400  (lowercase)
                            "EURO1234.50"  -> 400  (four letters)
                            "1,234.50"     -> 400  (group separator)
```

A bare integer is fine, but **the moment a currency code is present the decimal point is
mandatory**. This design always emits a code, so the amount must be normalised to two decimals
before it is sent. Getting this wrong produces a 400 on every save of an integral amount — the exact
case a user is most likely to type.

## Design

### A. API layer

New `Modules/ApiInterface/Documents/DocumentCustomField.swift`:

```swift
public struct DocumentCustomField: Codable, Equatable, Hashable, Sendable {
    public let field: CustomField.Id
    public let value: JSONValue
}
```

`JSONValue` already exists in `ApiInterface/Shared/` and already carries heterogeneous custom field
values for `CustomFieldQuery.Atom`. The value side needs nothing new.

`Document` gains `customFields: [DocumentCustomField]`, decoded from `custom_fields` with
`decodeIfPresent ?? []` and added to `CodingKeys`, `encode(to:)` and `testValue`. The
`decodeIfPresent` is not defensive padding about the server: `Document` values are persisted through
`ApiCache`, and every cached document written before this change lacks the key.

`UpdateDocumentInput` gains the same array, always sent. It is a plain `[DocumentCustomField]`, not
`@NullEncodable` — the array itself is never null, and its emptiness is meaningful.

`JSONEncoder.apiEncoder` carries a global `dateEncodingStrategy` of `.formatted(.createdDate)`.
Custom field dates never reach it: the form formats them into a `JSONValue.string`, so the encoder
sees a string. This feature stays uncoupled from any future document-level date decision.

### B. Form state

`DocumentFormSection` gains `.customFields`, between `.content` and `.notes` in the ⋯ menu.

`DocumentFormInput` gains one array — the document's own order, newly attached fields appended:

```swift
var customFields = IdentifiedArrayOf<DocumentFormCustomField>()

struct DocumentFormCustomField: Equatable, Identifiable, Sendable {
    let id: CustomField.Id
    var value: DocumentFormCustomFieldValue
}
```

It stores the field **id**, never the `CustomField`. The definition is read from
`@Shared(.customFields(server))` at render time, the way `CustomFieldQueryAtomEditorReducer` already
does, so renaming a field on the server cannot register as an unsaved edit on an open sheet.

`DocumentFormCustomFieldValue`, in `DocumentForm/CustomFields/`, is the typed editor state,
converted to and from `JSONValue` against the field definition:

```swift
enum DocumentFormCustomFieldValue: Equatable, Sendable {
    case boolean(Bool)
    case date(Date?)
    case documentLink([Document.Id])
    case monetary(currency: String, amount: String)
    case number(String)
    case select(String?)
    case text(String)
    case unsupported(JSONValue)
}
```

`number` and `monetary.amount` hold **text, not `Double`**. A half-typed `"1."` has to survive the
next keystroke, and re-formatting under the cursor is how numeric fields become unusable.

`unsupported` is the correctness case. A field whose `data_type` decodes as `.unknown` — a type a
future paperless-ngx adds — keeps its original JSON verbatim and renders read-only. Without it,
editing a title would silently blank every value this app does not recognise, because the save
replaces the whole list.

### C. Reducer

No child reducer. The section is fields bound to `$store.input`, so `BindingReducer` carries the
edits and `DocumentFormReducer` gains three view actions:

```swift
case addCustomFieldTapped(CustomField.Id)
case removeCustomFieldTapped(CustomField.Id)
case documentLinkTapped(CustomField.Id)
```

`Destination` gains `.documentPicker(DocumentPickerReducer)`. Which field the picker is filling is
held in `State` as `documentLinkFieldId: CustomField.Id?`, set when the sheet opens and cleared on
dismiss — the picker itself stays free of any knowledge of custom fields.

`Reset` and `isModified` need no change. `isModified` compares `input` to a freshly derived
`DocumentFormInput(document:server:)`; both sides run the same `JSONValue → typed` conversion, so
the comparison holds as long as that conversion is deterministic. It has one visible consequence: a
value another client stored as `"1234"` is shown as `EUR` + `1234.00` and is sent normalised as
`"EUR1234.00"` — but only once the user changes something else, since normalisation alone never
makes `isModified` true.

### D. Views

`DocumentFormView` currently decides two things from `store.section`: `Sheet`'s
`isScrollingEnabled` (`== .details`) and its `padding` (`0` for `.notes`). Both need the new case —
the custom fields list scrolls and takes the normal `.x4` padding — and the `bottom` switch has to
put `.customFields` on the Reset/Save side rather than the note composer side. Three `switch`
statements, each easy to miss.

- `DocumentFormCustomFieldsView` — the list, the `＋ Add field` menu of definitions not yet
  attached, and two distinct empty states: the server defines no fields at all, versus none attached
  to this document yet.
- `DocumentFormCustomFieldRow` — one `switch` over `dataType` onto components that already exist:
  `Field` + `TextField`, `DateField`, `Toggle`, `TextEditor` for longtext, `MenuField` for select
  and for the monetary currency, `DocumentPickerView` for documentlink. A trailing `✕` detaches.

Behaviour settled during design:

- Clearing a value keeps the field attached and sends `null`. Detaching is only the `✕`.
- Attaching gives the type's empty value — `""`, no date, no selection, `[]` — except `boolean`,
  which starts at `false`, since a `Toggle` has no third position.
- Monetary is a currency `MenuField` plus an amount. The code is preselected from the field's
  `extra_data.default_currency`, falling back to the device locale's currency. The amount is
  formatted to exactly two decimals on save, per the asymmetric rule above.
- A number or amount that does not parse shows an inline error through `Field`'s existing `error`
  binding and disables `Save`. URLs are not validated; the server does not validate them either.
- Linked document titles are resolved with `getDocumentsByIds` on appear, as the atom editor does.
  An id that does not come back renders as `#42` rather than disappearing.

### E. One targeted refactor

The documentlink editor needs a searchable, multi-select document picker. One exists, buried at
`DocumentFilter/CustomField/Cards/AtomEditor/DocumentPicker/` as
`CustomFieldQueryDocumentPickerReducer`. It has nothing to do with queries — it searches documents
and returns a selection.

Move it to `Modules/DocumentsFeature/DocumentPicker/` as `DocumentPickerReducer` /
`DocumentPickerView`, no behaviour change, and use it from both the atom editor and the form. Tests
move with it, and `Snapshots/DocumentsFeatureTests/CustomFieldQueryDocumentPickerViewTests/` is a
`git mv` to the new suite name: the recorded images stay byte-identical, so any diff there is a real
regression rather than a re-record.

The alternative is a second copy of a paging searchable picker.

## Testing

`ApiInterfaceTests/Documents/` — extend `DocumentTests`, add `DocumentCustomFieldTests`:

- decoding each wire shape in the table above
- an unknown `data_type` decoding to `.unknown` and re-encoding byte-identical
- absent `custom_fields` decoding to `[]`, covering cached documents written before this change
- `UpdateDocumentInputTests`: the array encodes as `custom_fields`, `null` survives, an empty array
  clears every field

`DocumentsFeatureTests/DocumentForm/` — reducer tests:

- attach, edit, save → asserts the exact `UpdateDocumentInput`
- detach → the field is omitted from the payload
- `Reset` restores the document's fields
- **`isModified` is false on open for every data type** — the `JSON → typed → JSON` round trip has
  to be stable, and this is the one place the design can quietly go wrong
- an unparseable number blocks `Save`
- an unknown-type field round-trips untouched through a save that edits a different field
- an integral monetary amount is sent as `"EUR1234.00"`, never `"EUR1234"`

View snapshot tests in the established style — `DocumentFormCustomFieldsViewTests` with cases for:
no fields defined, none attached, one of every data type, a validation error, and an unknown type
rendered read-only.

## Strings

New keys in `Shared/Framework/Resources/Localizable.xcstrings`, **en and de both** — the catalog has
no untranslated key today and this should not introduce the first. Roughly `addCustomField`,
`removeCustomField`, `noCustomFieldsDefined`, `noCustomFieldsAttached`, `invalidNumber`, `currency`.
`customFields` already exists.
