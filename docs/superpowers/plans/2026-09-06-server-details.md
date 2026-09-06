# Server Details Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A read-only screen, reached from a server row's swipe actions, showing everything the app knows about one server and the account it connects with.

**Architecture:** A new `ServerDetailReducer` whose State holds the per-server `@Shared` caches directly, so the screen renders what is cached the instant it opens and updates itself as a refresh lands. One piece of new plumbing: the paperless-ngx version, read from the `x-version` header on the request the app already makes to negotiate the API version.

**Tech Stack:** Swift 6, swift-composable-architecture, swift-dependencies, swift-sharing, swift-snapshot-testing, Swift Testing, Tuist, mise.

**Spec:** `docs/superpowers/specs/2026-09-06-server-details-design.md`

## Global Constraints

- **Existence, never values, for anything secret.** The screen reports that a token exists and which custom headers are set; it never renders a token or a header value. A screenshot of this screen must leak nothing.
- **A value never fetched renders as unknown, never as `0`.** "0 tags" and "never asked" are different facts and the screen must distinguish them.
- **A failed refresh never clears a cached value and never replaces the screen.**
- **Read-only.** No control on this screen changes anything on the server.
- **Not permission-gated.** The screen reports what an account can do; hiding it from a restricted account would defeat its purpose. Missing data renders as missing.
- Never write `///` or `/** */` doc comments — only `//`, and only where a reader would otherwise wonder why the code is as it is. See AGENTS.md.
- Each module owns its strings: new user-facing text goes in `Modules/ServersFeature/Resources/Localizable.xcstrings`, in both `en` and `de`, `"extractionState": "manual"`, keys sorted alphabetically.
- Run `mise run ci:lint` before every commit; it must exit 0.
- Tests need the dev instance and an uncached build: `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` and always pass `--no-selective-testing`. `localhost` does not route to it from this machine.

---

### Task 1: Capture the paperless-ngx version

**Files:**
- Modify: `Modules/ApiInterface/Shared/` — the file declaring `.apiVersion(_ server:)`, adding a sibling key
- Modify: `Modules/ApiImplementation/ApiVersion/ApiVersionRepository.swift`
- Modify: `Modules/ApiImplementation/ApiVersion/NegotiateApiVersionUseCase.swift`
- Test: `Modules/ApiImplementationTests/ApiVersion/` — the existing negotiate tests

**Interfaces:**
- Produces: `SharedKey` `.paperlessVersion(_ server: Server)` holding `String?`; `ApiVersionRepository.getServerVersions(server:)` returning both versions.

- [ ] **Step 1: Find the existing key and the probe**

Read `Modules/ApiImplementation/ApiVersion/ApiVersionRepository.swift`. Its `getAdvertisedApiVersion(server:)` sends one request to `/api/ui_settings/` and reads the `X-Api-Version` response header. Its comment explains two constraints that still apply and must not be broken: the probe has to hit an endpoint that authenticates, because `ApiVersionMiddleware` only sets the header for authenticated users; and it must not name a version, because a rejected guess answers 406 with no header at all.

Then find where `.apiVersion(_ server:)` is declared in `Modules/ApiInterface` and read its neighbours — the new key goes beside it in the same shape.

- [ ] **Step 2: Add the shared key**

Following the shape of `.apiVersion`, add:

```swift
    static func paperlessVersion(_ server: Server) -> Self {
        .fileStorage(.serverScoped(server, "paperless-version"))
    }
```

Use whatever the neighbouring keys actually use for their storage and naming — read them first and match exactly rather than copying the line above verbatim if it does not fit.

- [ ] **Step 3: Return both versions from the one probe**

`x-version` (the paperless-ngx version, e.g. `3.0.5`) arrives on the same response as `x-api-version`. Replace the repository's single-value closure with one returning both:

```swift
public struct ServerVersions: Equatable, Sendable {

    public let apiVersion: Int?

    public let paperlessVersion: String?

    public init(apiVersion: Int?, paperlessVersion: String?) {
        self.apiVersion = apiVersion
        self.paperlessVersion = paperlessVersion
    }
}
```

and in the live implementation read both headers off the same `HTTPURLResponse`:

```swift
        guard let httpResponse = response.response as? HTTPURLResponse else {
            return ServerVersions(apiVersion: nil, paperlessVersion: nil)
        }
        return ServerVersions(
            apiVersion: httpResponse.value(forHTTPHeaderField: "X-Api-Version").flatMap(Int.init),
            paperlessVersion: httpResponse.value(forHTTPHeaderField: "X-Version")
        )
```

Note the change from the current code: a response that arrives without the API version header is no longer indistinguishable from one that is not an `HTTPURLResponse`. Both still yield a nil API version, so `ApiVersion.negotiated(from:)` behaves exactly as before.

Update `previewValue` and `testValue` to return a `ServerVersions`.

- [ ] **Step 4: Write both keys**

In `NegotiateApiVersionUseCase`, keep the existing negotiation and add the second write:

```swift
        @Shared(.apiVersion(server))
        var apiVersion: Int?

        @Shared(.paperlessVersion(server))
        var paperlessVersion: String?

        let versions = try await repository.getServerVersions(server: server)
        let negotiated = try ApiVersion.negotiated(from: versions.apiVersion)

        $apiVersion.withLock { $0 = negotiated }
        // Written even when nil: a server that stops sending the header should stop reporting a
        // version rather than keep showing the last one it sent.
        $paperlessVersion.withLock { $0 = versions.paperlessVersion }

        return negotiated
```

- [ ] **Step 5: Write the tests**

Add to the existing negotiate tests. Read them first for how they stub the repository.

```swift
    @Test
    func negotiateStoresBothVersions() async throws {
        let server = Server.testValue()

        @Shared(.apiVersion(server)) var apiVersion: Int?
        @Shared(.paperlessVersion(server)) var paperlessVersion: String?

        try await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in
                ServerVersions(apiVersion: ApiVersion.clientMaximum, paperlessVersion: "3.0.5")
            }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server)
        }

        #expect(apiVersion == ApiVersion.clientMaximum)
        #expect(paperlessVersion == "3.0.5")
    }

    // A server that sends no X-Version must leave the key nil rather than keeping a stale value,
    // so the screen can say "unknown" instead of reporting a version that is no longer true.
    @Test
    func negotiateClearsThePaperlessVersionWhenTheHeaderIsAbsent() async throws {
        let server = Server.testValue()

        @Shared(.paperlessVersion(server)) var paperlessVersion: String?
        $paperlessVersion.withLock { $0 = "3.0.5" }

        try await withDependencies {
            $0.apiVersionRepository.getServerVersions = { _ in
                ServerVersions(apiVersion: ApiVersion.clientMaximum, paperlessVersion: nil)
            }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server)
        }

        #expect(paperlessVersion == nil)
    }
```

- [ ] **Step 6: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: all pass, lint exits 0. Every existing negotiate test must still pass — the negotiation itself is unchanged and their passing is the evidence.

- [ ] **Step 7: Commit**

```bash
git add Modules/ApiInterface Modules/ApiImplementation Modules/ApiImplementationTests
git commit -m "feat: capture the paperless-ngx version alongside the api version"
```

---

### Task 2: Group permissions by type

**Files:**
- Create: `Modules/ApiInterface/Permissions/PermissionSummary.swift`
- Test: `Modules/ApiInterfaceTests/Permissions/PermissionSummaryTests.swift`

**Interfaces:**
- Consumes: `Permission` (a `String`-raw-valued enum, e.g. `.addDocumentType = "add_documenttype"`).
- Produces: `PermissionSummary.grouped(_ permissions: [Permission]) -> [PermissionSummary]`, each with `type: String` and `actions: [String]`, sorted by `type`.

166 codenames is a wall nobody reads. `Tag — view, add` across the types answers the question actually being asked.

- [ ] **Step 1: Write the failing test**

```swift
@testable import ApiInterface

import Testing

@Suite
struct PermissionSummaryTests {

    @Test
    func groupsByTypeAndSortsByTypeName() {
        let summaries = PermissionSummary.grouped([
            .viewTag,
            .addTag,
            .viewCorrespondent,
        ])

        #expect(summaries.map(\.type) == ["correspondent", "tag"])
        #expect(summaries[0].actions == ["view"])
        // Sorted so the same set always reads the same way, rather than in enum declaration order.
        #expect(summaries[1].actions == ["add", "view"])
    }

    // The raw value is the wire format and splits at the FIRST underscore only: add_documenttype is
    // one word, but global_statistics would split into "global" + "statistics" if the split ran
    // from the right.
    @Test
    func splitsAtTheFirstUnderscoreOnly() {
        let summaries = PermissionSummary.grouped([.addDocumentType, .changeCustomfield])

        #expect(summaries.map(\.type) == ["customfield", "documenttype"])
    }

    @Test
    func emptyInputProducesNoSummaries() {
        #expect(PermissionSummary.grouped([]).isEmpty)
    }
}
```

- [ ] **Step 2: Run it to verify it fails**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
```
Expected: FAIL — `PermissionSummary` does not exist.

- [ ] **Step 3: Implement it**

```swift
import Foundation

// A permission codename is <action>_<type>, and the type may itself contain no separator -
// add_documenttype is one word. Splitting at the first underscore is therefore the whole rule.
public struct PermissionSummary: Equatable, Sendable {

    public let actions: [String]

    public let type: String

    public static func grouped(_ permissions: [Permission]) -> [PermissionSummary] {
        var actionsByType: [String: [String]] = [:]

        for permission in permissions {
            let parts = permission.rawValue.split(separator: "_", maxSplits: 1)
            guard parts.count == 2 else {
                continue
            }
            actionsByType[String(parts[1]), default: []].append(String(parts[0]))
        }

        return actionsByType
            .map { PermissionSummary(actions: $0.value.sorted(), type: $0.key) }
            .sorted { $0.type < $1.type }
    }
}
```

- [ ] **Step 4: Run the tests**

Same command as Step 2. Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/Permissions/PermissionSummary.swift Modules/ApiInterfaceTests
git commit -m "feat: group permission codenames by the type they apply to"
```

---

### Task 3: The reducer and the route to it

**Files:**
- Create: `Modules/ServersFeature/ServerDetail/ServerDetailReducer.swift`
- Create: `Modules/ServersFeature/ServerDetail/ServerDetailReducer+TestValue.swift`
- Modify: `Modules/ServersFeature/ServerRow/ServerRowReducer.swift` (Delegate, View action)
- Modify: `Modules/ServersFeature/ServerRow/ServerRowView.swift` (third swipe action)
- Modify: `Modules/ServersFeature/ServerList/ServerListReducer.swift` (Destination, delegate handling)
- Modify: `Modules/ServersFeature/ServerList/ServerListView.swift` (navigationDestination)
- Test: `Modules/ServersFeatureTests/ServerDetail/ServerDetailReducerTests.swift`

**Interfaces:**
- Consumes: `.paperlessVersion(server)` from Task 1.
- Produces: `ServerDetailReducer` with `State(server:)`, and `ServerRowReducer.Action.Delegate.showDetails`.

- [ ] **Step 1: Read what the caches and the statistics give you**

`GetStatisticsUseCase` writes only `.inboxDocumentCount` and `.inboxTags` to shared keys and **discards the rest of its payload**, so `documentsTotal`, `characterCount`, `currentAsn`, `tagCount`, `correspondentCount`, `documentTypeCount`, `storagePathCount` and `documentFileTypeCounts` are not cached anywhere. This reducer holds the returned `GetStatisticsOutput` in its own State — adding a shared key for a value only this screen wants would be over-engineering.

Everything else is already cached per server: `.apiVersion`, `.paperlessVersion`, `.currentUser`, `.permissions`, `.tags`, `.correspondents`, `.documentTypes`, `.storagePaths`, `.customFields`, `.savedViews`, `.users`, `.groups`, `.favorites`.

- [ ] **Step 2: Write the State**

```swift
    @ObservableState
    public struct State: Equatable {

        let server: Server

        // Held rather than snapshotted so the screen updates itself as the refresh lands: a nested
        // @Shared inside @ObservableState notifies observation.
        @Shared var apiVersion: Int?
        @Shared var correspondents: IdentifiedArrayOf<Correspondent>
        @Shared var currentUser: User?
        @Shared var customFields: IdentifiedArrayOf<CustomField>
        @Shared var documentTypes: IdentifiedArrayOf<DocumentType>
        @Shared var groups: IdentifiedArrayOf<Group>
        @Shared var paperlessVersion: String?
        @Shared var permissions: [Permission]?
        @Shared var savedViews: IdentifiedArrayOf<SavedView>
        @Shared var storagePaths: IdentifiedArrayOf<StoragePath>
        @Shared var tags: IdentifiedArrayOf<Tag>
        @Shared var users: IdentifiedArrayOf<User>

        // Not cached anywhere: GetStatisticsUseCase keeps only the inbox counts.
        var statistics: GetStatisticsOutput?

        var isRefreshing = false

        // A failed refresh leaves every cached value alone and says so quietly. It must never
        // replace the screen - the last known numbers are still the best answer available.
        var refreshFailed = false

        public init(server: Server) {
            self.server = server
            _apiVersion = Shared(wrappedValue: nil, .apiVersion(server))
            _paperlessVersion = Shared(wrappedValue: nil, .paperlessVersion(server))
            _currentUser = Shared(wrappedValue: nil, .currentUser(server))
            _permissions = Shared(wrappedValue: nil, .permissions(server))
            _correspondents = Shared(wrappedValue: [], .correspondents(server))
            _customFields = Shared(wrappedValue: [], .customFields(server))
            _documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            _groups = Shared(wrappedValue: [], .groups(server))
            _savedViews = Shared(wrappedValue: [], .savedViews(server))
            _storagePaths = Shared(wrappedValue: [], .storagePaths(server))
            _tags = Shared(wrappedValue: [], .tags(server))
            _users = Shared(wrappedValue: [], .users(server))
        }
    }
```

Read the actual element types and shared-key signatures before writing this — use whatever the existing keys declare rather than the names above if they differ.

- [ ] **Step 3: Write the reducer body**

`onAppear` refreshes; the refresh both updates the caches and returns the statistics. `updateCache` already tolerates each endpoint failing separately, so an account without `view_user` leaves `users` empty while everything else fills in.

```swift
            case .view(.onAppear):
                state.isRefreshing = true
                state.refreshFailed = false
                return .runRefresh(server: state.server)
            case let .statisticsLoaded(statistics):
                state.statistics = statistics
                state.isRefreshing = false
                return .none
            case .refreshFailed:
                // Cached values stay exactly as they are.
                state.isRefreshing = false
                state.refreshFailed = true
                return .none
```

with the effect calling `updateCache(server)` then `getStatistics(server)`, sending `.statisticsLoaded` on success and `.refreshFailed` on any throw.

- [ ] **Step 4: Add the route**

In `ServerRowReducer`, add `case showDetails` to `Delegate` and a `detailsButtonTapped` view action returning `.send(.delegate(.showDetails))`, exactly as `editButtonTapped` returns `.send(.delegate(.editServer))`.

In `ServerRowView.swipeActions()`, add a third button **before** Edit so the destructive Delete stays outermost:

```swift
        Button {
            send(.detailsButtonTapped)
        } label: {
            Image(systemName: "info.circle")
        }
        .accessibilityLabel(.serverDetails)
        .tint(.m3Secondary)
```

In `ServerListReducer`, add `case serverDetail(ServerDetailReducer)` to `Destination` and handle the new delegate beside the existing `.editServer` case:

```swift
                case .showDetails:
                    guard let server = state.servers[id: id]?.server else {
                        return .none
                    }
                    state.destination = .serverDetail(ServerDetailReducer.State(server: server))
                    return .none
```

In `ServerListView`, present it with `navigationDestination`, matching how `diagnosticsList` is already presented — not the sheet that `serverForm` uses. Edit's sheet is for a form the user submits; this is a screen they drill into and leave.

- [ ] **Step 5: Write the reducer tests**

```swift
    @Test
    func onAppearRefreshesAndKeepsTheStatistics() async {
        let store = TestStore(initialState: ServerDetailReducer.State(server: .testValue())) {
            ServerDetailReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in }
            $0.getStatistics.execute = { _ in .testValue() }
        }

        await store.send(.view(.onAppear)) {
            $0.isRefreshing = true
        }
        await store.receive(\.statisticsLoaded) {
            $0.statistics = .testValue()
            $0.isRefreshing = false
        }
    }

    // The decision this test defends: a failed refresh must cost nothing. The screen keeps the last
    // known numbers rather than emptying or replacing itself.
    @Test
    func aFailedRefreshKeepsTheCachedValues() async {
        let server = Server.testValue()

        @Shared(.tags(server)) var tags: IdentifiedArrayOf<Tag>
        $tags.withLock { $0 = [.testValue()] }

        let store = TestStore(initialState: ServerDetailReducer.State(server: server)) {
            ServerDetailReducer()
        } withDependencies: {
            $0.updateCache.execute = { _ in throw TestError.someError }
        }

        await store.send(.view(.onAppear)) {
            $0.isRefreshing = true
        }
        await store.receive(\.refreshFailed) {
            $0.isRefreshing = false
            $0.refreshFailed = true
        }

        #expect(store.state.tags.count == 1)
    }
```

Use whatever error type and `.testValue()` fixtures the neighbouring ServersFeature tests already use.

- [ ] **Step 6: Run the tests**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test ServersFeature -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: pass, lint 0. No existing ServersFeature snapshot may change — adding a swipe action alters no rendered body, and this harness renders no swipe tray. If one changes, stop and report it.

- [ ] **Step 7: Commit**

```bash
git add Modules/ServersFeature Modules/ServersFeatureTests
git commit -m "feat: add the server detail reducer and the route to it"
```

---

### Task 4: The view

**Files:**
- Create: `Modules/ServersFeature/ServerDetail/ServerDetailView.swift`
- Modify: `Modules/ServersFeature/Resources/Localizable.xcstrings`
- Test: `Modules/ServersFeatureTests/ServerDetail/ServerDetailViewTests.swift`

**Interfaces:**
- Consumes: `ServerDetailReducer` from Task 3, `PermissionSummary.grouped(_:)` from Task 2.

- [ ] **Step 1: Read a neighbouring list-shaped screen**

Read `Modules/SettingsFeature/SettingList/SettingListView.swift` for how this app builds a sectioned list — row backgrounds use `Color.m3SurfaceContainer`, and sections carry their own headers. Match it; do not invent a second idiom.

- [ ] **Step 2: Build the five sections**

| Section | Contents |
|---|---|
| Server | alias, URL, id, auth mode, custom header names with masked values |
| Versions | paperless-ngx, API |
| User | username, superuser, staff, groups |
| Permissions | `PermissionSummary.grouped(...)`, one row per type |
| Content | documents, inbox, characters, current ASN, file types; counts for tags, correspondents, document types, storage paths, custom fields, saved views, users, groups, favourites |

Two rules the whole screen turns on:

**Never render a secret.** The auth mode row says `token` or `remote-user` and nothing more — derive it as `UpdateCacheUseCase` does, from whether a token exists. Custom headers render their **name** with a fixed mask for the value:

```swift
                ForEach(store.server.headers) { header in
                    LabeledContent(header.name) {
                        Text(verbatim: "••••")
                    }
                }
```

**Never print `0` for something never fetched.** A count whose cache has never been filled is unknown, not zero:

```swift
    // "0 tags" and "we have never asked" are different facts, and telling them apart is the point
    // of this screen. statistics is nil until the first refresh returns.
    private func count(_ value: Int?) -> String {
        value.map(String.init) ?? String(localized: .unknownValue)
    }
```

Cache-derived counts (custom fields, saved views, users, groups, favourites) come from the shared arrays and are labelled as cached; the rest come from `store.statistics`, which is `nil` until a refresh lands.

- [ ] **Step 3: Add the strings**

Add every new key to `Modules/ServersFeature/Resources/Localizable.xcstrings` in both `en` and `de`, `"extractionState": "manual"`, keys sorted alphabetically. Append rather than rewriting the file — a `json.dump` of the whole document reformats every existing entry and buries the change.

- [ ] **Step 4: Write the secret test**

This is the guard on the masking decision, and it must fail if any future field prints a raw value.

Two headers with the **same name and different values** must render to the **same image**. If any
future field prints a raw value, the two images diverge and this fails. `String(describing:)` on a
SwiftUI body does not reliably surface rendered text, so the image is the honest instrument here —
and it is the one this repo already has.

```swift
    // The masking decision is only as good as something that fails when a field prints a raw value,
    // and this screen will accumulate fields. Two different secrets must be indistinguishable on
    // screen; if one ever reaches the output, these two images stop matching.
    @Test
    func twoDifferentSecretsRenderIdentically() throws {
        func image(headerValue: String) throws -> Data {
            let server = Server.testValue(
                headers: [HTTPHeader(name: "X-Api-Key", value: headerValue)]
            )
            let view = ServerDetailView(
                store: Store(initialState: ServerDetailReducer.State(server: server)) {
                    ServerDetailReducer()
                }
            )
            let png = try #require(
                ImageRenderer(content: view.frame(width: 390, height: 844)).uiImage?.pngData()
            )
            return png
        }

        #expect(try image(headerValue: "SECRET-ONE") == (try image(headerValue: "SECRET-TWO")))
    }
```

Read the existing view tests first — if `ImageRenderer` is not how this repo rasterises a view
outside `assertSnapshot`, use whatever they use. The assertion is what matters: same header name,
different values, identical output. Report which mechanism you used.

- [ ] **Step 5: Add the three snapshots**

Read the existing ServersFeature view tests for the fixture idiom first. Then add:

- **fully populated** — every cache seeded, statistics present, a superuser
- **never fetched** — no cache seeded at all, statistics nil: every count reads unknown, and this is the case that catches a screen printing `0`
- **restricted** — permissions seeded without `view_user`, users and groups empty, everything else present

Seed each cache explicitly. All three sit in the rendered list body, which this harness does render, so unlike the toolbar chrome of earlier projects these images genuinely discriminate.

- [ ] **Step 6: Verify the snapshots discriminate**

```bash
md5 -q Snapshots/ServersFeatureTests/ServerDetailViewTests/*.png | sort | uniq -d
```
Expected: prints nothing. A reference byte-identical to a sibling asserts nothing — an earlier project shipped one and had to delete it. If two match, the fixtures do not differ in anything the screen renders; fix the fixtures, do not delete the assertion.

- [ ] **Step 7: Run everything**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test ServersFeature -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing
mise run ci:lint
```
Expected: all pass, lint 0. New snapshot cases record on the first run and fail, then pass on the second; that is expected, not a problem to debug.

- [ ] **Step 8: Commit**

```bash
git add Modules/ServersFeature Modules/ServersFeatureTests Snapshots/ServersFeatureTests
git commit -m "feat: show everything the app knows about a server"
```
