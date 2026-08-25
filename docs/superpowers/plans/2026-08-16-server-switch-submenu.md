# Server Switch Submenu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a **Servers** submenu to the ellipsis menu shared by the Inbox and All Documents screens, listing every configured server with the current one checked, so switching servers takes two taps instead of a trip through Settings.

**Architecture:** Server switching already works entirely through `@Shared(.selectedServer)`: `AppReducer` observes that key and rebuilds `MainReducer.State` from scratch on every change. This plan adds a second trigger for that same write — a view action on `DocumentListReducer` whose effect writes the shared value — plus the menu that sends it. Along the way the server list's sort comparison moves into `Server: Comparable` so the submenu and the Settings server list cannot order servers differently.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture (TCA 1.22.3), swift-dependencies, swift-sharing, Swift Testing, swift-snapshot-testing, Tuist.

**Design doc:** `docs/superpowers/specs/2026-08-16-server-switch-submenu-design.md` — read it before starting.

## Global Constraints

- **Comments:** `//` only. **Never `///`, never `/** ... */`**, anywhere, including in test files that still contain old-style doc comments (`ServerRowReducerTests.swift:86` has one — do not copy it). Comment only when a future reader would otherwise stop and wonder *why*; never restate what the code says. See `AGENTS.md`.
- **No blank line between an attribute and its declaration** — `mise/scripts/attribute_blank_lines.py --check` runs in lint and enforces this. Write `@Shared(.servers)` on the line immediately above `var servers`.
- **Alphabetical member ordering** is the convention throughout this codebase — enum cases, struct properties, `CancelID` cases and switch cases are all alphabetical. Every insertion point below names its exact neighbours; match them.
- **Test runner:** `tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:<Target>/<Suite>`. Scheme names are the module names: `ApiInterface`, `ServersFeature`, `DocumentsFeature`. **`--no-selective-testing` is not optional during TDD** — without it Tuist fingerprints the target and reports "The scheme's test action has no tests to run, finishing early" on a re-run, which reads exactly like a pass.
- **Lint before each commit:** `mise run ci:lint` (runs `swiftformat --lint .`, `swiftlint --strict`, the blank-line script, and `tuist inspect dependencies --only implicit`). `mise run format` fixes formatting drift.
- **No string catalog changes.** `servers` already exists in `Shared/Framework/Resources/Localizable.xcstrings` — it backs the Settings row. Do not add a key.
- **No Tuist dependency changes.** Everything below stays inside modules that already depend on `ApiInterface`. If `tuist inspect dependencies` complains, something went wrong — do not add a dependency to silence it.
- **Branch:** work on `feature/server-switch-submenu`, which already exists and holds the design doc commit.

---

### Task 1: One ordering for servers

`Server` already conforms to `Comparable`, but its `<` is a plain alias comparison while `ServerListReducer.sort()` uses a case-insensitive, numeric, forced-ordering compare. The submenu will sort with `sorted()`, so `<` has to become the richer comparison or the two lists will disagree.

**Files:**
- Modify: `Modules/ApiInterface/Shared/Server.swift:51-55`
- Modify: `Modules/ServersFeature/ServerList/ServerListReducer.swift:98-109`
- Test: `Modules/ApiInterfaceTests/Shared/ServerTests.swift`

**Interfaces:**
- Consumes: `Server.testValue(alias:headers:id:username:url:)` (existing, `Server.swift:33`).
- Produces: `Server: Comparable` whose `<` orders by alias case-insensitively and numerically. Task 3 relies on this for `store.servers.sorted()`.

- [ ] **Step 1: Write the failing tests**

Append both tests to `Modules/ApiInterfaceTests/Shared/ServerTests.swift`, after `encode_decode_roundTrip`. The suite already carries `.dependencies()` and imports `Testing` — no import changes.

```swift
    @Test
    func comparable_ordersCaseInsensitively() async throws {
        let apple = Server.testValue(alias: "apple", id: "1")
        let banana = Server.testValue(alias: "Banana", id: "2")

        #expect(apple < banana)
        #expect(!(banana < apple))
    }

    @Test
    func comparable_ordersNumerically() async throws {
        let second = Server.testValue(alias: "Server 2", id: "1")
        let tenth = Server.testValue(alias: "Server 10", id: "2")

        #expect(second < tenth)
        #expect(!(tenth < second))
    }
```

Both fail against today's `<`. Swift's `String <` compares Unicode scalars, so `"Banana" < "apple"` (uppercase `B` sorts before lowercase `a`) and `"Server 10" < "Server 2"` (`"1"` before `"2"`) — the exact inverse of both expectations.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:ApiInterfaceTests/ServerTests
```

Expected: FAIL — `comparable_ordersCaseInsensitively` and `comparable_ordersNumerically` both fail on their first `#expect`. `decode_withHeaders` and `encode_decode_roundTrip` pass.

- [ ] **Step 3: Move the richer comparison into `<`**

In `Modules/ApiInterface/Shared/Server.swift`, replace the existing `Comparable` conformance:

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

`compare(_:options:)` comes from Foundation, which `Server.swift` already imports.

- [ ] **Step 4: Run the tests to verify they pass**

```bash
tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:ApiInterfaceTests/ServerTests
```

Expected: PASS — 4 tests.

- [ ] **Step 5: Point `ServerListReducer.sort()` at the shared comparator**

In `Modules/ServersFeature/ServerList/ServerListReducer.swift`, replace the whole body of `sort()`:

```swift
    mutating func sort() {
        servers.sort { $0.server < $1.server }
    }
```

This deletes the inline `alias.compare(_:options:)` call — the options list now lives in `Server.<` and must not be duplicated here.

- [ ] **Step 6: Run the server list tests to verify the order is unchanged**

```bash
tuist test ServersFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS — the existing `ServerListReducerTests` sort coverage is what proves the comparator move preserved the Settings list's order. If any sort assertion fails, the comparison was transcribed wrong; fix `Server.<` rather than the test.

- [ ] **Step 7: Lint and commit**

```bash
mise run ci:lint
git add Modules/ApiInterface/Shared/Server.swift \
        Modules/ApiInterfaceTests/Shared/ServerTests.swift \
        Modules/ServersFeature/ServerList/ServerListReducer.swift
git commit -m "refactor: give Server one ordering for alias sorting"
```

---

### Task 2: The reducer selects a server

Adds the shared server list to `DocumentListReducer.State`, the view action the menu will send, and the effect that performs the switch. After this task the behaviour is complete and tested; nothing sends the action yet.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentListReducer.State.testValue(server:)` (existing, `DocumentListReducer+TestValue.swift:8`), `SharedReaderKey.servers` and `SharedReaderKey.selectedServer` (existing, `ApiInterface/Extensions/SharedReaderKey+Extensions.swift:99` and `:113`).
- Produces: `DocumentListReducer.State.servers: IdentifiedArrayOf<Server>` (read by Task 3 as `store.servers`), `DocumentListReducer.Action.View.serverButtonTapped(Server)` (sent by Task 3), and `Effect.runSelectServer(server:)`.

- [ ] **Step 1: Write the failing tests**

Add both tests to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`, immediately after `test_view_scanButtonTapped`. The file already imports `ApiInterface`, `ComposableArchitecture`, `Foundation`, `Testing` and `TestSupport`, and the suite already carries `.dependencies()` — no import or trait changes.

`@Shared(.selectedServer)` is file storage, which the test context backs with an in-memory store, so each test starts with it `nil`. This is the same pattern `ServerListReducerTests` and `ServerRowReducerTests` use.

```swift
    @Test
    func test_view_serverButtonTapped() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server?

        let current = Server.testValue(alias: "Home", id: "home")
        let other = Server.testValue(alias: "Office", id: "office")

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            server: current
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.serverButtonTapped(other)))
        await store.finish()

        #expect(selectedServer == other)
    }

    @Test
    func test_view_serverButtonTapped_alreadySelected_doesNothing() async throws {
        @Shared(.selectedServer)
        var selectedServer: Server?

        let current = Server.testValue(alias: "Home", id: "home")

        let store = TestStore(initialState: DocumentListReducer.State.testValue(
            server: current
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.serverButtonTapped(current)))

        #expect(selectedServer == nil, "tapping the current server must not restart the app's server observer")
    }
```

`await store.finish()` in the first test is required: `runSelectServer` writes the shared value from inside a `.run` and sends no action back, so without it the assertion can run before the effect does.

- [ ] **Step 2: Run the tests to verify they fail**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentListReducerTests
```

Expected: FAIL to **compile**, with "type 'DocumentListReducer.Action.View' has no member 'serverButtonTapped'". A compile failure is the correct red state here.

- [ ] **Step 3: Add the shared server list to `State`**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, insert into the `@Shared` block of `State` — between `savedViews` and `storagePaths`, keeping the block alphabetical:

```swift
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server>
```

Unlike its neighbours, this one carries its key in the attribute rather than being assigned in `init`: the other shared properties are scoped to `server` and need the init argument, `servers` is global and has nothing to wait for. `.servers` is a `.Default` key, so the property needs no initialiser and `init` needs no new line. This mirrors `ShareExtensionReducer.State:42`.

Leave `init` untouched.

- [ ] **Step 4: Add the view action**

In the same file, add to `Action.View`, between `scanButtonTapped` and `toggleSelectionModeButtonTapped`:

```swift
            case serverButtonTapped(Server)
```

- [ ] **Step 5: Handle the action**

In the same file's `case let .view(viewAction):` switch, insert between `case .scanButtonTapped:` and `case .toggleSelectionModeButtonTapped:`:

```swift
                case let .serverButtonTapped(server):
                    guard server != state.server else {
                        return .none
                    }
                    return .runSelectServer(server: server)
```

- [ ] **Step 6: Add the effect**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift`, add after `runRefreshDocuments` (the last `run*` function in the file):

```swift
    static func runSelectServer(server: Server) -> Self {
        .run { _ in
            @Shared(.selectedServer)
            var selectedServer: Server?

            // An effect rather than a synchronous write: this is what makes `AppReducer` discard
            // `MainReducer.State`, and with it the store currently being reduced.
            $selectedServer.withLock { $0 = server }
        }
        .cancellable(
            id: CancelID.selectServer,
            cancelInFlight: true
        )
    }
```

The file's imports already cover this: `ApiInterface` for `Server` and the shared key, `ComposableArchitecture` for `@Shared` and `Effect`.

Then add to the `private enum CancelID` at the bottom of the file, after `refreshStatistics`:

```swift
    case selectServer
```

- [ ] **Step 7: Run the tests to verify they pass**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing -- -only-testing:DocumentsFeatureTests/DocumentListReducerTests
```

Expected: PASS — the two new tests plus all 36 existing ones. The existing tests are unaffected by the new `@Shared` property because `State.testValue` leaves `servers` empty and every `TestStore` in the file compares equal on it.

- [ ] **Step 8: Lint and commit**

```bash
mise run ci:lint
git add Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift \
        Modules/DocumentsFeature/DocumentList/DocumentListReducer+Effect.swift \
        Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift
git commit -m "feat: let the document list reducer switch servers"
```

---

### Task 3: The Servers submenu

Wires the menu to the action from Task 2. Both the Inbox and All Documents screens apply this one modifier, so both gain the submenu.

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListTopTrailingToolbar.swift`

**Interfaces:**
- Consumes: `store.servers` and `Action.View.serverButtonTapped(Server)` from Task 2; `Server: Comparable` from Task 1; the file's existing private `send(_:)` helper (`DocumentListTopTrailingToolbar.swift:92-95`).
- Produces: nothing further depends on this task.

- [ ] **Step 1: Add the submenu builder**

In `Modules/DocumentsFeature/DocumentList/DocumentListTopTrailingToolbar.swift`, add a new `@ViewBuilder` property. Place it after `selectActionsMenu` and before the `send(_:)` helper:

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

Three things this deliberately does **not** do:

- It does not read `@Shared(.selectedServer)`. `store.server` *is* the selected server — `MainReducer.State` is built from it — so a second read would be two names for one value.
- It does not gate on `count >= 1`. With one server there is nothing to switch to, and the menu should keep exactly its current three items.
- It does not sort inline. `sorted()` uses `Server: Comparable` from Task 1, which is the same ordering the Settings server list uses.

- [ ] **Step 2: Nest it in the default menu**

In the same file, add `serversMenu` as the first entry of `defaultActionsMenu`, above the Import button:

```swift
    @ViewBuilder
    private var defaultActionsMenu: some View {
        Menu {
            serversMenu

            Button {
                send(.importButtonTapped)
            } label: {
                Label(.import, systemImage: "doc.badge.plus")
            }
```

Leave the Scan and Select buttons and the outer `label:` closure untouched. `selectActionsMenu` is not modified — the submenu is intentionally absent while a selection is active.

- [ ] **Step 3: Build and run the DocumentsFeature tests**

```bash
tuist test DocumentsFeature -d "iPhone 17 Pro" --no-selective-testing
```

Expected: PASS, including the existing `DocumentListViewTests` snapshots. Those are unaffected: their `testValue` state leaves `servers` empty, so the submenu is hidden, and a collapsed `Menu` renders as the same single toolbar button either way.

**No automated test covers the unfolded submenu.** An open `Menu` is presented by UIKit outside the SwiftUI hierarchy, so `assertSnapshot` cannot reach it — the same limitation recorded for the filter sheet's ellipsis menu. Step 4 is the verification.

- [ ] **Step 4: Verify by hand in the simulator**

The `DocumentsApp` scheme runs the document list against the docker container (`mise run docker:start`, then `mise run docker:seed` if it has not been seeded). It sets `defaultFileStorage = .inMemory`, so `@Shared(.servers)` is empty there and the submenu will be **hidden** — that is the single-server rule working, and it is what to confirm first.

To see the submenu itself, run the full **Less Paper** scheme, add a second server through Settings → Servers, then check:

- the ellipsis menu on Inbox shows **Servers** above Import, with a disclosure chevron;
- unfolding it lists both aliases, checkmark on the current one;
- tapping the other alias switches the app — the document list reloads against the new server, and Settings now shows it as current;
- tapping the already-current alias does nothing at all — no reload, no flicker;
- entering selection mode replaces the menu with the Select menu, which has no Servers entry.

- [ ] **Step 5: Lint and commit**

```bash
mise run ci:lint
git add Modules/DocumentsFeature/DocumentList/DocumentListTopTrailingToolbar.swift
git commit -m "feat: switch servers from the document list menu"
```

---

## Done when

- `tuist test ApiInterface`, `tuist test ServersFeature` and `tuist test DocumentsFeature` all pass.
- `mise run ci:lint` is clean.
- The manual checks in Task 3 Step 4 all hold.
- Three commits sit on `feature/server-switch-submenu` above the design doc commit.
