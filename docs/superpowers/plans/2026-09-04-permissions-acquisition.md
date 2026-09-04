# Permissions acquisition implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Read the current user's effective permissions from `/api/ui_settings/` — the one endpoint
that does not require a permission a restricted user may lack — cache them per server, refresh them
on foreground, and expose a single query over them. No control is gated yet.

**Architecture:** `/api/ui_settings/` already returns the full user object and the flattened
effective permission list, so the change is mostly a deletion: `UISettings` decodes both, the second
request to `/api/users/<id>/` goes away in the two places that make it, and a `PermissionsQuery`
dependency answers `can(permission, server)` from a per-server cache. Everything fails open — the
server remains the security boundary.

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
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing`.
  The `--no-selective-testing` flag is required: a plain `tuist test` can exit 0 having run **zero**
  tests, which is indistinguishable from success. Schemes: `ApiInterface`, `ApiImplementation`,
  `AppFeature`.
- **Also run `mise run ci:lint`** — formatting, `swiftlint --strict`, implicit-dependency check.
- **`ApiImplementation`'s scheme has ~31 pre-existing network-dependent test failures**
  (`NSURLErrorDomain -1004`) without a local paperless instance. They predate this work. Separate
  them from your own results; never present them as your failures and never try to fix them.
- **New `.swift` files need no Tuist edit** — targets glob their module directory. This plan adds no
  new modules and needs no `Module+Dependencies.swift` change.

---

### Task 1: Capture a real `ui_settings` payload and test the bug

Evidence, not code. Two things this plan rests on are currently assumptions, and both are cheap to
settle before anyone writes a model against them.

**Files:** none modified. One fixture written:
- Create: `Modules/ApiImplementationTests/Fixtures/ui-settings.json` (if a real payload is obtained)

**Interfaces:**
- Consumes: nothing.
- Produces: a captured JSON payload used as the decoding fixture in Task 2, and a verdict on the bug.

- [ ] **Step 1: Bring up a paperless instance**

The repository has a docker setup under `docker/`. Read `docker/` and any compose file there, plus
`mise/tasks/docker/` if present, and start it the way the repository intends.

**A previous session found this blocked**: colima could not mount `docker/caddy/Caddyfile` ("not a
directory"). If you hit that or anything like it, spend a reasonable effort, then **stop and report
precisely what failed**. Do not spend the task fighting infrastructure — Steps 4 and 5 tell you what
to do instead.

- [ ] **Step 2: Capture the payload**

With paperless running and a superuser token, capture the raw response:

```bash
curl -s -H "Authorization: Token <token>" http://localhost:8000/api/ui_settings/ | python3 -m json.tool
```

Save it to `Modules/ApiImplementationTests/Fixtures/ui-settings.json`. Create the `Fixtures`
directory if it does not exist.

**What to look at, and report explicitly:**
- Does the response contain a `permissions` key? Is it an array of strings?
- Does `user` contain **every** field Swift's `User` requires? Read
  `Modules/ApiInterface/Users/User.swift` and check each non-optional stored property against the
  JSON: `date_joined`, `email`, `first_name`, `groups`, `id`, `inherited_permissions`, `is_active`,
  `is_mfa_enabled`, `is_staff`, `is_superuser`, `last_name`, `user_permissions`, `username`.

That second question is the one that matters. Swift's `User` was written for `/api/users/<id>/` and
has non-optional properties. If `ui_settings` omits even one of them, Task 2's decoding fails and
the model needs those fields made optional — a change this plan does not currently specify. **Report
any missing field by name.**

- [ ] **Step 3: Test the bug**

In paperless's admin, create a user who has `view_uisettings` but **not** `view_user`. Then, with a
token for that user:

```bash
curl -s -o /dev/null -w "ui_settings: %{http_code}\n" -H "Authorization: Token <token>" http://localhost:8000/api/ui_settings/
curl -s -o /dev/null -w "users/<id>: %{http_code}\n" -H "Authorization: Token <token>" http://localhost:8000/api/users/<their-id>/
```

Expected if the inference is right: `200` then `403`. Report both codes whatever they are.

- [ ] **Step 4: If any of the above is blocked, say so plainly**

A truthful "could not run paperless, here is exactly what failed" is a **complete and successful
outcome** for this task. Do not fabricate a fixture, do not guess at the payload, and do not skip the
step silently.

If no real payload could be captured, write the fixture by hand from
`Modules/ApiInterface/Users/User.swift`'s coding keys, and **mark it clearly at the top of your
report as hand-written and unverified** so the reviewer knows the decoding test proves the model
agrees with itself rather than with paperless.

- [ ] **Step 5: Report**

Write the payload findings, the two status codes (or why you could not get them), and any missing
`User` field. No commit unless a real fixture was captured, in which case:

```bash
git add Modules/ApiImplementationTests/Fixtures/ui-settings.json
git commit -m "test: capture a real ui_settings payload as a decoding fixture"
```

---

### Task 2: `UISettings` carries the user and the permissions

**Files:**
- Modify: `Modules/ApiInterface/UISettings/UISettings.swift`
- Test: Create `Modules/ApiInterfaceTests/UISettings/UISettingsTests.swift`

**Interfaces:**
- Consumes: the fixture from Task 1 (or a hand-written one).
- Produces:
  - `UISettings.user: ApiInterface.User` (replacing the nested `UISettings.User` struct)
  - `UISettings.permissions: [Permission]?`
  - `UISettings.testValue(settings:user:permissions:)`

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/UISettings/UISettingsTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct UISettingsTests {

    @Test
    func decodesTheUserAndPermissions() throws {
        let json = """
        {
          "user": {
            "id": 3,
            "username": "reader",
            "email": "reader@example.com",
            "first_name": "Read",
            "last_name": "Only",
            "date_joined": "2026-01-02T03:04:05.000000Z",
            "is_active": true,
            "is_staff": false,
            "is_superuser": false,
            "is_mfa_enabled": false,
            "groups": [2],
            "user_permissions": ["view_document"],
            "inherited_permissions": ["view_tag"]
          },
          "settings": { "version": "2.18.4" },
          "permissions": ["view_document", "view_tag"]
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.user.id == 3)
        #expect(settings.user.username == "reader")
        #expect(settings.user.isSuperuser == false)
        #expect(settings.permissions == [.viewDocument, .viewTag])
    }

    // A newer paperless sends codenames this enum does not know. Skipping them is what keeps a
    // server upgrade from making the app undecodable - and an unknown permission is one the app
    // cannot gate on anyway, which fails open, which is correct.
    @Test
    func skipsUnknownPermissionStrings() throws {
        let json = """
        {
          "user": {
            "id": 1, "username": "a", "email": "", "first_name": "", "last_name": "",
            "date_joined": "2026-01-02T03:04:05.000000Z",
            "is_active": true, "is_staff": false, "is_superuser": false, "is_mfa_enabled": false,
            "groups": [], "user_permissions": [], "inherited_permissions": []
          },
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
          "user": {
            "id": 1, "username": "a", "email": "", "first_name": "", "last_name": "",
            "date_joined": "2026-01-02T03:04:05.000000Z",
            "is_active": true, "is_staff": false, "is_superuser": false, "is_mfa_enabled": false,
            "groups": [], "user_permissions": [], "inherited_permissions": []
          },
          "settings": {}
        }
        """

        let settings = try JSONDecoder.apiDecoder.decode(UISettings.self, from: Data(json.utf8))

        #expect(settings.permissions == nil)
    }
}
```

If Task 1 captured a real payload, add a fourth test decoding that file and asserting
`settings.user.username` and a non-nil `permissions`. If Task 1 reported a missing `User` field,
**stop and report** — the model needs a change this plan does not specify.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL to compile — `UISettings` has no `permissions`, and `settings.user.username` does not
exist on the nested `UISettings.User`.

- [ ] **Step 3: Replace the nested user and add permissions**

In `Modules/ApiInterface/UISettings/UISettings.swift`:

Delete the nested `public struct User` entirely, and delete the
`public extension UISettings.User { static func testValue(id:) }` block at the bottom of the file.

Change the stored properties and initialiser:

```swift
    public let settings: Settings

    public let user: User

    // Optional, and the optionality is load-bearing: nil means the server did not send the key -
    // an older paperless - while [] means it sent an empty list. contains() answers false for every
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

`User` here now resolves to `ApiInterface.User`, since the nested type is gone.

**`@SkipUnknownValues` currently wraps `[T]`, not `[T]?`.** Check
`Modules/ApiInterface/.../SkipUnknownValues.swift`. If it does not support an optional wrapped value,
do **not** contort the property wrapper — decode `permissions` in a custom `init(from:)` instead:

```swift
        permissions = try container
            .decodeIfPresent([MaybeDecodable<Permission>].self, forKey: .permissions)?
            .compactMap(\.wrapped)
```

Use whichever of the two compiles cleanly, and say which in your report. The requirement is the
behaviour the three tests pin, not a particular spelling.

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

- [ ] **Step 5: Fix every call site the compiler finds**

Run: `grep -rn "UISettings.User\|uiSettings.user" --include=*.swift Modules`

`GetCurrentUserUseCase` and `GetForwardAuthIdentityUseCase` both read `uiSettings.user.id`, which
still compiles — `ApiInterface.User` has `id` too. Anything referencing the nested type by name must
change. Fix what the compiler reports and nothing more; Task 4 changes those two use cases properly.

- [ ] **Step 6: Run the tests to verify they pass**

```
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: `ApiInterface` PASS, `ci:lint` exit 0.

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
- Consumes: `Permission` (existing), `Server` (existing).
- Produces:
  - `SharedReaderKey.permissions(_ server: Server)` for `FileStorageKey<[Permission]?>`
  - `PermissionsQuery.can: @Sendable (Permission, Server) -> Bool`
  - `DependencyValues.permissionsQuery`

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
and these do not touch the filesystem or leak between tests.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL to compile — neither `PermissionsQuery` nor `.permissions(server)` exists.

- [ ] **Step 3: Add the shared key**

Append to `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, beside the existing
`currentUser` key:

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

### Task 4: Stop fetching the user twice

Two use cases fetch `ui_settings` and then immediately fetch `/api/users/<id>/` for data
`ui_settings` already returned. That second request is what requires `view_user` — the permission a
restricted user does not have.

**Files:**
- Modify: `Modules/ApiImplementation/Users/GetCurrentUserUseCase.swift`
- Modify: `Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift`
- Test: Modify `Modules/ApiImplementationTests/Users/GetCurrentUserUseCaseTests.swift`

**Interfaces:**
- Consumes: `UISettings.user`, `UISettings.permissions`, `SharedReaderKey.permissions(_:)`.
- Produces: `getCurrentUser` writes both `.currentUser(server)` and `.permissions(server)`.

- [ ] **Step 1: Write the failing test**

The assertion is the **absence** of a call. `view_user` is invisible in behaviour until the code
meets a restricted account, so asserting the returned user is right would not catch a reintroduced
second request.

Add both tests to the existing `Modules/ApiImplementationTests/Users/GetCurrentUserUseCaseTests.swift`.
Read what is already there first — if an existing test stubs `usersRepository.getUser` and asserts on
its result, that test encodes the behaviour this task removes and must be updated, not left to fail:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct GetCurrentUserUseCaseTests {

    // /api/users/<id>/ requires view_user, which is exactly the permission a restricted user lacks.
    // ui_settings already returns the whole user, so calling getUser at all is the defect.
    @Test
    func doesNotFetchTheUserSeparately() async throws {
        let getUserCalled = LockIsolated(false)

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .testValue(user: .testValue(id: 7), permissions: [.viewDocument])
            }
            $0.usersRepository.getUser = { _, _ in
                getUserCalled.setValue(true)
                return .testValue()
            }
        } operation: {
            _ = try await GetCurrentUserUseCase.liveValue.execute(Server.testValue())
        }

        #expect(getUserCalled.value == false)
    }

    @Test
    func cachesThePermissionsFromUISettings() async throws {
        let server = Server.testValue()

        try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .testValue(user: .testValue(), permissions: [.viewDocument, .changeDocument])
            }
        } operation: {
            _ = try await GetCurrentUserUseCase.liveValue.execute(server)

            @Shared(.permissions(server))
            var permissions: [Permission]?

            #expect(permissions == [.viewDocument, .changeDocument])
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`
Expected: `doesNotFetchTheUserSeparately` FAILS (`getUserCalled` is `true`), and
`cachesThePermissionsFromUISettings` fails or does not compile. Ignore the ~31 pre-existing
`-1004` network failures elsewhere in this scheme.

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

        // ui_settings carries the whole user and the flattened effective permission set. Fetching
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

The `@Dependency(\.usersRepository)` declaration goes with the call. Remove the import only if
nothing else in the file needs it.

- [ ] **Step 4: Apply the same fix to forward auth**

`Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift` fetches `ui_settings`
then `getUser` purely to read `user.username`. Replace the two calls with one:

```swift
                let settings = try await uiSettingsRepository.getUISettings(
                    input: .init(),
                    server: server
                )
                return settings.user.username
```

Remove the now-unused `usersRepository` dependency from that function if nothing else uses it.

This is the same defect in a second place, and it matters more than it looks: remote-user mode is how
a reverse proxy signs someone in, and those deployments are exactly where a restricted account is
likely.

- [ ] **Step 5: Run the tests to verify they pass**

```
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: the two new tests PASS and no previously-passing test in the scheme regresses. Compare the
failing-suite list against a run on `main` if you are unsure which failures are pre-existing.

- [ ] **Step 6: Commit**

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

Add to `Modules/ApiImplementationTests/Cache/UpdateCacheUseCaseTests.swift`. Follow the existing
`executeSurvivesUsersAndGroupsBeingForbidden` test's shape for stubbing the other use cases:

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

If the compiler reports another unimplemented dependency, add it to the block the same way and note
it in your report.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`
Expected: FAIL — the thrown `ApiError` propagates out of `execute`.

- [ ] **Step 3: Guard the await**

In `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`, replace the unguarded
`_ = try await currentUser` with a `do`/`catch` beside the existing `groups` and `users` blocks:

```swift
        // Reading your own permissions can 403 on a server that has not granted view_uisettings.
        // Losing them costs gating, which is presentation - it must never cost the app.
        do {
            _ = try await currentUser
        } catch {
            log.warning("current user unavailable, permissions unknown: \(error.localizedDescription)", category: .api)
        }
```

Place it with the other two `do`/`catch` blocks so the three read as one group. The existing comment
above them explains the `groups`/`users` case and stays where it is.

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
- Modify: `Modules/AppFeature/AppReducer+Effect.swift` (add `runRefreshPermissions`)
- Test: Modify `Modules/AppFeatureTests/AppReducerTests.swift`

**Interfaces:**
- Consumes: `getCurrentUser` from Task 4, `SharedReaderKey.permissions(_:)` from Task 3.
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

Add `import SwiftSharing` to the test file's imports if it is not already there.

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

In `Modules/AppFeature/AppReducer.swift`:

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
Expected: `ApiInterface` and `AppFeature` clean; `ApiImplementation` shows only its ~31 pre-existing
`-1004` failures.

- [ ] **Step 7: Commit**

```bash
git add Modules/AppFeature Modules/AppFeatureTests
git commit -m "feat: refresh permissions when the app becomes active"
```
