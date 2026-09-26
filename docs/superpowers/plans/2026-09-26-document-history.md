# Document History Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A read-only **History** section in the document viewer that lists a document's paperless audit log the way the web's History tab does, offered only to users the server would answer.

**Architecture:** A new `AuditLogEntry` model and `GetDocumentHistoryUseCase` (ApiInterface) backed by a `HistoryRepository` (ApiImplementation) calling `GET /api/documents/{id}/history/`. `GetCurrentUserUseCase` caches `auditlog_enabled` from `/api/ui_settings/`, and `ServerPermissions.canViewHistory(of:)` combines it with `view_logentry` and document ownership. A `DocumentHistoryReducer` is scoped into `DocumentViewerReducer` as the new `DocumentViewerSection.history`; one `DocumentViewerSection.visible(...)` helper replaces the three copies of the section filter.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing, swift-dependencies, Swift Testing, swift-snapshot-testing, Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-26-document-history-design.md` — read it before starting; this plan argues from it.

## Global Constraints

- Comments are `//` only — never `///` or `/** */` — and only where a reader would otherwise stop and wonder why (AGENTS.md → Comment Style).
- In a view annotated `@ViewAction(for:)`, send with `send(...)`, never `store.send(...)`.
- Every new user-facing string goes into `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, in `en` **and** `de`, with `"extractionState": "manual"`, keys sorted alphabetically.
- No API-version gate: the history endpoint exists on every supported server (paperless-ngx ≥ 2.15.3, `ApiVersion.minimumSupported = 8`).
- Gate = `auditLogEnabled != false` **and** `can(.viewLogEntry)` **and** (document has no owner, or current user owns it, or current user is superuser). Each unknown (`nil`) cache counts as allowed.
- `"None"` and JSON `null` on either side of a `[old, new]` pair decode to `nil`.
- Changes are listed sorted by key; an unrecognised change shape is skipped, never fails the entry.
- `content` values are cut to their first 100 characters, with `…` appended when cut.
- Tests target the dev instance. Export for **both** generate and test:
  `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000`
- Test command shape (substitute `<Scheme>` and `<Target/Suite>`):
  ```bash
  export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 && mise exec -- sh -c 'tuist test <Scheme> -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing -- -testLanguage en -testRegion DE -collect-test-diagnostics never -only-testing:<Target/Suite>'
  ```
- Before the final commit: `mise run format` then `mise run ci:lint`, both clean.
- Every commit message ends with a blank line and `Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>`.

## Review Focus

1. **Tag changes sent as raw ids** — `"tags": [97, [96, 97]]` and `[null, [102]]`. A user expects *Tags: Invoice, Paid*, not *96, 97* or a crash. Pinned in Task 3 (decoding) and Task 6 (formatting).
2. **Note changes sent as numbers** — `"Note Added": ["None", 40]`. Must decode (not throw on a non-string pair) and show *40*. Pinned in Task 3 and Task 6.
3. **A cached name that no longer exists** — correspondent id `"8"` deleted since. Expect the raw id, not an empty line. Pinned in Task 6.
4. **A fresh install before `ui_settings` is read** — all caches `nil`. History must be offered, not hidden. Pinned in Task 2.
5. **A non-superuser looking at another user's document** — the server answers 403, so the menu must not offer History. Pinned in Task 2 and Task 7 (the reducers' `canViewHistory`).

---

## File Map

| File | Change | Responsibility |
| --- | --- | --- |
| `Modules/ApiInterface/Shared/JSONValue.swift` | Modify | add `boolValue` |
| `Modules/ApiInterface/UISettings/UISettings.swift` | Modify | `Settings.auditLogEnabled` accessor; `Settings.testValue(auditLogEnabled:)` |
| `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` | Modify | `.auditLogEnabled(server)` key |
| `Modules/ApiImplementation/Users/GetCurrentUserUseCase.swift` | Modify | cache the flag |
| `Modules/ApiInterface/Permissions/ServerPermissions.swift` | Modify | `canViewHistory(of:)` |
| `Modules/ApiInterface/History/AuditLogEntry.swift` | Create | model + lenient decoding + test values |
| `Modules/ApiInterface/History/GetDocumentHistoryUseCase.swift` | Create | use case interface |
| `Modules/ApiImplementation/History/HistoryRepository.swift` | Create | HTTP call |
| `Modules/ApiImplementation/History/GetDocumentHistoryUseCase.swift` | Create | live use case |
| `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryReducer.swift` (+`+Effect`, `+TestValue`) | Create | load / error / retry |
| `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryChangeLine.swift` | Create | `Change` → display line, name resolution |
| `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryEntryView.swift` | Create | one row |
| `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryView.swift` | Create | section view |
| `Modules/DocumentsFeature/DocumentViewer/DocumentViewerSection.swift` | Modify | `.history`, `visible(...)` |
| `Modules/DocumentsFeature/DocumentViewer/DocumentViewerReducer.swift` (+`+TestValue`) | Modify | scope history, `canViewHistory` |
| `Modules/DocumentsFeature/DocumentViewer/DocumentViewerView.swift` | Modify | render section, use `visible` |
| `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift`, `DocumentDetailView.swift` | Modify | `canViewHistory`, use `visible` |
| `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift`, `DocumentRowView.swift` | Modify | `canViewHistory`, use `visible` |
| `Modules/DocumentsFeature/Resources/Localizable.xcstrings` | Modify | six new keys |

New files in `Modules/<Name>/` are picked up by the synchronized folder — no manifest edit.

---

### Task 1: Cache `auditlog_enabled` from ui_settings

**Files:**
- Modify: `Modules/ApiInterface/Shared/JSONValue.swift` (end of the `public extension JSONValue` block)
- Modify: `Modules/ApiInterface/UISettings/UISettings.swift` (the `public extension UISettings.Settings` accessor block around `var savedViews`, and `Settings.testValue` around line 133)
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` (after the `.permissions` key, line ~26)
- Modify: `Modules/ApiImplementation/Users/GetCurrentUserUseCase.swift`
- Test: `Modules/ApiInterfaceTests/UISettings/UISettingsTests.swift`, `Modules/ApiImplementationTests/Users/GetCurrentUserUseCaseTests.swift`

**Interfaces:**
- Produces: `JSONValue.boolValue: Bool?`; `UISettings.Settings.auditLogEnabled: Bool?`; `UISettings.Settings.testValue(savedViews:version:auditLogEnabled:)`; `SharedReaderKey.auditLogEnabled(_ server: Server) -> FileStorageKey<Bool?>`.

- [ ] **Step 1: Write the failing tests**

Append to `UISettingsTests`:

```swift
    @Test
    func auditLogEnabled_readsTheFlagFromRawSettings() throws {
        let settings = try JSONDecoder.apiDecoder.decode(
            UISettings.Settings.self,
            from: Data(#"{"auditlog_enabled": false, "version": "3.0.5"}"#.utf8)
        )

        #expect(settings.auditLogEnabled == false)
    }

    // Absent, not false: an unknown flag must not hide History.
    @Test
    func auditLogEnabled_isNilWhenTheServerDoesNotSendIt() throws {
        let settings = try JSONDecoder.apiDecoder.decode(
            UISettings.Settings.self,
            from: Data(#"{"version": "3.0.5"}"#.utf8)
        )

        #expect(settings.auditLogEnabled == nil)
    }
```

Append to `GetCurrentUserUseCaseTests` (before the trailing `@Shared` property):

```swift
    @Test
    func cachesTheAuditLogFlagFromUISettings() async throws {
        let server = Server.testValue()

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .testValue(settings: .testValue(auditLogEnabled: false))
            }
        } operation: {
            _ = try await GetCurrentUserUseCase.liveValue.execute(server)

            @Shared(.auditLogEnabled(server))
            var auditLogEnabled: Bool?

            #expect(auditLogEnabled == false)
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run the command from Global Constraints with `<Scheme>` = `ApiInterface`, `<Target/Suite>` = `ApiInterfaceTests/UISettingsTests`.
Expected: build failure — `value of type 'UISettings.Settings' has no member 'auditLogEnabled'`.

- [ ] **Step 3: Implement**

In `JSONValue.swift`, add inside `public extension JSONValue` after `intValue`:

```swift
    var boolValue: Bool? {
        guard case let .bool(value) = self else {
            return nil
        }
        return value
    }
```

In `UISettings.swift`, add to the `public extension UISettings.Settings` block that holds `savedViews`:

```swift
    // nil when the key is absent, which must read as "unknown" rather than "disabled" — History
    // stays offered until the server says otherwise.
    var auditLogEnabled: Bool? {
        raw["auditlog_enabled"]?.boolValue
    }
```

Change `UISettings.Settings.testValue` to:

```swift
    static func testValue(
        savedViews: UISettings.Settings.SavedViews? = nil,
        version: String = "2.18.4",
        auditLogEnabled: Bool? = nil
    ) -> Self {
        var settings = Self(raw: ["version": .string(version)])

        if let auditLogEnabled {
            settings.raw["auditlog_enabled"] = .bool(auditLogEnabled)
        }
        settings.savedViews = savedViews
        return settings
    }
```

In `SharedReaderKey+Extensions.swift`, after the `.permissions` extension:

```swift
public extension SharedReaderKey where Self == FileStorageKey<Bool?> {

    static func auditLogEnabled(_ server: Server) -> Self {
        .fileStorage(
            .applicationGroupDirectory.appending(component: "\(server.id)-audit-log-enabled.json"),
            decoder: .apiDecoder,
            encoder: .apiEncoder
        )
    }
}
```

In `GetCurrentUserUseCase.execute`, declare next to the other two caches:

```swift
        @Shared(.auditLogEnabled(server))
        var auditLogEnabled: Bool?
```

and after `$permissions.withLock { … }`:

```swift
        $auditLogEnabled.withLock { $0 = uiSettings.settings.auditLogEnabled }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run `ApiInterface` / `ApiInterfaceTests/UISettingsTests`, then `ApiImplementation` / `ApiImplementationTests/GetCurrentUserUseCaseTests`.
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface Modules/ApiImplementation Modules/ApiInterfaceTests Modules/ApiImplementationTests
git commit -m "feat: cache whether the server keeps an audit log

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 2: `ServerPermissions.canViewHistory(of:)`

**Files:**
- Modify: `Modules/ApiInterface/Permissions/ServerPermissions.swift`
- Test: `Modules/ApiInterfaceTests/Permissions/ServerPermissionsTests.swift`

**Interfaces:**
- Consumes: `.auditLogEnabled(server)` (Task 1).
- Produces: `public func canViewHistory(of document: Document) -> Bool` on `ServerPermissions`.

- [ ] **Step 1: Write the failing tests**

Append to `ServerPermissionsTests` (before `private func write`), and add the helper below `write`:

```swift
    @Test
    func canViewHistory_ownerWithViewLogEntry() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewLogEntry])

        #expect(permissions.canViewHistory(of: .testValue(owner: 5)))
    }

    @Test
    func canViewHistory_unownedDocument() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewLogEntry])

        #expect(permissions.canViewHistory(of: .testValue(owner: nil)))
    }

    // The endpoint answers 403 here even with view_logentry.
    @Test
    func canViewHistory_anotherUsersDocumentIsDenied() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewLogEntry])

        #expect(!permissions.canViewHistory(of: .testValue(owner: 6)))
    }

    @Test
    func canViewHistory_superuserSeesAnotherUsersDocument() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: true), permissions: [])

        #expect(permissions.canViewHistory(of: .testValue(owner: 6)))
    }

    @Test
    func canViewHistory_withoutViewLogEntryIsDenied() {
        let permissions = writeHistory(user: .testValue(id: 5, isSuperuser: false), permissions: [.viewDocument])

        #expect(!permissions.canViewHistory(of: .testValue(owner: 5)))
    }

    @Test
    func canViewHistory_auditLogDisabledDeniesEvenASuperuser() {
        let permissions = writeHistory(
            user: .testValue(id: 5, isSuperuser: true),
            permissions: [.viewLogEntry],
            auditLogEnabled: false
        )

        #expect(!permissions.canViewHistory(of: .testValue(owner: 5)))
    }

    // Nothing read yet: offer the section and let the server refuse it, same as can().
    @Test
    func canViewHistory_nothingCachedAllows() {
        let server = Server.testValue()

        #expect(ServerPermissions(server: server).canViewHistory(of: .testValue(owner: 6)))
    }

    private func writeHistory(
        user: User,
        permissions: [Permission]?,
        auditLogEnabled: Bool? = true
    ) -> ServerPermissions {
        @Shared(.auditLogEnabled(Server.testValue()))
        var cachedAuditLogEnabled: Bool?

        $cachedAuditLogEnabled.withLock { $0 = auditLogEnabled }

        return write(user: user, permissions: permissions)
    }
```

- [ ] **Step 2: Run to verify failure**

`ApiInterface` / `ApiInterfaceTests/ServerPermissionsTests`.
Expected: build failure — `value of type 'ServerPermissions' has no member 'canViewHistory'`.

- [ ] **Step 3: Implement**

In `ServerPermissions`, add the property after `currentUser`:

```swift
    @Shared var auditLogEnabled: Bool?
```

initialise it in `init(server:)`:

```swift
        _auditLogEnabled = Shared(wrappedValue: nil, .auditLogEnabled(server))
```

and add after `can(_:)`:

```swift
    // Mirrors the history endpoint's own checks: 400 when the audit log is off, 403 without
    // view_logentry or on someone else's document unless superuser. Each unknown counts as allowed,
    // as in can(), so a fresh install offers the section and lets the server refuse it.
    public func canViewHistory(of document: Document) -> Bool {
        guard auditLogEnabled != false, can(.viewLogEntry) else {
            return false
        }
        guard let owner = document.owner, let currentUser else {
            return true
        }
        return currentUser.isSuperuser || owner == currentUser.id
    }
```

- [ ] **Step 4: Run to verify pass**

`ApiInterface` / `ApiInterfaceTests/ServerPermissionsTests`. Expected: all PASS, including the existing five.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/Permissions Modules/ApiInterfaceTests/Permissions
git commit -m "feat: ask whether the current user may read a document's history

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 3: `AuditLogEntry` model and lenient decoding

**Files:**
- Create: `Modules/ApiInterface/History/AuditLogEntry.swift`
- Test: `Modules/ApiInterfaceTests/History/AuditLogEntryTests.swift`

**Interfaces:**
- Produces:
  ```swift
  public struct AuditLogEntry: Decodable, Equatable, Identifiable, Sendable {
      public typealias Id = Tagged<AuditLogEntry, Int>
      public let action: Action; public let actor: Actor?; public let changes: [Change]
      public let id: Id; public let timestamp: Date
      public enum Action: Equatable, Sendable { case create, delete, other(String), update }
      public struct Actor: Decodable, Equatable, Sendable { public let id: User.Id; public let username: String }
      public enum Change: Equatable, Sendable {
          case customField(field: String, value: String)
          case field(key: String, old: JSONValue?, new: JSONValue?)
          case relation(key: String, operation: String, objects: [String])
      }
  }
  static func AuditLogEntry.testValue(action:actor:changes:id:timestamp:) -> AuditLogEntry
  static func AuditLogEntry.Actor.testValue(id:username:) -> AuditLogEntry.Actor
  ```

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/History/AuditLogEntryTests.swift`. The payloads are recorded from the paperless-ngx 3.0.5 dev instance.

```swift
@testable import ApiInterface

import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct AuditLogEntryTests {

    @Test
    func decoding_readsAnM2MChangeAndItsActor() throws {
        let entry = try decode(#"""
        {"id": 106, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "update",
         "changes": {"tags": {"type": "m2m", "operation": "add", "objects": ["Audio", "Manual"]}},
         "actor": {"id": 2, "username": "admin"}}
        """#)

        #expect(entry.id == 106)
        #expect(entry.action == .update)
        #expect(entry.actor == .testValue(id: 2, username: "admin"))
        #expect(entry.changes == [.relation(key: "tags", operation: "add", objects: ["Audio", "Manual"])])
    }

    @Test
    func decoding_readsFieldChangesSortedByKeyWithNoneAsNil() throws {
        let entry = try decode(#"""
        {"id": 105, "timestamp": "2026-09-07T11:37:29.576535Z", "action": "update",
         "changes": {"storage_path": ["None", "3"], "correspondent": ["None", "8"]},
         "actor": null}
        """#)

        #expect(entry.actor == nil)
        #expect(entry.changes == [
            .field(key: "correspondent", old: nil, new: .string("8")),
            .field(key: "storage_path", old: nil, new: .string("3")),
        ])
    }

    // Not every pair is two strings: notes send a number, and a tag change written outside the bulk
    // editor sends raw ids — the source of the web's "Tags: 7".
    @Test
    func decoding_keepsNonStringPairs() throws {
        let entry = try decode(#"""
        {"id": 3234, "timestamp": "2026-09-25T17:51:35.821786Z", "action": "update",
         "changes": {"Note Added": ["None", 40], "tags": [null, [102]]}, "actor": null}
        """#)

        #expect(entry.changes == [
            .field(key: "Note Added", old: nil, new: .number(40)),
            .field(key: "tags", old: nil, new: .array([.number(102)])),
        ])
    }

    @Test
    func decoding_readsACustomFieldChange() throws {
        let entry = try decode(#"""
        {"id": 7, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "create",
         "changes": {"custom_fields": {"type": "custom_field", "field": "Invoice", "value": "42"}},
         "actor": {"id": 2, "username": "admin"}}
        """#)

        #expect(entry.action == .create)
        #expect(entry.changes == [.customField(field: "Invoice", value: "42")])
    }

    @Test
    func decoding_skipsAnUnknownChangeShapeAndKeepsTheRest() throws {
        let entry = try decode(#"""
        {"id": 8, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "update",
         "changes": {"mystery": {"type": "something_new"}, "title": ["Old", "New"]}, "actor": null}
        """#)

        #expect(entry.changes == [.field(key: "title", old: .string("Old"), new: .string("New"))])
    }

    @Test
    func decoding_keepsAnUnknownActionAsOther() throws {
        let entry = try decode(#"""
        {"id": 9, "timestamp": "2026-09-07T11:37:29.581744Z", "action": "access", "changes": {}, "actor": null}
        """#)

        #expect(entry.action == .other("access"))
        #expect(entry.changes.isEmpty)
    }

    @Test
    func decoding_readsAListResponse() throws {
        let entries = try JSONDecoder.apiDecoder.decode(
            [AuditLogEntry].self,
            from: Data(#"""
            [{"id": 2, "timestamp": "2026-09-07T11:30:00.620678Z", "action": "update",
              "changes": {"created": ["2026-09-07", "2026-09-07 13:29:34+02:00"]}, "actor": null},
             {"id": 1, "timestamp": "2026-09-07T11:30:00.613971Z", "action": "create",
              "changes": {"title": ["None", "Sonos Sub"]}, "actor": null}]
            """#.utf8)
        )

        #expect(entries.map(\.id) == [2, 1])
    }

    private func decode(_ json: String) throws -> AuditLogEntry {
        try JSONDecoder.apiDecoder.decode(AuditLogEntry.self, from: Data(json.utf8))
    }
}
```

- [ ] **Step 2: Run to verify failure**

`ApiInterface` / `ApiInterfaceTests/AuditLogEntryTests`.
Expected: build failure — `cannot find 'AuditLogEntry' in scope`.

- [ ] **Step 3: Implement**

Create `Modules/ApiInterface/History/AuditLogEntry.swift`:

```swift
import Foundation
import Tagged

public struct AuditLogEntry: Equatable, Identifiable, Sendable {

    public typealias Id = Tagged<AuditLogEntry, Int>

    public let action: Action

    public let actor: Actor?

    public let changes: [Change]

    public let id: Id

    public let timestamp: Date

    public init(
        action: Action,
        actor: Actor?,
        changes: [Change],
        id: Id,
        timestamp: Date
    ) {
        self.action = action
        self.actor = actor
        self.changes = changes
        self.id = id
        self.timestamp = timestamp
    }
}

public extension AuditLogEntry {

    enum Action: Equatable, Sendable {
        case create
        case delete
        case other(String)
        case update
    }

    // The payload's actor carries two fields where User carries thirteen, so it cannot be decoded
    // as one — the same reason Note has its own Author.
    struct Actor: Decodable, Equatable, Sendable {

        public let id: User.Id

        public let username: String

        public init(
            id: User.Id,
            username: String
        ) {
            self.id = id
            self.username = username
        }
    }

    enum Change: Equatable, Sendable {
        case customField(field: String, value: String)
        case field(key: String, old: JSONValue?, new: JSONValue?)
        case relation(key: String, operation: String, objects: [String])
    }
}

extension AuditLogEntry: Decodable {

    private enum CodingKeys: String, CodingKey {
        case action, actor, changes, id, timestamp
    }

    // Sorted by key, as the web's keyvalue pipe sorts them, so both list a change in the same
    // place. A shape nothing here recognises costs its own line, not the entry: the audit log is
    // written by many server paths and one of them may grow a new shape.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        action = try container.decode(Action.self, forKey: .action)
        actor = try container.decodeIfPresent(Actor.self, forKey: .actor)
        id = try container.decode(Id.self, forKey: .id)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        changes = try (container.decodeIfPresent([String: JSONValue].self, forKey: .changes) ?? [:])
            .sorted { $0.key < $1.key }
            .compactMap { Change(key: $0.key, value: $0.value) }
    }
}

extension AuditLogEntry.Action: Decodable {

    public init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        switch value {
        case "create": self = .create
        case "delete": self = .delete
        case "update": self = .update
        default: self = .other(value)
        }
    }
}

private extension AuditLogEntry.Change {

    init?(key: String, value: JSONValue) {
        switch value {
        case let .array(pair) where pair.count == 2:
            self = .field(key: key, old: pair[0].auditLogValue, new: pair[1].auditLogValue)
        case let .object(object):
            switch object["type"]?.stringValue {
            case "m2m":
                guard let operation = object["operation"]?.stringValue,
                      let objects = object["objects"]?.arrayValue
                else {
                    return nil
                }
                self = .relation(key: key, operation: operation, objects: objects.compactMap(\.stringValue))
            case "custom_field":
                guard let field = object["field"]?.stringValue,
                      let value = object["value"]?.stringValue
                else {
                    return nil
                }
                self = .customField(field: field, value: value)
            default:
                return nil
            }
        default:
            return nil
        }
    }
}

private extension JSONValue {

    // django-auditlog writes an empty side as the string "None", and some paths as null.
    var auditLogValue: JSONValue? {
        switch self {
        case .null, .string("None"):
            nil
        default:
            self
        }
    }
}

public extension AuditLogEntry {

    static func testValue(
        action: Action = .update,
        actor: Actor? = .testValue(),
        changes: [Change] = [.relation(key: "tags", operation: "add", objects: ["Privat"])],
        id: Id = 1,
        timestamp: Date = .testValue()
    ) -> Self {
        .init(
            action: action,
            actor: actor,
            changes: changes,
            id: id,
            timestamp: timestamp
        )
    }
}

public extension AuditLogEntry.Actor {

    static func testValue(
        id: User.Id = 1,
        username: String = "admin"
    ) -> Self {
        .init(
            id: id,
            username: username
        )
    }
}
```

- [ ] **Step 4: Run to verify pass**

`ApiInterface` / `ApiInterfaceTests/AuditLogEntryTests`. Expected: 7 PASS. If the timestamp fails to decode, the `…SSSSSSZ` formatter in `JSONDecoder+Extensions.swift` is not matching `Z`; fix in the model's test payload only if the dev server truly sends another format (it sends `2026-09-25T17:51:36.609630Z`).

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/History Modules/ApiInterfaceTests/History
git commit -m "feat: decode a document's audit log entries

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 4: `GetDocumentHistoryUseCase` and `HistoryRepository`

**Files:**
- Create: `Modules/ApiInterface/History/GetDocumentHistoryUseCase.swift`
- Create: `Modules/ApiImplementation/History/HistoryRepository.swift`
- Create: `Modules/ApiImplementation/History/GetDocumentHistoryUseCase.swift`
- Test: `Modules/ApiImplementationTests/History/HistoryRepositoryTests.swift`

**Interfaces:**
- Consumes: `AuditLogEntry` (Task 3).
- Produces: `DependencyValues.getDocumentHistory: GetDocumentHistoryUseCase` with `execute: (Document.Id, Server) async throws -> [AuditLogEntry]`.

- [ ] **Step 1: Write the failing integration test**

Create `Modules/ApiImplementationTests/History/HistoryRepositoryTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct HistoryRepositoryTests {

    // Every consumed document has at least its create entry, so an empty answer means the request
    // or the decoding went wrong, not that there is no history.
    @Test(
        .testDependencies {
            $0.authenticationProvider = .integrationTest
            $0.context = .live
        },
        .tags(.integrationTests)
    )
    func test_getHistory_returnsTheCreateEntry() async throws {
        let documents = try await documentsRepository.getDocuments(
            input: .testValue(),
            server: .testValue()
        ).results
        let documentId = try #require(documents.first).id

        let entries = try await repository.getHistory(
            documentId: documentId,
            server: .testValue()
        )

        #expect(entries.contains { $0.action == .create })
    }

    @Dependency(\.historyRepository)
    private var repository

    @Dependency(\.documentsRepository)
    private var documentsRepository
}
```

- [ ] **Step 2: Run to verify failure**

`ApiImplementation` / `ApiImplementationTests/HistoryRepositoryTests`.
Expected: build failure — `value of type 'DependencyValues' has no member 'historyRepository'`.

- [ ] **Step 3: Implement**

`Modules/ApiInterface/History/GetDocumentHistoryUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetDocumentHistoryUseCase: Sendable {

    public var execute: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [AuditLogEntry]
}

extension GetDocumentHistoryUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _, _ in [.testValue()] }
    )

    public static let testValue = Self(
        execute: { _, _ in [.testValue()] }
    )
}

public extension DependencyValues {

    var getDocumentHistory: GetDocumentHistoryUseCase {
        get { self[GetDocumentHistoryUseCase.self] }
        set { self[GetDocumentHistoryUseCase.self] = newValue }
    }
}
```

`Modules/ApiImplementation/History/HistoryRepository.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct HistoryRepository: Sendable {

    var getHistory: @Sendable (
        _ documentId: Document.Id,
        _ server: Server
    ) async throws -> [AuditLogEntry]
}

extension HistoryRepository: TestDependencyKey {

    static let previewValue = Self(
        getHistory: { _, _ in [.testValue()] }
    )

    static let testValue = Self(
        getHistory: { _, _ in [.testValue()] }
    )
}

extension DependencyValues {

    var historyRepository: HistoryRepository {
        get { self[HistoryRepository.self] }
        set { self[HistoryRepository.self] = newValue }
    }
}

extension HistoryRepository: DependencyKey {
    static let liveValue = Self(
        getHistory: getHistory(documentId:server:)
    )
}

private extension HistoryRepository {

    static func getHistory(
        documentId: Document.Id,
        server: Server
    ) async throws -> [AuditLogEntry] {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/documents/\(documentId)/history/",
                method: .get
            ))
            .value
    }
}
```

`Modules/ApiImplementation/History/GetDocumentHistoryUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetDocumentHistoryUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(documentId:server:)
    )
}

private extension GetDocumentHistoryUseCase {

    static func execute(
        documentId: Document.Id,
        server: Server
    ) async throws -> [AuditLogEntry] {
        @Dependency(\.historyRepository)
        var repository

        return try await repository.getHistory(
            documentId: documentId,
            server: server
        )
    }
}
```

- [ ] **Step 4: Run to verify pass**

`ApiImplementation` / `ApiImplementationTests/HistoryRepositoryTests` with `TUIST_PAPERLESS_TEST_URL` exported for generate and test. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/History Modules/ApiImplementation/History Modules/ApiImplementationTests/History
git commit -m "feat: fetch a document's history

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 5: `DocumentHistoryReducer`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryReducer+Effect.swift`
- Create: `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentHistory/DocumentHistoryReducerTests.swift`

**Interfaces:**
- Consumes: `\.getDocumentHistory.execute` (Task 4).
- Produces: `DocumentHistoryReducer` with `State(documentId:server:)`, `state.entries: [AuditLogEntry]?`, `state.isLoading`, `state.loadError: String?`, `state.server`; actions `.historyResult(Result<[AuditLogEntry], Error>)`, `.view(.onAppear)`, `.view(.retryLoadButtonTapped)`; `State.testValue(documentId:entries:isLoading:loadError:server:)`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentHistory/DocumentHistoryReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentHistoryReducerTests {

    @Test
    func test_view_onAppear_loadsHistory() async throws {
        let entries = [AuditLogEntry.testValue()]
        let store = TestStore(initialState: DocumentHistoryReducer.State.testValue()) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in entries }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.entries = entries
        }
    }

    @Test
    func test_view_onAppear_passesTheDocumentIdAndServer() async throws {
        let received = LockIsolated<(id: Document.Id, server: Server)?>(nil)
        let server = Server.testValue(alias: "home")
        let store = TestStore(initialState: DocumentHistoryReducer.State.testValue(
            documentId: 42,
            server: server
        )) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { id, server in
                received.setValue((id, server))
                return []
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.entries = []
        }

        #expect(received.value?.id == 42)
        #expect(received.value?.server == server)
    }

    @Test
    func test_view_onAppear_alreadyLoaded_doesNotRefetch() async throws {
        let store = TestStore(
            initialState: DocumentHistoryReducer.State.testValue(entries: [.testValue()])
        ) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in
                Issue.record("History must load once per sheet, not on every return to the section.")
                return []
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_afterFailure_doesNotRetrySilently() async throws {
        let store = TestStore(
            initialState: DocumentHistoryReducer.State.testValue(loadError: "Audit log is disabled")
        ) {
            DocumentHistoryReducer()
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_view_onAppear_failure_setsLoadErrorAndToasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: DocumentHistoryReducer.State.testValue()) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in throw ApiError.testValue() }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.loadError = ApiError.testValue().localizedDescription
        }

        #expect(toasts.value.count == 1)
    }

    @Test
    func test_view_retryLoadButtonTapped_clearsTheErrorAndRefetches() async throws {
        let entries = [AuditLogEntry.testValue()]
        let store = TestStore(
            initialState: DocumentHistoryReducer.State.testValue(loadError: "Audit log is disabled")
        ) {
            DocumentHistoryReducer()
        } withDependencies: {
            $0.getDocumentHistory.execute = { _, _ in entries }
        }

        await store.send(.view(.retryLoadButtonTapped)) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.historyResult) {
            $0.isLoading = false
            $0.entries = entries
        }
    }
}
```

- [ ] **Step 2: Run to verify failure**

`DocumentsFeature` / `DocumentsFeatureTests/DocumentHistoryReducerTests`.
Expected: build failure — `cannot find 'DocumentHistoryReducer' in scope`. (If `$0.toastPresenter.present` or `ApiError.testValue()` does not compile, open `DocumentMetadataReducerTests.test_view_onAppear_failure_setsLoadErrorAndToasts` and copy its exact spelling — this test mirrors it.)

- [ ] **Step 3: Implement**

`DocumentHistoryReducer.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentHistoryReducer: Sendable {

    public enum Action: ViewAction {
        case historyResult(Result<[AuditLogEntry], Error>)
        case view(View)

        public enum View {
            case onAppear
            case retryLoadButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable {

        let documentId: Document.Id

        // nil until the first load lands; an empty array means loaded with nothing to show.
        var entries: [AuditLogEntry]?

        var isLoading = false

        var loadError: String?

        let server: Server

        init(
            documentId: Document.Id,
            server: Server
        ) {
            self.documentId = documentId
            self.server = server
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .historyResult(result):
                state.isLoading = false
                switch result {
                case let .failure(error):
                    state.loadError = error.localizedDescription
                    return .toast(error)
                case let .success(entries):
                    state.loadError = nil
                    state.entries = entries
                    return .none
                }
            case let .view(viewAction):
                switch viewAction {
                case .onAppear:
                    // Switching sections away and back must not refetch, and a failed load is not
                    // retried silently — that is what the retry button is for.
                    guard state.entries == nil, state.loadError == nil, !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    return .runGetDocumentHistory(
                        documentId: state.documentId,
                        server: state.server
                    )
                case .retryLoadButtonTapped:
                    guard !state.isLoading else {
                        return .none
                    }
                    state.isLoading = true
                    state.loadError = nil
                    return .runGetDocumentHistory(
                        documentId: state.documentId,
                        server: state.server
                    )
                }
            }
        }
    }
}
```

`DocumentHistoryReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == DocumentHistoryReducer.Action {

    static func runGetDocumentHistory(
        documentId: Document.Id,
        server: Server
    ) -> Self {
        .run { send in
            @Dependency(\.getDocumentHistory.execute)
            var getDocumentHistory
            try await send(.historyResult(.success(getDocumentHistory(documentId, server))))
        } catch: { error, send in
            await send(.historyResult(.failure(error)))
        }
    }
}
```

`DocumentHistoryReducer+TestValue.swift`:

```swift
import ApiInterface
import Foundation

extension DocumentHistoryReducer.State {

    static func testValue(
        documentId: Document.Id = 1,
        entries: [AuditLogEntry]? = nil,
        isLoading: Bool = false,
        loadError: String? = nil,
        server: Server = .testValue()
    ) -> Self {
        var state = Self(
            documentId: documentId,
            server: server
        )
        state.entries = entries
        state.isLoading = isLoading
        state.loadError = loadError
        return state
    }
}
```

- [ ] **Step 4: Run to verify pass**

`DocumentsFeature` / `DocumentsFeatureTests/DocumentHistoryReducerTests`. Expected: 6 PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature/DocumentHistory Modules/DocumentsFeatureTests/DocumentHistory
git commit -m "feat: load a document's history in its own reducer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 6: Turn a change into a display line

**Files:**
- Create: `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryChangeLine.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentHistory/DocumentHistoryChangeLineTests.swift`

**Interfaces:**
- Consumes: `AuditLogEntry.Change` (Task 3); `Correspondent.Id.get(_:)`, `DocumentType.Id.get(_:)`, `StoragePath.Id.get(_:)`, `User.Id.get(_:)` and `@Dependency(\.apiCache).tag(id:server:)` (existing).
- Produces:
  ```swift
  struct DocumentHistoryChangeLine: Equatable {
      let label: String      // "Add Tags", "Document_type", "Invoice"
      let value: String      // "Privat", "Information", "42"
      init(change: AuditLogEntry.Change, server: Server)
  }
  ```

The web's `titlecase` pipe upper-cases the first letter of each space-separated word and lower-cases the rest, so `document_type` → `Document_type` and `Note Added` → `Note Added`. The app matches it.

- [ ] **Step 1: Write the failing tests**

`Modules/DocumentsFeatureTests/DocumentHistory/DocumentHistoryChangeLineTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .testDependencies()
)
struct DocumentHistoryChangeLineTests {

    @Test
    func relation_readsOperationKeyAndObjects() {
        let line = DocumentHistoryChangeLine(
            change: .relation(key: "tags", operation: "add", objects: ["Audio", "Manual"]),
            server: .testValue()
        )

        #expect(line == .init(label: "Add Tags", value: "Audio, Manual"))
    }

    @Test
    func customField_readsFieldAndValue() {
        let line = DocumentHistoryChangeLine(
            change: .customField(field: "Invoice", value: "42"),
            server: .testValue()
        )

        #expect(line == .init(label: "Invoice", value: "42"))
    }

    // Underscores survive, matching the web's titlecase pipe.
    @Test
    func field_titleCasesTheKeyLikeTheWeb() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "archive_serial_number", old: nil, new: .string("2")),
            server: .testValue()
        )

        #expect(line == .init(label: "Archive_serial_number", value: "2"))
    }

    @Test
    func field_resolvesACorrespondentIdToItsName() {
        withDependencies {
            $0.apiCache.correspondent = { id, _ in id == 8 ? .testValue(id: 8, name: "ACME") : nil }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "correspondent", old: nil, new: .string("8")),
                server: .testValue()
            )

            #expect(line == .init(label: "Correspondent", value: "ACME"))
        }
    }

    @Test
    func field_fallsBackToTheIdWhenTheCacheHasNoMatch() {
        withDependencies {
            $0.apiCache.correspondent = { _, _ in nil }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "correspondent", old: nil, new: .string("8")),
                server: .testValue()
            )

            #expect(line == .init(label: "Correspondent", value: "8"))
        }
    }

    @Test
    func field_resolvesAStoragePathToItsPath() {
        withDependencies {
            $0.apiCache.storagePath = { _, _ in .testValue(id: 3, path: "Emma/{{ created_year }}") }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "storage_path", old: nil, new: .string("3")),
                server: .testValue()
            )

            #expect(line == .init(label: "Storage_path", value: "Emma/{{ created_year }}"))
        }
    }

    @Test
    func field_resolvesAnOwnerToTheUsername() {
        withDependencies {
            $0.apiCache.user = { _, _ in .testValue(id: 2, username: "johannes") }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "owner", old: nil, new: .string("2")),
                server: .testValue()
            )

            #expect(line == .init(label: "Owner", value: "johannes"))
        }
    }

    // The web shows "Tags: 7" here. The ids are in the cache, so the app can do better.
    @Test
    func field_resolvesRawTagIdsToNames() {
        withDependencies {
            $0.apiCache.tag = { id, _ in
                switch id {
                case 96: .testValue(id: 96, name: "Invoice")
                case 97: .testValue(id: 97, name: "Paid")
                default: nil
                }
            }
        } operation: {
            let line = DocumentHistoryChangeLine(
                change: .field(key: "tags", old: .number(97), new: .array([.number(96), .number(97), .number(5)])),
                server: .testValue()
            )

            #expect(line == .init(label: "Tags", value: "Invoice, Paid, 5"))
        }
    }

    @Test
    func field_showsANoteIdAsAnInteger() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "Note Added", old: nil, new: .number(40)),
            server: .testValue()
        )

        #expect(line == .init(label: "Note Added", value: "40"))
    }

    @Test
    func field_cutsContentAtAHundredCharacters() {
        let content = String(repeating: "a", count: 150)
        let line = DocumentHistoryChangeLine(
            change: .field(key: "content", old: nil, new: .string(content)),
            server: .testValue()
        )

        #expect(line.value == String(repeating: "a", count: 100) + "…")
    }

    @Test
    func field_leavesShortContentWhole() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "content", old: nil, new: .string("Sub")),
            server: .testValue()
        )

        #expect(line.value == "Sub")
    }

    @Test
    func field_showsAnEmDashWhenTheNewValueIsGone() {
        let line = DocumentHistoryChangeLine(
            change: .field(key: "Note Deleted", old: .number(40), new: nil),
            server: .testValue()
        )

        #expect(line == .init(label: "Note Deleted", value: "—"))
    }
}
```

- [ ] **Step 2: Run to verify failure**

`DocumentsFeature` / `DocumentsFeatureTests/DocumentHistoryChangeLineTests`.
Expected: build failure — `cannot find 'DocumentHistoryChangeLine' in scope`. (If a fixture such as `Correspondent.testValue(id:name:)`, `StoragePath.testValue(id:path:)` or `Tag.testValue(id:name:)` has different labels, read its `testValue` in `Modules/ApiInterface/<Entity>/<Entity>.swift` and adjust the call — do not add new fixtures.)

- [ ] **Step 3: Implement**

`Modules/DocumentsFeature/DocumentHistory/DocumentHistoryChangeLine.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation

struct DocumentHistoryChangeLine: Equatable {

    let label: String

    let value: String
}

extension DocumentHistoryChangeLine {

    init(change: AuditLogEntry.Change, server: Server) {
        switch change {
        case let .customField(field, value):
            self.init(label: field, value: value)
        case let .field(key, _, new):
            self.init(label: key.titleCased, value: Self.value(for: key, new, server: server))
        case let .relation(key, operation, objects):
            self.init(label: "\(operation.titleCased) \(key.titleCased)", value: objects.joined(separator: ", "))
        }
    }

    private static let contentLimit = 100

    // Names are resolved on every render rather than stored: a correspondent renamed since reads
    // with its current name without refetching the history.
    private static func value(for key: String, _ value: JSONValue?, server: Server) -> String {
        guard let value else {
            return "—"
        }

        switch key {
        case "content":
            let text = value.auditLogText
            return text.count > contentLimit ? String(text.prefix(contentLimit)) + "…" : text
        case "correspondent":
            return resolve(value) { Correspondent.Id(rawValue: $0).get(server)?.name }
        case "document_type":
            return resolve(value) { DocumentType.Id(rawValue: $0).get(server)?.name }
        case "owner":
            return resolve(value) { User.Id(rawValue: $0).get(server)?.username }
        case "storage_path":
            return resolve(value) { StoragePath.Id(rawValue: $0).get(server)?.path }
        case "tags":
            @Dependency(\.apiCache)
            var apiCache
            return resolve(value) { apiCache.tag(Tag.Id(rawValue: $0), server)?.name }
        default:
            return value.auditLogText
        }
    }

    private static func resolve(_ value: JSONValue, name: (Int) -> String?) -> String {
        if case let .array(values) = value {
            return values.map { resolve($0, name: name) }.joined(separator: ", ")
        }
        guard let id = value.auditLogId else {
            return value.auditLogText
        }
        return name(id) ?? String(id)
    }
}

private extension JSONValue {

    // Ids arrive as strings ("8") from the scalar-change path and as numbers (97) from the others.
    var auditLogId: Int? {
        switch self {
        case let .number(value):
            Int(exactly: value)
        case let .string(value):
            Int(value)
        default:
            nil
        }
    }

    var auditLogText: String {
        switch self {
        case let .array(values):
            values.map(\.auditLogText).joined(separator: ", ")
        case let .bool(value):
            String(value)
        case .null:
            "—"
        case let .number(value):
            Int(exactly: value).map(String.init) ?? String(value)
        case .object:
            "…"
        case let .string(value):
            value
        }
    }
}

private extension String {

    // The web's titlecase pipe: first letter of each space-separated word up, the rest down.
    var titleCased: String {
        split(separator: " ", omittingEmptySubsequences: false)
            .map { $0.prefix(1).uppercased() + $0.dropFirst().lowercased() }
            .joined(separator: " ")
    }
}
```

Check `ApiCache.tag`'s closure labels in `Modules/ApiInterface/Shared/ApiCache.swift` line ~35; if it is declared `(_ id: Tag.Id?, _ server: Server)`, the call above is right. Adjust only if the compiler disagrees.

- [ ] **Step 4: Run to verify pass**

`DocumentsFeature` / `DocumentsFeatureTests/DocumentHistoryChangeLineTests`. Expected: 12 PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature/DocumentHistory Modules/DocumentsFeatureTests/DocumentHistory
git commit -m "feat: word a history change the way the web does, with names for ids

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 7: History section in the viewer, gated at every entrance

**Files:**
- Create: `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryEntryView.swift`
- Create: `Modules/DocumentsFeature/DocumentHistory/DocumentHistoryView.swift`
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerSection.swift`
- Modify: `Modules/DocumentsFeature/DocumentViewer/DocumentViewerReducer.swift`, `DocumentViewerReducer+TestValue.swift`, `DocumentViewerView.swift`
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailReducer.swift:83`, `DocumentDetailView.swift:127-133`
- Modify: `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift:107`, `DocumentRowView.swift:101-105`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Test: `Modules/DocumentsFeatureTests/DocumentViewer/DocumentViewerSectionTests.swift` (create), `DocumentViewerReducerTests.swift`, `DocumentDetail/DocumentDetailReducerTests.swift`, `DocumentRow/DocumentRowReducerTests.swift`, `DocumentHistory/DocumentHistoryViewTests.swift` (create)

**Interfaces:**
- Consumes: `DocumentHistoryReducer` (Task 5), `DocumentHistoryChangeLine` (Task 6), `ServerPermissions.canViewHistory(of:)` (Task 2).
- Produces: `DocumentViewerSection.history`; `static func DocumentViewerSection.visible(canViewHistory: Bool, canViewNotes: Bool) -> [DocumentViewerSection]`; `canViewHistory: Bool` on `DocumentDetailReducer.State`, `DocumentRowReducer.State`, `DocumentViewerReducer.State`; `DocumentViewerReducer.State.history`; `DocumentViewerReducer.State.testValue(…, history: [AuditLogEntry]? = nil, …)`.

- [ ] **Step 1: Add the strings**

Add these keys to `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, keeping keys sorted, each shaped exactly like the existing `notes` entry:

| key | en | de |
| --- | --- | --- |
| `auditLogActionCreate` | Create | Erstellt |
| `auditLogActionDelete` | Delete | Gelöscht |
| `auditLogActionUpdate` | Update | Geändert |
| `history` | History | Verlauf |
| `noHistoryFound` | No entries found. | Keine Einträge gefunden. |
| `system` | System | System |

Use a script so the ordering is exact:

```bash
python3 - <<'EOF'
import json
p = "Modules/DocumentsFeature/Resources/Localizable.xcstrings"
d = json.load(open(p))
new = {
    "auditLogActionCreate": ("Create", "Erstellt"),
    "auditLogActionDelete": ("Delete", "Gelöscht"),
    "auditLogActionUpdate": ("Update", "Geändert"),
    "history": ("History", "Verlauf"),
    "noHistoryFound": ("No entries found.", "Keine Einträge gefunden."),
    "system": ("System", "System"),
}
for key, (en, de) in new.items():
    assert key not in d["strings"], key
    d["strings"][key] = {
        "extractionState": "manual",
        "localizations": {
            "de": {"stringUnit": {"state": "translated", "value": de}},
            "en": {"stringUnit": {"state": "translated", "value": en}},
        },
    }
d["strings"] = dict(sorted(d["strings"].items()))
json.dump(d, open(p, "w"), ensure_ascii=False, indent=2, separators=(",", " : "))
open(p, "a").write("\n")
EOF
git diff --stat Modules/DocumentsFeature/Resources/Localizable.xcstrings
```

Expected: only additions (~60 lines). If the diff rewrites unrelated lines, the file's formatting differs from `indent=2, separators=(",", " : ")` — `git checkout` the file, inspect its first 20 lines, match the format, and rerun.

- [ ] **Step 2: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentViewer/DocumentViewerSectionTests.swift`:

```swift
@testable import DocumentsFeature

import Testing

@Suite
struct DocumentViewerSectionTests {

    @Test
    func visible_everythingAllowed() {
        #expect(DocumentViewerSection.visible(canViewHistory: true, canViewNotes: true) == [
            .content, .customFields, .history, .metadata, .notes,
        ])
    }

    @Test
    func visible_dropsHistory() {
        #expect(DocumentViewerSection.visible(canViewHistory: false, canViewNotes: true) == [
            .content, .customFields, .metadata, .notes,
        ])
    }

    @Test
    func visible_dropsNotes() {
        #expect(DocumentViewerSection.visible(canViewHistory: true, canViewNotes: false) == [
            .content, .customFields, .history, .metadata,
        ])
    }

    @Test
    func visible_dropsBoth() {
        #expect(DocumentViewerSection.visible(canViewHistory: false, canViewNotes: false) == [
            .content, .customFields, .metadata,
        ])
    }
}
```

Append to `DocumentViewerReducerTests` (next to `theSectionMenuOpensWithViewNote`):

```swift
    @Test
    func theSectionMenuDropsHistoryOnAnotherUsersDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        @Shared(.auditLogEnabled(server)) var auditLogEnabled: Bool?
        $currentUser.withLock { $0 = .testValue(id: 5, isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewLogEntry] }
        $auditLogEnabled.withLock { $0 = true }

        let state = DocumentViewerReducer.State.testValue(document: .testValue(owner: 6), server: server)

        #expect(!state.canViewHistory)
    }

    @Test
    func theSectionMenuOffersHistoryOnTheUsersOwnDocument() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        @Shared(.auditLogEnabled(server)) var auditLogEnabled: Bool?
        $currentUser.withLock { $0 = .testValue(id: 5, isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument, .viewLogEntry] }
        $auditLogEnabled.withLock { $0 = true }

        let state = DocumentViewerReducer.State.testValue(document: .testValue(owner: 5), server: server)

        #expect(state.canViewHistory)
    }
```

In `test_isContentScrollable_perSection`, before the `var content = loaded` line, add:

```swift
        var history = loaded
        history.section = .history
        #expect(!history.isContentScrollable)
```

Append to `DocumentDetailReducerTests` (next to `canViewNotesOpensWithViewNote`; copy that test's state construction for the detail reducer):

```swift
    @Test
    func canViewHistoryFollowsTheAuditLogFlag() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        @Shared(.auditLogEnabled(server)) var auditLogEnabled: Bool?
        $currentUser.withLock { $0 = .testValue(id: 5, isSuperuser: false) }
        $permissions.withLock { $0 = [.viewLogEntry] }
        $auditLogEnabled.withLock { $0 = false }

        let state = DocumentDetailReducer.State.testValue(document: .testValue(owner: 5), server: server)

        #expect(!state.canViewHistory)
    }
```

Append to `DocumentRowReducerTests` (next to the `canViewNotes` tests around line 253; copy how that test builds `state`):

```swift
    @Test
    func canViewHistoryNeedsViewLogEntry() {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        @Shared(.auditLogEnabled(server)) var auditLogEnabled: Bool?
        $currentUser.withLock { $0 = .testValue(id: 5, isSuperuser: false) }
        $permissions.withLock { $0 = [.viewDocument] }
        $auditLogEnabled.withLock { $0 = true }

        let state = DocumentRowReducer.State.testValue(document: .testValue(owner: 5), server: server)

        #expect(!state.canViewHistory)
    }
```

If `DocumentDetailReducer.State.testValue` or `DocumentRowReducer.State.testValue` names its parameters differently, read the `+TestValue.swift` file next to the reducer and use its labels.

Create `Modules/DocumentsFeatureTests/DocumentHistory/DocumentHistoryViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Dependencies
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentHistoryViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(state: .testValue(entries: [
                .testValue(
                    actor: .testValue(id: 2, username: "johannes"),
                    changes: [.field(key: "tags", old: .number(7), new: .array([.number(1), .number(7)]))],
                    id: 3,
                    timestamp: now.addingTimeInterval(-11 * 3600)
                ),
                .testValue(
                    actor: nil,
                    changes: [
                        .field(key: "document_type", old: nil, new: .string("1")),
                        .relation(key: "tags", operation: "add", objects: ["Privat"]),
                    ],
                    id: 2,
                    timestamp: now.addingTimeInterval(-21 * 3600)
                ),
                .testValue(
                    action: .create,
                    actor: nil,
                    changes: [.field(key: "title", old: nil, new: .string("Elternbrief"))],
                    id: 1,
                    timestamp: now.addingTimeInterval(-22 * 3600)
                ),
            ])),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    @Test
    func testSnapshot_empty() async throws {
        assertSnapshot(
            of: view(state: .testValue(entries: [])),
            as: .image(layout: .device(config: .iPhone12)),
            named: "empty"
        )
    }

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(loadError: "Audit log is disabled")),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    private let now = Date.testValue()

    // Relative times are measured against the dependency clock, so the capture is the same on
    // every run.
    private func view(state: DocumentHistoryReducer.State) -> some View {
        withDependencies {
            $0.date.now = now
        } operation: {
            DocumentHistoryView(
                store: Store(
                    initialState: state,
                    reducer: {
                        DocumentHistoryReducer()
                    }
                )
            )
        }
    }
}
```

- [ ] **Step 3: Run to verify failure**

`DocumentsFeature` / `DocumentsFeatureTests/DocumentViewerSectionTests`.
Expected: build failure — `type 'DocumentViewerSection' has no member 'history'`.

- [ ] **Step 4: Implement the section and the helper**

In `DocumentViewerSection.swift`, add `case history` between `customFields` and `metadata`, then in `localized` add `case .history: .history`, and in `systemImage` add `case .history: "clock.arrow.circlepath"`. Add below the existing extension:

```swift
extension DocumentViewerSection {

    // The one place a section is dropped for lack of permission. Three menus open this sheet — the
    // detail toolbar, the row's context menu and the sheet's own picker — and each copy of the
    // filter was one more place to forget a new section.
    static func visible(canViewHistory: Bool, canViewNotes: Bool) -> [Self] {
        allCases.filter { section in
            switch section {
            case .content, .customFields, .metadata:
                true
            case .history:
                canViewHistory
            case .notes:
                canViewNotes
            }
        }
    }
}
```

Update the comment on `DocumentViewerMenu` (`DocumentViewerMenu.swift`) that says the detail toolbar narrows `sections` "to drop Notes without `view_note`" to: "…the callers narrow it through `DocumentViewerSection.visible`, which drops Notes and History the user cannot read."

- [ ] **Step 5: Wire the reducers**

`DocumentViewerReducer.swift`:
- Action: add `case history(DocumentHistoryReducer.Action)` (alphabetical, after `documentResult`).
- State: add `var history: DocumentHistoryReducer.State` after `customFields`; add `var canViewHistory: Bool { permissions.canViewHistory(of: document) }` after `canViewNotes`.
- `isContentScrollable`: add `case .history: return false` with the comment `// The list scrolls itself, as Notes does.`
- `init`: add
  ```swift
            self.history = DocumentHistoryReducer.State(
                documentId: document.wrappedValue.id,
                server: server
            )
  ```
- `body`: add after the customFields `Scope`:
  ```swift
        Scope(state: \.history, action: \.history) {
            DocumentHistoryReducer()
        }
  ```
- Change `case .binding, .metadata, .notes:` to `case .binding, .history, .metadata, .notes:`.

`DocumentViewerReducer+TestValue.swift`: add a `history: [AuditLogEntry]? = nil` parameter after `hasLoadedContent` and `state.history.entries = history` in the body.

`DocumentDetailReducer.swift` after line 83, and `DocumentRowReducer.swift` after line 107:

```swift
        var canViewHistory: Bool { permissions.canViewHistory(of: document) }
```

- [ ] **Step 6: Write the views**

`Modules/DocumentsFeature/DocumentHistory/DocumentHistoryEntryView.swift`:

```swift
import ApiInterface
import Components
import DesignTokens
import SwiftUI

struct DocumentHistoryEntryView: View {

    var body: some View {
        VStack(alignment: .leading, spacing: .x3) {
            HStack(spacing: .x2) {
                Text(relativeTimestamp)
                    .foregroundStyle(Color.m3OnSurfaceVariant)
                Text(entry.actor?.username ?? String(localized: .system))
                    .italic()
                    .foregroundStyle(Color.m3OnSurface)
                Spacer(minLength: .x2)
                actionBadge()
            }
            .font(.caption)

            ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                (Text(line.label + ": ").foregroundStyle(Color.m3OnSurface)
                    + Text(line.value).font(.body.monospaced()).foregroundStyle(Color.m3Primary))
                    .font(.body)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.x4)
        .background(Color.m3SurfaceContainer)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .accessibilityElement(children: .combine)
        .listRowBackground(Color.clear)
        // The list is edge to edge, so the row carries the sheet's horizontal inset itself.
        .listRowInsets(EdgeInsets(top: .x3, leading: .x4, bottom: .x3, trailing: .x4))
        .listRowSeparator(.hidden)
    }

    let entry: AuditLogEntry

    let now: Date

    let server: Server

    private var lines: [DocumentHistoryChangeLine] {
        entry.changes.map { DocumentHistoryChangeLine(change: $0, server: server) }
    }

    private var relativeTimestamp: String {
        RelativeDateTimeFormatter().localizedString(for: entry.timestamp, relativeTo: now)
    }

    @ViewBuilder
    private func actionBadge() -> some View {
        let isCreate = entry.action == .create
        Text(actionTitle)
            .padding(.horizontal, .x2)
            .padding(.vertical, 2)
            .background(isCreate ? Color.m3PrimaryContainer : Color.m3SecondaryContainer)
            .foregroundStyle(isCreate ? Color.m3OnPrimaryContainer : Color.m3OnSecondaryContainer)
            .clipShape(Capsule())
    }

    private var actionTitle: String {
        switch entry.action {
        case .create:
            String(localized: .auditLogActionCreate)
        case .delete:
            String(localized: .auditLogActionDelete)
        case let .other(value):
            value.prefix(1).uppercased() + value.dropFirst()
        case .update:
            String(localized: .auditLogActionUpdate)
        }
    }
}
```

If `Text + Text` with `.foregroundStyle` triggers a deprecation warning on this toolchain, build the line with an `AttributedString` instead (label run plus a value run whose `foregroundColor` is `.m3Primary` and `font` is `.body.monospaced()`); a warning is an error on CI.

`Modules/DocumentsFeature/DocumentHistory/DocumentHistoryView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Dependencies
import SwiftUI

@ViewAction(for: DocumentHistoryReducer.self)
struct DocumentHistoryView: View {

    var body: some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentHistoryReducer>

    @Dependency(\.date.now)
    private var now

    @ViewBuilder
    private func content() -> some View {
        if let loadError = store.loadError {
            EmptyListView(
                systemImage: "clock.arrow.circlepath",
                title: .init(stringLiteral: loadError)
            ) {
                Button {
                    send(.retryLoadButtonTapped)
                } label: {
                    Text(.retry)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        } else if let entries = store.entries {
            if entries.isEmpty {
                EmptyListView(
                    systemImage: "clock.arrow.circlepath",
                    title: .noHistoryFound
                )
            } else {
                List(entries) { entry in
                    DocumentHistoryEntryView(entry: entry, now: now, server: store.server)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
        } else {
            ProgressView()
                .controlSize(.large)
        }
    }
}

#Preview {
    DocumentHistoryView(
        store: Store(
            initialState: DocumentHistoryReducer.State.testValue(entries: [.testValue()]),
            reducer: {
                DocumentHistoryReducer()
            }
        )
    )
}
```

`store.server` is a `let` on State, readable because the view is in the same module.

- [ ] **Step 7: Render the section and use the helper at all three menus**

`DocumentViewerView.swift`:
- In `Sheet(padding:)`, change the condition to `store.section == .customFields || store.section == .history || store.section == .notes ? 0 : .x4`.
- In the `switch store.section`, add:
  ```swift
            case .history:
                DocumentHistoryView(store: historyStore)
  ```
- Add next to `metadataStore`:
  ```swift
    private var historyStore: StoreOf<DocumentHistoryReducer> {
        store.scope(state: \.history, action: \.history)
    }
  ```
- In `sectionMenu()`, replace the `ForEach(DocumentViewerSection.allCases.filter { … }, id: \.self)` argument with `DocumentViewerSection.visible(canViewHistory: store.canViewHistory, canViewNotes: store.canViewNotes)`, and replace the comment above it with: `// Sections the server would refuse drop out here too. Gating the entrance one screen earlier is not enough: this picker is a second way into the same sheet.`

`DocumentDetailView.swift` `viewerMenu()` and `DocumentRowView.swift` (around line 101): replace
```swift
        // Without view_note the endpoint answers 403, so Notes drops out here rather than opening
        // onto a section with nothing to show.
        DocumentViewerMenu(
            sections: DocumentViewerSection.allCases.filter { $0 != .notes || store.canViewNotes }
        ) { send(.viewButtonTapped($0)) }
```
with
```swift
        // Notes and History answer 403 without their permissions, so they drop out here rather
        // than opening onto a section with nothing to show.
        DocumentViewerMenu(
            sections: DocumentViewerSection.visible(
                canViewHistory: store.canViewHistory,
                canViewNotes: store.canViewNotes
            )
        ) { send(.viewButtonTapped($0)) }
```

- [ ] **Step 8: Run the logic tests to verify they pass**

Run `DocumentsFeature` with `-only-testing:DocumentsFeatureTests/DocumentViewerSectionTests -only-testing:DocumentsFeatureTests/DocumentViewerReducerTests -only-testing:DocumentsFeatureTests/DocumentDetailReducerTests -only-testing:DocumentsFeatureTests/DocumentRowReducerTests -only-testing:DocumentsFeatureTests/DocumentHistoryReducerTests -only-testing:DocumentsFeatureTests/DocumentHistoryChangeLineTests`.
Expected: all PASS. The existing parameterised `test_view_viewButtonTapped(section:)` tests now also run for `.history` and must pass unchanged.

- [ ] **Step 9: Record and inspect the snapshots**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise run snapshots:record DocumentsFeature --only DocumentsFeatureTests/DocumentHistoryViewTests
```

Expected: the task reports three recorded references (the run ends in `TEST FAILED` — that is success in record mode, per AGENTS.md). **Open each new PNG under `Snapshots/` with the Read tool** and check against the spec's "Rendering an entry":
- the first row shows *11 hours ago*, *johannes*, an *Update* badge and *Tags: One, Seven* (the preview `apiCache.tag` names ids 1 and 7 "One" and "Seven")
- the second shows *System* and two lines, *Document_type: …* and *Add Tags: Privat*
- the third shows a tinted *Create* badge
- empty shows *No entries found.*; error shows the message and a Retry button

Then re-run `DocumentHistoryViewTests` without recording. Expected: PASS.

Existing `DocumentViewerViewTests` snapshots capture the section picker only when it is open, so they should still pass; run `DocumentsFeatureTests/DocumentViewerViewTests` and, if one fails, open the diff with `mise run snapshots:diff` before re-recording — a changed menu is expected, anything else is a bug.

- [ ] **Step 10: Commit**

```bash
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots
git commit -m "feat: a History section in the document viewer

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

---

### Task 8: Whole-branch verification

**Files:** none new.

- [ ] **Step 1: Format and lint**

```bash
mise run format
mise run ci:lint
```

Expected: `ci:lint` exits 0. It stops at the first failing step, so if it fails, fix and run again until it passes — a dependency complaint from `tuist inspect dependencies --only implicit` is fixed by adding the named module to the target in `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`.

- [ ] **Step 2: Warnings as errors**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
TUIST_WARNINGS_AS_ERRORS=true mise exec -- tuist generate --no-open
mise exec -- sh -c 'tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" --no-selective-testing -- -testLanguage en -testRegion DE -collect-test-diagnostics never'
```

Expected: builds and all `DocumentsFeatureTests` PASS. Repeat for `ApiInterface` and `ApiImplementation`. Afterwards regenerate without the variable: `mise exec -- tuist generate --no-open`.

- [ ] **Step 3: See it in the app**

Build and run on the simulator via XcodeBuildMCP (`session_show_defaults`, then `build_run_sim`). Sign in to `http://192.168.64.1:8000` as `admin`, open any document, and choose **View ▸ History**. Confirm the entries match the web's History tab for the same document (`http://192.168.64.1:8000/documents/<id>/history`), and take a screenshot.

- [ ] **Step 4: Commit any formatter changes**

```bash
git status --short
git add -A Modules Snapshots
git commit -m "chore: format the document history changes

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>"
```

Skip the commit if `git status` is clean.
