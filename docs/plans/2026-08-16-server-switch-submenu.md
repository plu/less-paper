# Server switch submenu

## Context

Switching servers today is a trip through Settings: the Settings tab's first row pushes
`ServerListView` (`SettingListView.swift:20-26`), and tapping a row there runs
`ServerRowReducer+Effect.runSelectServer`, which warms the cache and then writes
`@Shared(.selectedServer)`.

That shared value is the app's pivot. `AppReducer` observes it
(`AppReducer+Effect.runSelectedServerObserver`) and, on every change, rebuilds `main` from scratch:

```swift
case .selectedServerChanged(let server):
    if let server {
        state.main = MainReducer.State(server: server)
        return .runUpdateCache(server: server)
    }
```

`AppView` keys `MainView` on `store.server.id`, so the entire tab hierarchy is replaced. Nothing
else needs to know a switch happened.

Meanwhile the Inbox and All Documents screens share one trailing toolbar,
`DocumentListTopTrailingToolbar`, whose `defaultActionsMenu` holds Import, Scan and Select. For a
user with more than one server, moving between them means leaving the list, opening Settings,
drilling into the server list, tapping, and navigating back.

## Goal

Put a **Servers** submenu at the top of that ellipsis menu, listing every configured server with the
current one checked, so switching is two taps from the document list.

## Design

### The submenu

`defaultActionsMenu` gains a nested `Menu` above Import. On iOS a `Menu` inside a `Menu` renders as
a row with a disclosure chevron that unfolds in place.

```swift
@ViewBuilder
private var serversMenu: some View {
    if store.servers.count > 1 {
        Menu {
            ForEach(store.servers.sorted()) { server in
                Button {
                    send(.serverButtonTapped(server))
                } label: {
                    if server == store.server {
                        Label(server.alias, systemImage: "checkmark")
                    } else {
                        Text(server.alias)
                    }
                }
            }
        } label: {
            Label(.servers, systemImage: "server.rack")
        }
    }
}
```

**Hidden below two servers.** With zero or one server configured there is nothing to switch to, and
the menu keeps exactly its current three items. `store.servers.count > 1` is the whole rule.

**The checkmark compares against `store.server`, not a second shared read.** `main` is built *from*
the selected server, so `DocumentListReducer.State.server` already *is* the selection; introducing
`@Shared(.selectedServer)` alongside it would be two names for one value. The checkmark renders on
the trailing edge — that is where UIKit menus place a `Label`'s image.

**No new string.** `servers` already exists in `Shared/Framework/Resources/Localizable.xcstrings`
for the Settings row.

### One ordering for servers

`Server` already conforms to `Comparable`, but its `<` is a plain alias comparison
(`Server.swift:51-55`), while `ServerListReducer.sort()` uses a richer one:

```swift
$0.server.alias.compare(
    $1.server.alias,
    options: [.caseInsensitive, .numeric, .forcedOrdering]
) == .orderedAscending
```

The submenu must not order servers differently from the server list, so the richer comparison moves
into `<`:

```swift
extension Server: Comparable {
    public static func < (lhs: Server, rhs: Server) -> Bool {
        lhs.alias.compare(
            rhs.alias,
            options: [.caseInsensitive, .numeric, .forcedOrdering]
        ) == .orderedAscending
    }
}
```

`ServerListReducer.sort()` then reads `servers.sort { $0.server < $1.server }`, and the submenu gets
the same order for free from `sorted()`. `<` on `Server` has no other call site, so nothing else
shifts.

### Selecting

`DocumentListReducer.State` gains the server list:

```swift
@Shared(.servers)
var servers: IdentifiedArrayOf<Server>
```

`Action.View` gains `serverButtonTapped(Server)`, handled as:

```swift
case let .serverButtonTapped(server):
    guard server != state.server else {
        return .none
    }
    return .runSelectServer(server: server)
```

Tapping the server that is already selected does nothing — without the guard it would tear down and
rebuild the whole tab hierarchy to arrive back where it started.

The effect mirrors `ServerRowReducer+Effect.runSelectServer`:

```swift
static func runSelectServer(server: Server) -> Self {
    .run { _ in
        @Shared(.selectedServer)
        var selectedServer: Server?

        $selectedServer.withLock { $0 = server }
    }
    .cancellable(
        id: CancelID.selectServer,
        cancelInFlight: true
    )
}
```

**Deliberately an effect rather than a synchronous `state.$selectedServer.withLock`.** Writing the
shared value is what causes `AppReducer` to discard `MainReducer.State` — this store included. The
effect keeps that teardown off the reduce that triggered it.

**It skips the `updateCache` pre-warm** that `ServerRowReducer` performs. That pre-warm exists so
the server row's `ProgressView` has something to cover; a menu dismisses instantly and has nowhere
to show one. `AppReducer.selectedServerChanged` already returns `runUpdateCache(server:)`, so the
cache is refreshed either way, just in the background.

### What a switch costs

Rebuilding `main` resets the active filter, scroll position, selection mode and any in-flight
request on both document tabs. That is inherent to how server switching already works from
Settings; the submenu changes where the switch is triggered, not what it does.

## Out of scope

- **Selection mode.** The submenu lives in `defaultActionsMenu`; while a selection is active the
  toolbar shows `selectActionsMenu` instead, and that stays as it is.
- **An "Add server…" entry.** Adding and editing servers remains the server list's job.
- **The Settings tab's own menu.** Unchanged.
- **Preserving filter or scroll across a switch.** See above — pre-existing behaviour.

## Testing

- **`DocumentListReducerTests`**
  - `serverButtonTapped` with a different server writes `@Shared(.selectedServer)`, asserted after
    the effect settles (the pattern `ServerListReducerTests` uses: declare `@Shared(.selectedServer)`
    in the test body and `#expect` on it).
  - `serverButtonTapped` with `state.server` returns no effect and leaves the shared value alone.
- **`ApiInterfaceTests/Shared/ServerTests.swift`** — `<` orders case-insensitively and numerically:
  `"apple" < "Banana"` and `"Server 2" < "Server 10"`.
- **`ServersFeatureTests/ServerList/ServerListReducerTests`** — existing sort coverage stays green
  and proves the comparator move preserved the server list's order.
- **No view test for the submenu contents.** An open `Menu` is presented by UIKit outside the
  SwiftUI hierarchy, so the snapshot tests cannot capture it — the same limitation noted for the
  filter sheet's ellipsis menu. Existing `DocumentListViewTests` snapshots are unaffected: its
  `testValue` state leaves `servers` empty, which hides the submenu, and the collapsed menu is a
  single unchanged toolbar button either way.

## Files

Changed:

- `Modules/ApiInterface/Shared/Server.swift` — `<` uses the case-insensitive, numeric, forced
  ordering comparison
- `Modules/ServersFeature/ServerList/ServerListReducer.swift` — `sort()` delegates to `<`
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift` — `@Shared(.servers)` on
  `State`; `serverButtonTapped(Server)` on `Action.View` and its reducer case
- `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift` — `runSelectServer`;
  `CancelID.selectServer`
- `Modules/DocumentsFeature/DocumentList/DocumentListTopTrailingToolbar.swift` — `serversMenu`,
  nested at the top of `defaultActionsMenu`
- `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`
- `Modules/ApiInterfaceTests/Shared/ServerTests.swift`
