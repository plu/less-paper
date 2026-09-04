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
`User` carries `userPermissions`, `inheritedPermissions`, `isSuperuser` and `isStaff`, both
permission arrays already wrapped in `@SkipUnknownValues`.

None of it gates anything. `userPermissions` appears in exactly three places: the model itself,
`SaveUserInput` (the admin screen for editing *other* users), and a test fixture that grants
`Permission.allCases`. There is no `hasPermission` helper anywhere. Every control in the app is shown
to every user.

### The acquisition problem

`GetCurrentUserUseCase` makes two requests: `/api/ui_settings/` to learn the current user's id, then
`/api/users/<id>/` to fetch that user.

`UserViewSet` uses `PaperlessObjectPermissions`, which falls back to Django model permissions for a
`User` object — so the second request requires `view_user`. That is precisely the permission a
restricted user does not have, and it is the same gap that made servers unaddable in #51, which
guarded `getGroups` and `getUsers` but not this call.

In `UpdateCacheUseCase` the result is awaited unguarded:

```swift
        _ = try await currentUser
```

So for a user without `view_user`, the cache update most likely throws and adding a server fails
outright. This has not been reproduced against a live restricted account — it is inference from the
permission classes and the call site, and verifying it is the first task of the plan rather than an
assumption the design rests on. The fix is correct either way.

The second request is also unnecessary. `/api/ui_settings/` already returns everything needed:

```typescript
export interface UiSettings {
  user: User
  settings: Object
  permissions: string[]
}
```

`user` is the full user object, matching the app's `User` model field for field, and `permissions`
is the flattened effective set — direct plus group-inherited — which is exactly what the web UI
checks against. The app decodes only `user.id` and discards both.

## Decisions

**Gating is presentation, not enforcement.** The server is and remains the security boundary. This
feature exists so the UI does not offer actions that will fail. Every edge case below resolves
against that sentence, and it is the reason the next decision is defensible.

**When permissions cannot be determined, everything is shown.** Fail open. `/api/ui_settings/`
requires `view_uisettings`, so a user can lack even this. Fail-closed would present an app with every
control missing, which reads as broken software rather than as a permission boundary; fail-open
reproduces today's behaviour exactly, so it is a strict non-regression and carries no security
consequence given the sentence above.

**"Unknown" and "empty" are different states, and the type must say so.** The cached permission set is
`[Permission]?`, not `[Permission]`. `nil` means never successfully read — fail open, show
everything. `[]` means the server was read and genuinely returned nothing. Collapsing the two into an
empty array is the trap this decision exists to avoid: `permissions.contains(x)` is `false` for every
`x` on an empty array, so an older paperless that omits the key, or a first launch before the network
answers, would hide every control in the app while looking like a deliberate permission boundary.
`UISettings.permissions` is therefore decoded as optional — key absent yields `nil`, not `[]`.

**A refresh that fails leaves the last known set in place.** It does not clear the cache. Clearing
would swing the whole UI on a transient network error — to ungated with `nil`, or to fully gated
with `[]` — and a permission set that is one foreground stale is far better than a UI that flickers
between two shapes.

**Take the user from `ui_settings` and delete the `/api/users/<id>/` call.** This is a deletion
rather than an addition: it removes a request, removes the `view_user` dependency, and yields the
effective permission list the second request never carried. The only consumer of the cached user —
`PermissionsFormReducer`, which defaults the owner field — receives the same object either way.

**Unknown permission strings are skipped, never fatal.** A newer paperless will send codenames this
enum does not know. `@SkipUnknownValues` already exists for exactly this and is already applied to
`User`'s two permission arrays; the new field uses it too. A permission the app cannot name is one it
cannot gate on, which fails open, which is correct.

**The effective set is used, not `userPermissions` merged with `inheritedPermissions`.** The server
already flattens them; recomputing the union in the app is a second implementation of a rule the
server owns, and it would drift the first time paperless changes how inheritance works.

**Hiding, not disabling, is the convention for later projects.** No control changes in this project,
but the decision is recorded here so the projects that do inherit it rather than relitigate it: a
control the user cannot use is not rendered.

## Changes

### `Modules/ApiInterface/UISettings/UISettings.swift`

`UISettings.User` — currently a nested struct holding only `id` — is replaced by
`ApiInterface.User`. `UISettings` gains:

```swift
    @SkipUnknownValues
    public var permissions: [Permission]
```

The nested `Settings` type and its `raw` dictionary are untouched.

### `Modules/ApiImplementation/Users/GetCurrentUserUseCase.swift`

The `usersRepository.getUser` call goes. The use case fetches `ui_settings`, caches
`uiSettings.user`, and returns it. It also caches the permission set (below).

`UsersRepository.getUser` itself stays — the admin user-editing screen still uses it, and that screen
already requires `view_user` to have listed users at all.

### `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`

A new per-server key alongside `currentUser`:

```swift
    static func permissions(_ server: Server) -> Self { ... }
```

backed by `.fileStorage(.applicationGroupDirectory.appending(component: "\(server.id)-permissions.json"))`,
defaulting to an empty array. Per-server because permissions are per-account, and cached so gating is
correct at launch before the network answers, and offline.

### `Modules/ApiInterface/Permissions/PermissionsQuery.swift` (new)

The single question the rest of the app will ask, as a `@DependencyClient` so it is overridable in
tests:

```swift
    public var can: @Sendable (_ permission: Permission, _ server: Server) -> Bool = { _, _ in true }
```

Its live implementation reads the cached user and permission set:

```swift
// Nothing read yet, so nothing to gate on. Gating is presentation, not enforcement - a user whose
// permissions could not be read sees the app as it has always been, and the server still refuses
// what it should. This branch is why the cache is optional rather than an empty array: contains()
// on an empty array denies everything, which is the opposite answer to the same question.
guard let permissions else {
    return true
}

// Superuser first, matching the web UI: Django hands a superuser every permission anyway, but the
// check is cheap and it keeps the rule true even if the server ever stops flattening them in.
return user?.isSuperuser == true || permissions.contains(permission)
```

The default value is `true` for the same reason: a test that forgets to stub this sees an ungated
app rather than a mysteriously empty one.

### `Modules/AppFeature/AppReducer.swift` and `AppReducer+Effect.swift`

Permissions are fetched today only when the cache updates — on cold launch and when the selected
server changes. An admin who revokes a permission while the app sits in the background is therefore
invisible to it, possibly for days, and the app goes on offering actions the server will now refuse.

`didBecomeActive` already refreshes statistics and favourites for the selected server; it gains a
third effect on the same guard:

```swift
            case .didBecomeActive:
                guard let server = state.main?.server else {
                    return .none
                }
                return .runRefreshStatistics(server: server)
                    .merge(with: .runRefreshFavorites(server: server))
                    .merge(with: .runRefreshPermissions(server: server))
```

`runRefreshPermissions` calls `getCurrentUser`, which writes both caches, and swallows any error
after logging it at warning level. Two properties matter and are easy to get wrong:

- **It never clears the cache on failure.** A foregrounding with no network keeps yesterday's
  permissions rather than reverting to `nil` and ungating the whole app.
- **It does not block anything.** No screen waits on it; the UI re-reads the cache when it changes.
  A permission revoked server-side takes effect on the next foreground, not mid-gesture.

This is also the only path that ever *narrows* what the user can do while the app is installed.
Everything else about permissions widens or stays put, so it is the case worth being deliberate
about.

### `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`

`currentUser` moves into a `do`/`catch` beside the existing `groups` and `users` blocks, logging at
warning level. A failure to learn who the user is must never stop them using the app — the same
principle, applied to the call that fetches it.

## Testing

**`UISettings` decoding** against fixtures: the full shape decodes; an unrecognised permission string
is skipped rather than throwing; an absent `permissions` key yields an empty array rather than a
decode failure, because an older paperless may not send it.

**`PermissionsQuery.can`** for five cases: a superuser without the permission returns `true`; a
non-superuser holding it returns `true`; a non-superuser lacking it returns `false`; a `nil` cache
returns `true`; and an **empty but non-nil** cache returns `false`.

The last two are the point. They are one character apart in the type and opposite in meaning, and a
reader who has not seen this document will find the `nil` branch redundant and delete it — at which
point every control in the app disappears for anyone whose paperless omits the key. Both tests exist
so that deletion fails.

**`GetCurrentUserUseCase`** asserts it issues **one** request. Not that it returns the right user —
that it does not call `getUser`. The `view_user` dependency is invisible in behaviour until it meets
a restricted account, so the test has to assert the absence of the call rather than the presence of a
result.

**`UpdateCacheUseCase`** asserts a throwing `getCurrentUser` no longer fails the update, mirroring
the existing tests for forbidden groups and users.

**`AppReducer.didBecomeActive`** asserts it refreshes permissions for the selected server, that it
does nothing when no server is selected, and — the one that protects the rule above — that a throwing
refresh leaves the cached set unchanged rather than clearing it.

## Out of scope

- **Gating any control.** No button, section or tab changes. This project ends with the question
  answerable; the answering is Projects 2 and 3.
- **Object-level permissions** — `user_can_change`, `owner`, `full_perms`. Documented in Context so
  the next design starts from research rather than repeating it, but nothing here touches them.
- **Making `/api/ui_settings/` optional.** It is already required for the app to function and this
  changes nothing about that; a user lacking `view_uisettings` is no worse off than today.
- **Editing one's own permissions.** The admin screens are unchanged.

## Risks

**Fail-open means a restricted user still sees actions that will fail**, exactly as today, until
Projects 2 and 3 land. That is the accepted cost of not shipping an app that looks broken, and it is
a non-regression rather than a new problem.

**Dropping the second request changes what `currentUser` contains** if `ui_settings` ever serialises
a user differently from `UserViewSet`. Both are the same `User` serializer today. Mitigated by the
decoding tests using a fixture captured from `ui_settings` rather than one hand-written to match the
old call.

**The bug this fixes is inferred, not observed.** If a restricted user turns out to fetch
`/api/users/<id>/` for themselves without `view_user`, the fix is still right — one request instead
of two, and the effective permission list — but its framing as a bug fix would be wrong. The plan
verifies this first.
