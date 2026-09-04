# Knowing what the user is allowed to do

Read the current user's effective permissions from the one endpoint that does not itself require a
permission they may lack, and expose a single query over them. No button changes yet.

## Context

paperless-ngx has two independent permission layers, and the app currently gates on neither.

**Global permissions** are Django model permissions: `<action>_<type>` over four actions — `add`,
`view`, `change`, `delete` — and roughly twenty types. The web UI's check is one line:

```typescript
currentUserCan(action, type) {
  return this.currentUser?.is_superuser || this.permissions?.includes(this.getPermissionCode(action, type))
}
```

**Object-level permissions** are django-guardian: an optional `owner` per object plus `view` and
`change` lists of users and groups. Three of its rules are counter-intuitive and worth writing down
before anyone designs against them: an object with **no owner is accessible to everyone**, the owner
bypasses every other check (and superusers own everything implicitly), and granting `change`
auto-assigns `view` server-side. List responses carry a computed `user_can_change` boolean by
default; the full structure needs `full_perms=true`.

This design covers **only the global layer's data acquisition**. Object-level gating is a separate
project and is not designed here.

### What the app already has

The modelling is nearly complete and entirely unused. `Permission` is a 72-case `String` enum
covering the whole matrix. `Permissions` models the object-level view/change × users/groups shape.
`User` carries `userPermissions`, `inheritedPermissions`, `isSuperuser` and `isStaff`.

None of it gates anything. There is no `hasPermission` helper anywhere, and every control in the app
is shown to every user.

### The bug, reproduced

`GetCurrentUserUseCase` makes two requests: `/api/ui_settings/` to learn the current user's id, then
`/api/users/<id>/` to fetch that user. `UserViewSet` uses `PaperlessObjectPermissions`, which falls
back to Django model permissions — so the second request requires `view_user`.

Against the repository's own CI paperless instance, with a user granted `view_document` and
`view_uisettings` but **not** `view_user`:

| Request | Status |
|---|---|
| `GET /api/ui_settings/` | `200` |
| `GET /api/users/<their id>/` | `403` |

That is exactly the pair `GetCurrentUserUseCase` issues, in that order. In `UpdateCacheUseCase` the
result is awaited unguarded:

```swift
        _ = try await currentUser
```

So the error propagates, the cache update fails, and **the server cannot be added at all**. This is
the same gap that made servers unaddable in #51, which guarded `getGroups` and `getUsers` but not
this call.

A user with `view_document` alone gets `403` from `/api/ui_settings/` too, so that endpoint is not
universally available either — which is what the fail-open decision below exists to handle.

### What `ui_settings` actually returns

Captured from a live instance rather than read off the frontend's TypeScript types, which declare
`user: User` and so read as though the full user is returned:

```json
{
  "user": { "id": 40, "username": "permtest", "is_staff": false, "is_superuser": false, "groups": [] },
  "settings": { },
  "permissions": ["view_document", "view_uisettings"]
}
```

`user` is a **reduced** five-field object. `permissions` is the flattened effective set — direct plus
group-inherited — and is exactly what the web UI checks against. The app decodes only `user.id` and
discards both.

### The app's `User` is bigger than anything reads

`ui_settings.user` omits `date_joined`, `email`, `first_name`, `last_name`, `is_active`,
`is_mfa_enabled`, `user_permissions` and `inherited_permissions`, all of which are non-optional
stored properties on `ApiInterface.User`. Rather than model two user shapes, `User` was audited
against what actually reads it:

| Field | Production reads |
|---|---|
| `dateJoined` | none anywhere, including tests |
| `email`, `firstName`, `lastName`, `isMfaEnabled` | none — tests only |
| `userPermissions`, `inheritedPermissions` | none — tests only |
| `isActive` | none — every hit is `documentSelection.isActive`, an unrelated type |

The one place reading those fields off a `User` is `SaveUserInput.init(user:)`, called from a single
test. **There is no user-editing screen in this app**: `SaveUserInput`, `createUser`, `updateUser`
and `deleteUser` are reached only from `UITestSupport` and `ApiTestSupport`, which provision users on
a test server. Users are fetched to populate owner and permission pickers, which need `id` and
`username`.

### Which user endpoints survive

| Endpoint | After this change |
|---|---|
| `GET /api/ui_settings/` | The sole source for the current user and their permissions |
| `GET /api/users/` (list) | Still required — owner and permission pickers need *other* users, which `ui_settings` cannot describe. Already guarded in #51, so a restricted user gets an empty picker rather than a failure |
| `GET /api/users/<id>/` (single) | **No production callers left.** Its only two were the use cases fixed here |

## Decisions

**Gating is presentation, not enforcement.** The server is and remains the security boundary. This
feature exists so the UI does not offer actions that will fail. Every edge case below resolves
against that sentence, and it is the reason the next decision is defensible.

**When permissions cannot be determined, everything is shown.** Fail open. `/api/ui_settings/`
requires `view_uisettings`, and a user can lack even that — measured above. Fail-closed would present
an app with every control missing, which reads as broken software rather than as a permission
boundary; fail-open reproduces today's behaviour exactly, so it is a strict non-regression and
carries no security consequence given the sentence above.

**"Unknown" and "empty" are different states, and the type must say so.** The cached permission set is
`[Permission]?`. `nil` means never successfully read — fail open, show everything. `[]` means the
server was read and genuinely returned nothing. Collapsing the two is the trap this decision exists
to avoid: `permissions.contains(x)` is `false` for every `x` on an empty array, so an older paperless
that omits the key, or a first launch before the network answers, would hide every control while
looking like a deliberate permission boundary. `UISettings.permissions` is decoded as optional — key
absent yields `nil`, not `[]`.

**`User` shrinks to the five fields `ui_settings` sends.** `{groups, id, isStaff, isSuperuser,
username}`. One type then decodes both endpoints, `GetCurrentUserUseCase` becomes a single request,
and there is no reduced twin, no partially-populated cache, and no ordering subtlety about which
cache is written before which call can fail.

The alternative — keep the wide `User` and add a small nested one for `ui_settings` — was rejected
for buying two user types and a best-effort second fetch to preserve eight fields nothing reads.
`/api/users/` still returns them; the model simply stops decoding them, so restoring one later is
additive. This is deliberately removing modelled data on the grounds that nothing uses it, which is
the right call today and a re-add if a screen ever shows an email address.

**The single-user endpoint goes with it.** Once both call sites are fixed, `UsersRepository.getUser`
has no production caller. It is deleted rather than left: dead code that requires a permission is
worse than dead code, because the next person who reaches for it reintroduces the bug this design
exists to fix. The list endpoint stays — pickers need it.

**A refresh that fails leaves the last known set in place.** It does not clear the cache. Clearing
would swing the whole UI on a transient network error — to ungated with `nil`, or to fully gated with
`[]` — and a permission set that is one foreground stale is far better than a UI that flickers
between two shapes.

**Unknown permission strings are skipped, never fatal.** A newer paperless will send codenames this
enum does not know. `@SkipUnknownValues` already exists for exactly this. A permission the app cannot
name is one it cannot gate on, which fails open, which is correct.

**Hiding, not disabling, is the convention for later projects.** No control changes here, but the
decision is recorded so the projects that do change controls inherit it rather than relitigate it.

## Changes

### `Modules/ApiInterface/Users/User.swift`

The struct becomes:

```swift
public struct User: Codable, Equatable, Hashable, Identifiable, Sendable {
    public typealias Id = Tagged<User, Int>

    public let groups: [Group.Id]
    public let id: User.Id
    public let isStaff: Bool
    public let isSuperuser: Bool
    public let username: String
}
```

`Comparable` and `CustomStringConvertible` both key off `username` and are unchanged, as is the
`User.Id.get(_:)` cache lookup. `testValue` loses the removed parameters.

### `Modules/ApiInterface/Users/SaveUserInput.swift`

`init(user:)` is deleted. It exists to seed an edit form from a fetched user, there is no edit form,
and after the shrink it could not source four of its fields. Its single caller is a repository test
that constructs the input directly instead.

`SaveUserInput` itself keeps all its fields — it is the *input* to user creation, which
`UITestSupport` genuinely uses.

### `Modules/ApiImplementation/Users/UsersRepository.swift`

`getUser` — the single-user fetch — is removed from the client, its live implementation, and its
test values. `getUsers`, `createUser`, `updateUser` and `deleteUser` stay.

### `Modules/ApiInterface/UISettings/UISettings.swift`

The nested `UISettings.User` struct and its `testValue` are deleted; `user` becomes
`ApiInterface.User`, which now matches the payload. `UISettings` gains:

```swift
    @SkipUnknownValues
    public var permissions: [Permission]?
```

The nested `Settings` type and its `raw` dictionary are untouched.

### `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`

A new per-server key alongside `currentUser`, file-backed in the app group container and defaulting
to `nil`. Per-server because permissions are per account, and cached so gating is correct at launch
before the network answers, and offline.

### `Modules/ApiInterface/Permissions/PermissionsQuery.swift` (new)

A `@DependencyClient` exposing the single question the rest of the app will ask:

```swift
    public var can: @Sendable (_ permission: Permission, _ server: Server) -> Bool = { _, _ in true }
```

Its live implementation reads the two caches:

```swift
// Nothing read yet, so nothing to gate on. Gating is presentation, not enforcement - the server
// still refuses what it should. This branch is why the cache is optional rather than an empty
// array: contains() on an empty array denies everything, which is the opposite answer.
guard let permissions else {
    return true
}

// Superuser first, matching the web UI. Django hands a superuser every permission anyway, so this
// is belt and braces - and it stays true if that ever stops.
return user?.isSuperuser == true || permissions.contains(permission)
```

The client's default is `true` for the same reason: a test that forgets to stub it sees an ungated
app rather than a mysteriously empty one.

### `Modules/ApiImplementation/Users/GetCurrentUserUseCase.swift`

One request. It fetches `ui_settings`, caches `uiSettings.user` and `uiSettings.permissions`, and
returns the user.

### `Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift`

The same two-call pair appears here, purely to read a username, and gets the same fix: one
`ui_settings` request, then `settings.user.username`. This matters more than it looks — remote-user
mode is how a reverse proxy signs someone in, and those deployments are where restricted accounts
live.

### `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`

`currentUser` moves into a `do`/`catch` beside the existing `groups` and `users` blocks, logging at
warning level. After the fix above this path should no longer fail for a restricted user, but a
failure to learn permissions must never stop someone using the app — the same principle, one layer
down.

### `Modules/AppFeature/AppReducer.swift` and `AppReducer+Effect.swift`

Permissions are otherwise read only at cold launch and on a server switch, so an admin who revokes
one while the app sits in the background stays invisible to it. `didBecomeActive` already refreshes
statistics and favourites for the selected server; it gains a third effect on the same guard:

```swift
            case .didBecomeActive:
                guard let server = state.main?.server else {
                    return .none
                }
                return .runRefreshStatistics(server: server)
                    .merge(with: .runRefreshFavorites(server: server))
                    .merge(with: .runRefreshPermissions(server: server))
```

`runRefreshPermissions` calls `getCurrentUser` and swallows any error after logging it. It **never
clears the cache on failure**, and **blocks nothing** — a permission revoked server-side takes effect
on the next foreground, not mid-gesture. This is the only path that ever *narrows* what the user can
do while the app is installed, so it is the case worth being deliberate about.

## Testing

**`UISettings` decoding** against a fixture captured from the live instance: the real payload
decodes, including the five-field user; an unrecognised permission string is skipped rather than
throwing; an absent `permissions` key yields `nil` rather than `[]`.

**`PermissionsQuery.can`** for five cases: a superuser without the permission → `true`; a
non-superuser holding it → `true`; a non-superuser lacking it → `false`; a `nil` cache → `true`; an
**empty but non-nil** cache → `false`. The last two are one character apart in the type and opposite
in meaning; a reader who has not seen this document will find the `nil` branch redundant and delete
it, at which point every control disappears for anyone whose paperless omits the key. Both tests
exist so that deletion fails.

**`GetCurrentUserUseCase`** asserts it issues **one** request. After `getUser` is deleted this is
enforced by the compiler as well, but the test states the intent for anyone who adds a second call
later.

**`UpdateCacheUseCase`** asserts a throwing `getCurrentUser` no longer fails the update, mirroring the
existing tests for forbidden groups and users.

**`AppReducer.didBecomeActive`** asserts it refreshes permissions for the selected server, does
nothing when no server is selected, and — the one that protects the rule above — that a throwing
refresh leaves the cached set unchanged rather than clearing it.

**Existing `UserTests`** lose the assertions for removed fields. What remains must still cover
decoding a real `/api/users/` list payload, which carries the extra fields the model now ignores —
that is the test proving the shrink did not break the endpoint that still uses this type.

## Out of scope

- **Gating any control.** No button, section or tab changes. This project ends with the question
  answerable; the answering is Projects 2 and 3.
- **Object-level permissions** — `user_can_change`, `owner`, `full_perms`. Documented in Context so
  the next design starts from research rather than repeating it.
- **Making `/api/ui_settings/` optional.** It is already required for the app to function; a user
  lacking `view_uisettings` is no worse off than today.
- **A user-editing screen.** None exists, and this does not add one.

## Risks

**Removing fields is a bet that nothing needs them.** The audit covers this repository at this
commit. If a future screen shows an email address or MFA status, the field comes back — additive,
since `/api/users/` still sends it. The bet is worth taking because the alternative cost is two user
types on every screen that touches one.

**Fail-open means a restricted user still sees actions that will fail**, exactly as today, until
Projects 2 and 3 land. That is the accepted cost of not shipping an app that looks broken.

**`ui_settings` could gain or lose fields on a paperless upgrade.** The decoding test uses a captured
payload, so an upgrade that changes the shape fails a test rather than a launch. The five fields kept
are the ones the web UI itself depends on, which makes them the least likely to move.
