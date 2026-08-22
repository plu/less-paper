# View document content and notes

## Context

A document's OCR content and its notes are both already on screen somewhere — but only inside
`DocumentFormView`, reachable through **Edit**. The form's header says *Edit document*, its ⋯ menu
switches between Details, Content and Notes, and its bottom slot carries Reset/Save or the note
composer.

That is the wrong door for a reader. Someone who wants to check what a scan actually says, or what
a colleague noted on it, has to open an editing surface, and every affordance in front of them
invites a change they did not come to make. The content section is a `TextEditor`; the notes
section has swipe-to-delete on every row.

So: a read-only way in, from the two places a document is already actionable.

### Where the entry points go

| Surface | Today | After |
| --- | --- | --- |
| `DocumentDetailView` toolbar ⋯ | Preview, Share | Preview, Share, **View ▸** |
| `DocumentRowView` long-press | Preview, Share, Edit, Delete | Edit, Preview, Share, **View ▸**, ─, Delete |

The reversible actions are ordered A–Z, so a new one has an obvious place to go rather than landing
wherever it was written. **Delete is held out below a `Divider`** instead of taking whatever row
its initial earns it — which alphabetically is the *top*, one mistap from everything else. That is
the same shape `DocumentListBottomToolbar`'s overflow menu already uses for its bulk delete, so the
two destructive actions now read the same way.

The ordering is the *source* order, which is A–Z in English only — the labels are localised, so the
row's four reversible actions read Edit, Preview, Share, View in English and Bearbeiten, Vorschau,
Teilen, Anzeigen in German, which is not alphabetical at all. Sorting at runtime by resolved label
would need every menu rebuilt as data rather than markup.

`DocumentFormSection` is reordered to match, so the edit sheet's section picker reads Content,
Details, Notes. The form still *opens* on Details — that is the state's default, not the first
case.

Menus whose order carries meaning are left alone: the filter, sort and date menus would be made
worse by alphabetising *Today* against *Last 7 days*.

**View** is a submenu, not a leaf:

```
View ▸ ─┬─ Content
        └─ Notes
```

A leaf labelled *Content & notes* was the first shape. The submenu replaces it because sections
will be added later, and a flat item would have to keep growing its label — or stop describing
what it opens. It also lets the reader land directly on the section they want instead of opening
on Content and switching.

`DocumentViewerMenu` builds both menus from `DocumentViewerSection.allCases`, so a new case reaches
the toolbar and the context menu at once without either naming its sections.

The detail menu carries `.disabled(store.downloadedURL == nil)` today, so it is greyed out until the
PDF finishes downloading. Content and notes need no download, so that modifier goes. Preview and
Share are already inside an `if let url`, so the menu is never empty — it just holds one item while
the download is in flight.

*View* next to *Preview* would say nothing on its own — Preview opens the PDF in QuickLook, this
opens text. The submenu resolves that: the parent is a verb, and its children name the two things
it can show.

## Architecture

A new `DocumentViewerReducer`/`DocumentViewerView` pair in
`Modules/DocumentsFeature/DocumentViewer/`, presented as a `.large` sheet from both surfaces.

```
DocumentDetailReducer ──┐
                        ├── Destination.documentViewer ── DocumentViewerReducer
DocumentRowReducer   ───┘                                        │
                                                                 └── Scope ── DocumentNotesReducer
```

### Content comes from the shared document

`DocumentFormReducer` keeps content in its own `content: String?` because it is editable and has to
be diffed against the server's copy to decide whether Save is enabled. The viewer edits nothing, so
it needs no copy.

`runGetDocument` already writes the full document into the `@Shared` document — the form does this,
and so will the viewer. The view renders `store.document.content` directly, and a separate
`hasLoadedContent` flag gates it:

```swift
@Shared var document: Document
var hasLoadedContent = false
var isLoadingDocument = false
var loadError: String?
var notes: DocumentNotesReducer.State
var section: DocumentViewerSection
let server: Server
```

The flag is not redundant with `document.content`. The list payload carries a *truncated* content
string, so a document always has some content to show — showing it before the full fetch lands would
present a cut-off scan as though it were the whole thing. `hasLoadedContent` is the only thing that
distinguishes "truncated placeholder" from "this is the document".

Because both the form and the viewer write the full document into the same `@Shared` value, opening
one warms the other.

No extraction of the form's content loading into a shared child reducer. The form's copy is
entangled with `isModified`, `resetButtonTapped` and `saveButtonTapped`; pulling it out would rewrite
three behaviours and their tests to save an effect that is nine lines long. The viewer gets its own
`runGetDocument`.

### Notes are reused as-is

`DocumentNotesReducer` already models exactly what the viewer needs: `nil` until loaded, an empty
array meaning "loaded and there are none", a `loadError`, and no silent refetch when a section is
switched away from and back. The viewer scopes into it unchanged.

Only the *view* changes. `DocumentNotesView` gains `isReadOnly: Bool = false`; when set it passes
`nil` for the row's delete handler, and `DocumentNoteRowView.deleteButtonTapped` becomes
`(() -> Void)?` and omits `.swipeActions` when it is nil. The viewer never renders
`DocumentNoteComposerView`. `DocumentFormView`'s call site is unchanged — the default keeps it
editable.

The delete path in the reducer stays reachable in principle but is never sent from a read-only view.
That is deliberate: a read-only *flag* on the reducer would be a second source of truth about
something the view already decides.

### Sections

```swift
public enum DocumentViewerSection: CaseIterable, Sendable {
    case content
    case notes
}
```

A separate enum rather than reusing `DocumentFormSection` minus `.details`. Both localize through
the same `content`/`notes` strings, and neither has to know about the other's cases. It is `public`
because it is the payload of `viewButtonTapped(_:)` on two public action enums, and `Sendable` so
it can be a `@Test(arguments:)` input.

The section is injected through `State.init(document:section:server:)`, so the menu decides where
the sheet opens. Once open, the header ⋯ holds a `Picker` bound to `$store.section`, mirroring
`DocumentFormView.sectionMenu()`.

The sheet header shows the **current section** — *Content* or *Notes* — rather than a fixed title.
Now that the submenu can land on either one, the header is what tells the reader where they are.

### View layout

```swift
Sheet(
    isScrollingEnabled: store.isContentScrollable,
    padding: store.section == .notes ? 0 : .x4
) { header } content: { … }
```

Inverted from the form on the scrolling flag, and for the same underlying reason. The form disables
the sheet's `ScrollView` in `.content` because a `TextEditor` scrolls itself; the viewer's content is
a plain `Text`, so it needs the sheet to scroll it. Notes bring their own `List` in both.

`isContentScrollable` rather than `section == .content`, though: only real text scrolls. The
loading, error and empty states are centred, and the sheet's `ScrollView` pins them to the top —
which is what the first recorded snapshots showed.

Content renders as `Text(content)` — `Document.content` is optional, and nil is folded into the
empty state — with `.textSelection(.enabled)`, because copying a reference number out of a scan is
the obvious next thing a reader wants. No bottom slot: nothing in the viewer is staged, saved or
composed.

### States

| Condition | Content section | Notes section |
| --- | --- | --- |
| loading | `ProgressView` | `ProgressView` (existing) |
| failed | `EmptyListView` + Retry | `EmptyListView` + Retry (existing) |
| loaded, empty | `EmptyListView`, *No content* | `EmptyListView`, *No notes yet* (existing) |
| loaded | selectable `Text` | `List` of rows, no swipe (existing) |

Empty content is not hypothetical: a document Paperless has not OCR'd, or a scan with no text layer,
returns an empty string. Falling through to a blank sheet would read as a bug.

Load failure is not retried silently on the next appearance — same rule the form and the notes
reducer already follow. `retryLoadButtonTapped` is the only way back.

## Strings

One new key in `Localizable.xcstrings` (en, de):

| Key | en | de |
| --- | --- | --- |
| `noContentFound` | No content | Kein Inhalt |

`content`, `notes`, `retry` and `view` already exist and are reused. `view` is currently the
permissions label; both are the verb, and both are *Anzeigen* in German, so it is one key rather
than a duplicate. If the two ever need to diverge, splitting them is trivial.

## Testing

**`DocumentViewerReducerTests`** — `onAppear` loads and sets `hasLoadedContent`; `onAppear` a second
time does not refetch; a failure sets `loadError` and toasts; `onAppear` after a failure does not
retry silently; `retryLoadButtonTapped` clears the error and refetches; the loaded document lands in
the `@Shared` document; `closeButtonTapped` dismisses.

**`DocumentViewerViewTests`** — snapshots for content loaded, loading, error, empty; notes loaded;
and dark mode.

**`DocumentNotesViewTests`** — a read-only snapshot proving the composer and swipe affordance are
gone.

**`DocumentDetailReducerTests` / `DocumentRowReducerTests`** — `viewButtonTapped(_:)` opens the
viewer on the requested section, run over `allCases` via `@Test(arguments:)` so a new section is
covered on both surfaces the moment it is added.

The rendered submenu itself is not covered: SwiftUI menus do not appear in snapshots, and driving
one open needs UI-interaction tooling.

**`DocumentDetailViewTests`** — the existing snapshots change, because the toolbar menu is no longer
greyed out while downloading.

## Also in this change: the edit sheet's content background

`DocumentFormView`'s content `TextEditor` filled with `m3SurfaceBright` and drew no outline. That
token is the *brightest* surface, which makes it behave asymmetrically against `m3Surface`:

| | fill | surface | result |
| --- | --- | --- | --- |
| light | `#F4FBF9` | `#F9FBF9` | all but invisible |
| dark | `#343A3A` | `#0E1514` | a stark grey slab |

Tuned in light mode, where the fill reads as nothing, it becomes a floating block in dark. The fix
swaps it for `m3SurfaceContainerLow` — one subtle step from the surface in *both* directions — and
adds an `m3OutlineVariant` hairline, with `.x3` of padding so the text clears that hairline —
`TextEditor` only insets itself by about 5pt, which reads as cramped against a visible border. Over
an area this size the outline is what says "editable"; the fill only has to bound it.

`m3SurfaceBright` stays where it belongs, on the small `Field` and the note composer, which are
outlined already and too small to read as slabs.

## Out of scope

- Editing anything from the viewer. Edit is one tap away in the same menu.
- Adding a note from the viewer. Considered and dropped: it would leave Content with an empty bottom
  slot and Notes with a composer, in a sheet whose whole premise is that it does not change things.
- A Details section. The row and the detail screen already show that metadata.
