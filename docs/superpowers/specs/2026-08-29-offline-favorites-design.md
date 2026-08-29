# Offline favorites

Keep a handful of important documents on the device — everything about them, including the PDF —
and read them with no server in reach, from a tab of their own.

## Context

**Nothing about a document survives a relaunch today.** Correspondents, custom fields, document
types and groups are file-backed through `SharedReaderKey+Extensions.swift`, each keyed by server
and written into the app group directory. Documents are the exception: `documents(_ server:)` is
`.inMemory`, so a document list is rebuilt from the server every launch. That asymmetry is the gap
this feature closes, and it closes it for a chosen few rather than for everything.

**A document's data arrives from four calls.** `Document` already carries `customFields` and `tags`
inline, so the list payload is most of it. `notes` and `DocumentMetadata` are separate endpoints
fetched per document by `DocumentNotesReducer` and `DocumentMetadataReducer`. The PDF is the fourth,
`DownloadDocumentUseCase`, which returns `Data` with no caching of any kind — the detail screen
writes it to a temporary file and forgets it.

**Thumbnails are cached but not kept.** `PipelineProvider` gives Nuke a `DataCache(name: "default")`,
which is an LRU: it will serve a thumbnail offline if it happens to still be there, and a blank one
otherwise. Nothing pins a thumbnail, so nothing about it can be relied on.

**paperless-ngx has no notion of a favorite.** There is no favorite flag on the API and no endpoint
to sync one. Anything the app calls a favorite is either its own idea or a tag wearing a costume.

## Decisions

**A favorite is a local flag, and the device is the only place it exists.** No tag is written to
the server, so favoriting needs no change permission, works against any paperless version, does not
pollute a document's tags or the tag list, and cannot fail because the network is down. The cost is
real and accepted: favorites do not sync between devices and are invisible in the web UI. Storing
the record behind a `FavoritesStore` dependency leaves room to back it with a tag later without the
UI knowing.

**Favorites are per server**, like every other piece of persisted state in the app. The tab shows
the selected server's favorites; another server's are neither shown nor searched.

**The Favorites tab is a reading surface: its detail screen is always read-only.** Editing offline
would need an outbox, conflict resolution against server-side changes, and partial-failure recovery
— a project of its own, and one that can silently lose an edit if done carelessly. The app has no
way to tell whether it is online (see below), so rather than guess, the tab commits: a favorite is a
snapshot, and a snapshot is not where you edit. Changing a document is still one tap away in
Documents or Inbox.

The gain is more than avoided machinery. Because nothing in the tab can write, an edit made *in the
tab* can never leave the snapshot behind it stale. Edits made elsewhere still can, which is a known
risk recorded below, but the tab is no longer both the cause and the victim.

**The row renders page one of the stored PDF instead of storing a thumbnail.** Downloading and
pinning a second asset would mean a second network call per favorite and a second thing to keep in
step; Nuke's cache cannot be relied on because it evicts. PDFKit is already in `Components` for
`PDFKitView`, and a thumbnail drawn from the file on disk is by construction consistent with the
file on disk. Documents whose original is not a PDF still have an archived PDF in practice, and the
empty state is the existing placeholder.

**A favorite whose document has been deleted on the server is marked unavailable, never deleted.**
The user deliberately kept that copy. A refresh that reacted to a 404 by destroying local data would
be the one behaviour capable of losing something irreplaceable, so refresh marks the record and
leaves the bytes alone; removing it stays a deliberate act.

**Refresh re-reads every favorite but re-downloads only what changed.** One request —
`GetDocumentsByIdsUseCase`, which already exists and issues `id__in` — returns the current
`Document` for every favorite at once. That payload is most of what a favorite stores, so it is
written back unconditionally. Only where `modified` has moved are the three expensive calls made
again: notes, metadata and the PDF. In the common case where nothing changed, a refresh is **one
request and a few kilobytes** instead of four requests per favorite and every PDF over the wire.

Two facts from the paperless-ngx source make this safe, and one makes it necessary to do it in
exactly this order.

`modified` is a sound gate for the expensive three. It is `auto_now=True` on `Document`, so any save
moves it; the notes endpoint explicitly does `doc.modified = timezone.now()` on **both** create and
delete, so a note added from the web UI is caught; and the PDF-mutating operations (`rotate`,
`edit_pdf`) route their output back through the consume pipeline as a new version, which saves the
document.

**Bulk edit does not move `modified`, which is why the document is written back unconditionally.**
`bulk_edit.py` sets correspondent, document type, storage path, owner, tags and ASN through
`QuerySet.update()`, which bypasses `auto_now` entirely, and its follow-up `bulk_update_documents`
task only reindexes — it never calls `save()`. A `modified`-gated refresh alone would therefore keep
stale tags forever, and this app has bulk edit, so it can cause that itself. Taking the fresh
`Document` from the same request that computed the gate costs nothing and closes the hole.

Because pull-to-refresh no longer re-downloads unconditionally, Settings also carries a
**"Redownload all"** action for when a local copy is suspected wrong — the original behaviour, kept,
just moved off the gesture that will be used most.

**Refresh also runs on launch and on returning to the foreground.** This was out of scope while a
refresh meant re-downloading everything; making phase one a single `id__in` request changed the
economics, and the decision deserves revisiting rather than inheriting. `AppReducer` already does
exactly this for statistics — `case .didBecomeActive` returns `.runRefreshStatistics(server:)` — so
favorites join it there, and at `bootstrap` for launch.

It belongs in `AppReducer` rather than the tab's `onAppear`, because the point is to be current
*before* the user needs it. Someone opening the Favorites tab has often opened it precisely because
they have no signal; refreshing then is too late to help.

**No throttle is needed, because phase two is self-limiting.** Once a refresh has run, nothing has
changed, so the next foreground costs one request and downloads nothing — the same profile as the
statistics call already sitting there. A throttle would be machinery guarding against a cost that
does not recur.

**An automatic refresh is silent.** It reports nothing on success and nothing on failure: the user
did not ask for it, and a toast every time a phone comes back into signal would be noise. Only
pull-to-refresh and "Redownload all" report. Nor may a *failed* phase one mark anything unavailable
— absence only means deleted when the request actually succeeded, and conflating "the server did not
answer" with "the document is gone" would badge every favorite the first time the app opens on a
plane.

**The app does not ask whether it is online, and this feature does not teach it to.** Adding an
`NWPathMonitor` would report the *interface*, not whether the paperless server is reachable — a
device on Wi-Fi with no route to the server still reads as online — so it would buy a gate that is
wrong exactly when it matters, plus a new dependency to keep honest. Making the tab unconditionally
read-only gets the same outcome with no infrastructure and no lie.

**The favorites row is a new reducer, not the document row wearing a flag.** `DocumentRowReducer`
and `DocumentRowView` are ~570 lines, and most of that is behaviour a favorite must not have: a
context menu offering edit and delete, download-for-preview and download-for-share intents that hit
the network, a `documentForm` destination, and a `DocumentImage` thumbnail that is a network call.
Reusing it would mean forking the thumbnail source, the context menu, the download intents, the
`documentForm` destination and the unavailable badge — five behavioural special cases in a reducer
two other tabs depend on.

What the lists genuinely share is presentation, so that is what gets shared: `detailsView` and
`tagsView` become a `DocumentRowContent` view over a plain `Document` and `Server`, rendered by both
rows. `FavoriteRowReducer` is then small — open, unfavorite, a local thumbnail, a badge.

`DocumentRowReducer` does still gain one thing, because favoriting is offered from the row: a
`favoriteButtonTapped` action, and a `@SharedReader(.favorites(server))` it derives `isFavorited`
from so the menu item can read "Favorite" or "Unfavorite". That is one capability the row genuinely
has, derived from shared state rather than passed in as a mode — not a flag that makes it behave
differently for one caller.

**Removing offline data and unfavoriting are the same act.** A "keep the favorite, drop the
download" state would be a favorite that is not offline, which is the one thing a favorite is for.
Settings offers the total size and a single destructive "Remove all favorites".

## Architecture

### The record and where it lives

`FavoriteDocument` is the whole of a document as the app can render it without a server:

```swift
public struct FavoriteDocument: Codable, Equatable, Identifiable, Sendable {
    public var id: Document.Id { document.id }

    public let document: Document          // carries customFields and tags already
    public let notes: [Note]
    public let metadata: DocumentMetadata?
    public let pdfByteCount: Int
    public let storedAt: Date

    // Set by a refresh that got a 404. Mutable because it is the one field that changes without
    // the document behind it changing — everything else is replaced wholesale by the next save.
    public var isUnavailable: Bool
}
```

It joins the other shared keys in `ApiInterface`, following their shape exactly:

```swift
public extension SharedReaderKey
where Self == FileStorageKey<IdentifiedArrayOf<FavoriteDocument>>.Default {
    static func favorites(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-favorites.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: []
        ]
    }
}
```

PDFs do not belong in that JSON. They are files at
`<applicationGroupDirectory>/Favorites/<server.id>/<document.id>.pdf`, written to a temporary
neighbour and moved into place, so a download killed mid-flight cannot leave a truncated file that
later reads as a corrupt PDF.

### Modules

`FavoriteDocument`, the shared key and the `FavoritesStore` client go in `ApiInterface`; the live
store and the use cases go in `ApiImplementation`. Both sit below `DocumentsFeature`, which is what
lets the detail screen and the row favorite a document without a dependency cycle.

`FavoritesFeature` is a new framework module holding the tab. It depends on `ApiInterface`,
`Components` and `DocumentsFeature` — the last because it reuses `DocumentRowReducer` and
`DocumentDetailReducer` rather than growing a second document UI. `AppFeature` depends on it. The
module carries its own `Resources/Localizable.xcstrings`, per the per-module catalogue convention.

Four use cases, all in `ApiImplementation`:

| Use case | Does |
|---|---|
| `SaveFavoriteUseCase` | fetches document, notes, metadata and PDF, writes the file, upserts the record |
| `RemoveFavoriteUseCase` | deletes the record and its PDF |
| `RefreshFavoritesUseCase` | one `id__in` request, then re-saves only the favorites whose `modified` moved |
| `RedownloadFavoritesUseCase` | the same, with the re-save forced for every favorite |
| `FavoritesStorageSizeUseCase` | sums the records and the files on disk |

### Favoriting

A heart in the `DocumentDetailView` toolbar, beside the existing edit and overflow buttons, filled
when the document is a favorite and outlined when it is not, and a new item in `DocumentRowView`'s
**existing long-press context menu** — not a swipe action.

**The heart was the tip jar's, and has been handed over.** `SettingListView` labelled tips with a
heart, which favorites has the stronger claim to — it is what Photos uses for exactly this. Tips
moved to `cup.and.saucer` on the `chore/settings-tidy` branch, so nothing here competes for the
glyph. `TipsFeature` keeps `heart.slash` for its failure state, which is why the favorites empty
state uses an outline `heart` instead.

**This feature therefore depends on that branch landing first.** It is a two-line change to a screen
this feature also touches, and doing it separately keeps the favorites diff about favorites.

`DocumentRowView` has no swipe actions today: it has `.onTapGesture` and `.contextMenu`, and the
only swipe anywhere in `DocumentsFeature` is on `DocumentNoteRowView`. Adding one would introduce a
second interaction affordance to the most-seen row in the app for the sake of a third tab, when the
row already has a menu holding exactly this class of per-document action.

**Where it sits in that menu needs deciding, because the menu has a rule.** A comment in
`contextMenu()` records it: the reversible actions run A-Z — Edit, Preview, Share, View — and Delete
is deliberately held out below a divider rather than "taking whatever row its initial earns it".
Favorite cannot follow the A-Z rule, because its label changes with state: *Favorite* sorts between
Edit and Preview, *Unfavorite* between Share and View, so the item would move under the user's
thumb as they used it. It is therefore anchored at the top above its own divider, mirroring how
Delete is anchored at the bottom, for the same reason the comment already gives.

`DocumentRowView` is shared by the Documents tab and the Inbox, so **the menu item appears in both**.
That is worth stating rather than discovering: favoriting straight out of the inbox is a reasonable
thing to want, and suppressing it there would cost a flag on the row whose only purpose is to make
one tab worse.

Both call `SaveFavoriteUseCase`, which does real work — a PDF download — so the row and the toolbar
show progress while it runs and report failure through the existing error handling rather than
leaving a half-written record. Unfavoriting is the same two affordances inverted.

### The tab

A fourth tab between Documents and Settings, `Label(.favorites, systemImage: "heart.fill")`, added
to `AppTab` and `MainView`. The empty state uses the outline `heart` rather than `heart.slash`,
which `TipsFeature` already uses to mean something went wrong.

**A fourth tab invalidates every App Store screenshot.** The tab bar is in all seven screens, so the
committed captures under `Screenshots/Captures` stop matching the app the moment this ships — and
they are already a version behind, having been taken before the tip jar. This is the expensive part
of the feature: `mise run screenshots:capture` is about an hour, against `screenshots:frame`'s five
seconds. It has to be planned in, and it is the one task here that cannot be hurried. The Settings
tidy-up should land before the re-record, so the new tab and the new tip jar symbol are captured in
one pass rather than two.

`FavoriteListReducer` holds `@Shared(.favorites(server))`, a `searchText`, and rows as
`IdentifiedArrayOf<FavoriteRowReducer.State>`. Tapping a row pushes the detail through a `Path`,
matching how `SettingListReducer` and `DocumentListReducer` already navigate. Unfavoriting the
document being viewed pops back to the list, because the thing the screen was showing no longer
exists offline.

The view follows the established search shape — `Searchable { … }.searchable(text: $store.searchText)`
— filtering in memory over title, the resolved correspondent, document type, storage path and tag
names, and the document's `content`. Notes are **not** searched: they are the one field that would
make a hit impossible to see in a row. Everything it searches is already on disk, so there is no
server round-trip and no debounce to get wrong. `.refreshable` drives the refresh, and
`EmptyListView` covers having no favorites yet.

`FavoriteRowView` renders `DocumentRowContent` — the extracted correspondent, date, title, ASN /
type / storage-path grid and tag chips — so a favorite looks like a document everywhere else. What
it puts around that content is its own: a thumbnail drawn from page one of the stored PDF instead of
`DocumentImage`, a badge when the record is unavailable, and a swipe action that unfavorites.
`FavoriteRowReducer` has two actions worth the name — open, and unfavorite.

**The two rows use different gestures on purpose.** On a document row, favoriting is one action
among many, so it belongs in the menu that already holds them. On a favorites row, removal is the
list's single management gesture, which is what `CorrespondentRowView`, `ServerRowView`,
`CustomFieldRowView` and `DocumentTypeRowView` all express as a swipe. Each row follows the idiom
its own list already established, rather than one being made to match the other.

### Reading offline

The tab pushes the existing `DocumentDetailReducer` with three dependencies rewritten to read from
the store rather than the server. Each use case gains a store-backed instance beside its existing
`liveValue`, and the Favorites path installs them:

```swift
DocumentDetailReducer()
    .dependency(\.getNotes, .favoritesStore)
    .dependency(\.getDocumentMetadata, .favoritesStore)
    .dependency(\.downloadDocument, .favoritesStore)
```

One detail UI, no duplication, and an override that is explicit at the call site and trivial to
assert in a `TestStore`. Unlike the row, these are not special cases: it is the same screen showing
the same content, reading from a different source.

The one thing that does change is a single `isOfflineSnapshot` flag on `DocumentDetailReducer.State`,
`false` everywhere else, which hides the edit and delete affordances. One flag for one coherent idea
— this screen is a snapshot — rather than the five the row would have needed.

A favorite marked `isUnavailable` reads exactly as it always did — the bytes are still there. The
list badges it so the state is visible, and refresh is what clears the badge if the document comes
back.

### Refresh

`RefreshFavoritesUseCase` runs in two phases.

**Phase one is a single request.** `GetDocumentsByIdsUseCase` is called with every favorite's id and
returns their current `Document`s. Each favorite's stored `Document` is replaced from that response
— unconditionally, for the bulk-edit reason above — and any id the server did not return is marked
`isUnavailable`. Absence is the signal here rather than a 404, because one request cannot 404 for
one document; a deleted document simply is not in the results. The id list goes out in chunks of 100
so a large favorites set cannot produce a URL the server rejects.

**Phase two touches only the changed.** Favorites whose returned `modified` differs from the stored
one get their notes, metadata and PDF re-fetched, through a `TaskGroup` bounded to three at a time —
enough to be quick, not enough to hammer a home server. Each document is isolated: one failure does
not abort the run. The use case returns a per-document result, which the list summarises.

A refresh that finds nothing changed therefore makes exactly one request. `RedownloadFavoritesUseCase`
is the same thing with phase two forced for every favorite, and is what the Settings action calls.

Refreshing without a reachable server fails in phase one, so the list reports one failure rather
than a pile of identical ones — and marks nothing unavailable, since it learned nothing about what
the server holds.

It runs from three places: pull-to-refresh in the tab, `AppReducer.bootstrap` at launch, and
`AppReducer.didBecomeActive` on returning to the foreground, alongside the statistics refresh
already there. The automatic two report nothing either way. An in-flight refresh is not restarted —
the effect is `.cancellable(id:)` and a second trigger is dropped rather than queued, so
backgrounding and foregrounding repeatedly cannot stack downloads.

### Settings and cleanup

Favorites get a **screen of their own** in Settings rather than three rows in the main list.
`DiagnosticsListView` is the precedent and the shape is identical: a screen about data the app is
holding, with the actions on that data in one place. Three rows in the main list — one of them
destructive — would lengthen a list that is already long, and would put "Remove all favorites" one
mistap from "Tags".

The row sits in the last section, which the tidy-up sorts A-Z, so the section reads Diagnostics,
Favorites, GitHub, Licenses, Tip jar. It is called **Favorites**, matching the tab: one concept, one
name, even though this screen is about the bytes rather than the list.

The screen shows the total on disk and offers "Redownload all", which forces phase two for every
favorite, and a destructive "Remove all favorites" behind the existing `DeleteConfirmationPresenter`.

**It lives in `SettingsFeature`, not `FavoritesFeature`.** It needs only the store and the use cases,
which are in `ApiInterface` and `ApiImplementation`; it needs nothing from the tab. Reaching for
`FavoritesFeature` would give `SettingsFeature` a dependency on `DocumentsFeature` through it — a
large module it does not currently link — for a screen with three rows on it. The favorites *tab* is
what depends on `DocumentsFeature`; Settings should not inherit that.

Deleting a server deletes its favorites and their files too; without that hook the bytes outlive the
server that explains them, with nothing in the UI to reach them.

## Testing

`TestStore` tests for `FavoriteListReducer`: search filtering, refresh success, refresh with one
document failing, a document going unavailable, and the empty state.

The refresh gate earns three of its own, because it is the part most likely to be quietly wrong: an
unchanged `modified` fetches no notes, no metadata and no PDF; a moved `modified` fetches all three;
and a document whose fields changed while `modified` did not — the bulk-edit case — still ends up
with the new fields stored. That last one is the test that would catch someone "simplifying" the
unconditional write-back away.

Automatic refresh gets two more, both about staying quiet: `AppReducer` on `didBecomeActive`
refreshes favorites alongside statistics, and a phase one that *fails* leaves every record untouched
— no badge, no error surfaced. The second is the one that matters, because getting it wrong badges
every favorite as unavailable the first time the app opens without signal. Store tests for the file layer
against a temporary directory, covering the atomic write, the size sum, and deletion removing both
record and file. Snapshot tests for the list in its empty, populated, badged-unavailable
and offline states, following the existing suites. The dependency overrides get a test of their own:
the detail screen fed by the store must produce the same state it would from the network.

`DocumentRowReducer` changed in exactly one way — the context-menu item that favorites a document —
and gets one test for it, covering both labels the item takes. Extracting `DocumentRowContent` is meant to be invisible to the Documents and Inbox
tabs, and the existing row snapshots are what prove it: they must not change. A snapshot diff there
is the signal that the extraction altered layout, not that a reference needs re-recording.

Strings land in `Modules/FavoritesFeature/Resources/Localizable.xcstrings` in both `en` and `de`,
with the few belonging to the toolbar going to `DocumentsFeature`, and the row plus the whole
management screen to `SettingsFeature`.

The Settings screen gets a snapshot per state — a size with favorites, and the empty case — and
`TestStore` tests that "Redownload all" forces phase two and that "Remove all favorites" clears both
records and files.

## Out of scope

**Editing offline.** No outbox, no queued mutations, no conflict resolution.

**Syncing favorites between devices.** The local flag is the decision; a tag-backed store is the
upgrade path if that changes.

**Background refresh.** Refresh runs on launch and on foreground, but the app never wakes itself to
do it — no `BGAppRefreshTask`, no push. A favorite is current as of the last time the app was open,
which is the moment before you needed it offline anyway.

**Re-saving a favorite after editing that document elsewhere in the app.** The next foreground
catches it. Wiring the document form to the favorites store to save one refresh would couple two
features for a few seconds' latency.

**A UI test journey.** Worth adding once the flow settles; it needs its own document uploaded by the
test user, per the rules in `AGENTS.md`.

## Risks

**A large PDF is held in memory.** `DownloadDocumentUseCase` returns `Data`, so a favorite is as big
in memory as it is on disk while it is being saved. Fine for the documents this targets, and the fix
if it bites is a streaming download, which is a change to the use case rather than to this design.

**Nothing bounds total size.** Unbounded storage was chosen deliberately, with Settings showing the
total and offering to clear it. If real use shows people favoriting hundreds of documents, a cap is
a later decision informed by that, not a guess now.

**The dependency-override trick is load-bearing.** If a future change to `DocumentDetailReducer`
adds a fourth network call, the Favorites tab will silently start hitting the network for it, and
the failure only shows up offline. The test that feeds the detail screen from the store is what
catches it; it needs to stay honest as the detail screen grows.

**A favorite is only as fresh as the last time the app was open.** Launch and foreground refreshes
close most of the gap, but a phone that has been in a pocket since yesterday holds yesterday's copy,
and nothing on screen says how old it is. Showing `storedAt` on the row is the cheap answer if that
turns out to matter.

**Phase two downloads without being asked.** An automatic refresh that finds a changed favorite
re-fetches its PDF, which could be megabytes on a cellular connection the user would not have chosen
to spend. The volume is bounded by design — a handful of documents, and only the ones that actually
changed, which in practice is rarely more than one — so no gate is built for it. If it bites,
`NWPathMonitor`'s `isExpensive` is the fix, and it is worth noting that this is the question that
monitor is *good* at: it reports the link honestly, unlike reachability, which is what it was
rejected for earlier in this document.

**The refresh gate leans on paperless-ngx internals.** That `modified` is `auto_now`, that the notes
endpoints bump it by hand, and that `bulk_edit` bypasses it are all facts read from the source at a
point in time, not guarantees of the API. If a future release adds another `QuerySet.update()` path
that changes something the gate protects — notes or the file — a favorite would stay stale through
refreshes with nothing to show for it. The unconditional document write-back limits the blast radius
to notes and the PDF, "Redownload all" is the escape hatch, and the reasoning is written down here
so the next person can check it rather than rediscover it.

**Extracting `DocumentRowContent` touches two shipping tabs.** The row is the most-seen view in the
app, and the extraction is pure refactoring in service of a third tab. The existing snapshot
references are the guard, and they should pass untouched; if they need re-recording, something moved
that was not supposed to.
