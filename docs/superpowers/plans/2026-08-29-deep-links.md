# Deep Links Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Open a document in Less Paper from a `lesspaper://` or `atlp://` link, and offer both link
formats from the document detail screen.

**Architecture:** A pure `DeepLink` value in `ApiInterface` parses and builds the URL, matching the
path from the end so a server's own path prefix falls out of the match. `AppReducer` turns an
incoming URL into a pending link, switches the selected server if the link names another one, and
applies the link once `MainReducer.State` exists for that server. `DocumentListReducer` does the
opening, because it owns the `Shared<Document>` that `DocumentDetailReducer.State` requires.

**Tech Stack:** Swift 6.3, iOS 18, The Composable Architecture, swift-sharing, Swift Testing, Tuist.

**Spec:** `docs/superpowers/specs/2026-08-29-deep-links-design.md`

## Global Constraints

- **Comments are `//` only.** Never `///` or `/** */`, anywhere, including tests — see `AGENTS.md`.
  Comment only what a future reader would otherwise stop and wonder about.
- **Branch:** `feat/deep-links`, already checked out and based on `main` (`f9f6da5`).
- **After creating or deleting any file, regenerate the project** — Tuist globs sources:
  `TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 mise exec -- tuist generate --no-open`
- **Run tests with xcodebuild** (verified working in this sandbox):
  `xcodebuild -workspace LessPaper.xcworkspace -scheme <Scheme> -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test`
  Swift Testing output appears as `✔ Test <name> passed` / `✘ … recorded an issue`.
- **Switching git branches needs credentials** (git-lfs fetches capture blobs):
  `mise exec -- fnox exec -- git -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=$GH_TOKEN"; };f' switch <branch>`
- **New user-facing strings go in `Shared/Framework/Resources/Localizable.xcstrings`** with both `en`
  and `de`, `"extractionState": "manual"`, and `"state": "translated"`. Xcode generates the
  `.someKey` accessor from the catalog; there is no Swift file to edit.
- **Scheme constants:** emit `lesspaper`, also parse `atlp`. `atlp` stays registered for the OIDC
  callback and is never advertised.

---

### Task 1: The `DeepLink` value

**Files:**
- Create: `Modules/ApiInterface/DeepLink/DeepLink.swift`
- Test: `Modules/ApiInterfaceTests/DeepLink/DeepLinkTests.swift`

**Interfaces:**
- Consumes: `Server` and `Document.Id` (`Tagged<Document, Int>`), both already in `ApiInterface`.
- Produces:
  - `DeepLink.Route.documentDetail(Document.Id)`
  - `DeepLink.init?(url: URL)`
  - `DeepLink.resolves(to server: Server) -> Bool`
  - `DeepLink.appURL(server: Server, route: Route) -> URL?`
  - `DeepLink.webURL(server: Server, route: Route) -> URL?`
  - `DeepLink.route: Route`, `DeepLink.host: String`

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/DeepLink/DeepLinkTests.swift`:

```swift
import ApiInterface
import Foundation
import Testing

@Suite
struct DeepLinkTests {

    @Test
    func parsesTheAppScheme() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com/documents/42/details")!))

        #expect(link.host == "paperless.example.com")
        #expect(link.port == nil)
        #expect(link.prefix == "")
        #expect(link.route == .documentDetail(42))
    }

    // Every link the shipping app ever wrote uses atlp, and those outlive the codebase that made
    // them: someone's note from a year ago has to keep working.
    @Test
    func parsesTheLegacyScheme() throws {
        let link = try #require(DeepLink(url: URL(string: "atlp://paperless.example.com/documents/42/details")!))

        #expect(link.route == .documentDetail(42))
    }

    @Test
    func rejectsAnyOtherScheme() {
        #expect(DeepLink(url: URL(string: "https://paperless.example.com/documents/42/details")!) == nil)
    }

    // The server's own path comes back as the prefix rather than having to be subtracted from the
    // match. The old app whole-matched the path and so never parsed a link to a server like this.
    @Test
    func keepsTheServersPathPrefix() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/documents/42/details")!))

        #expect(link.prefix == "/paperless")
        #expect(link.route == .documentDetail(42))
    }

    @Test
    func keepsThePort() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com:8200/documents/42/details")!))

        #expect(link.port == 8200)
    }

    @Test
    func toleratesATrailingSlash() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/documents/42/details/")!))

        #expect(link.route == .documentDetail(42))
    }

    @Test
    func rejectsANonNumericId() {
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/documents/abc/details")!) == nil)
    }

    @Test
    func rejectsAPathThatIsNotADocumentDetail() {
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/documents/42")!) == nil)
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/tags/42/details")!) == nil)
        #expect(DeepLink(url: URL(string: "lesspaper://example.com/oidc-callback")!) == nil)
    }

    @Test
    func resolvesAgainstTheServerItNames() throws {
        let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com/documents/42/details")!))

        #expect(link.resolves(to: server))
    }

    @Test
    func doesNotResolveAcrossHostsPortsOrPrefixes() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com:8200/paperless/documents/42/details")!))

        #expect(link.resolves(to: .testValue(url: URL(string: "https://elsewhere.example.com:8200/paperless")!)) == false)
        #expect(link.resolves(to: .testValue(url: URL(string: "https://paperless.example.com:9000/paperless")!)) == false)
        #expect(link.resolves(to: .testValue(url: URL(string: "https://paperless.example.com:8200/other")!)) == false)
        #expect(link.resolves(to: .testValue(url: URL(string: "https://paperless.example.com:8200/paperless")!)))
    }

    // A trailing slash on the configured server URL is the user's typing, not a different server.
    @Test
    func resolvesRegardlessOfATrailingSlashOnTheServer() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/documents/42/details")!))

        #expect(link.resolves(to: .testValue(url: URL(string: "https://example.com/paperless/")!)))
    }

    // Build and parse are one type so the two formats cannot drift: a link the app writes but
    // cannot read is invisible until someone taps one.
    @Test
    func roundTripsThroughTheAppURL() throws {
        for server in [
            Server.testValue(url: URL(string: "https://paperless.example.com")!),
            Server.testValue(url: URL(string: "https://example.com/paperless")!),
            Server.testValue(url: URL(string: "http://example.com:8200")!),
        ] {
            let url = try #require(DeepLink.appURL(server: server, route: .documentDetail(42)))
            let link = try #require(DeepLink(url: url))

            #expect(link.resolves(to: server))
            #expect(link.route == .documentDetail(42))
        }
    }

    @Test
    func appURLUsesTheAppScheme() throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let url = try #require(DeepLink.appURL(server: server, route: .documentDetail(42)))

        #expect(url.absoluteString == "lesspaper://example.com/paperless/documents/42/details")
    }

    @Test
    func webURLKeepsTheServersOwnScheme() throws {
        let server = Server.testValue(url: URL(string: "http://example.com:8200")!)
        let url = try #require(DeepLink.webURL(server: server, route: .documentDetail(42)))

        #expect(url.absoluteString == "http://example.com:8200/documents/42/details")
    }
}
```

- [ ] **Step 2: Regenerate and run the tests to verify they fail**

```bash
TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 mise exec -- tuist generate --no-open
xcodebuild -workspace LessPaper.xcworkspace -scheme ApiInterface \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|Test run with"
```

Expected: compile errors — `cannot find 'DeepLink' in scope`.

- [ ] **Step 3: Write the implementation**

Create `Modules/ApiInterface/DeepLink/DeepLink.swift`:

```swift
import Foundation

// A link into the app: which server it names, and what to open there.
//
// Parsing and building live in one type on purpose. Two functions in two modules drift the first
// time the path changes, and the failure - links the app writes but cannot read - is invisible
// until someone taps one.
public struct DeepLink: Equatable, Sendable {

    public enum Route: Equatable, Sendable {
        case documentDetail(Document.Id)
    }

    // What new links are written with. `atlp` is still parsed because the shipping app wrote it
    // and those links outlive the codebase that made them, but it is never advertised. It stays
    // registered for its other job, the OIDC callback.
    public static let scheme = "lesspaper"

    public static let legacyScheme = "atlp"

    public let host: String

    public let port: Int?

    // Whatever the path carries before the route, which is the server's own base path. Empty for a
    // server hosted at the root.
    public let prefix: String

    public let route: Route

    public init(
        host: String,
        port: Int? = nil,
        prefix: String = "",
        route: Route
    ) {
        self.host = host
        self.port = port
        self.prefix = prefix
        self.route = route
    }
}

public extension DeepLink {

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let scheme = components.scheme?.lowercased(),
              scheme == Self.scheme || scheme == Self.legacyScheme,
              let host = components.host,
              !host.isEmpty,
              let parsed = Self.parse(path: components.path)
        else {
            return nil
        }

        self.init(
            host: host,
            port: components.port,
            prefix: parsed.prefix,
            route: parsed.route
        )
    }

    func resolves(to server: Server) -> Bool {
        guard let components = URLComponents(url: server.url, resolvingAgainstBaseURL: false),
              let serverHost = components.host
        else {
            return false
        }

        return serverHost.lowercased() == host.lowercased()
            && components.port == port
            && Self.normalized(path: components.path) == prefix
    }

    static func appURL(server: Server, route: Route) -> URL? {
        url(scheme: Self.scheme, server: server, route: route)
    }

    static func webURL(server: Server, route: Route) -> URL? {
        url(scheme: server.url.scheme ?? "https", server: server, route: route)
    }
}

private extension DeepLink {

    // Matched from the end, which is what lets a server hosted under a subpath work without the
    // parser knowing any server exists: the prefix is whatever the match leaves behind.
    static func parse(path: String) -> (prefix: String, route: Route)? {
        var segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        guard segments.count >= 3,
              segments.removeLast() == "details",
              let id = Int(segments.removeLast()),
              segments.removeLast() == "documents"
        else {
            return nil
        }

        let prefix = segments.isEmpty ? "" : "/" + segments.joined(separator: "/")

        return (prefix, .documentDetail(Document.Id(rawValue: id)))
    }

    static func normalized(path: String) -> String {
        var path = path

        while path.hasSuffix("/") {
            path.removeLast()
        }

        return path
    }

    static func url(scheme: String, server: Server, route: Route) -> URL? {
        guard var components = URLComponents(url: server.url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        switch route {
        case let .documentDetail(id):
            components.path = normalized(path: components.path) + "/documents/\(id.rawValue)/details"
        }

        components.scheme = scheme

        return components.url
    }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

```bash
xcodebuild -workspace LessPaper.xcworkspace -scheme ApiInterface \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|✘|Test run with"
```

Expected: `Test run with NNN tests in NN suites passed`.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/DeepLink Modules/ApiInterfaceTests/DeepLink
git commit -m "feat: a DeepLink that parses and writes document links"
```

---

### Task 2: Opening a document from the list

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentList/DocumentListReducer+DeepLink.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListDeepLinkTests.swift`

**Interfaces:**
- Consumes: nothing from Task 1.
- Produces: `DocumentListReducer.Action.openDocument(Document.Id)` — public, sent by `AppReducer` in
  Task 3. Also `DocumentListReducer.Action.documentFetched(Document)`, internal to this task.

**Context you need:** `State.documents` is `IdentifiedArrayOf<DocumentRowReducer.State>` keyed by
`Document.Id`, and each row holds `@Shared var document: Document`, so `row.$document` is the
`Shared<Document>` that `DocumentDetailReducer.State(document:server:)` requires. `State.path` is a
`StackState<Path.State>` whose `.documentDetail` case carries that state. `State.isSplitLayout` is
true on iPad's split layout, where the existing row-tap path clears the stack before appending.

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentList/DocumentListDeepLinkTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentListDeepLinkTests {

    // The document is on screen already: reuse the row's shared value rather than fetching a second
    // copy, or an edit made through the link never reaches the row behind it.
    @Test
    func openDocument_reusesALoadedDocument() async {
        let server = Server.testValue()
        let document = Document.testValue(id: 42)
        let store = TestStore(
            initialState: DocumentListReducer.State(
                documents: [DocumentRowReducer.State(document: Shared(value: document), server: server)],
                server: server
            ),
            reducer: { DocumentListReducer() },
            withDependencies: {
                $0.getDocument.execute = { _, _ in
                    Issue.record("a loaded document must not be fetched again")
                    return .testValue()
                }
            }
        )

        await store.send(.openDocument(42)) {
            $0.path.append(.documentDetail(DocumentDetailReducer.State(
                document: Shared(value: document),
                server: server
            )))
        }
    }

    @Test
    func openDocument_fetchesOneTheListDoesNotHave() async {
        let server = Server.testValue()
        let document = Document.testValue(id: 7)
        let store = TestStore(
            initialState: DocumentListReducer.State(server: server),
            reducer: { DocumentListReducer() },
            withDependencies: {
                $0.getDocument.execute = { id, _ in
                    #expect(id == 7)
                    return document
                }
            }
        )

        await store.send(.openDocument(7))
        await store.receive(\.documentFetched) {
            $0.path.append(.documentDetail(DocumentDetailReducer.State(
                document: Shared(value: document),
                server: server
            )))
        }
    }

    // Tapping the same link twice is ordinary. Two identical screens stacked on each other is
    // something the user then has to unwind by hand.
    @Test
    func openDocument_popsToADocumentAlreadyOnThePath() async {
        let server = Server.testValue()
        let document = Document.testValue(id: 42)
        let other = Document.testValue(id: 43)
        var path = StackState<DocumentListReducer.Path.State>()
        path.append(.documentDetail(DocumentDetailReducer.State(document: Shared(value: document), server: server)))
        path.append(.documentDetail(DocumentDetailReducer.State(document: Shared(value: other), server: server)))

        let store = TestStore(
            initialState: DocumentListReducer.State(
                documents: [DocumentRowReducer.State(document: Shared(value: document), server: server)],
                path: path,
                server: server
            ),
            reducer: { DocumentListReducer() }
        )

        await store.send(.openDocument(42)) {
            $0.path.removeLast()
        }
    }

    @Test
    func openDocument_reportsAFetchFailure() async {
        let store = TestStore(
            initialState: DocumentListReducer.State(server: .testValue()),
            reducer: { DocumentListReducer() },
            withDependencies: {
                $0.getDocument.execute = { _, _ in throw TestError.someError }
            }
        )
        store.exhaustivity = .off

        await store.send(.openDocument(7))
        await store.receive(\.error)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

```bash
TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 mise exec -- tuist generate --no-open
xcodebuild -workspace LessPaper.xcworkspace -scheme DocumentsFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|Test run with"
```

Expected: compile errors — `type 'DocumentListReducer.Action' has no member 'openDocument'`.

- [ ] **Step 3: Add the two actions**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, add to `enum Action`, in
alphabetical order with its neighbours:

```swift
        case documentFetched(Document)
```

```swift
        case openDocument(Document.Id)
```

- [ ] **Step 4: Add the shared presentation helper**

Create `Modules/DocumentsFeature/DocumentList/DocumentListReducer+DeepLink.swift`:

```swift
import ApiInterface
import ComposableArchitecture

extension DocumentListReducer.State {

    // One place decides what showing a document detail means, so a deep link and a tapped row
    // cannot disagree about it.
    mutating func presentDocumentDetail(_ document: Shared<Document>) {
        // Already open: pop back to it. Tapping the same link twice is ordinary, and two identical
        // screens stacked on each other is something the user has to unwind by hand.
        for elementId in path.ids {
            guard case let .documentDetail(detail) = path[id: elementId],
                  detail.document.id == document.wrappedValue.id
            else {
                continue
            }

            path.pop(to: elementId)
            return
        }

        // A detail column shows one document: picking a second replaces the first rather than
        // stacking behind it, which is what appending would do and what makes three taps leave
        // three screens deep on iPad.
        if isSplitLayout {
            path.removeAll()
        }

        path.append(.documentDetail(DocumentDetailReducer.State(
            document: document,
            server: server
        )))
    }
}

extension Effect where Action == DocumentListReducer.Action {

    static func runGetDocument(id: Document.Id, server: Server) -> Self {
        @Dependency(\.getDocument.execute)
        var getDocument

        return .run { send in
            await send(.documentFetched(try await getDocument(id, server)))
        } catch: { error, send in
            await send(.error(error))
        }
    }
}
```

- [ ] **Step 5: Handle the actions and reuse the helper for a tapped row**

In `DocumentListReducer.swift`, add these cases to the `Reduce` switch:

```swift
            case let .documentFetched(document):
                state.presentDocumentDetail(Shared(value: document))
                return .none
```

```swift
            case let .openDocument(id):
                // A document the list already holds keeps its shared value: a copy would let an
                // edit made here go unseen by the row behind it.
                if let document = state.documents[id: id]?.$document {
                    state.presentDocumentDetail(document)
                    return .none
                }
                return .runGetDocument(id: id, server: state.server)
```

Then replace the body of the existing `case .presentDocumentDetail(document)` branch (inside
`case let .documents(.element(id:action: .delegate(delegateAction)))`) with the helper:

```swift
                case let .presentDocumentDetail(document):
                    state.presentDocumentDetail(document)
                    return .none
```

Both new cases are handled above, so the catch-all at
`Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift:519`
(`case .binding, .delegate, .destination, .documentImport, .documentSelection, .documents, .path:`)
stays exactly as it is. If the compiler reports the switch is not exhaustive, a case above was
mistyped — fix that rather than widening the catch-all.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
xcodebuild -workspace LessPaper.xcworkspace -scheme DocumentsFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|✘|Test run with"
```

Expected: `Test run with NNN tests in NN suites passed`, including the four new tests. The existing
document-list tests must pass unchanged — the row-tap path now goes through the helper, and the
pop-to-existing behaviour is new for it too.

- [ ] **Step 7: Commit**

```bash
git add Modules/DocumentsFeature/DocumentList Modules/DocumentsFeatureTests/DocumentList
git commit -m "feat: open a document by id, from the list or a fetch"
```

---

### Task 3: Routing an incoming URL

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift`
- Create: `Modules/AppFeature/DeepLinkError.swift`
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: `Modules/AppFeatureTests/AppReducerDeepLinkTests.swift`

**Interfaces:**
- Consumes: `DeepLink` from Task 1; `DocumentListReducer.Action.openDocument(Document.Id)` from
  Task 2.
- Produces: `AppReducer.Action.openURL(URL)`, sent by `AppView` in Task 4.

**Context you need:** `AppReducer.State.main` is `MainReducer.State?`, rebuilt wholesale by
`selectedServerChanged`. That action arrives from `runSelectedServerObserver`, a publisher on the
main run loop watching `@Shared(.selectedServer)` — so setting the selection and pushing a document
cannot happen in one reduction. `MainReducer.State.selectedTab` is an `AppTab`, and `MainReducer`
already forwards `.documentList` actions.

- [ ] **Step 1: Add the localized string**

In `Shared/Framework/Resources/Localizable.xcstrings`, add this entry to the `"strings"` object,
keeping the file's alphabetical key order:

```json
    "deepLinkServerNotFound" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Kein Server für %@ eingerichtet"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "No server configured for %@"
          }
        }
      }
    },
```

- [ ] **Step 2: Write the failing tests**

Create `Modules/AppFeatureTests/AppReducerDeepLinkTests.swift`:

```swift
@testable import AppFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct AppReducerDeepLinkTests {

    // The link names the server that is already open: nothing to switch, so it applies at once.
    @Test
    func openURL_forTheSelectedServer_opensTheDocument() async {
        let server = Server.testValue(id: "1", url: URL(string: "https://paperless.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: server)),
            reducer: { AppReducer() }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://paperless.example.com/documents/42/details")!))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.documentList.openDocument)

        #expect(store.state.main?.selectedTab == .documents)
        #expect(store.state.pendingLink == nil)
    }

    // The link names another server. The selection changes, MainReducer.State is rebuilt for it,
    // and only then can the document be pushed - so the link has to wait rather than be dropped.
    @Test
    func openURL_forAnotherServer_waitsForTheSwitch() async {
        let current = Server.testValue(id: "1", url: URL(string: "https://one.example.com")!)
        let other = Server.testValue(id: "2", url: URL(string: "https://two.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [current, other]

        @Shared(.selectedServer)
        var selectedServer: Server? = current

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: current)),
            reducer: { AppReducer() }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://two.example.com/documents/42/details")!))

        #expect(store.state.pendingLink?.server.id == "2")
        #expect(selectedServer?.id == "2")

        // What the observer would deliver once the selection changed.
        await store.send(.selectedServerChanged(other))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.documentList.openDocument)

        #expect(store.state.pendingLink == nil)
    }

    // A URL can arrive before servers have loaded at all. Held, not dropped.
    @Test
    func openURL_beforeAServerIsSelected_waits() async {
        let server = Server.testValue(id: "1", url: URL(string: "https://paperless.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://paperless.example.com/documents/42/details")!))

        #expect(store.state.pendingLink?.server.id == "1")

        await store.send(.selectedServerChanged(server))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.documentList.openDocument)
    }

    @Test
    func openURL_forAnUnknownHost_toastsAndHoldsNothing() async {
        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [.testValue(url: URL(string: "https://paperless.example.com")!)]

        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.toastPresenter.present = { value in
                    toasts.withValue { $0.append(value) }
                }
            }
        )

        await store.send(.openURL(URL(string: "lesspaper://stranger.example.com/documents/42/details")!))
        await store.finish()

        #expect(store.state.pendingLink == nil)
        #expect(toasts.value.count == 1)
    }

    // atlp:// is also the OIDC callback scheme. That callback never reaches onOpenURL, but a URL
    // this app cannot read is not worth a toast either way - it says nothing the user can act on.
    @Test
    func openURL_thatIsNotADeepLink_isIgnored() async {
        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() }
        )

        await store.send(.openURL(URL(string: "atlp://oidc-callback?code=c0ff33")!))

        #expect(store.state.pendingLink == nil)
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 mise exec -- tuist generate --no-open
xcodebuild -workspace LessPaper.xcworkspace -scheme AppFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|Test run with"
```

Expected: compile errors — no member `openURL`, `applyPendingLink`, or `pendingLink`.

- [ ] **Step 4: Add the error type**

Create `Modules/AppFeature/DeepLinkError.swift`:

```swift
import Foundation

enum DeepLinkError: Error, Equatable {
    case serverNotFound(host: String)
}

extension DeepLinkError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case let .serverNotFound(host):
            String(localized: .deepLinkServerNotFound(host))
        }
    }
}
```

- [ ] **Step 5: Add the state, the actions and the routing**

In `Modules/AppFeature/AppReducer.swift`:

Add to `enum Action`, alphabetically:

```swift
        case applyPendingLink
```

```swift
        case openURL(URL)
```

Add the pending-link type above `AppReducer` (same file, after the imports):

```swift
// A link that has been resolved to a server but cannot be acted on yet, because the selected
// server has to change first and MainReducer.State is rebuilt asynchronously when it does. A URL
// arriving at cold start is the same shape, so both wait here rather than in two special cases.
struct PendingDeepLink: Equatable {

    let route: DeepLink.Route

    let server: Server
}
```

Add to `State`, alphabetically among the stored properties:

```swift
        var pendingLink: PendingDeepLink?
```

Add these cases to the `Reduce` switch:

```swift
            case .applyPendingLink:
                guard let pending = state.pendingLink,
                      state.main?.server.id == pending.server.id
                else {
                    return .none
                }
                state.pendingLink = nil
                switch pending.route {
                case let .documentDetail(id):
                    state.main?.selectedTab = .documents
                    return .send(.main(.documentList(.openDocument(id))))
```

```swift
            case let .openURL(url):
                guard let link = DeepLink(url: url) else {
                    return .none
                }

                @Shared(.servers)
                var servers

                guard let server = servers.first(where: { link.resolves(to: $0) }) else {
                    return .toast(DeepLinkError.serverNotFound(host: link.host))
                }

                state.pendingLink = PendingDeepLink(route: link.route, server: server)

                if state.main?.server.id == server.id {
                    return .send(.applyPendingLink)
                }

                @Shared(.selectedServer)
                var selectedServer

                $selectedServer.withLock { $0 = server }

                return .none
```

Extend the existing `selectedServerChanged` case so a waiting link is applied once `main` exists:

```swift
            case .selectedServerChanged(let server):
                if let server {
                    state.main = MainReducer.State(server: server)
                    let updateCache = Effect<Action>.runUpdateCache(server: server)
                    guard state.pendingLink != nil else {
                        return updateCache
                    }
                    return updateCache.merge(with: .send(.applyPendingLink))
                } else {
                    state.main = nil
                    state.serverList = ServerListReducer.State()
                    return .none
                }
```

Add `import Components` at the top of the file if `.toast` does not resolve — it lives in
`Modules/Components/Extensions/Effect+Toast.swift`.

- [ ] **Step 6: Run the tests to verify they pass**

```bash
xcodebuild -workspace LessPaper.xcworkspace -scheme AppFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|✘|Test run with"
```

Expected: all AppFeature tests pass, including the five new ones and the existing bootstrap tests.

- [ ] **Step 7: Commit**

```bash
git add Modules/AppFeature Modules/AppFeatureTests Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: route an incoming document link to its server"
```

---

### Task 4: Receiving the URL

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift:10-17`
- Modify: `Modules/AppFeature/AppView.swift`

**Interfaces:**
- Consumes: `AppReducer.Action.openURL(URL)` from Task 3.
- Produces: nothing later tasks rely on.

- [ ] **Step 1: Register the scheme**

In `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift`, under `case .app`, extend the existing
schemes array — `atlp` stays, because it is the OIDC callback and because links already exist that
use it:

```swift
                "CFBundleURLTypes": [
                    [
                        "CFBundleTypeRole": "Editor",
                        "CFBundleURLSchemes": [
                            "atlp",
                            "lesspaper",
                        ]
                    ]
                ],
```

- [ ] **Step 2: Hand incoming URLs to the store**

In `Modules/AppFeature/AppView.swift`, add the modifier directly after the existing `.onChange`:

```swift
        .onOpenURL { url in
            store.send(.openURL(url))
        }
```

- [ ] **Step 3: Regenerate and build**

```bash
TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000 mise exec -- tuist generate --no-open
xcodebuild -workspace LessPaper.xcworkspace -scheme "Less Paper" \
  -destination 'generic/platform=iOS Simulator' build 2>&1 | grep -E "error:|BUILD"
```

Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 4: Verify by hand against the running app**

There is no unit test for a view modifier, so this is the check. Run the app on a booted simulator
with at least one server configured and one document, then:

```bash
xcrun simctl openurl booted "lesspaper://<your-server-host>/documents/<an-id>/details"
```

Expected: the app comes to the front, the Documents tab is selected, and that document is pushed.
Send it a second time: the stack must not grow. Then try a host you have not configured:

```bash
xcrun simctl openurl booted "lesspaper://stranger.example.com/documents/1/details"
```

Expected: a toast naming `stranger.example.com`, and the app stays where it was.

- [ ] **Step 5: Commit**

```bash
git add Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift Modules/AppFeature/AppView.swift
git commit -m "feat: register lesspaper:// and hand incoming URLs to the store"
```

---

### Task 5: Sharing a link to a document

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift:42-64`
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `DeepLink.appURL(server:route:)` and `DeepLink.webURL(server:route:)` from Task 1.
- Produces: nothing later tasks rely on.

**Context you need:** `DocumentDetailReducer.State` exposes `document` and `server`, so the view
reaches both through `store`. The existing menu already uses `ShareLink` for the downloaded file;
these two share a URL instead, which is what the shipping app did (`candybarphone` for the app link,
`globe` for the web link).

- [ ] **Step 1: Add the localized strings**

In `Shared/Framework/Resources/Localizable.xcstrings`, add both entries in alphabetical order:

```json
    "shareAppLink" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "App-Link teilen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Share app link"
          }
        }
      }
    },
```

```json
    "shareWebLink" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Web-Link teilen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Share web link"
          }
        }
      }
    },
```

- [ ] **Step 2: Add the two menu items**

In `Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift`, the toolbar `Menu` has this
shape:

```swift
            Menu {
                if let url = store.downloadedURL {
                    // preview, ShareLink for the file, viewerMenu()
                } else {
                    viewerMenu()
                }
                // <- the two items go here
            } label: {
                Label(.moreActions, systemImage: "ellipsis.circle")
            }
```

Add them after the closing brace of the `else` branch and before `} label: {`, so a link can be
shared whether or not the file has finished downloading:

```swift
                if let url = DeepLink.appURL(server: store.server, route: .documentDetail(store.document.id)) {
                    ShareLink(item: url) {
                        Label(.shareAppLink, systemImage: "candybarphone")
                    }
                }

                if let url = DeepLink.webURL(server: store.server, route: .documentDetail(store.document.id)) {
                    ShareLink(item: url) {
                        Label(.shareWebLink, systemImage: "globe")
                    }
                }
```

Add `import ApiInterface` at the top of the file if it is not already there.

- [ ] **Step 3: Build and check the snapshot tests**

```bash
xcodebuild -workspace LessPaper.xcworkspace -scheme DocumentsFeature \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' test 2>&1 | grep -E "error:|✘|Test run with"
```

Expected: pass. The menu is collapsed in any snapshot reference, so none should change. **If a
snapshot fails, stop and look at what was recorded before re-recording anything** — re-recording is
a scheme edit, documented in `AGENTS.md`, and a reference records whatever the code produced,
including a bug.

- [ ] **Step 4: Verify by hand**

Run the app, open a document, open the menu. Both items appear. Share the app link to Notes, then
tap it: it opens that document. Share the web link: it opens the paperless web UI in Safari.

- [ ] **Step 5: Commit**

```bash
git add Modules/DocumentsFeature/DocumentDetail/DocumentDetailView.swift Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: share an app or web link to a document"
```

---

## Done when

- `lesspaper://` and `atlp://` links to `/documents/{id}/details` open that document, on the server
  they name, switching servers when needed.
- A link to a server that is not configured toasts with the host in it and changes nothing.
- The document detail menu offers both link formats.
- `ApiInterface`, `AppFeature` and `DocumentsFeature` test suites pass, and `Less Paper` builds.
