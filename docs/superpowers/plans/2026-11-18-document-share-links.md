# Document Share Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create, list, copy and delete paperless-ngx share links for a document from a small bottom sheet reached through the existing Share menu, handing a new link straight to the system share sheet.

**Architecture:** Three new use cases in `ApiInterface/ShareLinks/` backed by a `ShareLinksRepository` in `ApiImplementation/ShareLinks/`, laid out like `Notes/`. A new `DocumentShareLinksReducer` + view in `DocumentsFeature/DocumentShare/`, presented as a destination from both `DocumentRowReducer` and `DocumentDetailReducer`; `DocumentShareMenu` gains an optional *Share link…* item.

**Tech Stack:** Swift, SwiftUI, The Composable Architecture, swift-dependencies, Get (`APIClient`), Swift Testing, Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-11-18-document-share-links-design.md`

## Global Constraints

- Comments: `//` only, never `///` or `/** */`; only for exceptional reasons (AGENTS.md).
- `@ViewAction` views call `send(…)`, never `store.send(…)`.
- No `.alert`, `.confirmationDialog` or `ConfirmationDialogState`; delete confirmation goes through `@Dependency(\.deleteConfirmation.present)`.
- Every new string goes into `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, `en` and `de`, `"extractionState": "manual"`, keys sorted alphabetically.
- Endpoints: `GET /api/documents/{id}/share_links/`, `POST /api/share_links/` (`document`, `expiration` ISO 8601 or `null`, `file_version` `"archive"`/`"original"`), `DELETE /api/share_links/{id}/`.
- Link URL: `<server url>/share/<slug>`, keeping any subpath prefix. Not a `DeepLink.Route`.
- Expiry choices exactly: 1 day, 7 days, 30 days, Never. Default 7 days. Archived-version toggle default on, shown only when `document.archivedFileName != nil`.
- Menu item visible only when `permissions.can(.addShareLink) && isEditable`. Delete button only when `permissions.can(.deleteShareLink)`.
- Sheet uses `Sheet` / `SheetHeader` / `SheetCloseButton` and `.presentationDetents([.sheet])`.
- Failures surface via `.toast(error)`; a failed initial load shows the empty state with a retry button.
- Tests run against the dev instance: `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` before both `tuist generate` and `tuist test`.

Test command used below (substitute the scheme):

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test <Scheme> -d "iPhone 17 Pro" -o 27.2 --no-selective-testing -- -only-testing:<Scheme>/<Suite>
```

On CI warnings are errors: skim the build output for each touched file.

## Review Focus

1. **Server hosted under a subpath, or with a trailing slash** (`https://h/paperless/`) — the link must be `https://h/paperless/share/<slug>`, never `//share` or missing the prefix. Pinned in Task 1.
2. **Create tapped twice while the request runs** — exactly one link created. Pinned in Task 3 (`isCreating` guard).
3. **List refused with 403** (user can change documents globally but not this one) — the sheet shows retry, the form still works. Pinned in Task 3.
4. **Delete of another user's link fails** — row stays, error toast, no crash. Pinned in Task 3.
5. **Sheet closed while a request is in flight** — no state written after dismissal. Effects use cancellable IDs; pinned in Task 3.

---

### Task 1: Share link API interface

**Files:**
- Create: `Modules/ApiInterface/ShareLinks/ShareLink.swift`
- Create: `Modules/ApiInterface/ShareLinks/CreateShareLinkInput.swift`
- Create: `Modules/ApiInterface/ShareLinks/GetShareLinksUseCase.swift`
- Create: `Modules/ApiInterface/ShareLinks/CreateShareLinkUseCase.swift`
- Create: `Modules/ApiInterface/ShareLinks/DeleteShareLinkUseCase.swift`
- Test: `Modules/ApiInterfaceTests/ShareLinks/ShareLinkTests.swift`
- Test: `Modules/ApiInterfaceTests/ShareLinks/CreateShareLinkInputTests.swift`

**Interfaces:**
- Produces:
  - `public struct ShareLink: Codable, Equatable, Hashable, Identifiable, Sendable` with `typealias Id = Tagged<ShareLink, Int>`, `created: Date`, `expiration: Date?`, `id: Id`, `slug: String`; `static func testValue(created:expiration:id:slug:)`.
  - `public enum ShareLink.FileVersion: String, Codable, Sendable { case archive, original }`.
  - `public extension ShareLink { func url(server: Server) -> URL? }`.
  - `public struct CreateShareLinkInput: Codable, Equatable, Sendable` with `document: Document.Id`, `expiration: Date?`, `fileVersion: ShareLink.FileVersion`; `static func testValue(…)`.
  - `GetShareLinksUseCase.execute(_ documentId: Document.Id, _ server: Server) async throws -> [ShareLink]`, `\.getShareLinks`.
  - `CreateShareLinkUseCase.execute(_ input: CreateShareLinkInput, _ server: Server) async throws -> ShareLink`, `\.createShareLink`.
  - `DeleteShareLinkUseCase.execute(_ id: ShareLink.Id, _ server: Server) async throws -> Void`, `\.deleteShareLink`.
  - All three `@DependencyClient` + `TestDependencyKey`, shaped exactly like `Notes/GetNotesUseCase.swift`.

- [ ] **Step 1: Write the failing tests**

`ShareLinkTests`:
- `decode_withExpiration` — JSON `{"id":3,"created":"2026-11-18T10:00:00.000000+01:00","expiration":"2026-11-25T10:00:00+01:00","slug":"aB3x9Q"}` decodes with the decoder other ApiInterface tests use; `expiration != nil`, `slug == "aB3x9Q"`, `id == 3`.
- `decode_withoutExpiration` — `"expiration": null` → `expiration == nil`.
- `url_rootServer` — server URL `https://paperless.example.com` → `https://paperless.example.com/share/aB3x9Q`.
- `url_subpathServer` — `https://example.com/paperless` → `https://example.com/paperless/share/aB3x9Q`.
- `url_trailingSlash` — `https://example.com/paperless/` → `https://example.com/paperless/share/aB3x9Q`.

`CreateShareLinkInputTests`:
- `encode_never` — `expiration: nil, fileVersion: .original` encodes to JSON containing `"expiration":null`, `"file_version":"original"`, `"document":42`. (Assert `expiration` is present as `null`, not omitted.)
- `encode_withExpiration` — `fileVersion: .archive` → `"file_version":"archive"` and an ISO 8601 `expiration` string.

- [ ] **Step 2: Run, expect FAIL** (`ShareLink` not defined) — scheme `ApiInterfaceTests`.

- [ ] **Step 3: Implement the five files.** Check how `Server` exposes its base URL (`DeepLink.webURL` builds from it) and append `share/<slug>` with `appending(path:)` so the subpath and trailing slash both survive. `CreateShareLinkInput` needs an explicit `encode(to:)` that writes `expiration` with `encodeNil` when nil, if the shared encoder would otherwise omit it; use the same key-strategy and date encoding as other inputs (see `CreateNoteInput` / `BulkEditDocumentsInput`).

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `feat: share link API interface`

### Task 2: Share link repository and live use cases

**Files:**
- Create: `Modules/ApiImplementation/ShareLinks/ShareLinksRepository.swift`
- Create: `Modules/ApiImplementation/ShareLinks/GetShareLinksUseCase.swift`
- Create: `Modules/ApiImplementation/ShareLinks/CreateShareLinkUseCase.swift`
- Create: `Modules/ApiImplementation/ShareLinks/DeleteShareLinkUseCase.swift`
- Test: `Modules/ApiImplementationTests/ShareLinks/ShareLinksRepositoryTests.swift`
- Test: `Modules/ApiImplementationTests/ShareLinks/ShareLinkUseCaseTests.swift`

**Interfaces:**
- Consumes: Task 1 types.
- Produces: `ShareLinksRepository` (`\.shareLinksRepository`) with `createShareLink(input:server:) -> ShareLink`, `deleteShareLink(id:server:) -> Void`, `getShareLinks(documentId:server:) -> [ShareLink]`; live values for the three use cases, each delegating to the repository like `ApiImplementation/Notes/GetNotesUseCase.swift`.

- [ ] **Step 1: Write the failing tests**, mirroring `NotesRepositoryTests` / `NoteUseCaseTests`:
- test-value tests for each repository verb and each use case.
- `test_createGetDelete_roundTrip` tagged `.integrationTests` with `$0.authenticationProvider = .integrationTest; $0.context = .live`: take the first document, create with `expiration: now + 1 day, fileVersion: .original`; `#expect(!created.slug.isEmpty)`; `getShareLinks` contains `created.id`; delete; `getShareLinks` no longer contains it.
- `test_create_never_roundTrip` (integration): create with `expiration: nil`; fetched link has `expiration == nil`; delete it in the test.

- [ ] **Step 2: Run, expect FAIL** — scheme `ApiImplementationTests`.

- [ ] **Step 3: Implement.** Paths and methods from Global Constraints; the create response is a single object, the delete has no body (send a `Request<Void>`).

- [ ] **Step 4: Run, expect PASS** (integration tests against the dev instance included).

- [ ] **Step 5: Commit** — `feat: share link repository`

### Task 3: `DocumentShareLinksReducer`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentShare/DocumentShareLinksReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentShare/DocumentShareLinksExpiry.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentShare/DocumentShareLinksReducerTests.swift`

**Interfaces:**
- Consumes: Task 1 use cases, `\.deleteConfirmation.present`, `Effect.toast`, `ShareItem`.
- Produces:
  - `enum DocumentShareLinksExpiry: CaseIterable, Identifiable { case oneDay, sevenDays, thirtyDays, never }` with `func expiration(from now: Date) -> Date?` (`+1/+7/+30` days via `Calendar`, `nil` for `never`) and a `localized: LocalizedStringResource`.
  - `@Reducer public struct DocumentShareLinksReducer` with
    - `State`: `let documentId: Document.Id`, `let hasArchiveVersion: Bool`, `let server: Server`, `var permissions: ServerPermissions`, `var links: IdentifiedArrayOf<ShareLink>?` (nil = not loaded), `var loadError: String?`, `var isLoading`, `var isCreating`, `var expiry: DocumentShareLinksExpiry = .sevenDays`, `var shareArchiveVersion = true`, `var shareItem: ShareItem?`, `var canDelete: Bool { permissions.can(.deleteShareLink) }`; `init(document: Document, server: Server)` deriving `hasArchiveVersion` from `archivedFileName != nil`; `static func testValue(…)`.
    - `Action`: `binding`, `linksResult(Result<[ShareLink], Error>)`, `createResult(Result<ShareLink, Error>)`, `deleteConfirmed(ShareLink.Id)`, `deleteResult(ShareLink.Id, Result<Void, Error>)`, `delegate(.close)`, `view(.onAppear | .retryButtonTapped | .createButtonTapped | .copyButtonTapped(ShareLink.Id) | .deleteButtonTapped(ShareLink.Id) | .closeButtonTapped)`.
    - `CancelID`: `load`, `create`, `confirmDelete`, `delete`.

- [ ] **Step 1: Write the failing tests** (`@MainActor @Suite(.testDependencies())`, `TestStore`, as in `DocumentNotesReducerTests`):
- `test_onAppear_loadsLinks` — `isLoading` true then links set.
- `test_onAppear_alreadyLoaded_doesNotRefetch`.
- `test_onAppear_failure_setsLoadError` — `loadError` set, `links` stays nil; `retryButtonTapped` loads again.
- `test_create_sevenDaysArchive_sendsInput` — with `\.date.now` fixed, captured input has `document == id`, `expiration == now + 7 days`, `fileVersion == .archive`; on success the link is inserted at index 0 and `shareItem == ShareItem(url: link.url(server:)!)`; `expiry` and `shareArchiveVersion` unchanged.
- `test_create_never_sendsNil` — `expiry = .never` → `expiration == nil`.
- `test_create_noArchive_sendsOriginal` — `hasArchiveVersion = false`, `shareArchiveVersion = true` in state → `fileVersion == .original`.
- `test_create_whileCreating_isIgnored` — `isCreating = true`, `createButtonTapped` → no effect.
- `test_create_failure_toasts` — `isCreating` back to false, list unchanged.
- `test_delete_cancelled_keepsLink` — confirmation returns false → nothing.
- `test_delete_confirmed_removesLink` — confirmation called with the slug as name; link removed after success.
- `test_delete_failure_keepsLinkAndToasts`.
- `test_delete_withoutPermission_isIgnored` — permissions seeded without `deleteShareLink` (see how `DocumentDetailReducerTests` seeds `ServerPermissions`).
- `test_copy_writesPasteboardAndToastsSuccess` — inject the pasteboard through a dependency (add `\.pasteboard` only if the module has none; check `Components` first) and assert the URL string.
- `test_onAppear_linksUnloaded_whenListRefused_formStillCreates` — load fails with 403-like error, `createButtonTapped` still creates and sets `links = [created]`.

- [ ] **Step 2: Run, expect FAIL** — scheme `DocumentsFeatureTests`.

- [ ] **Step 3: Implement.** `createButtonTapped` guards `!isCreating`. On create success when `links == nil`, set `links = [link]`. Delete runs `presentConfirmation(.deleteShareLink, link.slug)` inside `.run`, cancellable by `CancelID.confirmDelete`. Add the `deleteShareLink` key (en *Delete share link*, de *Freigabelink löschen*) and the expiry labels now (en *1 day / 7 days / 30 days / Never*, de *1 Tag / 7 Tage / 30 Tage / Nie*) plus the copy toast (en *Link copied*, de *Link kopiert*).

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `feat: share links reducer`

### Task 4: `DocumentShareLinksView`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentShare/DocumentShareLinksView.swift`
- Create: `Modules/DocumentsFeature/DocumentShare/DocumentShareLinkRow.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentShare/DocumentShareLinksViewTests.swift`

**Interfaces:**
- Consumes: Task 3 `DocumentShareLinksReducer`.
- Produces: `@ViewAction(for: DocumentShareLinksReducer.self) struct DocumentShareLinksView: View` with `init(store:)`.

- [ ] **Step 1: Write the failing snapshot tests**, copying the setup from `DocumentNotesViewTests`: `loaded` (two links, one with expiry, one never), `empty`, `loadError`, `noArchive` (toggle hidden), `withoutDeletePermission` (no trash buttons), `accessibilityXXL` (loaded, at the largest Dynamic Type the other snapshot tests use).

- [ ] **Step 2: Run, expect FAIL**; record snapshots once implemented, then review every image by eye.

- [ ] **Step 3: Implement** to the spec's sketch: `Sheet(isScrollingEnabled:padding:)` with `SheetHeader(title: .shareLinks, left: SheetCloseButton)`; list rows show the URL with `.truncationMode(.middle)` and *Expires in …* (relative date) or *Never expires*; copy (`doc.on.doc`) and trash buttons with accessibility labels; empty text *No share links yet*; error state reusing the `EmptyListView` + retry shape from `DocumentDetailView.errorView`; `Picker` for expiry and `Toggle` *Share archived version* (only when `hasArchiveVersion`); bottom `Button` *Create link* with `.buttonStyle(.primary(isLoading: $store.isCreating))`. `.sheet(item: $store.shareItem) { ShareSheet(url: $0.url) }`. `.presentationDetents([.sheet])`, `.task { await send(.onAppear).finish() }`. All strings en + de.

- [ ] **Step 4: Run, expect PASS.**

- [ ] **Step 5: Commit** — `feat: share links sheet`

### Task 5: Wire into the Share menu, row and detail

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentShare/DocumentShareMenu.swift`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`, `DocumentRowView.swift`, `DocumentRowDestinations.swift`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift`, `DocumentDetailView.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentRow/DocumentRowReducerTests.swift`, `Modules/DocumentsFeatureTests/DocumentDetail/DocumentDetailReducerTests.swift`

**Interfaces:**
- Consumes: Tasks 3–4.
- Produces:
  - `DocumentShareMenu.init(documentId:server:shareLinks: (() -> Void)? = nil, document:)` — the item *Share link…* (`link.badge.plus`, key `shareLink`, de *Freigabelink…*) after *Web link*, only when `shareLinks != nil`.
  - On both reducers: `Destination` gains `case shareLinks(DocumentShareLinksReducer)`, `View` gains `shareLinksButtonTapped`, `State` gains `var canShareLinks: Bool { permissions.can(.addShareLink) && isEditable }` (row: add `isEditable` alongside its existing `canEdit` if it lacks one, honouring its offline-snapshot flag).
  - `.delegate(.close)` from the child sets `destination = nil`.

- [ ] **Step 1: Write the failing tests**, for both reducers:
- `test_shareLinksButtonTapped_presentsSheet` — destination becomes `.shareLinks` with the document id, `hasArchiveVersion` matching the document, the server.
- `test_shareLinksButtonTapped_withoutAddShareLink_isIgnored`.
- `test_shareLinksButtonTapped_withoutChangeDocument_isIgnored`.
- `test_shareLinksButtonTapped_offlineSnapshot_isIgnored`.
- `test_shareLinksClose_dismisses`.

- [ ] **Step 2: Run, expect FAIL.**

- [ ] **Step 3: Implement.** Views pass `shareLinks: store.canShareLinks ? { send(.shareLinksButtonTapped) } : nil`. Present with `.sheet(item: $store.scope(state: \.destination?.shareLinks, action: \.destination.shareLinks)) { DocumentShareLinksView(store: $0) }` — in `DocumentRowDestinations` for the row and next to the detail's existing destinations.

- [ ] **Step 4: Run all `DocumentsFeatureTests`, expect PASS**, and check the build log for warnings in touched files. Re-record any existing snapshot that shows the share menu and review it.

- [ ] **Step 5: Commit** — `feat: share link entry in the share menu`

### Task 6: UI journey

**Files:**
- Create: `Modules/AppUITests/DocumentShareLinkJourneyTests.swift`

**Interfaces:**
- Consumes: the accessibility labels from Task 4 and `Fixtures.uploadDocument(titled:token:)`.

- [ ] **Step 1: Write the journey** following `DocumentBrowsingJourneyTests` setup (per-test user, `UITestConfiguration`): upload a document with the **test user's** token; long-press its row → Share → *Share link…*; pick *Never*; tap *Create link*; the system share sheet appears — dismiss it; one row with *Never expires* is listed; tap delete → confirm in the popup; the list is empty. Delete the uploaded document in `tearDown`.

- [ ] **Step 2: Run it** — scheme `AppUITests`, `-only-testing:AppUITests/DocumentShareLinkJourneyTests`. Expect PASS.

- [ ] **Step 3: Commit** — `test: share link journey`
