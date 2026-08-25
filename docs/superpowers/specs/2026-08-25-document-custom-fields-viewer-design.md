# Read-only custom fields on a document

## Context

Since [#189](2026-08-24-document-custom-field-editing-design.md) a document's custom fields can be
edited, in the Edit document sheet's Custom fields section. There is no way to *read* them without
entering an editor — every other facet of a document has one:

```
DocumentViewerSection: content | metadata | notes
```

`DocumentViewer` is a sheet with a section menu, reached from two places. Both go through
`DocumentViewerMenu`, whose comment states the contract this design depends on:

> Driven by `allCases` so a new section reaches the document detail toolbar and the row's context
> menu at once, without either of them naming the sections.

So a fourth case is all that "reachable from details and row" requires. Nothing in
`DocumentDetailView` or `DocumentRowView` needs to change.

### What already exists

- **`DocumentFormCustomFieldValue.init(field:json:)`** decodes a `DocumentCustomField`'s
  `JSONValue` into a typed case per data type. Internal to `DocumentsFeature`, so it is reusable
  from a sibling folder without plumbing.
- **`DocumentMetadataGroupView`** renders a titled card of label/value rows and drops rows whose
  value is empty. It is what the metadata section looks like, and reusing it is what makes the new
  section look like its neighbour.
- **`getDocumentsByIds`** resolves `Document.Id`s to full documents. `DocumentFormReducer` already
  uses it to turn link ids into titles, falling back to `#id`.
- **`.noCustomFieldsAttached`** — "No fields on this document yet" — already exists as a string.

A document carries `customFields: [DocumentCustomField]`, each `{field: CustomField.Id, value:
JSONValue}`. Definitions come from the per-server cache.

## Decisions

**Attached fields only.** The view lists what the document has, mirroring the edit form so the two
agree. Fields defined on the server but never attached stay out: on a server with thirty
definitions, listing them all as blanks buries the three that matter.

**A link opens the whole linked document, as a modal sheet.** Tapping one presents
`DocumentDetailView` — content, metadata, its own custom fields, edit — rather than a fields-only
screen. Depth is unbounded: a link inside that document presents another sheet, and dismissing walks
back out.

This supersedes the original decision, which was an in-sheet `NavigationStack` showing only the
linked document's fields. That was chosen to avoid a recursive reducer; the recursion turned out not
to be a problem (see below), so the weaker option had no reason to stand.

## Architecture

### The section

`DocumentViewerSection` gains `case customFields`, with `.customFields` as its label and
`list.bullet.rectangle` as its icon — the symbol the edit form already uses for custom fields. Both
entry points follow from `allCases`.

### The recursion is fine

`DocumentDetailReducer.Destination` already holds a `documentViewer`, so presenting a detail from
the viewer means `DocumentViewerReducer.State` transitively contains itself. Swift permits this —
the generated `Destination.State` is an enum, and enums can recurse.

What Swift does *not* do is synthesise `Equatable` across the cycle, and `@Reducer` adds that
conformance for no destination at all. Every `Destination` in this codebase declares it by hand, and
this one is no different:

```swift
extension DocumentViewerReducer.Destination.State: Equatable {}
```

Without that line the compiler says only `type 'DocumentViewerReducer.State' does not conform to
protocol 'Equatable'`, with no note naming a cause — which reads like a recursion problem and is
not one. A non-recursive destination fails identically.

The viewer holds a plain `@Presents var destination: Destination.State?`. Tapping a link sets it;
dismissing clears it.

The section scrolls its own content rather than the sheet's, so the scroll view reaches the sheet's
edges instead of being inset by its padding. `isContentScrollable` is therefore `false` for this
section and the sheet passes it no padding.

### Rendering

Values reuse `DocumentFormCustomFieldValue`, extended with a read-only formatter:

| Type | Rendered as |
|---|---|
| boolean | Yes / No |
| date | formatted date |
| monetary | currency and amount |
| float, integer | the number |
| select | the option's **label**, not its id |
| string, url, longText | the text |
| documentLink | capsules of linked titles, tappable once resolved |
| unknown | shown verbatim, as the edit form shows it |

Two row shapes follow. Everything except a document link is a label and a string, so it reuses
`DocumentMetadataGroupView.Row` and inherits the metadata card's look. A document link cannot: that
row renders a `String?`, and links need capsules that respond to a tap. Links get their own row,
matching how the edit form presents them.

### Data flow

On appear, a screen resolves its own document's link ids through `getDocumentsByIds` and holds the
results in `linkedDocuments`. A title that has not arrived renders as `#id`, exactly as the edit
form does. Each pushed screen resolves its own links the same way.

Definitions come from `@Shared(.customFields(server))` — the same store `DocumentFormReducer.State`
reads. The viewer already carries `server`, so nothing new is fetched.

### States

- **No attached fields** — `EmptyListView` with `.noCustomFieldsAttached`. No new strings.
- **Link not yet resolved** — the capsule renders `#id` and is **not tappable**. It becomes tappable
  when the title arrives. Nothing can push a screen with no document behind it, so the pushed screen
  needs neither a loading nor an error state.
- **Link resolution fails** — the same inert `#id` capsule. A failed lookup degrades a label; it
  does not empty the screen.
- **Definition missing** — a document can reference a custom field that has since been deleted,
  because custom fields are global and deletable. The row renders with the field id as its name
  rather than being dropped: showing something true beats implying the document carries less than
  it does.
- **Unknown data type** — shown verbatim, matching the edit form, which renders unsupported values
  read-only rather than hiding them.

## Testing

**Reducer tests** for: resolving links on appear, a link tap appending to the viewer's stack, a pop
returning, and a document with no fields staying empty.

**Snapshot tests** following `DocumentFormCustomFieldsViewTests`: no fields, plain types, link
types, and a pushed screen.

**No UI journey here.** It belongs with the journey inventory in the UI testing plan, and that suite
is still stabilising.

## Risks

**Sheets stack.** A chain of links presents a sheet per level rather than pushing onto one stack.
Deep chains are therefore sheets over sheets, which iOS handles but which has a practical depth
limit before it reads badly.

**Select options can go stale.** A select value stores an option id; if the definition changes, the
id may no longer resolve. It renders as the raw id rather than a blank, so the screen shows
something true rather than implying the field is unset.
