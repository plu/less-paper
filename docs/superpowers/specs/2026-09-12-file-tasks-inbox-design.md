# What happened to the documents I sent

A file task list, reached from the inbox's leading toolbar button, showing every import paperless has
run for this account — Failed, Complete, Started, Queued — with the failures counted on the button
itself and dismissable from the list.

## Context

The app can send a document to paperless from three places — the share extension, the import button
and the scanner — and then tells the user nothing. Consumption is asynchronous: paperless answers the
upload immediately with a celery task id and does the work afterwards, so a document that failed OCR,
hit a duplicate check or tripped a workflow simply never appears. The inbox stays as it was, with no
explanation anywhere in the app. `docs/ideas.md` already records the neighbouring half of this
problem ("Refresh lists after an import"), which is about membership; this is about *outcome*.

Paperless answers that question at `/api/tasks/`, and the web UI dedicates a screen to it. The app has
no tasks endpoint at all today, though `Permission` already carries `viewPaperlessTask`,
`changePaperlessTask` and `deletePaperlessTask`.

`InboxView`'s leading toolbar slot is empty — `DocumentListTopLeadingToolbar.swift:31` returns
`EmptyView()` for `.inbox` while `.documents` gets the filter and saved-view menus. That is the slot
this feature fills.

This is the first of two projects. The second polls in the background after an upload and raises a
toast when the document lands or fails. Everything here is shaped so that project needs no
rework — see [What the follow-up inherits](#what-the-follow-up-inherits).

## Decisions

**Only `consume_file` tasks.** The endpoint carries twelve task types, and on the dev instance 958 of
1001 rows are scheduled housekeeping — `train_classifier`, `mail_fetch`, `check_workflows` — that the
user did not start and cannot act on. 43 are imports. The screen is about documents the user sent, so
the other eleven types are filtered out, and a type filter for the curious is a later idea at most.

**Both payload shapes, because the app promises both.** `ApiVersion.minimumSupported` is 8 and
`clientMaximum` is 10, and `/api/tasks/` is a different endpoint at each end of that range. Probed
against paperless 3.0.5 (which advertises API version 10):

| | v9 and below | v10 |
|---|---|---|
| envelope | bare JSON array, unpaginated | `count` / `next` / `results`, `page` and `page_size` honoured |
| file name | `task_file_name` | `input_data.filename` |
| document | `related_document` | `result_data.document_id`, else first of `related_document_ids` |
| status | `SUCCESS`, `FAILURE`, `STARTED`, `PENDING` | `success`, `failure`, `started`, `pending` |
| message | `result`, a human-readable string | `result_data`, an object |
| kind | `task_name` is the task, `type` is the trigger | `task_type` and `trigger_source`, each with a `_display` twin |
| dismiss | `POST /api/acknowledge_tasks/` | `POST /api/tasks/acknowledge/` |

Gating the feature behind v10 was considered and rejected: it would hide the screen from every server
the README tells people is supported. The cost is one extra payload struct and a mapping, which is
smaller than the support burden of a feature that silently is not there.

**One domain model, decided by us, not by the wire.** `FileTask` carries only what the screen needs.
Version-specific payload structs live in `ApiImplementation` and map into it, so no view and no
reducer ever learns which server shape produced a row. `GetSavedViewsUseCase.swift:24` is the
precedent for reading `@Shared(.apiVersion(server))` and branching, including its rule that a version
not yet negotiated reads as the oldest supported one.

**An unknown status can never break a page.** Paperless will add task states. The payload structs
keep `status` as a plain `String`, so no unfamiliar value can fail the decode of a whole list; mapping
to `FileTaskStatus` is a total function whose `default` is `.queued`; and `FileTaskStatus` gets a
lenient `init(from:)` with the same fallback, so a cached value written by a future build of this app
cannot throw either. `.queued` is the deliberate choice of default because it is the one bucket that
raises no alarm and implies no outcome.

On v10 each segment is fetched with `status=<segment>`, so a state neither version knows is *absent*
from all four segments rather than misfiled — the same behaviour the paperless web tabs have. The
failure badge asks for `status=failure` and is unaffected.

**A segmented picker, one group at a time.** Four segments — Failed, Complete, Started, Queued —
matching the web's tabs. No counts in the segment labels: four numbers do not fit an iPhone SE, and
the number that deserves attention is on the toolbar badge where it is actionable.

**The badge counts unacknowledged failures, nothing else.** A failed import is the only state that
asks something of the user. Counting work in flight would give the button a number that changes for
reasons nobody can act on and never settles at zero on a busy server. It also gives swipe-to-dismiss
an obvious purpose: dismissing a failure clears the badge.

**The badge is read from the server, never computed locally.** `refreshFailedFileTaskCount(server:)`
writes `@Shared(.failedFileTaskCount(server))`, copying `refreshStatistics(server:)` exactly. After a
successful dismiss the count is re-read rather than decremented, so the badge cannot drift from the
server, and the background poller of the follow-up project updates the badge by calling the same
function.

**The count comes from the list endpoint, not from `status_counts`.** `/api/tasks/status_counts/`
exists on v10, honours `?task_type=` (undocumented but verified) and reports `needs_attention` — whose
relationship to "unacknowledged failures" is guesswork, and which does not exist on v9 at all. A
`page_size=1` request with `status=failure&acknowledged=false` returns the number in `count`,
unambiguously, and the v9 branch counts the array it has already fetched.

**The sheet never opens onto an empty screen.** The initial segment is `.failed` when the shared
failure count is above zero and `.complete` otherwise: the problem when there is one, the newest
imports when there is not.

**Switching segments reloads.** Caching four lists would flatten into a dictionary-keyed state that is
tedious to assert on, for the benefit of avoiding one 50-row request. On v9 a switch re-downloads the
whole array, which is accepted rather than hidden behind a cache inside the repository — the legacy
path pays a legacy price.

**The list screen does not know what a document detail is.** A tapped row delegates
`openDocument(Document.Id)` upward, and `DocumentListReducer.Action.openDocument` — which exists at
`DocumentListReducer.swift:336` and already handles a document the list has not loaded — does the
rest.

**The button is hidden without `viewPaperlessTask`, and the swipe action without
`changePaperlessTask`.** A button whose only possible outcome is a 403 is worse than no button.
`ServerPermissions.can` answers `true` before anything has been fetched, so a first run gates
nothing — the same behaviour as every other screen.

## Architecture

```
ApiInterface
  Tasks/FileTask                        domain model: id, fileName, status, dates,      [new]
                                        documentId, message, isAcknowledged
  Tasks/FileTaskStatus                  complete | failed | queued | started            [new]
  Tasks/FileTaskPage                    tasks + nextPage, so the reducer never sees     [new]
                                        the pagination difference
  Tasks/GetFileTasksUseCase             (server, status, page) -> FileTaskPage           [new]
  Tasks/GetFailedFileTaskCountUseCase   (server) -> Int                                 [new]
  Tasks/AcknowledgeFileTaskUseCase      (id, server) -> Void                            [new]
  .failedFileTaskCount(server)          new @Shared app-storage key                     [new]
        ^
        |
ApiImplementation
  Tasks/FileTaskRepository              branches on @Shared(.apiVersion(server))         [new]
  Tasks/FileTaskPayloadV9               bare array shape -> FileTask                    [new]
  Tasks/FileTaskPayloadV10              paginated shape -> FileTask                     [new]
  Tasks/RefreshFailedFileTaskCount      free function, shaped like refreshStatistics    [new]
        ^
        |
FileTasksFeature
  FileTaskListReducer                   one segment's page at a time                    [new]
  FileTaskListView                      Sheet + SheetHeader + segmented Picker + List   [new]
  FileTaskRowView                       value view, no per-row reducer                  [new]
  Resources/Localizable.xcstrings        en + de, this module's own                     [new]
        ^
        |
DocumentsFeature
  DocumentListTopLeadingToolbar          .inbox gains the button and its badge           [changed]
  DocumentListReducer                    Destination case .fileTasks, delegate wiring    [changed]
  InboxView                              second .sheet beside the filter one             [changed]
```

`DocumentsFeature` depending on `FileTasksFeature` is the shape `SettingsFeature` already has with
`TrashFeature`. The alternative — building this inside `DocumentsFeature` — was rejected because the
follow-up poller has to outlive the inbox screen, and would then live inside the module whose reducer
it is meant to be independent of.

## Changes

### `FileTaskRepository`

Three calls, each branching once on the negotiated version:

- **list**: v10 sends `task_type=consume_file`, `status=<segment>`, `ordering=-date_created`,
  `page`, `page_size=50` and returns `ListOutput`; v9 and below send `GET /api/tasks/` and filter to
  `task_name == "consume_file"` and the segment's status in memory, sorted newest first, with
  `nextPage: nil` — an unpaginated endpoint has handed over everything it has.
- **failed count**: v10 reads `count` from `status=failure&acknowledged=false&page_size=1`; older
  versions count the filtered array.
- **acknowledge**: `POST /api/tasks/acknowledge/` on v10, `POST /api/acknowledge_tasks/` below, body
  `{"tasks": [id]}` either way.

The failure message is read defensively: v9's `result` is already a string; on v10 `result_data` is an
object whose failure shape is unverified, so the mapping takes any string value it finds, falls back
to the raw JSON, and otherwise leaves the message `nil`. No key is assumed.

### `FileTaskListReducer`

State: `segment`, `tasks: IdentifiedArrayOf<FileTask>`, `nextPage: Int?`, `isLoaded`, `isLoadingMore`,
`isDismissing: Set<FileTask.Id>`, `permissions: ServerPermissions`, `let server: Server`.
`permissions` is stored rather than computed for the reason given at `TrashListReducer.swift:38`:
constructing one reads two files and arms two watchers.

`segment` is bound through `BindingReducer`, and `.binding(\.segment)` cancels the in-flight load and
starts the new one. `onRowAppear` on the last row with a `nextPage` loads the next page, as the
document list does. A dismiss marks the row, posts, removes it on success and calls
`refreshFailedFileTaskCount`; on failure it un-marks the row, toasts, and leaves it where it was.
Errors go through `Effect.toast(error)` and set `isLoaded`, so the empty state appears with pull to
refresh still working.

### `FileTaskListView`

`Sheet(isScrollingEnabled: false)` — scrolling off is what allows the content to be a real `List`,
which `swipeActions` and `refreshable` both require — with a `SheetHeader` titled *File Tasks* and a
`SheetCloseButton`. Below the header, a segmented `Picker` bound to `$store.segment`; below that the
list.

A row shows the file name, the relative time, and a status icon tinted from `DesignTokens`. A failed
row also shows the server's message inline, untruncated, with `.textSelection(.enabled)`: a reason
the user can neither read nor copy is no better than no reason. Rows with a `documentId` are tappable;
queued and started rows are not. The swipe reveals one Dismiss button, present only with
`changePaperlessTask`, disabled while dismissing, and not `role: .destructive` — the trap recorded at
`TrashRowView.swift:44` applies here too.

### Inbox integration

`DocumentListToolbarType.inbox` returns the button instead of `EmptyView()`: a tray icon, badged with
`@Shared(.failedFileTaskCount(server))` when that is above zero, hidden entirely without
`viewPaperlessTask`. That badge is not the tab badge `InboxView` already sets from
`inboxDocumentCount` — two different numbers that must not be conflated.

`refreshFailedFileTaskCount(server:)` is called where statistics already refresh: inbox appear, pull
to refresh, and foreground.

## Testing

**Recorded payloads, both shapes, one assertion.** `ApiImplementationTests/Tasks/FileTaskPayloadTests`
follows `TrashPayloadTests`. The fixtures are real responses for the *same* consume_file tasks, taken
from the dev instance at both `Accept: application/json; version=9` and version 10, and the test
asserts the two decode to identical `FileTask` values. Alongside: an unknown status string maps to
`.queued`, and a failure message is extracted without assuming a `result_data` key.

**Reducer tests** for the behaviours the decisions turn on: a segment switch cancels the in-flight
load, the last row pages, a dismiss marks then removes then re-reads the count, a failed dismiss
restores the row, and the permission flags gate the swipe action.

**Snapshots** at `.iPhone12`: the failed segment with an inline message, the complete segment, the
empty state, and dark mode. Each must differ by hash from its siblings.

**`DocumentsFeatureTests`**: the button is absent without `viewPaperlessTask`, tapping it sets the
destination, `delegate(.openDocument)` pushes the detail, and an `InboxView` snapshot carries the
badge.

**One `AppUITests` journey**, not a harness app: the test user uploads with
`Fixtures.uploadDocument(titled:token:)`, opens File Tasks from the inbox, finds the file under
Complete, and dismisses it.

## What the follow-up inherits

Nothing in the polling-and-toast project needs a change here. It calls the same
`refreshFailedFileTaskCount(server:)` to move the badge, the same `GetFileTasksUseCase` to read a
status, and `Toast` and `ToastPresenter`, which already exist.

The one thing it will need that this project does not build: correlating an upload with *its* task.
`POST /api/documents/post_document/` answers with the celery task id, and
`DocumentsRepository.swift:145` currently discards that response body while `/api/tasks/` accepts a
`task_id` filter. Threading that id out of `CreateDocumentUseCase` is the follow-up's first step, and
it is what lets the toast speak about one document rather than guessing from the newest row.

## Out of scope

- **Background polling and the import toast.** The next project.
- **Task types other than `consume_file`.** Parked in `docs/ideas.md` if it is ever wanted.
- **Dismiss all.** The endpoint takes `{"all": true}`; nothing asks for it yet.
- **Retrying a failed import.** `/api/tasks/run/` exists on v10 only, and a retry that silently does
  nothing on older servers is worse than no retry.
- **Counts in the segment labels.** The badge carries the number that matters.

## Risks

**Two legacy behaviours are read from paperless 2.x source, not probed.** The only instance reachable
from this machine is 3.0.5, where `/api/acknowledge_tasks/` is gone and unknown query parameters are
honoured rather than ignored. So the v9 dismiss path and the assumption that an old server ignores
`task_type=consume_file` (which is why that branch also filters in memory) are both unverified
against a real 2.15.x server. Both are cheap to confirm by running one 2.15.3 container on the host
under its own project name and port; until then the in-memory filter is what keeps the v9 list
correct either way.

**Whether a non-superuser sees only their own tasks is unverified, and the journey depends on it.**
Every UI test runs as its own freshly created user, so if `/api/tasks/` is not owner-scoped the
journey's "find the file I just uploaded" step will be looking at a list full of other users' imports.
`docker:seed`'s permission-scenario users are the cheapest way to check this before the journey is
written.

**The badge's shared key is not in the app group.** `appStorage` keys read
`UserDefaults.standard` per process, the caveat `docs/ideas.md` already records for
`inboxDocumentCount`. Latent for the same reason — only the app writes this key — and it becomes real
the moment the share extension wants to move the badge after an upload, which is exactly what the
follow-up project might want.
