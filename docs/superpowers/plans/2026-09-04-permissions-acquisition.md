# Permissions acquisition implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read the current user's effective permissions from `/api/ui_settings/` — the one endpoint
that does not require a permission a restricted user may lack — cache them per server, refresh them
on foreground, and expose a single query over them. No control is gated yet.

**Architecture:** `ApiInterface.User` shrinks to the five fields `ui_settings` actually sends, so one
type decodes both user-bearing endpoints. `GetCurrentUserUseCase` and `GetForwardAuthIdentityUseCase`
then each collapse from two requests to one, the single-user endpoint loses its last caller and is
deleted, and a `PermissionsQuery` dependency answers `can(permission, server)` from a per-server
cache. Everything fails open — the server remains the security boundary.

**Tech Stack:** Swift 6, Swift Testing, `swift-dependencies` (`@DependencyClient`,
`withDependencies`), `swift-sharing` (`@Shared`, `FileStorageKey`),
`swift-composable-architecture` (`TestStore`), Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-04-permissions-acquisition-design.md`

## Global Constraints

- **Gating is presentation, not enforcement.** The server is the security boundary. Every ambiguous
  case resolves toward showing more, never less.
- **Fail open.** When permissions cannot be determined, `can` returns `true`.
- **`nil` and `[]` are different.** The cache is `[Permission]?`. `nil` = never successfully read →
  everything allowed. `[]` = read and genuinely empty → nothing allowed. Never collapse them.
- **A failed refresh never clears the cache.** It leaves the last known value in place.
- **Comments:** Never `///`, never `/** */`. Only `//`, and only where a future reader would
  otherwise wonder why the code is as it is. See `AGENTS.md`. Do not edit prose inside an existing
  `///` block; convert the whole block to `//` if one must be corrected.
- **Decoding is snake_case-aware.** `JSONDecoder.apiDecoder` sets
  `keyDecodingStrategy = .convertFromSnakeCase`, so `is_superuser` maps to `isSuperuser` with no
  `CodingKeys`. `User` declares none today and must not gain any.
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing`.
  The flag is required: a plain `tuist test` can exit 0 having run **zero** tests, which is
  indistinguishable from success. Schemes: `ApiInterface`, `ApiImplementation`, `AppFeature`.
- **Also run `mise run ci:lint`** — formatting, `swiftlint --strict`, implicit-dependency check.
- **`ApiImplementation` has ~31 pre-existing network-dependent failures** (`NSURLErrorDomain -1004`)
  when no local paperless is reachable. Separate them from your own results; never present them as
  your failures and never try to fix them. A dev instance may be running at
  `http://192.168.64.1:8000` and a CI one at `:9000`, in which case they pass.
- **New `.swift` files need no Tuist edit** — targets glob their module directory. This plan adds no
  new modules and needs no `Module+Dependencies.swift` change.

---

### Task 1: Shrink `User` to what the API actually gives us

`ui_settings.user` carries five fields. `ApiInterface.User` declares thirteen, eight of them
non-optional and none of them read by production code. This task removes the eight, which is what
lets one type serve both endpoints in Task 2.

**Files:**
- Modify: `Modules/ApiInterface/Users/User.swift`
- Modify: `Modules/ApiInterface/Users/SaveUserInput.swift`
- Test: Modify `Modules/ApiInterfaceTests/Users/UserTests.swift`
- Test: Modify `Modules/ApiImplementationTests/Users/UsersRepositoryTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `User` with exactly `groups`, `id`, `isStaff`, `isSuperuser`, `username`, and
  `User.testValue(groups:id:isStaff:isSuperuser:username:)`.

- [ ] **Step 1: Trim the existing decoding tests**

`Modules/ApiInterfaceTests/Users/UserTests.swift` has three tests — `decode_superuser`,
`decode_admin`, `decode_user` — each decoding a real `/api/users/` payload.

**Keep every JSON literal exactly as it is.** Those payloads still carry `date_joined`, `email` and
the rest, and Swift's decoder ignores keys a type does not declare. That is the point: these tests
become the proof that the shrink did not break decoding the wider endpoint.

Delete only the assertion lines naming removed fields — `email`, `firstName`, `lastName`,
`dateJoined`, `isMfaEnabled`, `isActive`, `userPermissions`, `inheritedPermissions`. Keep every
assertion on `id`, `username`, `groups`, `isStaff`, `isSuperuser`.

Then add one test pinning the new contract:

```swift
    // The point of the shrink: /api/users/ still sends eight fields this type no longer declares,
    // and decoding must ignore them rather than fail. If this breaks, one of the removed properties
    // has been added back.
    @Test
    func decode_ignoresFieldsTheModelNoLongerDeclares() throws {
        let json = """
        {
          "id": 40,
          "username": "permtest",
          "email": "permtest@example.com",
          "first_name": "Perm",
          "last_name": "Test",
          "date_joined": "2026-09-04T23:21:58.878556+02:00",
          "is_active": true,
          "is_staff": false,
          "is_superuser": false,
          "is_mfa_enabled": false,
          "groups": [],
          "user_permissions": ["view_document"],
          "inherited_permissions": ["view_tag"]
        }
        """

        let user = try JSONDecoder.apiDecoder.decode(User.self, from: Data(json.utf8))

        #expect(user.id == 40)
        #expect(user.username == "permtest")
        #expect(user.isSuperuser == false)
        #expect(user.isStaff == false)
        #expect(user.groups.isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`
Expected: the three existing tests PASS (you only removed assertions) and the new test PASSES too —
`User` still declares the wide shape, so nothing is red yet. **This step is a baseline, not a red
bar.** Record that the suite is green before you change the model.

- [ ] **Step 3: Shrink `User`**

`Modules/ApiInterface/Users/User.swift` becomes:

```swift
import Dependencies
import Foundation
import Tagged

// Five fields, because that is what /api/ui_settings/ sends and one type decoding both endpoints is
// worth more than eight properties nothing reads. /api/users/ still returns the rest; the decoder
// ignores them. Restoring one is additive if a screen ever needs it.
public struct User: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<User, Int>

    public let groups: [Group.Id]

    public let id: User.Id

    public let isStaff: Bool

    public let isSuperuser: Bool

    public let username: String

    public init(
        groups: [Group.Id],
        id: User.Id,
        isStaff: Bool,
        isSuperuser: Bool,
        username: String
    ) {
        self.groups = groups
        self.id = id
        self.isStaff = isStaff
        self.isSuperuser = isSuperuser
        self.username = username
    }
}
```

Keep the existing `Comparable`, `CustomStringConvertible` and `User.Id.get(_:)` extensions exactly as
they are — all three key off `username` or `id` and are unaffected. Replace `testValue` with:

```swift
public extension User {

    static func testValue(
        groups: [Group.Id] = [],
        id: User.Id = 1,
        isStaff: Bool = true,
        isSuperuser: Bool = true,
        username: String = "admin"
    ) -> Self {
        .init(
            groups: groups,
            id: id,
            isStaff: isStaff,
            isSuperuser: isSuperuser,
            username: username
        )
    }
}
```

- [ ] **Step 4: Delete `SaveUserInput.init(user:)`**

In `Modules/ApiInterface/Users/SaveUserInput.swift`, delete the whole
`public extension SaveUserInput { init(user: User?) { … } }` block. It seeds an edit form from a
fetched user, there is no edit form, and after Step 3 it cannot source four of its fields.

**Leave `SaveUserInput`'s own properties alone.** It is the input to user *creation*, which
`UITestSupport` genuinely uses, and it legitimately carries `email`, `firstName` and the rest.

- [ ] **Step 5: Fix the one caller**

`Modules/ApiImplementationTests/Users/UsersRepositoryTests.swift:84` does
`var updateUserInput = SaveUserInput(user: user)`. Construct it directly instead, preserving whatever
the test then mutates and asserts:

```swift
        var updateUserInput = SaveUserInput(
            email: "jane@doe.com",
            firstName: "Jane",
            groups: [],
            isActive: true,
            isStaff: false,
            isSuperuser: false,
            lastName: "Doe",
            password: nil,
            userPermissions: [],
            username: user.username
        )
```

Read the surrounding test before pasting this — it mutates `firstName` and `userPermissions` and
asserts on the response, so the starting values must keep those assertions meaningful. Adjust the
literals to match what the test expects, and say in your report what you changed.

- [ ] **Step 6: Fix everything else the compiler finds**

Run the build and fix each error. Expect breakage only in test fixtures and test-support code that
passed the removed parameters to `User(...)` or `User.testValue(...)`. Run:

```bash
grep -rn "dateJoined\|isMfaEnabled\|inheritedPermissions" --include=*.swift Modules
```

Every remaining hit must be in `SaveUserInput` (which keeps its own fields) or gone. `userPermissions`
and `isActive` also legitimately remain on `SaveUserInput`; anything referencing them **on a `User`**
must go.

- [ ] **Step 7: Run the tests to verify they pass**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: `ApiInterface` PASS, `ApiImplementation` shows only its known network failures, `ci:lint`
exit 0.

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface Modules/ApiInterfaceTests Modules/ApiImplementationTests
git commit -m "refactor: shrink User to the fields the API actually gives us"
```

---

### Task 2: `UISettings` carries the user and the permissions

**Files:**
- Modify: `Modules/ApiInterface/UISettings/UISettings.swift`
- Test: Create `Modules/ApiInterfaceTests/UISettings/UISettingsTests.swift`
- Delete: `Modules/ApiInterfaceTests/Fixtures/ui-settings.json`

**Interfaces:**
- Consumes: `User` from Task 1.
- Produces: `UISettings.user: ApiInterface.User`, `UISettings.permissions: [Permission]?`,
  `UISettings.testValue(settings:user:permissions:)`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/UISettings/UISettingsTests.swift`. The first payload is captured
verbatim from a live paperless — a restricted user on the CI instance — so this test checks the app
against the server rather than against itself:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct UISettingsTests {

    // Captured from /api/ui_settings/ on a live instance. Note what user does NOT contain: no
    // date_joined, email, first_name, last_name, is_active, is_mfa_enabled, user_permissions or
    // inherited_permissions. That absence is why User is five fields.
    @Test
    func decodesTheCapturedPayload() throws {
        let json = """
        {
          "user": {
            "id": 40,
            "username": "permtest",
            "is_staff": false,
            "is_superuser": false,
            "groups": []
          },
          "settings": { "version": "2.18.4" },
          "permissions": ["view_document", "view_uisettings"]
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.user.id == 40)
        #expect(settings.user.username == "permtest")
        #expect(settings.user.isSuperuser == false)
        #expect(settings.permissions == [.viewDocument, .viewUiSettings])
    }

    // A newer paperless sends codenames this enum does not know. Skipping them keeps a server
    // upgrade from making the app undecodable - and an unknown permission is one the app cannot gate
    // on anyway, which fails open, which is correct.
    @Test
    func skipsUnknownPermissionStrings() throws {
        let json = """
        {
          "user": { "id": 1, "username": "a", "is_staff": false, "is_superuser": false, "groups": [] },
          "settings": {},
          "permissions": ["view_document", "invent_teleporter"]
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.permissions == [.viewDocument])
    }

    // An older paperless may not send the key at all. That is "unknown", not "none" - and the
    // difference decides whether the app shows every control or hides every control.
    @Test
    func absentPermissionsKeyDecodesToNilRatherThanEmpty() throws {
        let json = """
        {
          "user": { "id": 1, "username": "a", "is_staff": false, "is_superuser": false, "groups": [] },
          "settings": {}
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.permissions == nil)
    }
}
```

`viewUiSettings` is the correct case name — verified in
`Modules/ApiInterface/Shared/Permission.swift:73`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL to compile — `UISettings` has no `permissions`, and `settings.user.username` does not
exist on the nested `UISettings.User`.

- [ ] **Step 3: Replace the nested user and add permissions**

In `Modules/ApiInterface/UISettings/UISettings.swift`:

Delete the nested `public struct User { … }` and the
`public extension UISettings.User { static func testValue(id:) }` block at the bottom of the file.

Then:

```swift
    public let settings: Settings

    public let user: User

    // Optional, and the optionality is load-bearing: nil means the server did not send the key - an
    // older paperless - while [] means it sent an empty list. contains() answers false for every
    // permission on an empty array, so collapsing the two would hide every control in the app for
    // anyone on an older server.
    @SkipUnknownValues
    public var permissions: [Permission]?

    public init(
        settings: Settings,
        user: User,
        permissions: [Permission]? = nil
    ) {
        self.settings = settings
        self.user = user
        self.permissions = permissions
    }
```

`User` now resolves to `ApiInterface.User`, which after Task 1 matches the payload exactly.

**`@SkipUnknownValues` currently wraps `[T]`, not `[T]?`.** Read
`Modules/ApiInterface/Shared/SkipUnknownValues.swift`. If it does not support an optional wrapped
value, do not contort the property wrapper — write a custom `init(from:)` for `UISettings` instead,
using the `MaybeDecodable` type the wrapper already uses:

```swift
        permissions = try container
            .decodeIfPresent([MaybeDecodable<Permission>].self, forKey: .permissions)?
            .compactMap(\.wrapped)
```

Use whichever compiles cleanly and say which in your report. The requirement is the behaviour the
three tests pin, not a particular spelling.

- [ ] **Step 4: Update `UISettings.testValue`**

```swift
    static func testValue(
        settings: UISettings.Settings = .testValue(),
        user: ApiInterface.User = .testValue(),
        permissions: [Permission]? = nil
    ) -> Self {
        .init(
            settings: settings,
            user: user,
            permissions: permissions
        )
    }
```

- [ ] **Step 5: Delete the now-redundant fixture file**

```bash
git rm Modules/ApiInterfaceTests/Fixtures/ui-settings.json
```

The captured payload now lives inside the test, matching how `UserTests` carries its payloads. A
second copy on disk that no test loads would drift.

- [ ] **Step 6: Run the tests to verify they pass**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: PASS, exit 0.

- [ ] **Step 7: Commit**

```bash
git add Modules/ApiInterface Modules/ApiInterfaceTests
git commit -m "feat: decode the user and effective permissions from ui_settings"
```

---

### Task 3: The cache and the query

**Files:**
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`
- Create: `Modules/ApiInterface/Permissions/PermissionsQuery.swift`
- Test: Create `Modules/ApiInterfaceTests/Permissions/PermissionsQueryTests.swift`

**Interfaces:**
- Consumes: `Permission`, `Server`, `User` (Task 1).
- Produces: `SharedReaderKey.permissions(_ server: Server)`,
  `PermissionsQuery.can: @Sendable (Permission, Server) -> Bool`, `DependencyValues.permissionsQuery`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/Permissions/PermissionsQueryTests.swift`:

```swift
@testable import ApiInterface

import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct PermissionsQueryTests {

    @Test
    func superuserCanDoAnythingWithoutHoldingThePermission() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: true), permissions: [], server: server)

        #expect(PermissionsQuery.liveValue.can(.deleteDocument, server))
    }

    @Test
    func nonSuperuserHoldingThePermissionCan() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: [.changeDocument], server: server)

        #expect(PermissionsQuery.liveValue.can(.changeDocument, server))
    }

    @Test
    func nonSuperuserLackingThePermissionCannot() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: [.viewDocument], server: server)

        #expect(!PermissionsQuery.liveValue.can(.changeDocument, server))
    }

    // Nothing has been read, so nothing is known. Gating is presentation, not enforcement: show the
    // control and let the server refuse it. Deleting this branch hides the whole app from anyone
    // whose paperless does not send the key.
    @Test
    func nilCacheAllowsEverything() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: nil, server: server)

        #expect(PermissionsQuery.liveValue.can(.deleteDocument, server))
    }

    // One character apart from the case above and the opposite answer: the server was read and it
    // granted nothing.
    @Test
    func emptyCacheAllowsNothing() {
        let server = Server.testValue()
        write(user: .testValue(isSuperuser: false), permissions: [], server: server)

        #expect(!PermissionsQuery.liveValue.can(.deleteDocument, server))
    }

    private func write(user: User, permissions: [Permission]?, server: Server) {
        @Shared(.currentUser(server))
        var cachedUser: User?

        @Shared(.permissions(server))
        var cachedPermissions: [Permission]?

        $cachedUser.withLock { $0 = user }
        $cachedPermissions.withLock { $0 = permissions }
    }
}
```

`@Shared` file storage is in-memory under a test context, so each test starts from the key's default
and none of this touches the filesystem or leaks between tests.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL to compile — neither `PermissionsQuery` nor `.permissions(server)` exists.

- [ ] **Step 3: Add the shared key**

Append to `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, beside `currentUser`:

```swift
public extension SharedReaderKey where Self == FileStorageKey<[Permission]?> {

    static func permissions(_ server: Server) -> Self {
        .fileStorage(
            .applicationGroupDirectory.appending(component: "\(server.id)-permissions.json"),
            decoder: .apiDecoder,
            encoder: .apiEncoder
        )
    }
}
```

Per server because permissions are per account, and on disk so gating is right at launch before the
network answers.

- [ ] **Step 4: Add the query**

Create `Modules/ApiInterface/Permissions/PermissionsQuery.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

// The one question the rest of the app asks about permissions. A client rather than a free function
// so a feature test can grant or deny without writing to a cache.
@DependencyClient
public struct PermissionsQuery: Sendable {

    // Defaults to true for the same reason the live value falls back to true: a test that forgets to
    // stub this sees the app it has always seen, not an empty one.
    public var can: @Sendable (_ permission: Permission, _ server: Server) -> Bool = { _, _ in true }
}

extension PermissionsQuery: DependencyKey {

    public static let liveValue = Self(
        can: { permission, server in
            @Shared(.permissions(server))
            var permissions: [Permission]?

            // Nothing read yet, so nothing to gate on. Gating is presentation, not enforcement - the
            // server still refuses what it should. This branch is why the cache is optional rather
            // than an empty array: contains() on an empty array denies everything, which is the
            // opposite answer to the same question.
            guard let permissions else {
                return true
            }

            @Shared(.currentUser(server))
            var user: User?

            // Superuser first, matching the web UI. Django hands a superuser every permission
            // anyway, so this is belt and braces - and it stays true if that ever stops.
            return user?.isSuperuser == true || permissions.contains(permission)
        }
    )
}

extension PermissionsQuery: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {

    var permissionsQuery: PermissionsQuery {
        get { self[PermissionsQuery.self] }
        set { self[PermissionsQuery.self] = newValue }
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: PASS, exit 0.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiInterface Modules/ApiInterfaceTests
git commit -m "feat: cache permissions per server and add the can query"
```

---

### Task 4: One request, and delete the endpoint that needed a permission

Two use cases fetch `ui_settings` and then immediately fetch `/api/users/<id>/` for data
`ui_settings` already returned. That second request is what requires `view_user`. Measured on the CI
instance with a user holding `view_uisettings` but not `view_user`: `ui_settings` → `200`,
`users/<id>` → `403`.

**Files:**
- Modify: `Modules/ApiImplementation/Users/GetCurrentUserUseCase.swift`
- Modify: `Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift`
- Modify: `Modules/ApiImplementation/Users/UsersRepository.swift`
- Test: Modify `Modules/ApiImplementationTests/Users/GetCurrentUserUseCaseTests.swift`
- Test: Modify `Modules/ApiImplementationTests/Users/UsersRepositoryTests.swift`

**Interfaces:**
- Consumes: `UISettings.user`, `UISettings.permissions`, `SharedReaderKey.permissions(_:)`.
- Produces: `getCurrentUser` writes both `.currentUser(server)` and `.permissions(server)`.
  `UsersRepository` no longer has `getUser`.

- [ ] **Step 1: Write the failing test**

Read `Modules/ApiImplementationTests/Users/GetCurrentUserUseCaseTests.swift` first. If an existing
test stubs `usersRepository.getUser` and asserts on its result, that test encodes the behaviour this
task removes — update it, do not leave it to fail.

Add:

```swift
    @Test
    func cachesTheUserAndPermissionsFromUISettings() async throws {
        let server = Server.testValue()

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .testValue(
                    user: .testValue(id: 40, isSuperuser: false, username: "permtest"),
                    permissions: [.viewDocument, .changeDocument]
                )
            }
        } operation: {
            let user = try await GetCurrentUserUseCase.liveValue.execute(server)

            #expect(user.username == "permtest")

            @Shared(.currentUser(server))
            var cachedUser: User?

            @Shared(.permissions(server))
            var permissions: [Permission]?

            #expect(cachedUser?.id == 40)
            #expect(permissions == [.viewDocument, .changeDocument])
        }
    }
```

Add `import SwiftSharing` if absent.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL — the use case still calls `getUser`, whose `testValue` returns a different user, and
nothing writes the permission cache. Ignore the known `-1004` failures elsewhere in the scheme.

- [ ] **Step 3: Rewrite `GetCurrentUserUseCase`**

```swift
private extension GetCurrentUserUseCase {

    static func execute(
        server: Server
    ) async throws -> User {
        @Shared(.currentUser(server))
        var cache: User?

        @Shared(.permissions(server))
        var permissions: [Permission]?

        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        // ui_settings carries the user and the flattened effective permission set. Fetching
        // /api/users/<id>/ for the same data additionally requires view_user, which a restricted
        // user does not have - so the second request cost a permission and bought nothing.
        let uiSettings = try await uiSettingsRepository.getUISettings(
            input: .init(),
            server: server
        )

        $cache.withLock { $0 = uiSettings.user }
        $permissions.withLock { $0 = uiSettings.permissions }

        return uiSettings.user
    }
}
```

Delete the `@Dependency(\.usersRepository)` declaration from this function.

- [ ] **Step 4: Apply the same fix to forward auth**

In `Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift`, the block currently
fetches `ui_settings` then `getUser` purely to read `user.username`. Replace both calls with:

```swift
                let settings = try await uiSettingsRepository.getUISettings(
                    input: .init(),
                    server: server
                )
                return settings.user.username
```

Remove the now-unused `usersRepository` dependency from that function if nothing else uses it.

This matters more than it looks: remote-user mode is how a reverse proxy signs someone in, and those
deployments are exactly where restricted accounts live.

- [ ] **Step 5: Delete `getUser` from the repository**

With both call sites fixed, the single-user fetch has no production caller. Dead code that requires a
permission is a trap for whoever reaches for it next, so remove it:

- the `getUser` property from the `UsersRepository` `@DependencyClient`
- its live implementation and the `getUser: getUser(input:server:)` wiring
- its `previewValue` and `testValue` entries
- `GetUserInput` / `GetUserOutput` if nothing else references them — grep before deleting

Keep `getUsers` (the list), `createUser`, `updateUser` and `deleteUser`. The list still populates
owner and permission pickers with *other* users, which `ui_settings` cannot describe, and #51 already
guards its failure.

Remove any `UsersRepositoryTests` test that exercises `getUser`, and say in your report which you
removed.

- [ ] **Step 6: Run the tests to verify they pass**

```
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: the new test PASSES and no previously-passing test regresses. If unsure which failures are
pre-existing, run the same scheme on `main` and compare the failing-suite lists.

- [ ] **Step 7: Commit**

```bash
git add Modules/ApiImplementation Modules/ApiImplementationTests
git commit -m "fix: stop requiring view_user to read your own permissions"
```

---

### Task 5: A permissions failure must not stop the app

**Files:**
- Modify: `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`
- Test: Modify `Modules/ApiImplementationTests/Cache/UpdateCacheUseCaseTests.swift`

**Interfaces:**
- Consumes: `getCurrentUser` from Task 4.
- Produces: nothing later tasks rely on.

- [ ] **Step 1: Write the failing test**

Add to `Modules/ApiImplementationTests/Cache/UpdateCacheUseCaseTests.swift`, following the shape of
the existing `executeSurvivesUsersAndGroupsBeingForbidden`:

```swift
    // A user who cannot read their own permissions must still be able to use the app. Before this,
    // the unguarded await meant a 403 here failed the whole cache update - and updateCache is what
    // adding a server runs, so the server could not be added at all.
    @Test
    func executeSurvivesTheCurrentUserBeingForbidden() async throws {
        let server = Server.testValue()
        let forbidden = ApiError(errors: ["You do not have permission to perform this action."])
        let getTagsCalled = LockIsolated(false)

        try await withDependencies {
            $0.getCorrespondents.execute = { _ in [.testValue()] }
            $0.getCurrentUser.execute = { _ in throw forbidden }
            $0.getDocumentTypes.execute = { _ in [.testValue()] }
            $0.getGroups.execute = { _ in [.testValue()] }
            $0.getSavedViews.execute = { _ in [.testValue()] }
            $0.getStoragePaths.execute = { _ in [.testValue()] }
            $0.getTags.execute = { _ in
                getTagsCalled.setValue(true)
                return [.testValue()]
            }
            $0.getUsers.execute = { _ in [.testValue()] }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(server)
        }

        #expect(getTagsCalled.value == true)
    }
```

If the compiler reports another unimplemented dependency, add it the same way and note it in your
report.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL — the thrown `ApiError` propagates out of `execute`.

- [ ] **Step 3: Guard the await**

In `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`, replace the unguarded
`_ = try await currentUser` with a `do`/`catch` placed beside the existing `groups` and `users`
blocks so the three read as one group:

```swift
        // Reading your own permissions can 403 on a server that has not granted view_uisettings.
        // Losing them costs gating, which is presentation - it must never cost the app.
        do {
            _ = try await currentUser
        } catch {
            log.warning("current user unavailable, permissions unknown: \(error.localizedDescription)", category: .api)
        }
```

The existing comment above the `groups`/`users` blocks explains those two and stays where it is.

- [ ] **Step 4: Run the tests to verify they pass**

```
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: the new test PASSES and the existing cache tests still pass.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementation Modules/ApiImplementationTests
git commit -m "fix: a permissions failure no longer blocks adding a server"
```

---

### Task 6: Refresh permissions on foreground

Permissions are otherwise read only at cold launch and on a server switch, so a permission revoked
while the app sits in the background stays invisible to it — possibly for days.

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift` (the `.didBecomeActive` case)
- Modify: `Modules/AppFeature/AppReducer+Effect.swift`
- Test: Modify `Modules/AppFeatureTests/AppReducerTests.swift`

**Interfaces:**
- Consumes: `getCurrentUser` (Task 4), `SharedReaderKey.permissions(_:)` (Task 3).
- Produces: `Effect<AppReducer.Action>.runRefreshPermissions(server:)`.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/AppFeatureTests/AppReducerTests.swift`:

```swift
    @Test
    func test_didBecomeActive_refreshesPermissions() async {
        let serversReceived = LockIsolated<[Server]>([])
        let server = Server.testValue()

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.getCurrentUser.execute = { server in
                    serversReceived.withValue { $0.append(server) }
                    return .testValue()
                }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.didBecomeActive)
        await store.finish()

        #expect(serversReceived.value == [server])
    }

    // A transient failure must leave the last known permissions in place. Clearing them would swing
    // the whole UI on a dropped connection - to ungated with nil, or fully gated with [].
    @Test
    func test_didBecomeActive_keepsCachedPermissionsWhenTheRefreshFails() async {
        let server = Server.testValue()

        @Shared(.permissions(server))
        var permissions: [Permission]?
        $permissions.withLock { $0 = [.viewDocument] }

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.getCurrentUser.execute = { _ in throw ApiError(errors: ["nope"]) }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.didBecomeActive)
        await store.finish()

        #expect(permissions == [.viewDocument])
    }
```

Add `import SwiftSharing` if absent.

`await store.finish()` is safe here: `.didBecomeActive` merges only finite effects, unlike
`.bootstrap`, which merges never-ending observers and would hang.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL — `serversReceived` is empty; nothing calls `getCurrentUser`.

- [ ] **Step 3: Add the effect**

Add to `Modules/AppFeature/AppReducer+Effect.swift`, beside `runRefreshStatistics`:

```swift
    // Permissions are otherwise read only at cold launch and on a server switch, so a permission
    // revoked while the app was backgrounded would stay invisible to it. The failure is swallowed
    // deliberately: the cache keeps its last value rather than being cleared, because clearing
    // swings the whole UI on a dropped connection.
    static func runRefreshPermissions(server: Server) -> Self {
        @Dependency(\.getCurrentUser.execute)
        var getCurrentUser

        @Dependency(\.log)
        var log

        return .run { _ in
            _ = try await getCurrentUser(server)
        } catch: { error, _ in
            log.warning("permissions refresh failed: \(error.localizedDescription)", category: .api)
        }
    }
```

- [ ] **Step 4: Merge it into `didBecomeActive`**

```swift
            case .didBecomeActive:
                guard let server = state.main?.server else {
                    return .none
                }
                return .runRefreshStatistics(server: server)
                    .merge(with: .runRefreshFavorites(server: server))
                    .merge(with: .runRefreshPermissions(server: server))
```

- [ ] **Step 5: Run the tests to verify they pass**

```
mise exec -- tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: PASS, exit 0. The existing `test_didBecomeActive_refreshesStatistics` and
`test_didBecomeActive_refreshesFavorites` must still pass — if either now fails on an unimplemented
`getCurrentUser`, stub it in those tests rather than weakening them.

- [ ] **Step 6: Run every affected scheme**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: `ApiInterface` and `AppFeature` clean; `ApiImplementation` shows only its known network
failures.

- [ ] **Step 7: Commit**

```bash
git add Modules/AppFeature Modules/AppFeatureTests
git commit -m "feat: refresh permissions when the app becomes active"
```
