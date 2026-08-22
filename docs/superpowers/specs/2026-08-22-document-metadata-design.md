# Show document metadata

## Context

`DocumentViewerMenu` opens a read-only sheet on a document's **Content** or **Notes**. Both are
things the document *says*. Nothing in the app shows what the document *is* — which file was
consumed, what type it is, how large it is, whether paperless made an archived copy of it, what its
checksum is.

Paperless has that behind a separate endpoint, `GET /api/documents/{id}/metadata/`, and none of it
is in the app today: no model, no use case, no repository method. So this change is a thin vertical
slice — one endpoint down, one section up — landing as a third case in a menu that is already built
to grow.

### What the endpoint returns

Verified against the local instance (paperless-ngx 3.0.5, `docker/`), document 44:

```json
{
  "original_checksum": "65990b5f…caa861f",
  "original_size": 335237,
  "original_mime_type": "application/pdf",
  "original_filename": "TonieBox.pdf",
  "media_filename": "0000044.pdf",
  "has_archive_version": true,
  "archive_checksum": "bbafb1f0…f593a0",
  "archive_media_filename": "0000044.pdf",
  "archive_size": 578585,
  "lang": "en",
  "original_metadata": [ { "namespace": …, "prefix": "pdf", "key": "Producer", "value": … } ],
  "archive_metadata":  [ … ]
}
```

Of the fourteen seeded documents, six have `has_archive_version: false` — and on those, all three
`archive_*` fields come back `null`. That is the shape the view has to handle, not a hypothetical.

**`original_metadata` and `archive_metadata` are out of this change.** They are XMP/PDF producer
junk — `xmpMM:InstanceID`, `pdf:Producer` — seven and twelve entries on the document above, and the
count varies per file. Rendering them well means a second layer of grouped, expandable rows for
information almost nobody reads. They are not decoded at all; the model simply has no property for
them, so adding them later is additive.

## Architecture

`Notes/` is the template on the API side and `DocumentNotes/` on the feature side, because both are
already document sub-resources fetched independently of the document itself.

```
DocumentViewerReducer
    ├── Scope ── DocumentNotesReducer
    └── Scope ── DocumentMetadataReducer ── getDocumentMetadata ── /api/documents/{id}/metadata/
```

### The model

`ApiInterface/Documents/DocumentMetadata.swift`, flat, `Codable, Equatable, Sendable`, every field
optional except `hasArchiveVersion`:

```swift
public struct DocumentMetadata: Codable, Equatable, Sendable {
    public let archiveChecksum: String?
    public let archiveMediaFilename: String?
    public let archiveSize: Int?
    public let hasArchiveVersion: Bool
    public let lang: String?
    public let mediaFilename: String?
    public let originalChecksum: String?
    public let originalFilename: String?
    public let originalMimeType: String?
    public let originalSize: Int?
}
```

No `CodingKeys`. The decoder is `.convertFromSnakeCase`, and every key maps under it — but note
`original_filename` is *one word* in this payload, so the property is `originalFilename`, not the
`originalFileName` that `Document` uses for the documents endpoint's `original_file_name`. The two
endpoints spell it differently; the models follow their own payloads rather than being made to
agree.

`lang` keeps the server's name. Calling it `language` would buy a nicer property at the cost of a
`CodingKeys` enum listing all ten keys, which is then a thing to maintain every time a field is
added. The label in the view says *Language* regardless.

### The API layer

- `documentsRepository.getDocumentMetadata(id:server:)` — `GET /api/documents/{id}/metadata/`,
  the same four-line shape as `getDocument`.
- `GetDocumentMetadataUseCase` in `ApiInterface/Documents/` and `ApiImplementation/Documents/`,
  `execute: (Document.Id, Server) async throws -> DocumentMetadata`, exposed as
  `\.getDocumentMetadata`.

### The section

```swift
public enum DocumentViewerSection: CaseIterable, Sendable {
    case content
    case metadata
    case notes
}
```

Alphabetical, which is also the order the two menus and the in-sheet picker render — `allCases`
drives all three, so the case is the entire wiring. Icon `info.circle`; the `.content` default in
`DocumentViewerReducer.State` is unchanged, so nothing opens on Metadata that did not ask for it.

### Loading

`DocumentMetadataReducer` owns its fetch, on its own view's `onAppear`. Opening the sheet on
Content costs no metadata request; switching to Metadata fetches once; switching away and back does
not refetch. That is the same guard `DocumentNotesReducer` and the viewer's content load already
use, for the same reason.

```swift
@ObservableState
public struct State: Equatable {
    let documentId: Document.Id
    var isLoading = false
    var loadError: String?
    // nil until the first load lands, so "loading" and "loaded" are distinguishable without a
    // second flag.
    var metadata: DocumentMetadata?
    let server: Server
}
```

Folding this into the viewer's existing `runGetDocument` was the alternative. It saves a child
reducer and costs a request on every sheet open for a section most opens never visit, plus two
unrelated failure states in one reducer — the content section would have to decide what to render
when the document loaded and the metadata did not.

### View layout

`DocumentMetadataView`, rendered inside the viewer's `Sheet` like the content section (padded, not
edge-to-edge).

```
Original
  Filename          TonieBox.pdf
  Media filename    0000044.pdf
  Type              application/pdf
  Size              327 KB
  Checksum          65990b5f…caa861f

Archive
  Media filename    0000044.pdf
  Size              565 KB
  Checksum          bbafb1f0…f593a0

Language            en
```

- A row whose value is `nil` is omitted rather than shown as a dash. The **Archive** group is
  omitted entirely when `hasArchiveVersion` is false — six of the fourteen seeded documents.
- Sizes format through `.byteCount(style: .file)`.
- Checksums are monospaced and truncate in the middle; the whole section is
  `.textSelection(.enabled)`, for the same reason the content section is — copying a checksum or a
  filename out is the point of showing it.
- States mirror the content section exactly: `ProgressView` while loading, `EmptyListView` with a
  retry button on failure, and an `EmptyListView` if every field came back empty.

## Strings

New keys in `Localizable.xcstrings` (en/de): `metadata` (Metadata/Metadaten), `original`
(Original/Original), `archive` (Archive/Archiv), `filename` (Filename/Dateiname), `mediaFilename`
(Media filename/Media-Dateiname), `mimeType` (Type/Typ), `size` (Size/Größe), `checksum`
(Checksum/Prüfsumme), `language` (Language/Sprache), `noMetadataFound` (No metadata found/Keine
Metadaten gefunden). Existing keys are reused where they already exist rather than duplicated.

## Testing

- `DocumentsRepositoryTests` — a `getDocumentMetadata` case against the docker instance, following
  the existing integration tests in that file.
- `DocumentMetadataReducerTests` — load success, load failure sets `loadError` and toasts, retry
  clears the error and refetches, and `onAppear` after a successful load does not refetch.
- `DocumentMetadataViewTests` — snapshots for loaded with archive, loaded without archive, loading,
  and error, light and dark.
- `DocumentViewerReducerTests` / `DocumentViewerViewTests` — the new scope, and a snapshot of the
  viewer on the metadata section.
- Existing viewer snapshots do not render the menu, so they are expected to pass unchanged. If any
  reference image does move, it is re-recorded rather than explained away.

## Out of scope

- `original_metadata` / `archive_metadata` XMP lists.
- Any metadata surface outside the viewer sheet — the detail screen keeps its layout, the row keeps
  its subtitle.
- Anything writable. Nothing here is editable in paperless either.
