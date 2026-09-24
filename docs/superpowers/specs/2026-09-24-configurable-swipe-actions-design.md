# Swipe actions the user picks

Both document lists get a leading and a trailing swipe, each built from a small catalogue of actions
the row already performs. The user chooses them in Settings, separately for the Inbox and the
Documents list, and the choice is stored once for the whole app rather than per server.

## Context

`ec30000` added the first swipe action in a document list: a trailing **Clear inbox tags** button on
`InboxView`, with an undo toast and a statistics refresh behind it. It is hard-coded — one action,
one edge, one screen. This project generalises it.

Four facts shape the work.

**The catalogue already exists.** `DocumentRowView.swift:37` attaches a context menu offering
favourite, edit, preview, share, open content / custom fields / metadata / notes, and delete. Every
one is a `DocumentRowReducer.Action.View` case, and the three that need it are already gated by
`canEdit`, `canDelete` and `canViewNotes` (`DocumentRowReducer.swift:89-93`). Promoting one onto a
swipe is wiring, not new behaviour. This is why the feature is smaller than it sounds.

**There are two screens and one reducer.** `DocumentRowView` is used in exactly two places —
`InboxView.swift:29` and `DocumentListView.swift:100` — and both are driven by `DocumentListReducer`,
told apart by `filter.isInbox`. "Per screen" is therefore a flag that already exists, not a second
code path. `DocumentListView` has no swipe action at all today.

**One action sits on the wrong reducer.** Every candidate lives on `DocumentRowReducer` except
clear-inbox-tags, which `ec30000` put on `DocumentListReducer` because it needed the filter's inbox
tag ids, the bulk edit and the undo toast. A builder that renders a configured list of actions needs
them all reachable from one store.

**`SettingsFeature` cannot see `DocumentsFeature`.** `Module+Dependencies.swift:521` lists
`SettingsFeature`'s dependencies and `documentsFeature` is not among them; only `AppFeature` depends
on it. A settings screen that names document actions cannot import the type from where the actions
live.

## Decisions

**The catalogue is the context menu, minus the two browsing verbs.** Seven actions: favourite,
edit, preview, share, open notes, delete, clear inbox tags. Open *content* and open *custom fields*
are dropped — they navigate rather than act, and a swipe that lands on a reader is a slower path to
what tapping the row already does. This is the cheapest decision to reverse: a new case plus two
strings.

**At most two actions per edge.** SwiftUI renders as many as it is given, but a full swipe only ever
fires the first, so a third button is a menu the user has to stop and read — which is precisely what
the long-press menu already is, and it carries everything. The cap is a rule in the settings screen,
not in the storage format, so raising it later costs one constant.

**Stored once for the app, not per server.** Every key in `SharedReaderKey+Extensions.swift` is
scoped by server, but those are caches of server state, not preferences. The precedent for a
preference is `ReviewPrompt+Live.swift:69` and `TipInvitation+Live.swift:112`, which use a bare
`.appStorage(…)` with no server in the name. A user's muscle memory does not change when they switch
servers, so neither should the bindings.

The consequence is that a stored configuration can name an action the current server forbids — a
config written against an admin account, then used on a read-only one. That is resolved at render,
not at storage: an action whose gate is false is simply not built, exactly as the context menu
already omits Edit for a user without `changeDocument`. Storage never needs migrating when
permissions change, and the settings screen offers all seven actions regardless of what the current
server allows — it is editing a preference, not a capability.

**Configured per screen, defaulted identically.**

| | Leading | Trailing |
|---|---|---|
| Inbox | Edit | Clear inbox tags |
| Documents | Edit | Clear inbox tags |

The defaults match on both screens deliberately. The two lists render the same rows, and the whole
value of a swipe is that you stop looking at it — a binding that changes meaning between two screens
showing the same documents defeats that. The configuration is still per screen, because a user who
wants Delete on Documents and not in the Inbox should be able to say so.

The cost is that on the Documents list the trailing default does nothing for any document without an
inbox tag, which is most of them. That is accepted. **An edge whose configured actions are all
hidden must not swipe open at all**, rather than opening onto an empty tray — an empty tray reads as
a bug, a dead edge reads as "nothing here".

**Delete confirms, and never takes a full swipe.** `DocumentRowReducer.swift:172` already routes
`deleteButtonTapped` to `runConfirmDelete(documentTitle:)`, which goes through
`DocumentDeleteConfirmationPresenter` to the `ConfirmationPopupView` the conventions mandate. A
swipe that sends the same action inherits the popup for free. Separately, `allowsFullSwipe` is a
property of the edge rather than of a button, so the rule is: **an edge whose first action is
destructive sets `allowsFullSwipe: false`.** Delete is never a default.

No button takes `role: .destructive`, for the reason `TrashRowView.swift:43` and
`FileTaskRowView.swift:66` both record: it removes the row the moment the button is tapped, before
the confirmation is answered and before the server has agreed.

**The action type lives in `Components`.** Not in `DocumentsFeature`, because `SettingsFeature`
cannot see it and adding that edge would pull the heaviest feature module into Settings for one
enum. `Components` is already a dependency of both.

It also settles the strings. `STRING_CATALOG_GENERATE_SYMBOLS` emits a catalogue's symbols as
`internal` to the target that compiles it, so an action name rendered in both the settings screen and
the swipe button would otherwise be two keys in two catalogues, free to drift. Putting the enum in
`Components` and exposing `var title: String` resolves the resource where the catalogue is and hands
both consumers a plain `String`. The enum carries `title`, `systemImage` and `isDestructive` and
nothing else — it is a value, and every question about whether an action *applies* is answered where
the document is.

**Clear inbox tags moves down into `DocumentRowReducer`.** This is the one real refactor, and it is
what makes a uniform builder possible. Sequenced after `ec30000` landed, which it has.

The row gains the inbox tag ids by reading `@SharedReader(.inboxTags(server))` directly, mirroring
`DocumentRowReducer.swift:137`, which already reads `.favorites(server)` the same way. That is
simpler than the current arrangement, which derives them from `filter.input.tag.selection.any`, and
it removes any need to thread the list's filter into the row.

What moves with it: the `modifyTags` bulk edit, the undo toast via `ToastPresenter.presentAction`,
and the restore. What stays on `DocumentListReducer`: the refresh, because refetching the list and
the statistics is list-level work a row has no business doing. The row announces the change with a
new `Delegate.inboxTagsChanged` case, and the list answers it with the existing
`runInboxTagsRefresh`, unchanged.

## Architecture

```
Components
  DocumentSwipeAction          enum: title, systemImage, isDestructive
  DocumentSwipeActionSettings  Codable: per screen, per edge
  .documentSwipeActions        AppStorageKey, no server in the key

SettingsFeature
  DocumentSwipeActionSettingsReducer/View   reads and writes the key

DocumentsFeature
  DocumentRowReducer     gains the inbox-tag actions and a delegate
  swipeActions(for:)     maps an action to a send, decides visibility
  InboxView              applies the .inbox configuration
  DocumentListView       applies the .documents configuration
```

The dependency direction is one way: `Components` knows nothing about either consumer,
`SettingsFeature` edits a value it cannot interpret, and `DocumentsFeature` is the only module that
knows what an action *does*.

## Changes

### `Modules/Components/SwipeActions/DocumentSwipeAction.swift` (new)

A `CaseIterable`, `Codable`, `Sendable` enum of the seven actions. `title: String` and
`systemImage: String` mirror the context menu's existing labels and glyphs so the two never disagree.
`isDestructive: Bool` is true for `delete` alone and exists so the full-swipe rule can be applied
without the caller pattern-matching the case.

### `Modules/Components/SwipeActions/DocumentSwipeActionSettings.swift` (new)

```swift
struct DocumentSwipeActionSettings: Codable, Equatable, Sendable {
    struct Edges: Codable, Equatable, Sendable {
        var leading: [DocumentSwipeAction]
        var trailing: [DocumentSwipeAction]
    }
    var inbox: Edges
    var documents: Edges
}
```

with the defaults from the table above, plus the shared key.

**Decoding is lenient.** A synthesised `Codable` enum throws on a case it does not know, which
would mean a configuration written by a newer build discards the whole preference on an older one
rather than the one action it cannot name. The decoder drops unknown actions and keeps the rest.

An `AppStorageKey` needs a
`RawRepresentable` bridge for a struct; if that proves awkward, a `FileStorageKey` with
`.applicationGroupDirectory` matches `inboxTags` and costs nothing extra — the storage backend is an
implementation detail this spec does not fix.

### `Modules/Components/Resources/Localizable.xcstrings`

Seven action names in `en` and `de`. These are the only copies: both consumers read `action.title`.

### `Modules/SettingsFeature/DocumentSwipeActionSettings/` (new)

A reducer and a view. One screen, four rows — Inbox leading, Inbox trailing, Documents leading,
Documents trailing — each opening a picker over the catalogue that enforces the two-action cap and
shows the resulting order. A **Reset to defaults** action, because a user who has made the Inbox
unusable needs a way back that is not deleting the app.

`SettingListReducer.Path` gains a case and `SettingListView` a `NavigationLink`, alongside
`favoriteSettings` at `SettingListView.swift:161`. `Module+Dependencies.swift` needs no edit —
`SettingsFeature` already depends on `components`.

### `Modules/DocumentsFeature/DocumentRow/DocumentRowReducer.swift` and `+Effect.swift`

Gains `clearInboxTagsButtonTapped` and the undo path moved down from the list, a
`@SharedReader(.inboxTags(server))`, and `Delegate.inboxTagsChanged`. Gains `var inboxTags: [Tag.Id]`
so the view can ask whether the action applies to this document.

### `Modules/DocumentsFeature/DocumentRow/DocumentRowSwipeActions.swift` (new)

The builder: given a `DocumentSwipeActionSettings.Edges` and a row store, produce the buttons. It
owns the two rules that cannot live in `Components` — whether an action is visible for this document
and this user (`canEdit`, `canDelete`, `canViewNotes`, and a non-empty `inboxTags`), and whether the
edge allows a full swipe. Returning an empty result is what makes the edge dead rather than empty.

### `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` and `+Effect.swift`

Loses `clearInboxTagsSwiped`, `inboxTagsCleared`, `inboxTagsFailed`, `inboxTagsRestored`,
`inboxTagsUndone`, `runClearInboxTags`, `runRestoreInboxTags`, `runPresentInboxTagsCleared` and
`inboxTagIds`. Keeps `runInboxTagsRefresh` and the `animation` parameter on `runGetDocuments`, now
driven by the row's delegate.

### `Modules/DocumentsFeature/DocumentList/InboxView.swift`, `DocumentListView.swift`

Each reads the settings and applies its own `Edges` through the builder. `InboxView` loses
`clearInboxTagsButton`. The rule that the swipe is hidden during multi-select stays, and moves into
the builder so both screens get it.

## Testing

- `DocumentRowReducerTests` inherit the six reducer tests written for `ec30000`, retargeted at the
  row: correct tags removed, nothing written when none apply, undo restores, a toast left alone
  restores nothing, the error path keeps the row.
- `DocumentListReducerTests` keep the refresh test, now driven by the delegate.
- The builder is tested as a function: which buttons a given configuration and document produce,
  that a forbidden action is omitted, that an all-hidden edge is empty, and that a destructive first
  action disables the full swipe.
- `DocumentSwipeActionSettings` round-trips through its storage, and an unknown case decodes without
  losing the rest of the configuration — a config written by a newer build must not brick an older
  one.
- Snapshot tests for the settings screen: defaults, a full edge, an empty edge.
- **Not covered:** the gesture. A swipe cannot be driven by a `TestStore`, and the simulator
  automation available here starts its drag at the element's centre, so it reveals the buttons but
  never crosses the full-swipe threshold. `ec30000` shipped with the same gap. Full swipe, and the
  destructive-edge rule that suppresses it, need a manual pass.

## Out of scope

- **Per-server overrides.** Decided against above, not deferred.
- **Reordering by drag** in the settings screen. Two actions per edge makes order a two-item choice;
  a picker that appends in tap order is enough.
- **Actions that need a picker of their own** — assign tag, set correspondent, set document type.
  They are a sheet, not a swipe, and the bulk-edit flows already reach them.
- **Swipes on the Favorites and Trash lists.** Different row types with their own actions;
  `TrashRowView` already has its own and they are not configurable.
- **Leading-edge full swipe on the Inbox as a triage shortcut.** Worth considering once the
  configuration exists and there is something to measure.

## Risks

**The Documents trailing default is inert on most rows.** Accepted, and mitigated by the dead-edge
rule, but it means a user who never opens Settings may conclude the Documents list has no swipe.
The alternative — different defaults per screen — was rejected for muscle memory. If it reads badly
in use, changing one default is a one-line change and no migration.

**The refactor touches code that is one commit old.** Moving clear-inbox-tags into the row rewrites
most of `ec30000`. The tests move with it and should keep passing essentially unchanged; if they need
rewriting rather than retargeting, that is a signal the split is wrong and worth stopping on.

**`AppStorage` with a struct.** If the `RawRepresentable` bridge is more friction than it is worth,
switch to `FileStorageKey` and move on — noted here so it is a decision already made rather than one
rediscovered mid-implementation.
