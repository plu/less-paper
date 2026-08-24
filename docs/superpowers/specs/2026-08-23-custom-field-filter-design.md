# Filter documents by custom fields

## Context

The app can filter documents by correspondent, document type, storage path, tag, date, ASN and
free text. It cannot filter by **custom fields** — neither by which fields a document carries nor
by what those fields contain. The field definitions themselves are already managed
(`CustomFieldsFeature`, spec `2026-08-22-custom-fields-design.md`), and that spec explicitly
deferred filtering to this one.

The scope here is **everything the paperless-ngx web UI supports**, which since 2.13 means one
thing: the `custom_field_query` rule and its expression builder. Presence filtering — "has this
field at all" — is not a separate feature; it is the `exists` operator inside that same query.

This is a hard mobile UI problem: the query is a nested boolean expression tree whose leaves have
type-dependent operators and value editors, and the web builder is a wide desktop control. So the
work splits into a **base branch** carrying everything that is not the UI, and **four UI branches**
that each build a different presentation on top of the same model.

### What the web actually produces

`filter-editor.component.ts` reads and writes `FILTER_CUSTOM_FIELDS_QUERY` (rule type 42) as the
one modern format. Two older rule types survive only as **read-side migrations**:

| Legacy rule | Type | Upgraded to |
|---|---|---|
| `has_custom_fields__id__all` | 38 | `["AND",[[id,"exists",true], …]]` |
| `has_custom_fields__id__in` | 39 | `["OR",[[id,"exists",true], …]]` |

`custom_fields__icontains` (36) is still produced, but as a **text-search target**, not a custom
field filter — and this app already has it as `DocumentFilterSearchType.customFields`. It stays
exactly where it is and is not touched by this work.

`has_custom_fields` (41) and `custom_fields__id__none` (40) are not referenced by the web filter
editor at all. They keep falling through to `unsupportedFilterRules`, unchanged.

### The wire format, verified

Verified against the local dev instance (paperless-ngx 3.0.5, `docker/`, port 8000) by creating one
custom field of each data type, issuing queries, and deleting the fields again.

An **atom** is a three-element array `[fieldId, operator, value]`. An **expression** is
`[logicalOperator, children]`. A bare atom is legal at the top level:

```
["AND",[[7,"exists",true]]]                    → 200
[7,"exists",true]                              → 200
["OR",[[7,"icontains","a"],[8,"gt",5]]]        → 200
```

**`NOT` is arity-1 and does not take a list.** This is the single most dangerous detail in the
format, because the natural guess is a 400 and the plausible-looking wrong guess is a *500*:

```
["NOT",[7,"exists",true]]                      → 200   ← child passed directly
["NOT",["AND",[[7,"exists",true]]]]            → 200   ← child may be an expression
["NOT",[[7,"exists",true]]]                    → 400   "Invalid custom field query expression"
["NOT",[[7,"exists",true],[8,"exists",true]]]  → 500   Server Error
```

So `AND`/`OR` hold a *list* of children and `NOT` holds *one* child. Encoding them with a shared
code path is exactly the bug that produces the 500. The model makes this unrepresentable rather
than relying on a validation check — see [The model](#the-model).

Other verified server behaviour:

```
["AND",[]]                        → 400  "Invalid expression list. Must be nonempty."
["AND",[[7,"gt",5]]]              → 400  "string does not support query expr 'gt'."
["AND",[[999,"exists",true]]]     → 400  "999 is not a valid custom field."
["XOR",[[7,"exists",true]]]       → 400  "Invalid logical operator 'XOR'"
notjson                           → 400  "Value must be valid JSON."
```

Two consequences worth stating plainly:

- **An empty query must emit no rule at all.** `["AND",[]]` is a 400, so a
  freshly-opened-and-untouched builder cannot serialize to an empty expression. Emitting nothing is
  the only correct behaviour, and it also keeps `isModified` honest.
- **The server validates operators against data types itself.** The client-side operator matrix is
  therefore about not offering nonsense, not about safety.

**The depth and atom limits are web-client conventions, not server rules.** The web enforces
`CUSTOM_FIELD_QUERY_MAX_DEPTH = 4` and `CUSTOM_FIELD_QUERY_MAX_ATOMS = 5`; the server accepted
depth 6 and six atoms without complaint. We mirror the limits anyway — a phone has far less room
than a desktop, and matching the web keeps queries portable between the two clients — but this is
a deliberate product choice, documented here so nobody later "fixes" it by reading it as a
protocol requirement.

### The operator matrix

From `src-ui/src/app/data/custom-field-query.ts`. Operators are grouped, and each data type admits
a set of groups:

| Group | Operators |
|---|---|
| basic | `exists`, `isnull` |
| exact | `exact` |
| string | `icontains` |
| arithmetic | `gt`, `gte`, `lt`, `lte` |
| containment | `contains` |
| subset | `in` |
| date | `gte`, `lte` |

| Data type | Groups |
|---|---|
| string, url | basic, exact, string |
| longtext | basic, string |
| date | basic, exact, date |
| boolean | basic, exact |
| integer, float | basic, exact, arithmetic |
| monetary | basic, exact, string, arithmetic |
| select | basic, exact, subset |
| documentlink | basic, containment |

`range` exists in the web's operator enum but appears in no group, so no UI can select it. We omit
it entirely rather than model a case nothing can produce.

Value kinds follow the operator, not the field: `exists`/`isnull` take a boolean, `contains`/`in`
take an array, `gt`/`lt` take a number, and the rest take a string or number. This is what lets a
UI pick a value editor from the operator alone once the field is known.

## Architecture

```
ApiInterface/CustomFields/
    CustomFieldQuery.swift              the recursive model + Codable
    CustomFieldQueryOperator.swift      11 cases, labels, value kinds
    CustomFieldQueryOperatorGroup.swift the group table + groups(for:dataType)
    CustomFieldQueryLogicalOperator.swift

DocumentsFeature/DocumentFilter/CustomField/
    DocumentFilterCustomFieldField.swift    the collapsed row on the filter sheet
    CustomFieldQuery+Summary.swift          human-readable collapsed text
    <one file set per UI variant, on its own branch>

DocumentFilterInput
    ├── parse   .customFieldsQuery → CustomFieldQuery
    │           .hasCustomFieldsAll/.hasCustomFieldsAny → migrated
    └── emit    CustomFieldQuery → exactly one .customFieldsQuery rule, or none
```

The model lives in `ApiInterface` beside `CustomField` because it is wire format, not presentation,
and because `JSONValue` — already in `ApiInterface/Shared` with its own tests — is what makes the
heterogeneous arrays encodable without a hand-rolled parser.

### The model

```swift
public indirect enum CustomFieldQuery: Equatable, Hashable, Sendable {
    case atom(Atom)
    case group(CustomFieldQueryLogicalOperator, [CustomFieldQuery])
    case negation(CustomFieldQuery)
}
```

`negation` is a separate case holding **one** child rather than a `.group(.not, [child])`, so the
500-producing shape cannot be constructed. `CustomFieldQueryLogicalOperator` is therefore `and` and
`or` only; `NOT` is not a member of it. This is the one place the model deliberately diverges from
the web's class hierarchy, which models all three uniformly and relies on a serialization special
case to unwrap.

`Atom` carries `field: CustomField.Id`, `operator: CustomFieldQueryOperator`, and
`value: JSONValue`. It holds an id rather than a resolved `CustomField` so that a query naming a
field that has since been deleted still round-trips; a UI renders such an atom as an unknown-field
row instead of silently dropping the user's saved view. This matches how the app already treats
unresolvable ids elsewhere — `DocumentFilterInput.resolve` preserves them in
`unsupportedFilterRules` — with the difference that here they must stay inside the single query
rule rather than beside it.

### Serialization

`Codable` conformance encodes to an unkeyed container:

- `.atom` → `[field, operator, value]`
- `.group(op, children)` → `[op, children]`
- `.negation(child)` → `[NOT, child]`  — child inline, **not** wrapped in a list

Decoding accepts a bare atom at the top level, since the server does. Decoding also accepts
`["NOT",[child]]` — the shape the server rejects — and normalizes it to `.negation(child)` when the
list holds exactly one element, so that a query hand-written elsewhere still loads.

An empty `.group` is not serializable: `DocumentFilterInput` drops the rule entirely when the query
has no atoms, which covers both the untouched builder and a builder emptied by deleting its last
row.

### Validation

`CustomFieldQuery` exposes `atomCount`, `depth`, and `isComplete`. A UI uses the first two to
disable its "+ Condition" / "+ Group" affordances at 5 and 4 respectively. `isComplete` is what
gates serialization: an atom whose value is still empty while the user is mid-edit must not reach
the server, so incomplete atoms are pruned on the way out. Pruning rather than blocking keeps the
live match-count in `DocumentFilterMatchCountView` working while a condition is half-built.

### `DocumentFilterInput` integration

A new `customFieldQuery: CustomFieldQuery?` property on `DocumentFilterInput`, parsed in the
`init(filterRules:server:sortDirection:sortField:)` loop and emitted from `filterRules`. Three new
cases join the switch:

```swift
case .customFieldsQuery:      // decode; on failure, fall through to unsupported
case .hasCustomFieldsAll:     // collect ids, migrate to AND-of-exists
case .hasCustomFieldsAny:     // collect ids, migrate to OR-of-exists
```

The two legacy cases accumulate across rules the way `hasTagsAll` already does, then combine with a
decoded `customFieldsQuery` if one is also present — the web does the same, and a saved view
written by an older client can legitimately carry both.

A malformed `custom_field_query` value decodes to nothing and the rule is preserved verbatim in
`unsupportedFilterRules`, so the app never destroys a query it failed to understand.

### One thing to be aware of: `FilterRule` equality

`FilterRule.==` compares `value?.components(separatedBy: ",").sorted()`. A query's JSON value is
full of commas, so two *different* query strings could in principle compare equal if their
comma-separated fragments are a permutation of one another. In practice the bracket runs carried by each
fragment break the symmetry, and testing found no query pair that compares equal without being
identical — not an atom swap, not an operator change, not even a reordering of whole atoms. The
comma-splitting loses nothing for this rule type, so `FilterRule` needs no change; `isModified` on
the filter sheet depends on it, so a test pins the behaviour rather than leaving it to be
rediscovered.

## The base branch

`feat/custom-field-filter-base`, PR into `main`. Contains everything above and no query-builder UI:

- the four model files in `ApiInterface`
- `DocumentFilterInput` parse/emit/migrate
- `CustomFieldQuery.summary` — the collapsed description shared by all four UIs
- `DocumentFilterCustomFieldField` — the `Field` row on `DocumentFilterView`, rendering the summary
  and, on this branch only, tapping to nothing
- `@Shared(.customFields(server))` added to `DocumentFilterReducer.State`
- localized strings for every operator, logical operator, and the empty state
- tests: codec round-trip per shape, the `NOT` shapes specifically, legacy migration, the operator
  matrix per data type, depth/atom counting, incomplete-atom pruning, `FilterRule` equality

At the end of this branch the filter sheet shows a "Custom fields" row that correctly displays a
query loaded from a saved view and correctly sends it back — it just has no way to author one.
That is a coherent, reviewable, shippable increment.

## The four UI branches

Each branches off `feat/custom-field-filter-base` and its PR targets that branch, so each diff is
only its own UI. Each adds a reducer plus views under
`DocumentsFeature/DocumentFilter/CustomField/`, wires `DocumentFilterCustomFieldField`'s tap to its
own destination, and ships snapshot tests at iPhone 12 — the rendered snapshots are the artefact
that makes the four comparable.

All four can author any query the web can — variant C by way of an escape hatch rather than
directly — so any one of them can ship alone.

### A — Condition rows (`feat/custom-field-filter-ui-rows`)

A detent sheet listing each condition as a row, with an All/Any segmented control above. Tapping a
row opens a second detent sheet holding three `MenuField`s — field, operator, value — where the
operator menu is built from the chosen field's data type and the value editor from the operator's
value kind. A nested group is a row that pushes onto a `NavigationStack` showing that group's own
list. `NOT` is a toggle on the group header.

Closest to the existing `DocumentFilterView` idiom, reuses `MenuField` and the detent-sheet pattern
wholesale, and degrades gracefully at any Dynamic Type size. Lowest risk; also the least
interesting to look at, and deep queries mean a lot of pushing.

### B — Sentence builder (`feat/custom-field-filter-ui-sentence`)

The query rendered as flowing prose out of tappable capsules — "Match **all** of **Invoice total**
**greater than** **100**" — laid out so chips reflow like text. Field and operator chips open
menus; the value chip opens the editor for its kind.

The densest use of a narrow screen and the most readable at a glance. The risks are real: chip
reflow at accessibility text sizes, and a VoiceOver experience that must group each atom's three
chips into one comprehensible element rather than announcing eleven loose buttons.

### C — Field-first browse (`feat/custom-field-filter-ui-fields`)

Opens on the searchable list of custom fields, like the tag sheet. Each row shows its current
condition or "any". Tapping a field opens an editor tailored to its data type: a `Toggle` for
boolean, `DateField` for date, operator-plus-number for numeric, the options list for select.

Flat by construction — conditions on distinct fields join under the top-level All/Any — which is
what makes it feel native, and also what makes it insufficient on its own. When a loaded query is
genuinely nested it cannot be represented, so the sheet shows the summary with an **Advanced**
button that hands off to variant A's tree editor. That handoff means this branch depends on A's
files; it carries its own copy so the branches stay independent, and the duplication resolves
whichever pair is chosen.

### D — Nested cards (`feat/custom-field-filter-ui-cards`)

The whole tree on one scrolling screen. Each group is a card with an And/Or segmented header, a
`NOT` toggle, and a coloured left rail keyed to depth; atoms are rows inside it; nested groups are
nested cards. "+ Condition" and "+ Group" sit in each card's footer.

The only variant where the structure of a complex query is visible without navigating, which is
also what makes it the most persuasive for the case this feature exists to serve. It pays for that
in horizontal space — at depth 4 on a small phone the innermost card is narrow — which is a large
part of why the depth limit is kept.

## Testing

Model and input work is covered by Swift Testing unit tests. Each UI branch adds snapshot tests
covering: empty state, a single atom, one atom per value-editor kind, a two-level nested query at
the atom limit, a negated group, and an unknown-field atom. Reducer tests cover adding, editing and
deleting atoms and groups, and the limit-enforcement behaviour.

The verified server behaviours in this document are encoded as codec tests, so the `NOT` arity and
the empty-list prohibition are protected by assertions rather than by this prose.

## Out of scope

- Showing or editing custom field *values* on a document. Filtering reads field definitions only.
- `has_custom_fields` (41) and `custom_fields__id__none` (40), which the web filter editor does not
  produce either. They continue to round-trip as unsupported rules.
- Changing `DocumentFilterSearchType.customFields`, the existing `custom_fields__icontains` text
  search. It is a text-search target and stays one.
- Any change to `FilterRule` equality semantics.
