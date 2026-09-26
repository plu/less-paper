# Document history

## Context

The paperless web UI has a **History** tab on every document: a timeline of who changed what and
when, read from the audit log.

```
11 hours ago   johannes   Update
  Tags: 7
21 hours ago   System     Update
  Add Tags: Privat
21 hours ago   System     Update
  Document_type: Information
```

Nothing in the app shows it. The viewer sheet — reached through **View ▸** on the document detail
toolbar and on the row's long-press menu — already carries Content, Custom fields, Metadata and
Notes, and [its spec](2026-08-22-view-document-content-and-notes-design.md) built the submenu from
`DocumentViewerSection.allCases` precisely so a section like this one could be added later.

### What the server actually offers

```
GET /api/documents/{id}/history/   → [AuditLogEntry], newest first
```

Probed against `paperless-ngx:3.0.5` on the dev instance:

```json
{
  "id": 106,
  "timestamp": "2026-09-07T11:37:29.581744Z",
  "action": "update",
  "changes": {
    "tags": { "type": "m2m", "operation": "add", "objects": ["Audio", "Manual"] }
  },
  "actor": { "id": 2, "username": "admin" }
}
```

`changes` is a map from field name to one of three shapes:

| Shape | Example | Meaning |
| --- | --- | --- |
| `[old, new]` | `"correspondent": ["None", "8"]` | A field changed. Each side is usually a string — ids arrive as strings, and "no value" is the string `"None"` — but not always: note changes send a number (`"Note Added": ["None", 40]`), and a tag change written outside the bulk editor sends raw ids (`"tags": [97, [96, 97]]`, or `[null, [102]]`). That last one is where the web's *Tags: 7* comes from. |
| `{"type": "m2m", …}` | `{"type": "m2m", "operation": "add", "objects": ["Audio"]}` | A many-to-many relation (tags) gained or lost objects, already resolved to names. |
| `{"type": "custom_field", …}` | `{"type": "custom_field", "field": "Invoice", "value": "42"}` | A custom field instance changed. |

Notes appear as scalar changes keyed `"Note Added"` / `"Note Deleted"`. `actor` is `null` for
changes the server made itself — consumption, workflows, the file handler — which the web shows as
*System*. `action` is `create`, `update` or `delete`; a `create` entry lists every field of the
freshly consumed document, `content` and `checksum` included.

### Why this is not gated on API version

The request was to show History only on servers whose API supports it. It turns out every supported
server does: the endpoint arrived with paperless-ngx 2.8 (PR #6388, April 2024), and it is present,
unchanged, in 2.15.3 — the release `ApiVersion.minimumSupported = 8` stands for. An API version
check would always pass.

What actually decides whether the endpoint answers is in its implementation
(`src/documents/views.py`, identical in 2.15.3 and 3.x):

```python
if not settings.AUDIT_LOG_ENABLED:
    return HttpResponseBadRequest("Audit log is disabled")
...
if not request.user.has_perm("auditlog.view_logentry") or (
    doc.owner is not None
    and doc.owner != request.user
    and not request.user.is_superuser
):
    return HttpResponseForbidden("Insufficient permissions")
```

The web hides its tab on the same three conditions, and `/api/ui_settings/` exposes the first as
`settings.auditlog_enabled`. The app gates on exactly these, the way Notes already drops out of the
menu without `view_note`.

## Goal

A read-only **History** section in the document viewer that lists a document's audit log the way
the web does — loaded lazily on first visit, and offered only to users the server would answer.

## Design

### API layer

A new `AuditLogEntry` in `ApiInterface/History/`:

```swift
public struct AuditLogEntry: Decodable, Equatable, Identifiable, Sendable {
    public typealias Id = Tagged<AuditLogEntry, Int>

    public let action: Action
    public let actor: Actor?
    public let changes: [Change]
    public let id: Id
    public let timestamp: Date

    public enum Action: Equatable, Sendable {
        case create
        case delete
        case other(String)
        case update
    }

    public struct Actor: Decodable, Equatable, Sendable {
        public let id: User.Id
        public let username: String
    }

    public enum Change: Equatable, Sendable {
        case customField(field: String, value: String?)
        case field(key: String, old: JSONValue?, new: JSONValue?)
        case relation(key: String, operation: String, objects: [String])
    }
}
```

`Actor` is its own type for the same reason `Note.Author` is: the payload carries two fields, not
`User`'s thirteen.

`changes` decodes from the JSON object into an array of `Change`. The object's key order is not
guaranteed to survive `JSONDecoder`, so the decoder sorts by key — the web's `keyvalue` pipe sorts
the same way, which keeps the two listings in the same order. The two sides of a pair stay
`JSONValue`, because they are not always strings (see the table above); `"None"` and `null` both
decode to `nil`. `action` decodes leniently: django-auditlog also knows an `access` action, and
anything outside create, update and delete lands in `.other` with its raw text rather than failing
the entry. A value that matches none of the three shapes is skipped rather than failing
the whole entry: the audit log is written by many server paths, and one unexpected shape should
cost one line, not the section.

`GetDocumentHistoryUseCase` — `(Document.Id, Server) -> [AuditLogEntry]` — follows the shape of
every other use case in the module, and delegates to a new `HistoryRepository` in
`ApiImplementation/History/`, one repository per folder per resource as `NotesRepository` does.

### Caching `auditlog_enabled`

`GetCurrentUserUseCase` already fetches `/api/ui_settings/` to cache the current user and the
permission set. It additionally writes `settings.auditlog_enabled` to a new per-server key:

```swift
static func auditLogEnabled(_ server: Server) -> Self  // FileStorageKey<Bool?>
```

`UISettings.Settings` keeps unknown keys in `raw`, so reading it is `raw["auditlog_enabled"]?.boolValue`
behind a named accessor — no change to how the settings decode or re-encode. `JSONValue` has
`intValue` and friends but no `boolValue` yet; it gains one alongside them.

### Gating

`ServerPermissions` grows the one question every entry point asks:

```swift
public func canViewHistory(of document: Document) -> Bool
```

It returns `true` only when all hold:

1. `auditLogEnabled` is not `false`.
2. `can(.viewLogEntry)`.
3. The document has no owner, the current user owns it, or the current user is a superuser.

Each clause treats "not read yet" (`nil`) as allowed, matching `can()`: denying before the cache
arrives would hide the section on a fresh install and bring it back a moment later. If the cache is
stale, the endpoint's own 400 or 403 lands in the section's error state (below), which is the same
fallback Notes has.

`ServerPermissions` holds `auditLogEnabled` as a `@Shared` like its other two caches, so a
foreground refresh re-renders the menus.

### Section visibility in one place

The `.notes` filter is written out three times today — the detail toolbar, the row context menu and
the viewer's own section picker — and History would make each copy longer. Instead, one helper on
`DocumentViewerSection`:

```swift
static func visible(canViewNotes: Bool, canViewHistory: Bool) -> [DocumentViewerSection]
```

All three call sites use it. Each reducer that feeds one of them — `DocumentDetailReducer`,
`DocumentRowReducer`, `DocumentViewerReducer` — gains a `canViewHistory` computed property next to
its `canViewNotes`, reading `permissions.canViewHistory(of: document)`.

### Feature layer

`DocumentViewerSection` gains `.history` (label *History*, symbol `clock.arrow.circlepath`). With
the cases in A–Z source order it lands between Custom fields and Metadata.

A new `DocumentHistoryReducer` / `DocumentHistoryView` in `Modules/DocumentsFeature/DocumentHistory/`,
scoped into `DocumentViewerReducer` with `Scope` as Notes and Metadata are:

```swift
@ObservableState
public struct State: Equatable {
    let documentId: Document.Id
    var entries: [AuditLogEntry]?
    var isLoading = false
    var loadError: String?
    let server: Server
}
```

`entries == nil` means not loaded; an empty array means loaded with nothing to show. Loading is the
same first-visit `onAppear` guard Notes uses — `DocumentViewerView` switches on the section, so the
view is only in the hierarchy while History is showing, and switching away and back does not
refetch. A retry button re-runs the load after an error.

`isContentScrollable` returns `false` for `.history`: the list scrolls itself, as Notes does.

#### Rendering an entry

Each entry is one row, mirroring the web:

- **Header:** relative time (*11 hours ago*), then the actor's username or *System*, then the action
  as a badge — tinted for *Create*, neutral otherwise. An `.other` action shows its raw text
  title-cased. The reference date comes from `@Dependency(\.date.now)`, so snapshots stay fixed.
- **One line per change:**
  - `.field` — the key title-cased with underscores kept (*Document_type*, matching the web), then
    the new value. For `correspondent`, `document_type`, `storage_path` and `owner` the id is
    resolved to a name through the cached `.correspondents`, `.documentTypes`, `.storagePaths` and
    `.users` lists, falling back to the raw id when the cache has no match. `storage_path` resolves
    to the path, as the web does. `tags` — which on the web shows raw ids — resolves each id through
    the cached tags the same way, so the app reads *Tags: Invoice, Paid* where the web reads
    *Tags: 7*. `content` is cut to its first 100 characters with an ellipsis. A
    `nil` new value shows as an em dash.
  - `.relation` — the operation title-cased, then the key, then the objects comma-joined:
    *Add Tags: Privat*.
  - `.customField` — the field name, then the value.

Changed values render in a monospaced, tinted style, the counterpart of the web's `<code>`.

Resolving names goes through the existing `Correspondent.Id.get(_:)`-style helpers on
`@Dependency(\.apiCache)`, called from a small formatter the view uses — not from the reducer: the
entries are the server's truth, and a renamed correspondent should read with its current name
without refetching the history.

Empty state: *No entries found.*, via `EmptyListView` like the other sections.

### Offline snapshots

No special case. From the Offline tab, the viewer's Notes and Metadata sections already try the
network and fall into their error state when it is unavailable; History does the same.

### Strings

*History*, *System*, *Create*, *Update*, *Delete* and *No entries found.* go into
`DocumentsFeature`'s own string catalog, with German translations, as every module owns its strings.

## Error handling

| Response | Cause | Shown |
| --- | --- | --- |
| 400 | Audit log switched off since the cache was read | The section's error state, with retry |
| 403 | Permission revoked, or the document changed owner, since the cache was read | Same |
| Transport error | Offline, server down | Same |
| Unknown change shape | A server path writes something new | That change is skipped; the entry still shows |

## Testing

- **Decoding** (`ApiImplementationTests/History/`): fixtures recorded from the dev instance covering
  a `create` entry, a scalar change with `"None"`, an m2m change, a custom-field change, a note
  change, a `null` actor, and an unknown shape that is skipped.
- **Repository:** the request path and the decoded result, against the live test server like
  `NotesRepositoryTests`.
- **Gating** (`ApiInterfaceTests`): `canViewHistory` for audit log disabled, missing
  `view_logentry`, another user's document, an unowned document, a superuser on another user's
  document, and every cache still `nil`.
- **Section visibility:** `DocumentViewerSection.visible` for each combination of the two flags.
- **Reducer** (`DocumentsFeatureTests/DocumentHistory/`): first load, no refetch on revisit, load
  error, retry.
- **View:** snapshot of a populated list, the empty state and the error state, in light and dark.
