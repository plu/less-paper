# File Task List Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fill the inbox's empty leading toolbar slot with a file task list — Failed, Complete, Started, Queued — badged with the number of unacknowledged failed imports, with swipe-to-dismiss and tap-to-open-document.

**Architecture:** A new `FileTasksFeature` module owns the sheet; `ApiInterface` gains a `FileTask` domain model and three use cases; `ApiImplementation` gains a repository with one function per wire shape, because `/api/tasks/` is a different endpoint at API v9 and v10 and this app supports both. The use cases, not the repository, branch on the negotiated version. `DocumentsFeature` gains one destination and one toolbar button, and reads the badge from a `@Shared` key that a free function refreshes — the same shape `inboxDocumentCount` and `refreshStatistics` already use, so the follow-up background poller needs no change here.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-dependencies, swift-sharing, Tagged, Get (HTTP), swift-snapshot-testing, Swift Testing, Tuist.

**Spec:** `docs/superpowers/specs/2026-09-12-file-tasks-inbox-design.md`

## Global Constraints

- **Comments are `//` only.** Never `///`, never `/** */`, anywhere, including test helpers. Comment only what a reader would otherwise stop and wonder about. See AGENTS.md "Comment Style".
- **Every module owns its strings.** A user-facing string goes in `Modules/<Name>/Resources/Localizable.xcstrings`, in both `en` and `de`, with `"extractionState": "manual"`, keys sorted alphabetically. There is no shared catalogue; two modules needing the same word each get their own key. That duplication is the design.
- **`@ViewAction` views call `send`, never `store.send`** — including inside `.task` and other modifiers.
- **Never `.alert`, `.confirmationDialog` or `ConfirmationDialogState`.** Nothing in this plan needs a confirmation, but if one appears, it goes through `PopupPresenter`.
- **Supported API range: `ApiVersion.minimumSupported` = 8, `ApiVersion.clientMaximum` = 10.** A version not yet negotiated reads as `minimumSupported`, i.e. the older wire shape.
- **`consume_file` is the only task type this feature shows.**
- **Status fallbacks:** unknown status string maps to `.queued`; `revoked` maps to `.failed`.
- **Local test runs need `--no-binary-cache`.** Cached binaries are built on the CI runner and bake its `#filePath` into `URL.projectRoot`, so fixture-reading tests fail for environmental reasons. `mise run ci:test:unit` does *not* help — `--clean` does not clear the binary cache.
- **Run `mise run format` before every commit** and `mise run ci:lint` before the final one. Lint failures mask each other: it is five steps under `set -eou pipefail`.
- **Warnings are errors on CI only.** To reproduce: `TUIST_WARNINGS_AS_ERRORS=true mise exec -- tuist generate --no-open`. It is read at *generate* time.
- **Tests target the dev instance at `http://192.168.64.1:8000`**: export `TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` for both the generate and the test run, or everything fails on connection refused to port 9000.

**The standard local test command**, used by every task below:

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test <Scheme> --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

## File Structure

```
Modules/ApiInterface/Tasks/
  FileTask.swift                        domain model + testValue                        [new, Task 1]
  FileTaskStatus.swift                  4 cases, lenient decoding                       [new, Task 1]
  FileTaskPage.swift                    tasks + nextPage                                [new, Task 1]
  GetFileTasksUseCase.swift             (server, status, page) -> FileTaskPage           [new, Task 3]
  GetFailedFileTaskCountUseCase.swift   (server) -> Int                                 [new, Task 4]
  AcknowledgeFileTaskUseCase.swift      (id, server) -> Void                            [new, Task 5]
Modules/ApiInterface/Extensions/
  SharedReaderKey+Extensions.swift      + .failedFileTaskCount(server)                  [modify, Task 4]
Modules/ApiImplementation/Tasks/
  FileTaskPayloadV9.swift               bare-array shape -> FileTask                    [new, Task 2]
  FileTaskPayloadV10.swift              paginated shape -> FileTask                     [new, Task 2]
  FileTaskRepository.swift              one function per wire shape                     [new, Task 3]
  GetFileTasksUseCase.swift             liveValue, branches on version                  [new, Task 3]
  GetFailedFileTaskCountUseCase.swift   liveValue, branches on version                  [new, Task 4]
  AcknowledgeFileTaskUseCase.swift      liveValue, branches on version                  [new, Task 5]
  RefreshFailedFileTaskCount.swift      free function, shaped like refreshStatistics    [new, Task 4]
Modules/FileTasksFeature/
  FileTaskList/FileTaskListReducer.swift                                                [new, Task 6]
  FileTaskList/FileTaskListReducer+Effect.swift                                         [new, Task 6]
  FileTaskList/FileTaskListReducer+TestValue.swift                                      [new, Task 7]
  FileTaskList/FileTaskListView.swift                                                   [new, Task 7]
  FileTaskList/FileTaskRowView.swift                                                    [new, Task 7]
  Resources/Localizable.xcstrings                                                       [new, Task 7]
Modules/DocumentsFeature/DocumentList/
  DocumentListTopLeadingToolbar.swift   .inbox gains the button + badge                 [modify, Task 8]
  DocumentListReducer.swift             Destination.fileTasks + delegate wiring         [modify, Task 8]
  InboxView.swift                       second .sheet                                   [modify, Task 8]
Modules/DocumentsFeature/Resources/Localizable.xcstrings   + fileTasks keys             [modify, Task 8]
Tuist/ProjectDescriptionHelpers/
  Module.swift                          two enum cases + three switches                 [modify, Task 6]
  Module+Dependencies.swift             two dependency lists                            [modify, Task 6]
```

Tests live beside their module: `Modules/ApiInterfaceTests/Tasks/`, `Modules/ApiImplementationTests/Tasks/`, `Modules/FileTasksFeatureTests/FileTaskList/`, `Modules/DocumentsFeatureTests/DocumentList/`, `Modules/AppUITests/`.

---

### Task 1: `FileTask`, `FileTaskStatus`, `FileTaskPage`

**Files:**
- Create: `Modules/ApiInterface/Tasks/FileTask.swift`
- Create: `Modules/ApiInterface/Tasks/FileTaskStatus.swift`
- Create: `Modules/ApiInterface/Tasks/FileTaskPage.swift`
- Test: `Modules/ApiInterfaceTests/Tasks/FileTaskStatusTests.swift`

**Interfaces:**
- Consumes: `Document.Id` (`Tagged<Document, Int>`), `Date.testValue()` from `TestSupport`.
- Produces: `FileTask` with `id: FileTask.Id`, `fileName: String?`, `status: FileTaskStatus`, `dateCreated: Date`, `dateDone: Date?`, `documentId: Document.Id?`, `message: String?`, `isAcknowledged: Bool`; `FileTask.testValue(...)`; `FileTaskStatus.init?(apiValue: String)`; `FileTaskPage(tasks: [FileTask], nextPage: Int?)`.

No Tuist manifest change: `ApiInterface` and `ApiInterfaceTests` are existing targets and pick new files up through their synchronized folder.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiInterfaceTests/Tasks/FileTaskStatusTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct FileTaskStatusTests {

    @Test
    func initApiValue_readsBothSpellings() {
        #expect(FileTaskStatus(apiValue: "SUCCESS") == .complete)
        #expect(FileTaskStatus(apiValue: "success") == .complete)
        #expect(FileTaskStatus(apiValue: "FAILURE") == .failed)
        #expect(FileTaskStatus(apiValue: "failure") == .failed)
        #expect(FileTaskStatus(apiValue: "STARTED") == .started)
        #expect(FileTaskStatus(apiValue: "started") == .started)
        #expect(FileTaskStatus(apiValue: "PENDING") == .queued)
        #expect(FileTaskStatus(apiValue: "pending") == .queued)
    }

    // A cancelled import is shown under Failed rather than dropped. The paperless web UI hides
    // revoked tasks entirely, and a row that exists on the server but nowhere in the app is the
    // worse of the two answers.
    @Test
    func initApiValue_mapsRevokedToFailed() {
        #expect(FileTaskStatus(apiValue: "REVOKED") == .failed)
        #expect(FileTaskStatus(apiValue: "revoked") == .failed)
    }

    @Test
    func initApiValue_isNilForAnythingElse() {
        #expect(FileTaskStatus(apiValue: "RETRY") == nil)
        #expect(FileTaskStatus(apiValue: "") == nil)
    }

    // Paperless will add task states. A value this app has never heard of must not throw: it reads
    // as queued, the one bucket that raises no alarm and promises no outcome.
    @Test
    func decode_fallsBackToQueued() throws {
        let json = #""not_a_real_status""#
        let status = try JSONDecoder.apiDecoder.decode(
            FileTaskStatus.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(status == .queued)
    }

    @Test
    func decode_roundTripsAKnownValue() throws {
        let json = #""failed""#
        let status = try JSONDecoder.apiDecoder.decode(
            FileTaskStatus.self,
            from: #require(json.data(using: .utf8))
        )

        #expect(status == .failed)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test ApiInterface --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `cannot find 'FileTaskStatus' in scope`.

- [ ] **Step 3: Write `FileTaskStatus`**

Create `Modules/ApiInterface/Tasks/FileTaskStatus.swift`:

```swift
import Foundation

public enum FileTaskStatus: String, CaseIterable, Codable, Equatable, Sendable {
    case complete
    case failed
    case queued
    case started

    // v9 shouts its celery states (SUCCESS), v10 lower-cases them (success), and the rest of the app
    // should never have to know which server it is talking to.
    public init?(apiValue: String) {
        switch apiValue.lowercased() {
        case "success":
            self = .complete
        case "failure", "revoked":
            self = .failed
        case "started":
            self = .started
        case "pending":
            self = .queued
        default:
            return nil
        }
    }

    // Never throws. A status written by a future build of this app, or read from a cache it left
    // behind, must not fail the decode of everything around it.
    public init(from decoder: any Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self = Self(rawValue: raw) ?? Self(apiValue: raw) ?? .queued
    }
}
```

- [ ] **Step 4: Write `FileTask` and `FileTaskPage`**

Create `Modules/ApiInterface/Tasks/FileTask.swift`:

```swift
import Foundation
import Tagged

public struct FileTask: Codable, Equatable, Hashable, Identifiable, Sendable {

    public typealias Id = Tagged<FileTask, Int>

    public let dateCreated: Date

    public let dateDone: Date?

    public let documentId: Document.Id?

    public let fileName: String?

    public let id: Id

    public let isAcknowledged: Bool

    // Whatever the server said about the outcome. v9 sends prose even on success, v10 sends nothing
    // at all there, so this is mapped as it arrives and only the failed rows display it.
    public let message: String?

    public let status: FileTaskStatus

    public init(
        dateCreated: Date,
        dateDone: Date?,
        documentId: Document.Id?,
        fileName: String?,
        id: Id,
        isAcknowledged: Bool,
        message: String?,
        status: FileTaskStatus
    ) {
        self.dateCreated = dateCreated
        self.dateDone = dateDone
        self.documentId = documentId
        self.fileName = fileName
        self.id = id
        self.isAcknowledged = isAcknowledged
        self.message = message
        self.status = status
    }
}

public extension FileTask {

    static func testValue(
        dateCreated: Date = .testValue(),
        dateDone: Date? = .testValue(),
        documentId: Document.Id? = 42,
        fileName: String? = "invoice.pdf",
        id: Id = 1,
        isAcknowledged: Bool = false,
        message: String? = nil,
        status: FileTaskStatus = .complete
    ) -> Self {
        .init(
            dateCreated: dateCreated,
            dateDone: dateDone,
            documentId: documentId,
            fileName: fileName,
            id: id,
            isAcknowledged: isAcknowledged,
            message: message,
            status: status
        )
    }
}
```

Create `Modules/ApiInterface/Tasks/FileTaskPage.swift`:

```swift
import Foundation

// One page of file tasks, whatever the server's idea of a page is. v10 paginates and answers with a
// next page number; v9 has no pagination at all and always answers nil, because it has already
// handed over everything it has.
public struct FileTaskPage: Equatable, Sendable {

    public let nextPage: Int?

    public let tasks: [FileTask]

    public init(
        nextPage: Int? = nil,
        tasks: [FileTask] = []
    ) {
        self.nextPage = nextPage
        self.tasks = tasks
    }
}

public extension FileTaskPage {

    static func testValue(
        nextPage: Int? = nil,
        tasks: [FileTask] = [.testValue()]
    ) -> Self {
        .init(
            nextPage: nextPage,
            tasks: tasks
        )
    }
}
```

- [ ] **Step 5: Run the test and watch it pass**

```bash
mise exec -- tuist test ApiInterface --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, five tests in `FileTaskStatusTests`.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/ApiInterface/Tasks Modules/ApiInterfaceTests/Tasks
git commit -m "feat: add a FileTask domain model whose status cannot break on a new server"
```

---

### Task 2: the two payload shapes

**Files:**
- Create: `Modules/ApiImplementation/Tasks/FileTaskPayloadV9.swift`
- Create: `Modules/ApiImplementation/Tasks/FileTaskPayloadV10.swift`
- Test: `Modules/ApiImplementationTests/Tasks/FileTaskPayloadTests.swift`

**Interfaces:**
- Consumes: `FileTask`, `FileTaskStatus`, `FileTaskPage`, `JSONValue` (`Modules/ApiInterface/Shared/JSONValue.swift`, with `objectValue`, `stringValue`, `intValue`), `ListOutput<Element, Id>` (`count`, `next`, `results`).
- Produces: `FileTaskPayloadV9` with `let isConsumeFile: Bool` and `var asFileTask: FileTask`; `FileTaskPayloadV10` with `var asFileTask: FileTask`; `typealias FileTaskListOutputV10 = ListOutput<FileTaskPayloadV10, FileTask.Id>`.

Both payloads are `Decodable` only — nothing posts a task — and rely on the api decoder's
`convertFromSnakeCase`, so `task_file_name` arrives as `taskFileName`.

- [ ] **Step 1: Write the failing test with the recorded payloads**

These are real responses from paperless 3.0.5, the same two consume_file tasks requested twice with
different `Accept` headers. Create `Modules/ApiImplementationTests/Tasks/FileTaskPayloadTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import CustomDump
import Foundation
import Testing
import TestSupport

@Suite
struct FileTaskPayloadTests {

    // GET /api/tasks/?task_type=consume_file with `Accept: application/json; version=9`, recorded
    // from a paperless 3.0.5 instance. No envelope: v9 answers with a bare array and ignores
    // page_size entirely.
    private static let recordedV9 = """
    [
        {
            "id": 267,
            "task_id": "04c46ed1-fe50-45f6-a623-f14ce8dd9a4c",
            "task_name": "consume_file",
            "task_file_name": "test.pdf",
            "type": "manual_task",
            "status": "SUCCESS",
            "date_created": "2026-09-08T14:48:16.989002+02:00",
            "date_done": "2026-09-08T14:48:17.130038+02:00",
            "result": "Success. New document id 43 created",
            "acknowledged": false,
            "related_document": 43,
            "duplicate_documents": [],
            "owner": 2
        },
        {
            "id": 1001,
            "task_id": "80d96522-269a-43c7-a230-0060d9b8e82f",
            "task_name": "check_workflows",
            "task_file_name": null,
            "type": "scheduled_task",
            "status": "SUCCESS",
            "date_created": "2026-09-12T09:05:00.014703+02:00",
            "date_done": "2026-09-12T09:05:00.326820+02:00",
            "result": null,
            "acknowledged": false,
            "related_document": null,
            "duplicate_documents": [],
            "owner": null
        }
    ]
    """

    // The same task 267, requested at version 10. Different envelope, different field names, and a
    // result that is an object rather than prose.
    private static let recordedV10 = """
    {
        "count": 43,
        "next": "http://192.168.64.1:8000/api/tasks/?ordering=-date_created&page=2&page_size=2&task_type=consume_file",
        "previous": null,
        "results": [
            {
                "id": 267,
                "task_id": "04c46ed1-fe50-45f6-a623-f14ce8dd9a4c",
                "task_type": "consume_file",
                "task_type_display": "Consume File",
                "trigger_source": "api_upload",
                "trigger_source_display": "API Upload",
                "status": "success",
                "status_display": "Success",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "date_started": "2026-09-08T14:48:16.992843+02:00",
                "date_done": "2026-09-08T14:48:17.130038+02:00",
                "duration_seconds": 0.137195,
                "wait_time_seconds": 0.003841,
                "input_data": {
                    "filename": "test.pdf",
                    "mime_type": "text/plain",
                    "overrides": {
                        "filename": "test.pdf",
                        "title": "Bulk Edit Set Storage Path Test F5E951B9-7ABA-4484-AF18-CB71E3F48EFE",
                        "created": "2026-09-08",
                        "owner_id": 2,
                        "skip_asn_if_exists": false
                    }
                },
                "result_data": {
                    "document_id": 43
                },
                "related_document_ids": [
                    43
                ],
                "acknowledged": false,
                "owner": 2
            }
        ]
    }
    """

    // The failure shape is the one thing that could not be recorded: the dev instance has no failed
    // consume task. result_data's failure keys are therefore a guess, and the mapping must not
    // depend on them - any string in the object will do.
    private static let syntheticFailureV10 = """
    {
        "count": 1,
        "next": null,
        "previous": null,
        "results": [
            {
                "id": 300,
                "task_id": "11111111-2222-3333-4444-555555555555",
                "task_type": "consume_file",
                "task_type_display": "Consume File",
                "trigger_source": "api_upload",
                "trigger_source_display": "API Upload",
                "status": "failure",
                "status_display": "Failure",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "date_started": "2026-09-08T14:48:16.992843+02:00",
                "date_done": "2026-09-08T14:48:17.130038+02:00",
                "duration_seconds": 0.1,
                "wait_time_seconds": 0.1,
                "input_data": { "filename": "broken.pdf" },
                "result_data": { "error": "not a valid pdf" },
                "related_document_ids": [],
                "acknowledged": false,
                "owner": 2
            }
        ]
    }
    """

    private func decodeV9() throws -> [FileTaskPayloadV9] {
        try JSONDecoder.apiDecoder.decode(
            [FileTaskPayloadV9].self,
            from: #require(Self.recordedV9.data(using: .utf8))
        )
    }

    private func decodeV10(_ json: String) throws -> FileTaskListOutputV10 {
        try JSONDecoder.apiDecoder.decode(
            FileTaskListOutputV10.self,
            from: #require(json.data(using: .utf8))
        )
    }

    // The whole point of two payload structs: the same task, read off two different wires, is the
    // same row to everything above this layer.
    @Test
    func bothVersions_agreeOnEverythingTheScreenShows() throws {
        let v9 = try #require(decodeV9().first).asFileTask
        let v10 = try #require(try decodeV10(Self.recordedV10).results.first).asFileTask

        #expect(v9.id == v10.id)
        #expect(v9.fileName == v10.fileName)
        #expect(v9.status == v10.status)
        #expect(v9.dateCreated == v10.dateCreated)
        #expect(v9.dateDone == v10.dateDone)
        #expect(v9.documentId == v10.documentId)
        #expect(v9.isAcknowledged == v10.isAcknowledged)
    }

    @Test
    func v9_mapsTheRecordedConsumeTask() throws {
        let task = try #require(decodeV9().first).asFileTask

        #expect(task.id == 267)
        #expect(task.fileName == "test.pdf")
        #expect(task.status == .complete)
        #expect(task.documentId == 43)
        #expect(task.isAcknowledged == false)
        #expect(task.message == "Success. New document id 43 created")
    }

    // Old servers have no task_type filter to honour, so the client has to recognise its own rows.
    @Test
    func v9_marksOnlyConsumeFileTasks() throws {
        let payloads = try decodeV9()

        #expect(payloads.map(\.isConsumeFile) == [true, false])
    }

    @Test
    func v10_mapsTheRecordedConsumeTask() throws {
        let output = try decodeV10(Self.recordedV10)
        let task = try #require(output.results.first).asFileTask

        #expect(task.id == 267)
        #expect(task.fileName == "test.pdf")
        #expect(task.status == .complete)
        #expect(task.documentId == 43)
        #expect(task.isAcknowledged == false)
        #expect(output.count == 43)
    }

    // v9 sends prose even on success; v10 sends none. Asserted rather than smoothed over, because a
    // future reader will otherwise "fix" the difference.
    @Test
    func v10_hasNoMessageForASuccess() throws {
        let task = try #require(try decodeV10(Self.recordedV10).results.first).asFileTask

        #expect(task.message == nil)
    }

    @Test
    func v10_readsAFailureMessageWithoutKnowingItsKey() throws {
        let task = try #require(try decodeV10(Self.syntheticFailureV10).results.first).asFileTask

        #expect(task.status == .failed)
        #expect(task.fileName == "broken.pdf")
        #expect(task.documentId == nil)
        #expect(task.message == "not a valid pdf")
    }

    @Test
    func unknownStatus_readsAsQueued() throws {
        let json = """
        [
            {
                "id": 1,
                "task_id": "x",
                "task_name": "consume_file",
                "task_file_name": "a.pdf",
                "type": "manual_task",
                "status": "SOMETHING_NEW",
                "date_created": "2026-09-08T14:48:16.989002+02:00",
                "date_done": null,
                "result": null,
                "acknowledged": false,
                "related_document": null,
                "duplicate_documents": [],
                "owner": 2
            }
        ]
        """
        let payloads = try JSONDecoder.apiDecoder.decode(
            [FileTaskPayloadV9].self,
            from: #require(json.data(using: .utf8))
        )

        #expect(try #require(payloads.first).asFileTask.status == .queued)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `cannot find 'FileTaskPayloadV9' in scope`.

- [ ] **Step 3: Write the v9 payload**

Create `Modules/ApiImplementation/Tasks/FileTaskPayloadV9.swift`:

```swift
import ApiInterface
import Foundation

// GET /api/tasks/ as answered by API version 9 and below: a bare array, no pagination, no filtering
// to rely on. `type` here is the trigger (manual_task, auto_task, scheduled_task) and `task_name` is
// the task - v10 swaps those names round, which is the trap this struct exists to absorb.
struct FileTaskPayloadV9: Decodable {

    let acknowledged: Bool

    let dateCreated: Date

    let dateDone: Date?

    let id: FileTask.Id

    let relatedDocument: Document.Id?

    let result: String?

    let status: String

    let taskFileName: String?

    let taskName: String?
}

extension FileTaskPayloadV9 {

    var isConsumeFile: Bool {
        taskName == "consume_file"
    }

    var asFileTask: FileTask {
        FileTask(
            dateCreated: dateCreated,
            dateDone: dateDone,
            documentId: relatedDocument,
            fileName: taskFileName,
            id: id,
            isAcknowledged: acknowledged,
            message: result,
            status: FileTaskStatus(apiValue: status) ?? .queued
        )
    }
}
```

- [ ] **Step 4: Write the v10 payload**

Create `Modules/ApiImplementation/Tasks/FileTaskPayloadV10.swift`:

```swift
import ApiInterface
import Foundation

typealias FileTaskListOutputV10 = ListOutput<FileTaskPayloadV10, FileTask.Id>

// GET /api/tasks/ as answered by API version 10: paginated, and with the interesting parts moved into
// two free-form JSON objects. `inputData` carries the file name, `resultData` the outcome.
struct FileTaskPayloadV10: Codable, Equatable, Sendable {

    let acknowledged: Bool

    let dateCreated: Date

    let dateDone: Date?

    let id: FileTask.Id

    let inputData: JSONValue?

    let relatedDocumentIds: [Document.Id]

    let resultData: JSONValue?

    let status: String
}

extension FileTaskPayloadV10 {

    var asFileTask: FileTask {
        FileTask(
            dateCreated: dateCreated,
            dateDone: dateDone,
            documentId: documentId,
            fileName: inputData?.objectValue?["filename"]?.stringValue,
            id: id,
            isAcknowledged: acknowledged,
            message: message,
            status: FileTaskStatus(apiValue: status) ?? .queued
        )
    }

    // `configureForApi` sets convertFromSnakeCase, which rewrites the keys inside a decoded
    // [String: JSONValue] as well - so the server's `document_id` arrives as `documentId`. Both
    // spellings are accepted rather than betting on that behaviour surviving a Foundation update.
    private var documentId: Document.Id? {
        let fromResult = resultData?.objectValue?["documentId"]?.intValue
            ?? resultData?.objectValue?["document_id"]?.intValue

        if let fromResult {
            return Document.Id(rawValue: fromResult)
        }
        return relatedDocumentIds.first
    }

    // No failed consume task could be recorded to learn the real key from, so nothing is assumed:
    // the first string in the object is the message. A success has none, which is correct - only
    // failed rows show this.
    private var message: String? {
        guard let object = resultData?.objectValue else {
            return resultData?.stringValue
        }
        return object
            .sorted { $0.key < $1.key }
            .compactMap { $0.value.stringValue }
            .first
    }
}
```

- [ ] **Step 5: Run the test and watch it pass**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, eight tests in `FileTaskPayloadTests`. If `v10_mapsTheRecordedConsumeTask` fails on
`documentId`, the dictionary-key conversion described in the comment is not happening — keep both
lookups and move on; the test is the arbiter, not the comment.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/ApiImplementation/Tasks Modules/ApiImplementationTests/Tasks
git commit -m "feat: decode both shapes of the paperless tasks endpoint into one row"
```

---

### Task 3: listing file tasks

**Files:**
- Create: `Modules/ApiInterface/Tasks/GetFileTasksUseCase.swift`
- Create: `Modules/ApiImplementation/Tasks/FileTaskRepository.swift`
- Create: `Modules/ApiImplementation/Tasks/GetFileTasksUseCase.swift`
- Test: `Modules/ApiImplementationTests/Tasks/GetFileTasksUseCaseTests.swift`

**Interfaces:**
- Consumes: `FileTaskPayloadV9`, `FileTaskPayloadV10`, `FileTaskListOutputV10` (Task 2); `FileTaskPage` (Task 1); `APIClient.client(server:)`, `ApiVersion.minimumSupported`, `@Shared(.apiVersion(server))`.
- Produces: `GetFileTasksUseCase.execute(server:status:page:) async throws -> FileTaskPage`, reachable as `@Dependency(\.getFileTasks)`; `FileTaskRepository` with `getFileTasksV9(server:)`, `getFileTasksV10(status:page:server:)`, `getFailedFileTaskCountV10(server:)` (used in Task 4), `acknowledgeFileTask(id:server:)` and `acknowledgeFileTaskLegacy(id:server:)` (used in Task 5), reachable as `@Dependency(\.fileTaskRepository)`.

The whole repository is written here, in one file, so Tasks 4 and 5 only add use cases. Its functions
are version-explicit on purpose: the branch belongs in the use cases, where a test can reach it.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/Tasks/GetFileTasksUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetFileTasksUseCaseTests {

    @Test
    func execute_onVersion10_asksTheServerToFilterAndPage() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        let askedFor = LockIsolated<(FileTaskStatus, Int)?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV10 = { status, page, _ in
                askedFor.setValue((status, page))
                return .init(
                    count: 43,
                    next: .testValue(string: "http://host/api/tasks/?page=2"),
                    results: [.testValue(id: 1)]
                )
            }
        } operation: {
            let page = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .failed,
                page: 1
            )

            #expect(page.tasks.map(\.id) == [1])
            #expect(page.nextPage == 2)
        }

        #expect(askedFor.value?.0 == .failed)
        #expect(askedFor.value?.1 == 1)
    }

    @Test
    func execute_onVersion10_reportsNoNextPageOnTheLastOne() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV10 = { _, _, _ in
                .init(count: 1, next: nil, results: [.testValue(id: 1)])
            }
        } operation: {
            let page = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .complete,
                page: 1
            )

            #expect(page.nextPage == nil)
        }
    }

    // An old server cannot filter or page, so the use case does both jobs itself: consume tasks
    // only, this status only, newest first, and nothing left to fetch.
    @Test
    func execute_onVersion9_filtersSortsAndClaimsNoNextPage() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        let v10Requested = LockIsolated(false)

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV10 = { _, _, _ in
                v10Requested.setValue(true)
                return .init()
            }
            $0.fileTaskRepository.getFileTasksV9 = { _ in
                [
                    .testValue(id: 1, dateCreated: .testValue(), status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 2, dateCreated: .testValue(adding: 60), status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 3, status: "FAILURE", taskName: "train_classifier"),
                    .testValue(id: 4, status: "SUCCESS", taskName: "consume_file")
                ]
            }
        } operation: {
            let page = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .failed,
                page: 1
            )

            #expect(page.tasks.map(\.id) == [2, 1])
            #expect(page.nextPage == nil)
        }

        #expect(!v10Requested.value)
    }

    // Nothing negotiated yet reads as the oldest supported server: the newer shape has to be earned
    // by a version this app has actually seen.
    @Test
    func execute_withNoNegotiatedVersion_usesTheOlderShape() async throws {
        let server = Server.testValue()
        let v9Requested = LockIsolated(false)

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV9 = { _ in
                v9Requested.setValue(true)
                return []
            }
        } operation: {
            _ = try await GetFileTasksUseCase.liveValue.execute(
                server: server,
                status: .complete,
                page: 1
            )
        }

        #expect(v9Requested.value)
    }
}
```

This needs a `testValue` on each payload. Add them in the same step, in
`Modules/ApiImplementationTests/Tasks/FileTaskPayloadTestValues.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Foundation
import TestSupport

extension FileTaskPayloadV9 {

    static func testValue(
        acknowledged: Bool = false,
        dateCreated: Date = .testValue(),
        dateDone: Date? = .testValue(),
        id: FileTask.Id = 1,
        relatedDocument: Document.Id? = 42,
        result: String? = nil,
        status: String = "SUCCESS",
        taskFileName: String? = "invoice.pdf",
        taskName: String? = "consume_file"
    ) -> Self {
        .init(
            acknowledged: acknowledged,
            dateCreated: dateCreated,
            dateDone: dateDone,
            id: id,
            relatedDocument: relatedDocument,
            result: result,
            status: status,
            taskFileName: taskFileName,
            taskName: taskName
        )
    }
}

extension FileTaskPayloadV10 {

    static func testValue(
        acknowledged: Bool = false,
        dateCreated: Date = .testValue(),
        dateDone: Date? = .testValue(),
        id: FileTask.Id = 1,
        inputData: JSONValue? = .object(["filename": .string("invoice.pdf")]),
        relatedDocumentIds: [Document.Id] = [42],
        resultData: JSONValue? = nil,
        status: String = "success"
    ) -> Self {
        .init(
            acknowledged: acknowledged,
            dateCreated: dateCreated,
            dateDone: dateDone,
            id: id,
            inputData: inputData,
            relatedDocumentIds: relatedDocumentIds,
            resultData: resultData,
            status: status
        )
    }
}
```

Check whether `Date.testValue(adding:)` exists in `TestSupport`; if it does not, use
`Date.testValue().addingTimeInterval(60)` in the sort assertion instead and drop the parameter.

- [ ] **Step 2: Run the test and watch it fail**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `cannot find 'GetFileTasksUseCase' in scope`.

- [ ] **Step 3: Declare the use case in `ApiInterface`**

Create `Modules/ApiInterface/Tasks/GetFileTasksUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetFileTasksUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server,
        _ status: FileTaskStatus,
        _ page: Int
    ) async throws -> FileTaskPage
}

extension GetFileTasksUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _, _ in .testValue() }
    )

    public static let testValue = Self(
        execute: { _, _, _ in .testValue() }
    )
}

public extension DependencyValues {

    var getFileTasks: GetFileTasksUseCase {
        get { self[GetFileTasksUseCase.self] }
        set { self[GetFileTasksUseCase.self] = newValue }
    }
}
```

- [ ] **Step 4: Write the repository**

Create `Modules/ApiImplementation/Tasks/FileTaskRepository.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

// One function per wire shape, and no idea which server it is talking to. The version branch lives in
// the use cases, where a test can stub this and assert which call was made.
@DependencyClient
struct FileTaskRepository: Sendable {

    var acknowledgeFileTask: @Sendable (
        _ id: FileTask.Id,
        _ server: Server
    ) async throws -> Void

    var acknowledgeFileTaskLegacy: @Sendable (
        _ id: FileTask.Id,
        _ server: Server
    ) async throws -> Void

    var getFailedFileTaskCountV10: @Sendable (
        _ server: Server
    ) async throws -> Int

    var getFileTasksV10: @Sendable (
        _ status: FileTaskStatus,
        _ page: Int,
        _ server: Server
    ) async throws -> FileTaskListOutputV10

    var getFileTasksV9: @Sendable (
        _ server: Server
    ) async throws -> [FileTaskPayloadV9]
}

extension FileTaskRepository: TestDependencyKey {

    static let previewValue = Self(
        acknowledgeFileTask: { _, _ in },
        acknowledgeFileTaskLegacy: { _, _ in },
        getFailedFileTaskCountV10: { _ in 0 },
        getFileTasksV10: { _, _, _ in .init() },
        getFileTasksV9: { _ in [] }
    )

    static let testValue = Self(
        acknowledgeFileTask: { _, _ in },
        acknowledgeFileTaskLegacy: { _, _ in },
        getFailedFileTaskCountV10: { _ in 0 },
        getFileTasksV10: { _, _, _ in .init() },
        getFileTasksV9: { _ in [] }
    )
}

extension FileTaskRepository: DependencyKey {

    static let liveValue = Self(
        acknowledgeFileTask: { id, server in
            try await acknowledge(id: id, path: "/api/tasks/acknowledge/", server: server)
        },
        acknowledgeFileTaskLegacy: { id, server in
            try await acknowledge(id: id, path: "/api/acknowledge_tasks/", server: server)
        },
        getFailedFileTaskCountV10: getFailedFileTaskCountV10(server:),
        getFileTasksV10: getFileTasksV10(status:page:server:),
        getFileTasksV9: getFileTasksV9(server:)
    )
}

extension DependencyValues {

    var fileTaskRepository: FileTaskRepository {
        get { self[FileTaskRepository.self] }
        set { self[FileTaskRepository.self] = newValue }
    }
}

private extension FileTaskRepository {

    static let pageSize = 50

    struct AcknowledgeBody: Encodable {
        let tasks: [FileTask.Id]
    }

    // Only the ids are read; the page exists to carry `count`.
    struct CountOutput: Decodable {
        let count: Int
    }

    static func acknowledge(
        id: FileTask.Id,
        path: String,
        server: Server
    ) async throws {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: path,
                method: .post,
                body: AcknowledgeBody(tasks: [id])
            ))
            .value
    }

    static func getFailedFileTaskCountV10(server: Server) async throws -> Int {
        try await APIClient
            .client(server: server)
            .send(Request<CountOutput>(
                path: "/api/tasks/",
                method: .get,
                query: [
                    ("task_type", "consume_file"),
                    ("status", "failure"),
                    ("acknowledged", "false"),
                    ("page_size", "1")
                ]
            ))
            .value
            .count
    }

    static func getFileTasksV10(
        status: FileTaskStatus,
        page: Int,
        server: Server
    ) async throws -> FileTaskListOutputV10 {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tasks/",
                method: .get,
                query: [
                    ("task_type", "consume_file"),
                    ("status", status.apiQueryValue),
                    ("ordering", "-date_created"),
                    ("page", String(page)),
                    ("page_size", String(pageSize))
                ]
            ))
            .value
    }

    // No query at all: an old server has no filters to honour, and sending some would only make the
    // request look like it was filtered.
    static func getFileTasksV9(server: Server) async throws -> [FileTaskPayloadV9] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/tasks/",
                method: .get
            ))
            .value
    }
}
```

- [ ] **Step 5: Write the version branch**

Add the query spelling to `Modules/ApiInterface/Tasks/FileTaskStatus.swift`:

```swift
public extension FileTaskStatus {

    // What v10 calls this status in a `?status=` filter. The reverse of init(apiValue:), and lower
    // case because v10 rejects the shouted spelling.
    var apiQueryValue: String {
        switch self {
        case .complete:
            "success"
        case .failed:
            "failure"
        case .queued:
            "pending"
        case .started:
            "started"
        }
    }
}
```

Create `Modules/ApiImplementation/Tasks/GetFileTasksUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

extension GetFileTasksUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:status:page:)
    )
}

private extension GetFileTasksUseCase {

    static func execute(
        server: Server,
        status: FileTaskStatus,
        page: Int
    ) async throws -> FileTaskPage {
        @Dependency(\.fileTaskRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        // Not yet negotiated reads as the oldest server this app supports, the same rule
        // GetSavedViewsUseCase follows: the newer shape is earned by a version we have seen.
        let version = apiVersion ?? ApiVersion.minimumSupported

        guard version >= 10 else {
            let payloads = try await repository.getFileTasksV9(server)
            let tasks = payloads
                .filter(\.isConsumeFile)
                .map(\.asFileTask)
                .filter { $0.status == status }
                .sorted { $0.dateCreated > $1.dateCreated }

            // An unpaginated endpoint has already handed over everything it has.
            return FileTaskPage(nextPage: nil, tasks: tasks)
        }

        let output = try await repository.getFileTasksV10(status, page, server)

        return FileTaskPage(
            nextPage: output.next == nil ? nil : page + 1,
            tasks: output.results.map(\.asFileTask)
        )
    }
}
```

- [ ] **Step 6: Run the test and watch it pass**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, four tests in `GetFileTasksUseCaseTests`, and Task 2's eight still green.

- [ ] **Step 7: Format and commit**

```bash
mise run format
git add Modules/ApiInterface/Tasks Modules/ApiImplementation/Tasks Modules/ApiImplementationTests/Tasks
git commit -m "feat: read consume tasks from either shape of the tasks endpoint"
```

---

### Task 4: the failed count, and the shared key behind the badge

**Files:**
- Create: `Modules/ApiInterface/Tasks/GetFailedFileTaskCountUseCase.swift`
- Create: `Modules/ApiImplementation/Tasks/GetFailedFileTaskCountUseCase.swift`
- Create: `Modules/ApiImplementation/Tasks/RefreshFailedFileTaskCount.swift`
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` (add beside `inboxDocumentCount`, around line 192)
- Test: `Modules/ApiImplementationTests/Tasks/GetFailedFileTaskCountUseCaseTests.swift`

**Interfaces:**
- Consumes: `FileTaskRepository.getFailedFileTaskCountV10`, `FileTaskRepository.getFileTasksV9` (Task 3); `FileTaskPayloadV9.isConsumeFile`, `.asFileTask` (Task 2).
- Produces: `@Shared(.failedFileTaskCount(server))` of type `Int` defaulting to `0`; `GetFailedFileTaskCountUseCase.execute(server:) async throws -> Int` as `@Dependency(\.getFailedFileTaskCount)`; `func refreshFailedFileTaskCount(server: Server) async` in `ApiImplementation`.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/Tasks/GetFailedFileTaskCountUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct GetFailedFileTaskCountUseCaseTests {

    @Test
    func execute_onVersion10_readsTheCountFromTheServer() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        try await withDependencies {
            $0.fileTaskRepository.getFailedFileTaskCountV10 = { _ in 3 }
        } operation: {
            let count = try await GetFailedFileTaskCountUseCase.liveValue.execute(server: server)

            #expect(count == 3)
        }
    }

    // Only unacknowledged failures count: a dismissed failure is one the user has dealt with, and
    // the badge is there to ask for something.
    @Test
    func execute_onVersion9_countsUnacknowledgedFailedConsumeTasks() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        try await withDependencies {
            $0.fileTaskRepository.getFileTasksV9 = { _ in
                [
                    .testValue(id: 1, status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 2, status: "FAILURE", taskName: "consume_file"),
                    .testValue(acknowledged: true, id: 3, status: "FAILURE", taskName: "consume_file"),
                    .testValue(id: 4, status: "SUCCESS", taskName: "consume_file"),
                    .testValue(id: 5, status: "FAILURE", taskName: "train_classifier")
                ]
            }
        } operation: {
            let count = try await GetFailedFileTaskCountUseCase.liveValue.execute(server: server)

            #expect(count == 2)
        }
    }

    @Test
    func refresh_writesTheSharedCount() async throws {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int

        #expect(failedFileTaskCount == 0)

        await withDependencies {
            $0.getFailedFileTaskCount.execute = { _ in 7 }
        } operation: {
            await refreshFailedFileTaskCount(server: server)
        }

        #expect(failedFileTaskCount == 7)
    }

    // A server that cannot answer must not blank the badge: the last known number is better than a
    // zero that means "we could not ask".
    @Test
    func refresh_leavesTheCountAloneOnFailure() async throws {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 4 }

        await withDependencies {
            $0.getFailedFileTaskCount.execute = { _ in throw ApiError.testValue() }
        } operation: {
            await refreshFailedFileTaskCount(server: server)
        }

        #expect(failedFileTaskCount == 4)
    }
}
```

Check what `ApiError` offers — if it has no `testValue()`, throw
`APIError.unacceptableStatusCode(500)` or any error already used in neighbouring tests.

- [ ] **Step 2: Run the test and watch it fail**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `cannot find 'GetFailedFileTaskCountUseCase' in scope`.

- [ ] **Step 3: Add the shared key**

In `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, extend the existing
`AppStorageKey<Int>.Default` block that holds `inboxDocumentCount`:

```swift
    static func failedFileTaskCount(_ server: Server) -> Self {
        Self[
            .appStorage("\(server.id)-failed-file-task-count"),
            default: 0
        ]
    }
```

- [ ] **Step 4: Declare the use case**

Create `Modules/ApiInterface/Tasks/GetFailedFileTaskCountUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetFailedFileTaskCountUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Int
}

extension GetFailedFileTaskCountUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in 0 }
    )

    public static let testValue = Self(
        execute: { _ in 0 }
    )
}

public extension DependencyValues {

    var getFailedFileTaskCount: GetFailedFileTaskCountUseCase {
        get { self[GetFailedFileTaskCountUseCase.self] }
        set { self[GetFailedFileTaskCountUseCase.self] = newValue }
    }
}
```

- [ ] **Step 5: Implement the use case and the refresh function**

Create `Modules/ApiImplementation/Tasks/GetFailedFileTaskCountUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

extension GetFailedFileTaskCountUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetFailedFileTaskCountUseCase {

    static func execute(server: Server) async throws -> Int {
        @Dependency(\.fileTaskRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        let version = apiVersion ?? ApiVersion.minimumSupported

        guard version >= 10 else {
            return try await repository.getFileTasksV9(server)
                .filter(\.isConsumeFile)
                .map(\.asFileTask)
                .filter { $0.status == .failed && !$0.isAcknowledged }
                .count
        }

        // status_counts/ exists here and would be one smaller request, but its `needs_attention` is
        // not documented as "unacknowledged failures" and does not exist on v9 at all. `count` off a
        // one-row page answers exactly the question being asked.
        return try await repository.getFailedFileTaskCountV10(server)
    }
}
```

Create `Modules/ApiImplementation/Tasks/RefreshFailedFileTaskCount.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

// Shaped like refreshStatistics: fire and forget, swallow the error. A failed refresh leaves the last
// known count in place, because a badge reading 0 for "we could not ask" is a lie.
func refreshFailedFileTaskCount(server: Server) async {
    @Dependency(\.getFailedFileTaskCount.execute)
    var getFailedFileTaskCount

    @Shared(.failedFileTaskCount(server))
    var failedFileTaskCount: Int

    do {
        let count = try await getFailedFileTaskCount(server)
        $failedFileTaskCount.withLock { $0 = count }
    } catch {}
}
```

- [ ] **Step 6: Run the test and watch it pass**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, four tests in `GetFailedFileTaskCountUseCaseTests`.

- [ ] **Step 7: Format and commit**

```bash
mise run format
git add Modules/ApiInterface Modules/ApiImplementation Modules/ApiImplementationTests
git commit -m "feat: count the failed imports nobody has dismissed yet"
```

---

### Task 5: dismissing a task

**Files:**
- Create: `Modules/ApiInterface/Tasks/AcknowledgeFileTaskUseCase.swift`
- Create: `Modules/ApiImplementation/Tasks/AcknowledgeFileTaskUseCase.swift`
- Test: `Modules/ApiImplementationTests/Tasks/AcknowledgeFileTaskUseCaseTests.swift`

**Interfaces:**
- Consumes: `FileTaskRepository.acknowledgeFileTask`, `.acknowledgeFileTaskLegacy` (Task 3).
- Produces: `AcknowledgeFileTaskUseCase.execute(id:server:) async throws -> Void` as `@Dependency(\.acknowledgeFileTask)`.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/Tasks/AcknowledgeFileTaskUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct AcknowledgeFileTaskUseCaseTests {

    @Test
    func execute_onVersion10_usesTheTasksSubresource() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 10 }

        let modern = LockIsolated<FileTask.Id?>(nil)
        let legacy = LockIsolated(false)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { id, _ in modern.setValue(id) }
            $0.fileTaskRepository.acknowledgeFileTaskLegacy = { _, _ in legacy.setValue(true) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(modern.value == 7)
        #expect(!legacy.value)
    }

    // 3.0.5 moved this endpoint. Older servers only have the top-level one, and calling the new path
    // there falls through to a non-DRF view that answers 403.
    @Test
    func execute_onVersion9_usesTheLegacyPath() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int?
        $apiVersion.withLock { $0 = 9 }

        let modern = LockIsolated(false)
        let legacy = LockIsolated<FileTask.Id?>(nil)

        try await withDependencies {
            $0.fileTaskRepository.acknowledgeFileTask = { _, _ in modern.setValue(true) }
            $0.fileTaskRepository.acknowledgeFileTaskLegacy = { id, _ in legacy.setValue(id) }
        } operation: {
            try await AcknowledgeFileTaskUseCase.liveValue.execute(id: 7, server: server)
        }

        #expect(legacy.value == 7)
        #expect(!modern.value)
    }
}
```

- [ ] **Step 2: Run the test and watch it fail**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `cannot find 'AcknowledgeFileTaskUseCase' in scope`.

- [ ] **Step 3: Declare the use case**

Create `Modules/ApiInterface/Tasks/AcknowledgeFileTaskUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct AcknowledgeFileTaskUseCase: Sendable {

    public var execute: @Sendable (
        _ id: FileTask.Id,
        _ server: Server
    ) async throws -> Void
}

extension AcknowledgeFileTaskUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in }
    )

    public static let testValue = Self(
        execute: { _, _ in }
    )
}

public extension DependencyValues {

    var acknowledgeFileTask: AcknowledgeFileTaskUseCase {
        get { self[AcknowledgeFileTaskUseCase.self] }
        set { self[AcknowledgeFileTaskUseCase.self] = newValue }
    }
}
```

- [ ] **Step 4: Implement it**

Create `Modules/ApiImplementation/Tasks/AcknowledgeFileTaskUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import SwiftSharing

extension AcknowledgeFileTaskUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(id:server:)
    )
}

private extension AcknowledgeFileTaskUseCase {

    static func execute(
        id: FileTask.Id,
        server: Server
    ) async throws {
        @Dependency(\.fileTaskRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        let version = apiVersion ?? ApiVersion.minimumSupported

        guard version >= 10 else {
            return try await repository.acknowledgeFileTaskLegacy(id, server)
        }
        try await repository.acknowledgeFileTask(id, server)
    }
}
```

- [ ] **Step 5: Run the test and watch it pass**

```bash
mise exec -- tuist test ApiImplementation --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, two tests in `AcknowledgeFileTaskUseCaseTests`.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/ApiInterface/Tasks Modules/ApiImplementation/Tasks Modules/ApiImplementationTests/Tasks
git commit -m "feat: dismiss a file task on whichever path the server has"
```

---

### Task 6: the `FileTasksFeature` module and its reducer

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift` (enum cases plus the `codeCoverageTarget`, `product` and — in `Module+Schemes.swift` — `schemes` switches)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`
- Create: `Modules/FileTasksFeature/FileTaskList/FileTaskListReducer.swift`
- Create: `Modules/FileTasksFeature/FileTaskList/FileTaskListReducer+Effect.swift`
- Test: `Modules/FileTasksFeatureTests/FileTaskList/FileTaskListReducerTests.swift`

**Interfaces:**
- Consumes: `GetFileTasksUseCase` (Task 3), `AcknowledgeFileTaskUseCase` (Task 5), `refreshFailedFileTaskCount` — *not* directly: the reducer calls `@Dependency(\.getFailedFileTaskCount)` and writes the shared key itself, because `refreshFailedFileTaskCount` is internal to `ApiImplementation` and features never import it; `@Shared(.failedFileTaskCount(server))` (Task 4); `ServerPermissions`, `Permission.changePaperlessTask`, `Permission.viewPaperlessTask`; `Effect.toast(_ error:)` from `Components`.
- Produces: `FileTaskListReducer` with `State(server:)` and `State(segment:tasks:isLoaded:server:)`, `Action.view(.onAppear | .onRefresh | .onRowAppear(FileTask) | .dismissButtonTapped(FileTask.Id) | .rowTapped(FileTask) | .closeButtonTapped)`, `Action.delegate(.openDocument(Document.Id) | .close)`, and state members `segment`, `tasks`, `nextPage`, `isLoaded`, `isLoadingMore`, `isDismissing`, `canDismiss`, `failedCount`.

The module has no view yet, so it compiles without a strings catalogue; the catalogue arrives with the
view in Task 7.

- [ ] **Step 1: Register the module with Tuist**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, add two cases to the `Module` enum, alphabetically
between `favoritesFeatureTests` and `forwardAuthFeature`:

```swift
    case fileTasksFeature = "FileTasksFeature"
    case fileTasksFeatureTests = "FileTasksFeatureTests"
```

Then add `.fileTasksFeature` to the `true` branch of `codeCoverageTarget` and to the framework branch
of `product`; add `.fileTasksFeatureTests` to the `false` branch of `codeCoverageTarget` and the
`.unitTests` branch of `product`. In `Module+Schemes.swift`, add `.fileTasksFeature` to the branch
that builds a scheme with a test action (the one listing `.favoritesFeature`, around line 108) and
`.fileTasksFeatureTests` to the `[]` branch. Every one of these switches is exhaustive, so the
compiler names each one you miss.

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add two entries modelled on
`.trashFeature` (around line 367):

```swift
        case .fileTasksFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .fileTasksFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.apiTestSupport),
                .target(.fileTasksFeature),
                .target(.testSupport),
            ]
```

Copy the exact `.external`/`.target` spellings from `.trashFeature` and `.trashFeatureTests` rather
than from this plan if they differ — `tuist inspect dependencies --only implicit` in `ci:lint` fails on
a module that is used but not declared, and that check is the reason to get this right now.

Create the folders so `tuist generate` has something to synchronize:

```bash
mkdir -p Modules/FileTasksFeature/FileTaskList Modules/FileTasksFeature/Resources
mkdir -p Modules/FileTasksFeatureTests/FileTaskList
```

- [ ] **Step 2: Write the failing test**

Create `Modules/FileTasksFeatureTests/FileTaskList/FileTaskListReducerTests.swift`:

```swift
@testable import FileTasksFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct FileTaskListReducerTests {

    @Test
    func test_onAppear_loadsTheSelectedSegment() async {
        let task = FileTask.testValue(id: 1, status: .failed)
        let store = TestStore(initialState: FileTaskListReducer.State(server: .testValue())) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in .testValue(nextPage: nil, tasks: [task]) }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.tasksLoaded) {
            $0.tasks = [task]
            $0.isLoaded = true
        }
    }

    // The sheet opens on the problem when there is one, and on the newest imports when there is not.
    @Test
    func test_initialSegment_followsTheFailureCount() async {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int

        #expect(FileTaskListReducer.State(server: server).segment == .complete)

        $failedFileTaskCount.withLock { $0 = 2 }

        #expect(FileTaskListReducer.State(server: server).segment == .failed)
    }

    @Test
    func test_segmentChanged_reloadsForTheNewSegment() async {
        let asked = LockIsolated<[FileTaskStatus]>([])
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                segment: .failed,
                tasks: [.testValue(id: 1, status: .failed)],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, status, _ in
                asked.withValue { $0.append(status) }
                return .testValue(nextPage: nil, tasks: [.testValue(id: 2, status: .complete)])
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.segment, .complete))) {
            $0.segment = .complete
            // Cleared rather than left in place: rows from the previous segment under a heading that
            // no longer matches them is the one state worse than an empty list.
            $0.tasks = []
            $0.isLoaded = false
        }
        await store.receive(\.tasksLoaded)

        #expect(asked.value == [.complete])
        #expect(store.state.tasks.map(\.id) == [2])
    }

    @Test
    func test_onRowAppear_loadsTheNextPageOnTheLastRow() async {
        let first = FileTask.testValue(id: 1)
        let second = FileTask.testValue(id: 2)
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                tasks: [first],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in .testValue(nextPage: nil, tasks: [second]) }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        store.state.nextPage = 2

        await store.send(.view(.onRowAppear(first)))
        await store.receive(\.moreTasksLoaded)

        #expect(store.state.tasks.map(\.id) == [1, 2])
        #expect(store.state.nextPage == nil)
    }

    @Test
    func test_onRowAppear_doesNothingWithNoNextPage() async {
        let first = FileTask.testValue(id: 1)
        let asked = LockIsolated(false)
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                tasks: [first],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.getFileTasks.execute = { _, _, _ in
                asked.setValue(true)
                return .testValue()
            }
        }

        await store.send(.view(.onRowAppear(first)))

        #expect(!asked.value)
    }

    @Test
    func test_dismiss_removesTheRowAndRereadsTheCount() async {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 1 }

        let store = TestStore(
            initialState: FileTaskListReducer.State(
                segment: .failed,
                tasks: [.testValue(id: 1, status: .failed)],
                isLoaded: true,
                server: server
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.acknowledgeFileTask.execute = { _, _ in }
            $0.getFailedFileTaskCount.execute = { _ in 0 }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.dismissButtonTapped(1)))
        await store.receive(\.dismissFinished)

        #expect(store.state.tasks.isEmpty)
        #expect(failedFileTaskCount == 0)
    }

    @Test
    func test_dismiss_keepsTheRowWhenItFails() async {
        let store = TestStore(
            initialState: FileTaskListReducer.State(
                segment: .failed,
                tasks: [.testValue(id: 1, status: .failed)],
                isLoaded: true,
                server: .testValue()
            )
        ) {
            FileTaskListReducer()
        } withDependencies: {
            $0.acknowledgeFileTask.execute = { _, _ in throw ApiError.testValue() }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.dismissButtonTapped(1)))
        await store.receive(\.dismissFinished)

        #expect(store.state.tasks.map(\.id) == [1])
        #expect(store.state.isDismissing.isEmpty)
    }

    @Test
    func test_rowTapped_delegatesADocumentItCanOpen() async {
        let task = FileTask.testValue(id: 1, documentId: 42)
        let store = TestStore(
            initialState: FileTaskListReducer.State(tasks: [task], isLoaded: true, server: .testValue())
        ) {
            FileTaskListReducer()
        }

        await store.send(.view(.rowTapped(task)))
        await store.receive(\.delegate.openDocument)
    }

    @Test
    func test_rowTapped_doesNothingWithoutADocument() async {
        let task = FileTask.testValue(id: 1, documentId: nil, status: .queued)
        let store = TestStore(
            initialState: FileTaskListReducer.State(tasks: [task], isLoaded: true, server: .testValue())
        ) {
            FileTaskListReducer()
        }

        await store.send(.view(.rowTapped(task)))
    }
}
```

Use whichever error `ApiError.testValue()` resolves to in this repo; if it does not exist, reuse the
error the `TrashFeatureTests` suites throw.

- [ ] **Step 3: Run the test and watch it fail**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test FileTasksFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `no such module 'FileTasksFeature'` if the manifest edits are incomplete,
otherwise `cannot find 'FileTaskListReducer' in scope`.

- [ ] **Step 4: Write the reducer**

Create `Modules/FileTasksFeature/FileTaskList/FileTaskListReducer.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import SwiftSharing

@Reducer
public struct FileTaskListReducer: Reducer, Sendable {

    @ObservableState
    public struct State: Equatable {

        var segment: FileTaskStatus

        var tasks: IdentifiedArrayOf<FileTask> = []

        var nextPage: Int?

        var isLoaded = false

        var isLoadingMore = false

        // The rows being dismissed, so they can say so and cannot be asked twice.
        var isDismissing: Set<FileTask.Id> = []

        // Stored rather than computed: constructing a ServerPermissions reads two files and arms two
        // file watchers, which is not something to do on every render.
        var permissions: ServerPermissions

        @Shared
        var failedCount: Int

        let server: Server

        var canDismiss: Bool { permissions.can(.changePaperlessTask) }

        public init(server: Server) {
            self.server = server
            permissions = ServerPermissions(server: server)
            _failedCount = Shared(.failedFileTaskCount(server))
            // Opening onto an empty Failed list is a worse first impression than opening onto the
            // imports that did work.
            segment = _failedCount.wrappedValue > 0 ? .failed : .complete
        }

        init(
            segment: FileTaskStatus = .complete,
            tasks: IdentifiedArrayOf<FileTask> = [],
            isLoaded: Bool = false,
            server: Server
        ) {
            self.isLoaded = isLoaded
            self.segment = segment
            self.server = server
            self.tasks = tasks
            permissions = ServerPermissions(server: server)
            _failedCount = Shared(.failedFileTaskCount(server))
        }
    }

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case dismissFinished(id: FileTask.Id, Result<Void, Error>)
        case moreTasksLoaded(Result<FileTaskPage, Error>)
        case tasksLoaded(Result<FileTaskPage, Error>)
        case view(View)

        public enum Delegate: Equatable, Sendable {
            case close
            case openDocument(Document.Id)
        }

        public enum View: Equatable, Sendable {
            case closeButtonTapped
            case dismissButtonTapped(FileTask.Id)
            case onAppear
            case onRefresh
            case onRowAppear(FileTask)
            case rowTapped(FileTask)
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.segment):
                state.isLoaded = false
                state.nextPage = nil
                state.tasks = []
                return .runLoadFileTasks(server: state.server, status: state.segment, page: 1)
            case .binding, .delegate:
                return .none
            case let .tasksLoaded(.success(page)):
                state.isLoaded = true
                state.nextPage = page.nextPage
                state.tasks = IdentifiedArray(uniqueElements: page.tasks)
                return .none
            case let .tasksLoaded(.failure(error)):
                state.isLoaded = true
                return .toast(error)
            case let .moreTasksLoaded(.success(page)):
                state.isLoadingMore = false
                state.nextPage = page.nextPage
                for task in page.tasks {
                    state.tasks.updateOrAppend(task)
                }
                return .none
            case let .moreTasksLoaded(.failure(error)):
                state.isLoadingMore = false
                return .toast(error)
            case let .dismissFinished(id, .success):
                // Removed rather than reloaded: the row is gone either way, and a reload would make
                // the dismiss look slower than it was.
                state.isDismissing.remove(id)
                state.tasks.remove(id: id)
                return .runRefreshFailedCount(server: state.server)
            case let .dismissFinished(id, .failure(error)):
                state.isDismissing.remove(id)
                return .toast(error)
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .send(.delegate(.close))
                case let .dismissButtonTapped(id):
                    guard !state.isDismissing.contains(id) else {
                        return .none
                    }
                    state.isDismissing.insert(id)
                    return .runDismiss(id: id, server: state.server)
                case .onAppear, .onRefresh:
                    return .runLoadFileTasks(server: state.server, status: state.segment, page: 1)
                case let .onRowAppear(task):
                    guard let nextPage = state.nextPage,
                          !state.isLoadingMore,
                          state.tasks.last?.id == task.id
                    else {
                        return .none
                    }
                    state.isLoadingMore = true
                    return .runLoadMoreFileTasks(
                        server: state.server,
                        status: state.segment,
                        page: nextPage
                    )
                case let .rowTapped(task):
                    guard let documentId = task.documentId else {
                        return .none
                    }
                    return .send(.delegate(.openDocument(documentId)))
                }
            }
        }
    }

    public init() {}
}
```

Create `Modules/FileTasksFeature/FileTaskList/FileTaskListReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import SwiftSharing

extension Effect where Action == FileTaskListReducer.Action {

    static func runLoadFileTasks(server: Server, status: FileTaskStatus, page: Int) -> Self {
        @Dependency(\.getFileTasks.execute)
        var getFileTasks

        return .run { send in
            await send(.tasksLoaded(.success(try await getFileTasks(server, status, page))))
        } catch: { error, send in
            await send(.tasksLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.loadFileTasks, cancelInFlight: true)
    }

    static func runLoadMoreFileTasks(server: Server, status: FileTaskStatus, page: Int) -> Self {
        @Dependency(\.getFileTasks.execute)
        var getFileTasks

        return .run { send in
            await send(.moreTasksLoaded(.success(try await getFileTasks(server, status, page))))
        } catch: { error, send in
            await send(.moreTasksLoaded(.failure(error)))
        }
        .cancellable(id: CancelID.loadMoreFileTasks, cancelInFlight: true)
    }

    static func runDismiss(id: FileTask.Id, server: Server) -> Self {
        @Dependency(\.acknowledgeFileTask.execute)
        var acknowledgeFileTask

        return .run { send in
            try await acknowledgeFileTask(id, server)
            await send(.dismissFinished(id: id, .success(())))
        } catch: { error, send in
            await send(.dismissFinished(id: id, .failure(error)))
        }
    }

    // The badge is re-read rather than decremented: the server is the only thing that knows how many
    // failures are left, and arithmetic here would drift the moment anything else dismissed one.
    static func runRefreshFailedCount(server: Server) -> Self {
        @Dependency(\.getFailedFileTaskCount.execute)
        var getFailedFileTaskCount

        return .run { _ in
            @Shared(.failedFileTaskCount(server))
            var failedCount: Int

            let count = try await getFailedFileTaskCount(server)
            $failedCount.withLock { $0 = count }
        } catch: { _, _ in
            // A failed refresh keeps the last known number. A badge reading 0 because the request
            // failed is worse than one that is briefly stale.
        }
    }
}

private enum CancelID {
    case loadFileTasks
    case loadMoreFileTasks
}
```

- [ ] **Step 5: Run the test and watch it pass**

```bash
mise exec -- tuist test FileTasksFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, nine tests in `FileTaskListReducerTests`.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Tuist Modules/FileTasksFeature Modules/FileTasksFeatureTests
git commit -m "feat: add a FileTasksFeature module with the file task list reducer"
```

---

### Task 7: the sheet

**Files:**
- Create: `Modules/FileTasksFeature/FileTaskList/FileTaskListView.swift`
- Create: `Modules/FileTasksFeature/FileTaskList/FileTaskRowView.swift`
- Create: `Modules/FileTasksFeature/FileTaskList/FileTaskListReducer+TestValue.swift`
- Create: `Modules/FileTasksFeature/Resources/Localizable.xcstrings`
- Test: `Modules/FileTasksFeatureTests/FileTaskList/FileTaskListViewTests.swift`

**Interfaces:**
- Consumes: `FileTaskListReducer` (Task 6); `Sheet`, `SheetHeader`, `SheetCloseButton`, `EmptyListView` from `Components`; `Color.m3*` and `.x*` spacing from `DesignTokens`.
- Produces: `FileTaskListView(store:)`, public; `FileTaskListReducer.State.testValue(...)`.

Strings needed, all new keys in this module's own catalogue: `fileTasks`, `fileTasksComplete`,
`fileTasksFailed`, `fileTasksQueued`, `fileTasksStarted`, `fileTasksEmpty`,
`fileTasksEmptyDescription`, `fileTasksDismiss`.

- [ ] **Step 1: Write the strings catalogue**

Create `Modules/FileTasksFeature/Resources/Localizable.xcstrings` with keys sorted alphabetically and
both languages present:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "fileTasks" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Dateiaufgaben" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "File Tasks" } }
      }
    },
    "fileTasksComplete" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Fertig" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Complete" } }
      }
    },
    "fileTasksDismiss" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Ausblenden" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Dismiss" } }
      }
    },
    "fileTasksEmpty" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Nichts hier" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Nothing here" } }
      }
    },
    "fileTasksEmptyDescription" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Für diesen Status gibt es keine Importe." } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "No imports have this status." } }
      }
    },
    "fileTasksFailed" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Fehlgeschlagen" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Failed" } }
      }
    },
    "fileTasksQueued" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Warteschlange" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Queued" } }
      }
    },
    "fileTasksStarted" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Läuft" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "Started" } }
      }
    }
  },
  "version" : "1.1"
}
```

No manifest edit is needed for this file: frameworks pick their catalogue up because
`Modules/FileTasksFeature` is a synchronized folder.

- [ ] **Step 2: Write the failing snapshot test**

Create `Modules/FileTasksFeatureTests/FileTaskList/FileTaskListViewTests.swift`:

```swift
@testable import FileTasksFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct FileTaskListViewTests {

    @Test
    func testSnapshot_failed() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: .testValue(
                        segment: .failed,
                        tasks: [
                            .testValue(
                                documentId: nil,
                                fileName: "invoice-march.pdf",
                                id: 1,
                                message: "Not consuming invoice-march.pdf: It is a duplicate of invoice-february.pdf",
                                status: .failed
                            ),
                            .testValue(
                                documentId: nil,
                                fileName: "scan_0012.pdf",
                                id: 2,
                                message: "Error while consuming document scan_0012.pdf: unsupported mime type",
                                status: .failed
                            )
                        ]
                    ),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_complete() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: .testValue(
                        segment: .complete,
                        tasks: [
                            .testValue(documentId: 42, fileName: "invoice.pdf", id: 1),
                            .testValue(documentId: 43, fileName: "letter.pdf", id: 2)
                        ]
                    ),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: .testValue(segment: .queued, tasks: []),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_failedDarkMode() async throws {
        assertSnapshot(
            of: FileTaskListView(
                store: Store(
                    initialState: .testValue(
                        segment: .failed,
                        tasks: [
                            .testValue(
                                documentId: nil,
                                fileName: "invoice-march.pdf",
                                id: 1,
                                message: "It is a duplicate of invoice-february.pdf",
                                status: .failed
                            )
                        ]
                    ),
                    reducer: {
                        FileTaskListReducer()
                    }
                )
            ),
            as: .image(
                layout: .device(config: .iPhone12),
                traits: .init(userInterfaceStyle: .dark)
            )
        )
    }
}
```

Copy the exact `@Suite` traits and `assertSnapshot` spelling from
`Modules/DocumentsFeatureTests/DocumentList/InboxViewTests.swift` if they differ from the above.

- [ ] **Step 3: Run the test and watch it fail**

```bash
mise exec -- tuist test FileTasksFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `cannot find 'FileTaskListView' in scope`.

- [ ] **Step 4: Write the test value**

Create `Modules/FileTasksFeature/FileTaskList/FileTaskListReducer+TestValue.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import IdentifiedCollections

extension FileTaskListReducer.State {

    static func testValue(
        segment: FileTaskStatus = .complete,
        tasks: IdentifiedArrayOf<FileTask> = [.testValue()],
        isLoaded: Bool = true,
        server: Server = .testValue()
    ) -> Self {
        .init(
            segment: segment,
            tasks: tasks,
            isLoaded: isLoaded,
            server: server
        )
    }
}
```

- [ ] **Step 5: Write the row**

Create `Modules/FileTasksFeature/FileTaskList/FileTaskRowView.swift`:

```swift
import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct FileTaskRowView: View {

    let task: FileTask
    let canDismiss: Bool
    let isDismissing: Bool
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            HStack(spacing: .x2) {
                Image(systemName: task.status.systemImage)
                    .foregroundStyle(task.status.tint)
                Text(task.fileName ?? String(localized: .fileTasks))
                    .foregroundColor(Color.m3OnSurface)
                    .clipShape(Rectangle())
            }
            Text(verbatim: (task.dateDone ?? task.dateCreated)
                .formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundColor(.m3Outline)
            if let message = task.message, task.status == .failed {
                // Selectable and unclipped: a reason the user can neither read in full nor copy into
                // a bug report is no better than no reason at all.
                Text(message)
                    .font(.caption)
                    .foregroundColor(.m3Error)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
        }
        .accessibilityElement()
        .accessibilityValue(accessibilityValue)
        .listRowBackground(Color.m3SurfaceContainer)
        .opacity(isDismissing ? 0.5 : 1.0)
        .swipeActions(content: swipeActions)
    }

    private var accessibilityValue: String {
        [
            task.fileName,
            (task.dateDone ?? task.dateCreated).formatted(date: .abbreviated, time: .shortened),
            task.status == .failed ? task.message : nil
        ]
        .compactMap { $0 }
        .joined(separator: ", ")
    }

    // Not `role: .destructive`: that removes the row the moment it is tapped, before the server has
    // agreed, which is the trap TrashRowView documents.
    @ViewBuilder
    private func swipeActions() -> some View {
        if canDismiss {
            Button(action: dismiss) {
                Image(systemName: "checkmark.circle")
            }
            .accessibilityLabel(.fileTasksDismiss)
            .disabled(isDismissing)
            .tint(.m3Primary)
        }
    }
}

private extension FileTaskStatus {

    var systemImage: String {
        switch self {
        case .complete:
            "checkmark.circle.fill"
        case .failed:
            "exclamationmark.triangle.fill"
        case .queued:
            "clock"
        case .started:
            "arrow.triangle.2.circlepath"
        }
    }

    var tint: Color {
        switch self {
        case .complete:
            .m3Primary
        case .failed:
            .m3Error
        case .queued, .started:
            .m3Outline
        }
    }
}
```

Check the token names against `Modules/DesignTokens` before running — use whatever the repo actually
defines for the error and outline colours if `m3Error` or `m3Outline` are spelled differently.

- [ ] **Step 6: Write the view**

Create `Modules/FileTasksFeature/FileTaskList/FileTaskListView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: FileTaskListReducer.self)
public struct FileTaskListView: View {

    public var body: some View {
        // isScrollingEnabled off because the content is a List: swipe actions and pull to refresh
        // both need one, and a List inside the Sheet's ScrollView would nest two scroll views.
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(title: {
                Text(.fileTasks)
            }, right: {
                SheetCloseButton {
                    send(.closeButtonTapped)
                }
            })
        } content: {
            VStack(spacing: .x0) {
                Picker(String(localized: .fileTasks), selection: $store.segment) {
                    ForEach(FileTaskStatus.allCases, id: \.self) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.x3)
                list()
            }
        } contentOverlay: {
            EmptyView()
        } bottom: {
            EmptyView()
        }
    }

    public init(store: StoreOf<FileTaskListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<FileTaskListReducer>

    @ViewBuilder
    private func list() -> some View {
        // The list is always present with the empty state over it: a ContentUnavailableView on its
        // own does not scroll, so pull to refresh would be unavailable exactly when it is wanted.
        List {
            ForEach(store.tasks) { task in
                FileTaskRowView(
                    task: task,
                    canDismiss: store.canDismiss,
                    isDismissing: store.isDismissing.contains(task.id),
                    dismiss: { send(.dismissButtonTapped(task.id)) }
                )
                .contentShape(Rectangle())
                .onTapGesture { send(.rowTapped(task)) }
                .onAppear { send(.onRowAppear(task)) }
            }
            if store.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                        .id(UUID())
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .listStyle(.plain)
        .overlay(emptyView())
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
    }

    @ViewBuilder
    private func emptyView() -> some View {
        if store.tasks.isEmpty, store.isLoaded {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray", title: .fileTasksEmpty) {
                    Text(.fileTasksEmptyDescription)
                        .font(.subheadline)
                        .foregroundStyle(Color.m3OnSurface)
                        .multilineTextAlignment(.center)
                }
            }
            // Without this the overlay swallows the scroll and pull to refresh stops working on an
            // empty list, which is exactly when it is needed.
            .allowsHitTesting(false)
        }
    }
}

private extension FileTaskStatus {

    var title: LocalizedStringResource {
        switch self {
        case .complete:
            .fileTasksComplete
        case .failed:
            .fileTasksFailed
        case .queued:
            .fileTasksQueued
        case .started:
            .fileTasksStarted
        }
    }
}

#Preview {
    FileTaskListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                FileTaskListReducer()
            }
        )
    )
}
```

Check `EmptyListView`'s initialiser in `Modules/Components/EmptyList` and match it; the shape above is
taken from `TrashListView`.

- [ ] **Step 7: Run the tests, then look at what was recorded**

```bash
mise exec -- tuist test FileTasksFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: the first run FAILS, having written four new references — swift-snapshot-testing records a
missing reference and then fails. Nothing warns you that it did.

**Open all four PNGs under `Modules/FileTasksFeatureTests/.../__Snapshots__/` and look at them.** A
reference records whatever the code produced, bug included; this repo once recorded 14 German
references showing English captions. Check: the segmented picker shows four translated titles, the
failed rows show their message in full rather than truncated, the empty state is centred, and the dark
mode image is actually dark.

Then run again:

```bash
mise exec -- tuist test FileTasksFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, four snapshot tests plus Task 6's nine reducer tests.

- [ ] **Step 8: Format and commit**

```bash
mise run format
git add Modules/FileTasksFeature Modules/FileTasksFeatureTests
git commit -m "feat: show file tasks in a sheet with one segment per status"
```

---

### Task 8: the inbox button

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListTopLeadingToolbar.swift:31`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` (the `Destination` enum around line 58, the action list, and the `.view` switch)
- Modify: `Modules/DocumentsFeature/DocumentList/InboxView.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (`.documentsFeature` gains `.target(.fileTasksFeature)`)
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListFileTasksTests.swift`

**Interfaces:**
- Consumes: `FileTaskListReducer`, `FileTaskListView` (Tasks 6, 7); `@Shared(.failedFileTaskCount(server))` (Task 4); `DocumentListReducer.Action.openDocument` (exists, `DocumentListReducer.swift:336`).
- Produces: `DocumentListReducer.Destination.fileTasks(FileTaskListReducer)`, `Action.View.fileTasksButtonTapped`.

New strings in `DocumentsFeature`'s own catalogue: `fileTasks` and `failedFileTaskCount` (the badge's
accessibility value). `FileTasksFeature` has its own `fileTasks` key — that duplication is the design,
so copy the entry verbatim, German included, so the two cannot drift.

- [ ] **Step 1: Write the failing test**

Create `Modules/DocumentsFeatureTests/DocumentList/DocumentListFileTasksTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct DocumentListFileTasksTests {

    @Test
    func test_fileTasksButtonTapped_presentsTheSheet() async {
        let store = TestStore(initialState: DocumentListReducer.State.testValue()) {
            DocumentListReducer()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.view(.fileTasksButtonTapped))

        #expect(store.state.destination?.fileTasks != nil)
    }

    // The list screen delegates a document id upward rather than knowing what a document detail is.
    @Test
    func test_fileTaskOpenDocument_pushesTheDetail() async {
        let document = Document.testValue(id: 42)
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(
                destination: .fileTasks(FileTaskListReducer.State(server: .testValue()))
            )
        ) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocument.execute = { _, _ in document }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.destination(.presented(.fileTasks(.delegate(.openDocument(42))))))

        #expect(store.state.path.count == 1)
    }

    @Test
    func test_fileTaskClose_dismissesTheSheet() async {
        let store = TestStore(
            initialState: DocumentListReducer.State.testValue(
                destination: .fileTasks(FileTaskListReducer.State(server: .testValue()))
            )
        ) {
            DocumentListReducer()
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.destination(.presented(.fileTasks(.delegate(.close)))))

        #expect(store.state.destination == nil)
    }
}
```

Check `DocumentListReducer.State.testValue`'s signature in
`Modules/DocumentsFeature/DocumentList/DocumentListReducer+TestValue.swift` — if it takes no
`destination` parameter, add one there in the same shape the other parameters use.

- [ ] **Step 2: Run the test and watch it fail**

```bash
mise exec -- tuist test DocumentsFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: compile failure, `type 'DocumentListReducer.Destination' has no member 'fileTasks'`.

- [ ] **Step 3: Declare the dependency and wire the reducer**

In `Module+Dependencies.swift`, add `.target(.fileTasksFeature)` to the `.documentsFeature` list and to
`.documentsFeatureTests`. Skipping this compiles — the module is reachable transitively — and then
fails `tuist inspect dependencies --only implicit` in `ci:lint`.

In `DocumentListReducer.swift`: `import FileTasksFeature`, add `case fileTasks(FileTaskListReducer)`
to the `Destination` enum, add `case fileTasksButtonTapped` to `Action.View`, and handle three cases:

```swift
            case .destination(.presented(.fileTasks(.delegate(.close)))):
                state.destination = nil
                return .none
            case let .destination(.presented(.fileTasks(.delegate(.openDocument(id))))):
                state.destination = nil
                return .send(.openDocument(id))
```

and, in the `.view` switch:

```swift
                case .fileTasksButtonTapped:
                    state.destination = .fileTasks(FileTaskListReducer.State(server: state.server))
                    return .none
```

- [ ] **Step 4: Add the strings**

Add to `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, keys in alphabetical position:

```json
    "failedFileTaskCount" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "%lld fehlgeschlagene Importe" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "%lld failed imports" } }
      }
    },
    "fileTasks" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : { "stringUnit" : { "state" : "translated", "value" : "Dateiaufgaben" } },
        "en" : { "stringUnit" : { "state" : "translated", "value" : "File Tasks" } }
      }
    },
```

- [ ] **Step 5: Add the button**

In `DocumentListTopLeadingToolbar.swift`, replace the `.inbox` branch's `EmptyView()` with
`fileTasksButton`, and add to the modifier:

```swift
    @Shared(.failedFileTaskCount(server))
    private var failedFileTaskCount: Int

    @ViewBuilder
    private var fileTasksButton: some View {
        if store.permissions.can(.viewPaperlessTask) {
            Button {
                send(.fileTasksButtonTapped)
            } label: {
                // An HStack rather than a badge overlay on the icon: an overlay on a toolbar item is
                // clipped by the navigation bar on some heights, and this cannot be.
                HStack(spacing: .x1) {
                    Image(systemName: "tray.and.arrow.down")
                    if failedFileTaskCount > 0 {
                        Text(verbatim: String(failedFileTaskCount))
                            .capsule(
                                backgroundColor: .m3ErrorContainer,
                                font: .caption2,
                                foregroundColor: .m3OnErrorContainer,
                                padding: .init(top: .x1, leading: .x2, bottom: .x1, trailing: .x2)
                            )
                    }
                }
            }
            .accessibilityLabel(.fileTasks)
            .accessibilityValue(
                failedFileTaskCount > 0
                    ? String(localized: .failedFileTaskCount(failedFileTaskCount))
                    : ""
            )
        }
    }
```

The `@Shared` key needs the server, so pass `store.server` into the modifier's init and build the
Shared there — `InboxView.init` does the same thing for `inboxDocumentCount`. Check whether
`DocumentListReducer.State` exposes `permissions`; if it does not, add it in the shape
`TrashListReducer.State` uses.

In `InboxView.swift`, add the sheet beside the existing pattern in `DocumentListView`:

```swift
        .sheet(
            item: $store.scope(
                state: \.destination?.fileTasks,
                action: \.destination.fileTasks
            )
        ) { store in
            FileTaskListView(store: store)
                .presentationDetents([.sheet])
        }
```

Then call the refresh wherever `refreshStatistics` is already triggered for the inbox — find those
call sites with `grep -rn "refreshStatistics" Modules` and add `refreshFailedFileTaskCount(server:)`
beside each one that runs on inbox appear, pull to refresh and foreground. It lives in
`ApiImplementation`, so if the call site is in a feature module, route it through the
`getFailedFileTaskCount` use case and the shared key exactly as
`FileTaskListReducer+Effect.runRefreshFailedCount` does.

- [ ] **Step 6: Run the tests and watch them pass**

```bash
mise exec -- tuist test DocumentsFeature --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS, three tests in `DocumentListFileTasksTests`. The existing `InboxViewTests` snapshots
will FAIL and record nothing — the toolbar changed. Delete the stale references for
`InboxViewTests` only, re-run to record, **look at the images** (the tray icon present, no badge on a
fixture whose count is 0), and run once more.

- [ ] **Step 7: Add a badged inbox snapshot**

Add to `Modules/DocumentsFeatureTests/DocumentList/InboxViewTests.swift`:

```swift
    // The badge is the only thing on the inbox that reports a failed import, so it gets its own
    // reference rather than riding along on the default one.
    @Test
    func testSnapshot_withFailedFileTasks() async throws {
        let server = Server.testValue()
        @Shared(.failedFileTaskCount(server))
        var failedFileTaskCount: Int
        $failedFileTaskCount.withLock { $0 = 3 }

        assertSnapshot(
            of: InboxView(
                store: Store(
                    initialState: DocumentListReducer.State.testValue(),
                    reducer: {
                        DocumentListReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }
```

Run, inspect the new reference — the badge must actually show `3` — and run again to green.

- [ ] **Step 8: Format and commit**

```bash
mise run format
git add Tuist Modules/DocumentsFeature Modules/DocumentsFeatureTests
git commit -m "feat: put the file tasks behind the inbox's leading toolbar button"
```

---

### Task 9: the journey

**Files:**
- Create: `Modules/AppUITests/FileTaskJourneyTests.swift`

**Interfaces:**
- Consumes: `UITestConfiguration`, `Fixtures.uploadDocument(titled:token:)`, and whatever user-creation helper the existing journeys use.

Read `Modules/AppUITests/DocumentBrowsingJourneyTests.swift` end to end first and copy its setup,
teardown and accessibility-driven navigation. Two rules from AGENTS.md apply directly: every test
creates its own Paperless user, and **no helper may delete all of something**. Upload with the *test
user's* token, never admin's — paperless owns a document to whoever created it, and an admin-owned one
is invisible to the user the journey runs as. Delete what you uploaded in `tearDown`; deleting the
user does not cascade.

- [ ] **Step 1: Check the owner-scoping assumption before writing the test**

The journey only works if `/api/tasks/` shows a non-superuser their own tasks. Verify against the dev
instance with one of `docker:seed`'s permission-scenario users:

```bash
TOKEN=$(curl -s -X POST http://192.168.64.1:8000/api/token/ \
  -H 'Content-Type: application/json' \
  -d '{"username":"<scenario-user>","password":"<password>"}' | python3 -c 'import sys,json;print(json.load(sys.stdin)["token"])')
curl -s "http://192.168.64.1:8000/api/tasks/?task_type=consume_file&page_size=5" \
  -H "Authorization: Token $TOKEN" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d["count"]);print({t["owner"] for t in d["results"]})'
```

Read the user names and passwords out of `docker/seed/permissions.py`. If the count matches the
admin's total and the owners are other users, the endpoint is **not** owner-scoped: then the journey
must find its row by the file name it uploaded rather than by position, and the Complete segment
assertion must not assume the list is short. Note what you found in the test file as a comment — the
next person will ask the same question.

- [ ] **Step 2: Write the journey**

Create `Modules/AppUITests/FileTaskJourneyTests.swift`, following the structure of
`DocumentBrowsingJourneyTests`:

1. create the test user and launch with a `UITestConfiguration` for the seeded server;
2. upload a document with `Fixtures.uploadDocument(titled:token:)` using the test user's token, with a
   file name unique to this run;
3. open the inbox tab, tap the File Tasks button by its accessibility label;
4. select the Complete segment, and wait for a row matching the uploaded file name;
5. swipe that row and tap Dismiss; assert the row goes away;
6. tear down: delete the uploaded document, then the user.

Use the same waiting helpers the other journeys use rather than `sleep`; consumption is asynchronous,
so the row may take a few seconds to appear, and a fixed sleep is what makes a journey flaky.

- [ ] **Step 3: Run the journey**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise exec -- tuist test AppUITests --no-binary-cache -d "iPhone 17 Pro" -o "26.5" -- -testLanguage en -testRegion DE
```

Expected: PASS. A failure at step 4 is the owner-scoping question from Step 1 coming back — check what
the app is actually showing with a screenshot before changing the app.

- [ ] **Step 4: Format and commit**

```bash
mise run format
git add Modules/AppUITests
git commit -m "test: walk the file task list from an upload to a dismissed row"
```

---

### Task 10: green the whole thing

**Files:**
- Modify: `docs/ideas.md`

- [ ] **Step 1: Run the full unit suite, not just the schemes you touched**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist generate --no-open
mise run ci:test:unit
```

Expected: PASS. If a snapshot elsewhere fails, something in `Components` or `DesignTokens` moved —
investigate rather than re-recording.

- [ ] **Step 2: Reproduce the CI-only warnings-as-errors build**

```bash
TUIST_WARNINGS_AS_ERRORS=true TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 mise exec -- tuist generate --no-open
mise exec -- tuist build FileTasksFeature
mise exec -- tuist build DocumentsFeature
```

Expected: no warnings. A `@ViewAction` view calling `store.send` is the likeliest one, and it is an
error on CI. Regenerate without the variable afterwards.

- [ ] **Step 3: Run the lint gate**

```bash
mise run ci:lint
```

Expected: PASS. It is five steps under `set -eou pipefail`, so the first failure hides the rest — fix,
re-run, and expect a second one rather than assuming you are done. The step that matters most here is
`tuist inspect dependencies --only implicit`: it is the one thing no test catches, and this project
added two modules and one cross-module dependency.

- [ ] **Step 4: Park the ideas this project deliberately left out**

Append to `docs/ideas.md`, in the established format:

```markdown
---

## Show task types other than imports

`/api/tasks/` carries twelve task types; the file task list filters to `consume_file` because the
other eleven are scheduled housekeeping the user did not start. On the dev instance that is 958 rows
of `train_classifier`, `mail_fetch` and `check_workflows` against 43 imports.

A type filter would make the screen a general task viewer. It needs a second picker or a filter
sheet, and on API v9 it cannot be server-side at all.

Surfaced during: `docs/superpowers/specs/2026-09-12-file-tasks-inbox-design.md`.

---

## `post_document` throws away the task id it is handed

`POST /api/documents/post_document/` answers with the celery task id, and
`DocumentsRepository.swift:145` discards the response body. `/api/tasks/` accepts a `task_id` filter,
so threading that id out of `CreateDocumentUseCase` is what would let the app follow one upload rather
than guess from the newest row.

Needed by the background-polling-and-toast project; not needed by the file task list itself.

Surfaced during: `docs/superpowers/specs/2026-09-12-file-tasks-inbox-design.md`.
```

- [ ] **Step 5: Commit**

```bash
mise run format
git add docs/ideas.md
git commit -m "docs: park the task-type filter and the post_document task id"
```

---

## Self-Review

**Spec coverage.** Every section of the spec maps to a task: the domain model and status leniency to
Task 1; both payload shapes and the recorded fixtures to Task 2; the list endpoint, the version branch
and the v9 in-memory filtering to Task 3; the badge count, the shared key and the refresh function to
Task 4; the version-dependent dismiss path to Task 5; the reducer, segment reload, paging and
permission flags to Task 6; the sheet, the segmented picker, the inline failure message and the
snapshots to Task 7; the toolbar button, its badge, permission gating and the delegate wiring to Task
8; the journey to Task 9; and the lint, implicit-dependency and warnings gates to Task 10, which also
parks the two follow-up ideas the spec names.

**Two places where the plan tells the executor to check the repo rather than trust the plan**, because
these could not be verified without compiling: `Date.testValue(adding:)` and `ApiError.testValue()`
may not exist, and `EmptyListView`'s initialiser and the exact `m3` colour token names need reading
off the source. Each is called out at the step that uses it, with a fallback.

**Interface consistency.** `FileTaskPage(nextPage:tasks:)`, `FileTaskStatus.init?(apiValue:)`,
`apiQueryValue`, `GetFileTasksUseCase.execute(server:status:page:)`,
`AcknowledgeFileTaskUseCase.execute(id:server:)`, `GetFailedFileTaskCountUseCase.execute(server:)`,
`refreshFailedFileTaskCount(server:)` and `.failedFileTaskCount(server)` are spelled identically in
every task that produces or consumes them, and the repository's five function names are fixed in Task
3 and reused verbatim in Tasks 4 and 5.
