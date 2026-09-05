# Hiding what the user cannot do

Gate the six entity-management screens on the permissions the app already knows about, so a
restricted user is not offered actions the server will refuse.

## Context

[Permissions acquisition](2026-09-04-permissions-acquisition-design.md) shipped the data: the app
reads the current user's effective permission set from `/api/ui_settings/`, caches it per server at
`.permissions(server)`, refreshes it when the app becomes active, and exposes
`PermissionsQuery.can(permission, server)`. Nothing consumes it. Every control is still shown to
every user.

That project was one of three. This is the second: **global gating** — hiding what a user can never
do, anywhere in the app, according to Django model permissions of the form `<action>_<type>`.
Object-level gating (`user_can_change` per document) remains the third and is not designed here.

### The surface

Six features manage entities and are structurally identical — `TagsFeature`,
`CorrespondentsFeature`, `DocumentTypesFeature`, `StoragePathsFeature`, `CustomFieldsFeature`,
`SavedViewsFeature`. Each is a `…List` reducer, a `…Row` reducer, and a `…Form`. Five affordances
per feature carry a permission:

| Affordance | Where | Permission |
|---|---|---|
| Settings row into the list | `SettingListView` | `view_<entity>` |
| Toolbar "+" | `…ListView` toolbar | `add_<entity>` |
| Empty-state "Create …" button | `…ListView` `emptyListView()` | `add_<entity>` |
| Swipe → edit | `…RowView.swipeActions` | `change_<entity>` |
| Swipe → delete | `…RowView.swipeActions` | `delete_<entity>` |

Rows do not navigate. Editing and deleting are both swipe actions, which is what makes this project
tractable: every gate hides a control, and none changes a navigation path or needs a second visual
state for a screen.

`DocumentsFeature` (import, scan, bulk edit, delete, notes) and `TrashFeature` (restore, empty) carry
the same kind of gate and are deliberately left to a follow-up — see Out of scope.

## Decisions

**Gating is presentation, not enforcement.** Inherited from the previous project and repeated here
because every edge case resolves against it: the server remains the security boundary. A hidden
control is a courtesy, not a defence, and when the answer is unknown the control is shown.

**Fail open.** `PermissionsQuery.can` returns `true` when the permission cache is `nil` — never read.
Nothing in this project changes that, and no gate may invert it. A user whose `ui_settings` request
failed sees the app exactly as it looks today.

**The gate lives in state, not in the view and not in a stored flag.** Each list and row State gains
a `ServerPermissions` value holding `@Shared(.permissions(server))` and `@Shared(.currentUser(server))`.
Views read `store.permissions.can(.addTag)`.

Two alternatives were rejected. Computing booleans into state on `.onAppear` goes stale the moment a
foreground refresh lands — and the previous project built that refresh precisely so a revoked
permission takes effect, so staleness would defeat it. Calling the dependency from a view body breaks
the convention that views read `store`, introducing a second idiom for one feature.

**The nesting was verified before the design relied on it.** A throwaway spike confirmed that a
struct holding `@Shared`, nested inside `@ObservableState`, still notifies observation when the cache
is written from outside — the foreground-refresh path — with a directly-declared `@Shared` as a
control. The Store-and-SwiftUI half of that path is already proven by shipping code:
`DocumentDetailView` renders `store.document.title` from a `@Shared` document and the Favorites tab
depends on it updating.

**`ServerPermissions.can` is the single implementation of the rule, and `PermissionsQuery` delegates
to it.** The previous project built `PermissionsQuery` as a dependency client on the assumption that
gating would ask it a question; gating instead holds shared state, so the client would otherwise have
no caller. Rather than keep two spellings of one rule, `can(_:)` moves to `ServerPermissions` and
`PermissionsQuery.liveValue` calls it. The client stays because a reducer or a test may want to grant
or deny without seeding a cache — but if it still has no caller when this project ends, it should be
deleted rather than left as decoration, and this document says so.

**Hiding, not disabling.** Established in the previous project's spec and honoured here: a control
the user cannot use is not rendered. A disabled control invites the question "why", and answering it
well would mean explaining Django permissions inside a swipe action.

**The empty state loses its button, not its message.** A user who cannot create tags and has no tags
sees "No tags found" with no call to action. That is the honest rendering: there is nothing there,
and they cannot change that. Substituting a "you do not have permission" message would explain a
boundary the app is not enforcing.

**A hidden Settings row does not hide the entity elsewhere.** Tag names still appear on documents,
because those come from the document payload rather than the tag list. This is not an inconsistency
to fix: the gate is on managing tags, not on seeing that a document has one.

## Architecture

```
ApiInterface
  ServerPermissions          @Shared(.permissions) + @Shared(.currentUser), can(_:)  [new]
  PermissionsQuery           delegates to ServerPermissions.can                      [changed]
        ^
        | held in State
        |
TagsFeature / CorrespondentsFeature / DocumentTypesFeature
StoragePathsFeature / CustomFieldsFeature / SavedViewsFeature
  …ListReducer.State         var permissions: ServerPermissions
  …ListView                  toolbar + empty state read store.permissions.can(.add…)
  …RowReducer.State          var permissions: ServerPermissions
  …RowView                   swipe actions read store.permissions.can(.change… / .delete…)
        ^
        |
SettingsFeature
  SettingListReducer.State   var permissions: ServerPermissions
  SettingListView            each NavigationLink gated on can(.view…)
```

`ServerPermissions` is initialised from a `Server`, which every one of these States already holds.

## Changes

### `Modules/ApiInterface/Permissions/ServerPermissions.swift` (new)

```swift
public struct ServerPermissions: Equatable, Sendable {

    @Shared public var permissions: [Permission]?

    @Shared public var currentUser: User?

    public init(server: Server) {
        _permissions = Shared(wrappedValue: nil, .permissions(server))
        _currentUser = Shared(wrappedValue: nil, .currentUser(server))
    }

    public func can(_ permission: Permission) -> Bool {
        guard let permissions else {
            return true
        }
        return currentUser?.isSuperuser == true || permissions.contains(permission)
    }
}
```

The `guard` comes first and returns `true`: nothing read means nothing known means show everything.
That branch reads as redundant and is not — `contains` on an empty array denies every permission, so
removing it hides the whole app from anyone whose paperless does not send the key.

### `Modules/ApiInterface/Permissions/PermissionsQuery.swift`

`liveValue.can` becomes `ServerPermissions(server: server).can(permission)`. The memoisation cache
added at the end of the previous project stays: it exists so the client is cheap to call repeatedly,
and constructing a `ServerPermissions` per call would reintroduce exactly the disk I/O that cache
removed.

### The six entity features

Identical in each. Using tags as the worked example:

`TagListReducer.State` gains `var permissions: ServerPermissions`, initialised alongside `server`.
`TagListView`'s toolbar button and the `emptyListView()` button are wrapped in
`if store.permissions.can(.addTag)`.

`TagRowReducer.State` gains the same property. `TagRowView.swipeActions()` wraps its edit button in
`if store.permissions.can(.changeTag)` and its delete button in `if store.permissions.can(.deleteTag)`.

The row needs its own copy rather than reading the list's, because `TagRowReducer` is scoped
per-row through `IdentifiedArrayOf` and has no path to its parent's state.

The permission cases per feature:

| Feature | add | change | delete | view |
|---|---|---|---|---|
| Tags | `.addTag` | `.changeTag` | `.deleteTag` | `.viewTag` |
| Correspondents | `.addCorrespondent` | `.changeCorrespondent` | `.deleteCorrespondent` | `.viewCorrespondent` |
| Document types | `.addDocumentType` | `.changeDocumentType` | `.deleteDocumentType` | `.viewDocumentType` |
| Storage paths | `.addStoragePath` | `.changeStoragePath` | `.deleteStoragePath` | `.viewStoragePath` |
| Custom fields | `.addCustomField` | `.changeCustomfield` | `.deleteCustomField` | `.viewCustomField` |
| Saved views | `.addSavedView` | `.changeSavedView` | `.deleteSavedView` | `.viewSavedView` |

`changeCustomfield` is spelled with a lowercase `f` in the enum, matching the paperless codename
`change_customfield`. That is not a typo to fix — the raw value is the wire format — and it is listed
here so nobody corrects it into a compile error.

### `Modules/SettingsFeature/SettingList/`

`SettingListReducer.State` gains `var permissions: ServerPermissions`. In `SettingListView`, each of
the six entity `NavigationLink`s is wrapped in `if store.permissions.can(.view…)`.

The `pdfPasswordList` and `trashList` links in the same `Section` are **not** gated. PDF passwords
are stored on device and have no server permission. Trash is `delete_document` and belongs with the
documents work in the follow-up.

A `Section` whose every row is hidden renders as nothing, so a user with no entity permissions at all
sees the section vanish rather than an empty box.

## Testing

**`ServerPermissions.can`** carries the rule and gets the five cases the previous project's query
had: superuser without the permission → `true`; non-superuser holding it → `true`; non-superuser
lacking it → `false`; `nil` cache → `true`; empty-but-not-nil cache → `false`. The last two are one
character apart in the type and opposite in meaning, and exist so that deleting the `guard` fails.

**`PermissionsQuery`'s existing five tests stay unchanged.** They now exercise the delegation, and
their passing unedited is the evidence that moving the rule did not alter it.

**Each feature's list and row get snapshot tests** for the gated states — a list with and without
`add`, a row with edit-only, delete-only, both and neither. Snapshots are the right instrument here
because the assertion is "this control is not on screen", which is what a snapshot captures directly.

Two things the snapshots must not paper over. A snapshot proves a control is absent from an image;
it does not prove the absence was caused by the permission rather than by an unrelated rendering
failure — so each feature also gets one reducer-level test asserting `can` returns what the fixture
implies. And the fixtures must seed the permission cache explicitly rather than relying on `nil`,
because `nil` fails open and would render every control, making a "gated" snapshot identical to an
ungated one.

**One test asserts the fail-open default end to end**: a list rendered with no permission cache at
all shows every control. That is the state a user on an older paperless is in, and it must look
exactly like today.

## Out of scope

- **`DocumentsFeature` and `TrashFeature`.** Import, scan, bulk edit, document delete, notes,
  restore and empty trash all carry global permissions and all belong in this project's shape. They
  are held back so the pattern is established on the six regular cases first and reviewed once,
  rather than debated across two dissimilar surfaces at the same time. This is Project 2b.
- **Object-level permissions.** `user_can_change`, `owner`, `full_perms`. Project 3.
- **Disabling instead of hiding.** Decided against; recorded above.
- **Explaining a missing control to the user.** No "you do not have permission" copy anywhere. The
  app is not enforcing the boundary and should not narrate one.
- **Gating reads.** Nothing hides a list's contents. `view_<entity>` gates the route into the
  management screen, not the rendering of entities the document payload already carries.

## Risks

**A wrong permission case silently over-hides.** `.changeCustomfield` versus `.changeCustomField` is
one lowercase letter, and the compiler catches the second — but a plausible-looking wrong case that
does compile, such as gating tags on `.changeCorrespondent`, would hide a control for users who
should see it and no test would notice unless it asserts the specific permission. The per-feature
reducer test above exists for this, and the table in Changes is the reference to check against.

**Six near-identical implementations invite drift.** The features are copies of each other today and
this adds five more copied lines to each. The alternative — a generic gating wrapper — would abstract
over six reducers that are only incidentally similar, and the repo's existing style is to let them
stay parallel. Accepted, with the table as the single place the mapping is written down.

**A user who gains a permission mid-session sees it appear.** This is the intended behaviour of the
foreground refresh, but it means the UI can change shape while the app is open. The alternative is
staleness, which the previous project deliberately removed.
