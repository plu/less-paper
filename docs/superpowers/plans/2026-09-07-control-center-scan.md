# Control Center Scan Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a Control Center control that opens Less Paper straight into the document scanner, on a server pinned when the control is placed.

**Architecture:** The control cannot scan by itself — `VNDocumentCameraViewController` must run in the app — so the control opens a deep link. `DeepLink.Route` gains `.scan`, the pinned server rides in the URL's host and path prefix, and `AppReducer`'s existing `pendingLink` machinery does the server-switch dance unchanged. A new `WidgetExtension` app-extension target holds the control; it depends on `ApiInterface` only and never touches the keychain or the network.

**Tech Stack:** Swift 6 (strict concurrency), SwiftUI, WidgetKit `ControlWidget` (iOS 18+), AppIntents, The Composable Architecture, swift-sharing, Tuist 4, mise, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-04-control-center-scan-design.md`

## Global Constraints

- **Deployment target is `iOS 18.0`** for every target (`Module+Targets.swift`). `ControlWidget` is iOS 18+, so no availability annotations are needed.
- **Comments: `//` only.** Never `///`, never `/** ... */` — see `AGENTS.md`, "Comment Style". This holds even in `Tuist/ProjectDescriptionHelpers/*`, whose existing comments are `/** */`. Comment only what is *exceptional*; do not restate the code.
- **Attributes sit on their own line with no blank line before the declaration** (`mise/scripts/attribute_blank_lines.py` enforces this):
  ```swift
  @Shared(.servers)
  var servers
  ```
- **Lint is strict and gates CI:** `swiftformat --lint .`, `swiftlint --strict`, `attribute_blank_lines.py --check`, and `tuist inspect dependencies --only implicit`. Run `mise run format` before committing.
- **CI builds with `TUIST_WARNINGS_AS_ERRORS: "true"`.** A new warning fails the build.
- **App group is `group.com.plunien.app.Paperless`.** Extension bundle ids must be prefixed `com.aptumtek.app.Paperless.` (see `Product.bundleId(name:)`).
- **App scheme is `lesspaper`**, legacy `atlp` is parsed but never written (`DeepLink.scheme` / `DeepLink.legacyScheme`).
- **Every localized string exists in `en` and `de`**, `"extractionState": "manual"`, in the owning module's `Resources/Localizable.xcstrings`.
- **Branch:** work on `feature/control-center-scan`. It is currently 14 commits behind `main`; Task 0 rebases it.

## Deviations from the spec, and why

Two things in the spec do not survive contact with the SDK and the build graph. Both are resolved
here; the spec is otherwise implemented as written.

1. **`scanURL(for:)` lives in `ApiInterface` as `DeepLink.scanURL(server:)`, not in `WidgetExtension`.**
   The spec extracts it "so it can be tested", but a `.appExtension` product cannot be linked into a
   unit-test bundle, and every test target in this project is a `.unitTests` bundle over a framework.
   Standing up a `WidgetExtensionTests` target for one pure function is not viable. The function uses
   only `Server` and `DeepLink`, both of which already live in `ApiInterface`, so moving it one box
   down the dependency arrow preserves the spec's intent — the testable part stays testable — at no
   cost. `ApiInterfaceTests` covers it.

2. **The configuration intent is not the action intent.** The spec says `ScanControlIntent`'s
   `perform()` returns `.result(opensIntent: OpenURLIntent(url))`. It cannot: `ControlConfigurationIntent`
   declares `associatedtype NeverResult where NeverResult == Never` and supplies its own
   `perform() async throws -> Never`. A configuration intent only carries the user's choice. So there
   are two intents — `ScanControlConfiguration` (a `ControlConfigurationIntent` holding the pinned
   server) and `ScanIntent` (a plain `AppIntent` with `openAppWhenRun`, built from the configuration
   in the control's content closure, which is what actually opens the URL).

A third thing the spec does not mention at all: **a new app extension needs its own App ID,
provisioning profile and CI secret**, or the release archive stops signing. Task 5 covers it, and it
contains the only steps a human must perform.

---

### Task 0: Rebase the branch onto main

**Files:** none — git only.

- [ ] **Step 1: Fetch and rebase**

```bash
git checkout feature/control-center-scan
git fetch origin
git rebase origin/main
```

- [ ] **Step 2: Confirm the branch is now one commit ahead and nothing behind**

Run: `git log --oneline origin/main..HEAD && git log --oneline HEAD..origin/main`
Expected: the first prints exactly one line (`docs: add Control Center scanning design`); the second prints nothing.

- [ ] **Step 3: Confirm the tree still builds and tests pass before anything is added**

Run: `mise run ci:test:unit`
Expected: PASS. If this fails, stop — the failure predates this work.

---

### Task 1: `DeepLink` learns the `.scan` route

The parser currently gets to assume one shape. This is the change the spec calls "the main cost", and
its failure mode is quiet — links the app writes but cannot read — so the existing `documentDetail`
tests stay exactly as they are and the new cases are added beside them.

**Files:**
- Modify: `Modules/ApiInterface/DeepLink/DeepLink.swift`
- Test: `Modules/ApiInterfaceTests/DeepLink/DeepLinkTests.swift`

**Interfaces:**
- Consumes: nothing from earlier tasks.
- Produces:
  - `DeepLink.Route.scan` — a new case on the existing `public enum Route: Equatable, Sendable`.
  - `static func DeepLink.scanURL(server: Server?) -> URL?` — public, on `DeepLink`.
  - `DeepLink.appURL(server:route:)` and `DeepLink(url:)` keep their existing signatures and now
    handle `.scan`.

- [ ] **Step 1: Write the failing tests**

Append these to `Modules/ApiInterfaceTests/DeepLink/DeepLinkTests.swift`, inside `struct DeepLinkTests`, after `webURLKeepsTheServersOwnScheme`:

```swift
    @Test
    func parsesTheScanRoute() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://paperless.example.com/scan")!))

        #expect(link.host == "paperless.example.com")
        #expect(link.port == nil)
        #expect(link.prefix == "")
        #expect(link.route == .scan)
    }

    // The prefix is what identifies the server, so a scan link to a server under a subpath has to
    // hand it back intact. Losing it resolves the link to no server at all, and the user gets
    // "server not found" from a control they configured correctly.
    @Test
    func keepsTheServersPathPrefixOnAScanLink() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/scan")!))

        #expect(link.prefix == "/paperless")
        #expect(link.route == .scan)
    }

    @Test
    func toleratesATrailingSlashOnAScanLink() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/scan/")!))

        #expect(link.route == .scan)
    }

    @Test
    func resolvesAScanLinkAgainstTheServerItNames() throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/paperless/scan")!))

        #expect(link.resolves(to: server))
    }

    @Test
    func appURLBuildsTheScanPath() throws {
        let server = Server.testValue(url: URL(string: "https://example.com/paperless")!)
        let url = try #require(DeepLink.appURL(server: server, route: .scan))

        #expect(url.absoluteString == "lesspaper://example.com/paperless/scan")
    }

    @Test
    func roundTripsAScanLink() throws {
        for server in [
            Server.testValue(url: URL(string: "https://paperless.example.com")!),
            Server.testValue(url: URL(string: "https://example.com/paperless")!),
            Server.testValue(url: URL(string: "http://example.com:8200")!),
        ] {
            let url = try #require(DeepLink.appURL(server: server, route: .scan))
            let link = try #require(DeepLink(url: url))

            #expect(link.resolves(to: server))
            #expect(link.route == .scan)
        }
    }

    // A server whose own path ends in "scan" is the case that would break a parser matching the
    // last segment without looking further: this must stay a document link, not become a scan.
    @Test
    func stillReadsADocumentLinkUnderAServerPathEndingInScan() throws {
        let link = try #require(DeepLink(url: URL(string: "lesspaper://example.com/scan/documents/42/details")!))

        #expect(link.prefix == "/scan")
        #expect(link.route == .documentDetail(42))
    }

    @Test
    func scanURLIsNilWithoutAServer() {
        #expect(DeepLink.scanURL(server: nil) == nil)
    }

    @Test
    func scanURLNamesTheServer() throws {
        let server = Server.testValue(url: URL(string: "https://example.com")!)
        let url = try #require(DeepLink.scanURL(server: server))

        #expect(url.absoluteString == "lesspaper://example.com/scan")
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise run ci:test:unit`
Expected: FAIL — compile errors, `type 'DeepLink.Route' has no member 'scan'` and `type 'DeepLink' has no member 'scanURL'`.

- [ ] **Step 3: Add the `.scan` case to `Route`**

In `Modules/ApiInterface/DeepLink/DeepLink.swift`, change:

```swift
    public enum Route: Equatable, Sendable {
        case documentDetail(Document.Id)
    }
```

to:

```swift
    public enum Route: Equatable, Sendable {
        case documentDetail(Document.Id)
        case scan
    }
```

- [ ] **Step 4: Teach the parser the second shape**

In the same file, replace the whole `parse(path:)` function in the `private extension DeepLink` block:

```swift
    // Matched from the end, which is what lets a server hosted under a subpath work without the
    // parser knowing any server exists: the prefix is whatever the match leaves behind.
    static func parse(path: String) -> (prefix: String, route: Route)? {
        var segments = path.split(separator: "/", omittingEmptySubsequences: true).map(String.init)

        if segments.last == "scan" {
            segments.removeLast()

            return (prefix(from: segments), .scan)
        }

        guard segments.count >= 3,
              segments.removeLast() == "details",
              let id = Int(segments.removeLast()),
              segments.removeLast() == "documents"
        else {
            return nil
        }

        return (prefix(from: segments), .documentDetail(Document.Id(rawValue: id)))
    }

    static func prefix(from segments: [String]) -> String {
        segments.isEmpty ? "" : "/" + segments.joined(separator: "/")
    }
```

- [ ] **Step 5: Teach the builder the second shape**

In the same `private extension DeepLink` block, in `url(scheme:server:route:)`, replace the `switch route` with:

```swift
        switch route {
        case let .documentDetail(id):
            components.path = normalized(path: components.path) + "/documents/\(id.rawValue)/details"
        case .scan:
            components.path = normalized(path: components.path) + "/scan"
        }
```

- [ ] **Step 6: Add `scanURL(server:)`**

In `Modules/ApiInterface/DeepLink/DeepLink.swift`, add to the existing `public extension DeepLink` block, after `webURL(server:route:)`:

```swift
    // Nil when there is no server to scan to, which is not an error: the control opens the app
    // plainly and the user lands on the server list. A control placed before any server exists is
    // the ordinary first-launch order of events, not a misconfiguration.
    static func scanURL(server: Server?) -> URL? {
        guard let server else {
            return nil
        }

        return appURL(server: server, route: .scan)
    }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `mise run ci:test:unit`
Expected: PASS, including every pre-existing `DeepLinkTests` case — in particular
`rejectsAPathThatIsNotADocumentDetail`, which is the regression guard for the parser learning a
second shape.

- [ ] **Step 8: Format and lint**

Run: `mise run format && mise run ci:lint`
Expected: no output from lint, exit 0.

- [ ] **Step 9: Commit**

```bash
git add Modules/ApiInterface/DeepLink/DeepLink.swift Modules/ApiInterfaceTests/DeepLink/DeepLinkTests.swift
git commit -m "feat: teach DeepLink a scan route"
```

---

### Task 2: `AppReducer` opens the scanner on the inbox

`openURL` is route-agnostic — it parses, resolves the server, parks the link, and applies it now or
after the server switch. Only `applyPendingLink` needs a new case.

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift`
- Test: `Modules/AppFeatureTests/AppReducerDeepLinkTests.swift`

**Interfaces:**
- Consumes: `DeepLink.Route.scan` from Task 1.
- Produces: no new API. The behaviour later tasks rely on is that
  `lesspaper://<host>/<prefix>/scan` presents the scanner on the **inbox** tab.

- [ ] **Step 1: Write the failing tests**

Append to `Modules/AppFeatureTests/AppReducerDeepLinkTests.swift`, inside `struct AppReducerDeepLinkTests`, after `openURL_forAnotherServer_waitsForTheSwitch`:

```swift
    // MainReducer holds two DocumentListReducer instances and both own a DocumentImportReducer, so
    // a route that presented the wrong one would still compile and still show a scanner. Receiving
    // on \.main.inbox is what tells them apart; the tab assertion is what a reader can see.
    @Test
    func openURL_forTheSelectedServer_opensTheScanner() async {
        let server = Server.testValue(id: "1", url: URL(string: "https://paperless.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [server]

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(selectedTab: .settings, server: server)),
            reducer: { AppReducer() }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://paperless.example.com/scan")!))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.inbox.documentImport.view)

        #expect(store.state.main?.selectedTab == .inbox)
        #expect(store.state.pendingLink == nil)
    }

    // The control pins a server, which need not be the one the app is showing. This is the case the
    // whole per-control-server design rests on, so it is asserted directly rather than assumed from
    // the documentDetail equivalent.
    @Test
    func openURL_scanningAnotherServer_waitsForTheSwitch() async {
        let current = Server.testValue(id: "1", url: URL(string: "https://one.example.com")!)
        let other = Server.testValue(id: "2", url: URL(string: "https://two.example.com")!)

        @Shared(.servers)
        var servers: IdentifiedArrayOf<Server> = [current, other]

        @Shared(.selectedServer)
        var selectedServer: Server? = current

        let store = TestStore(
            initialState: AppReducer.State(main: MainReducer.State(server: current)),
            reducer: { AppReducer() },
            withDependencies: {
                $0.updateCache.execute = { _ in }
            }
        )
        store.exhaustivity = .off

        await store.send(.openURL(URL(string: "lesspaper://two.example.com/scan")!))

        #expect(store.state.pendingLink?.server.id == "2")
        #expect(selectedServer?.id == "2")

        await store.send(.selectedServerChanged(other))
        await store.receive(\.applyPendingLink)
        await store.receive(\.main.inbox.documentImport.view)

        #expect(store.state.main?.selectedTab == .inbox)
        #expect(store.state.pendingLink == nil)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise run ci:test:unit`
Expected: FAIL — `switch must be exhaustive` in `AppReducer.applyPendingLink` once Task 1 landed
`.scan`, so this may already be a compile error before the tests run. Either way the two new tests
must not pass.

- [ ] **Step 3: Handle `.scan` in `applyPendingLink`**

In `Modules/AppFeature/AppReducer.swift`, in the `case .applyPendingLink:` branch, extend the
`switch pending.route`:

```swift
                switch pending.route {
                case let .documentDetail(id):
                    state.main?.selectedTab = .documents
                    return .send(.main(.documentList(.openDocument(id))))
                // The inbox, not the documents tab: a freshly scanned document is unfiled, so it
                // lands there, and .inbox is already the default tab - a cold launch from the
                // control presents the scanner without a visible tab switch behind it.
                case .scan:
                    state.main?.selectedTab = .inbox
                    return .send(.main(.inbox(.documentImport(.view(.scanButtonTapped)))))
                }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mise run ci:test:unit`
Expected: PASS.

- [ ] **Step 5: Format and lint**

Run: `mise run format && mise run ci:lint`
Expected: exit 0.

- [ ] **Step 6: Commit**

```bash
git add Modules/AppFeature/AppReducer.swift Modules/AppFeatureTests/AppReducerDeepLinkTests.swift
git commit -m "feat: open the scanner on the inbox for a scan deep link"
```

---

### Task 3: A `WidgetExtension` target with a control that scans on the selected server

Everything in `Project.swift` is driven by `Module.allCases`, and several switches over it are
exhaustive — adding one case means touching all of them. This task adds the target and a working
control that scans on whichever server the app currently has selected. Task 4 then makes the server
a per-control choice. Both increments ship something; neither leaves throwaway code behind.

The target is named for the container, not the control: a widget extension holds any number of
widgets, so a later home-screen widget belongs in this target rather than a second one.

**Files:**
- Create: `Modules/WidgetExtension/WidgetExtensionBundle.swift`
- Create: `Modules/WidgetExtension/ScanIntent.swift`
- Create: `Modules/WidgetExtension/ScanControl.swift`
- Create: `Modules/WidgetExtension/Resources/Localizable.xcstrings`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`

**Interfaces:**
- Consumes: `DeepLink.scanURL(server:)` from Task 1; `SharedReaderKey.selectedServer` from `ApiInterface`.
- Produces:
  - `Module.widgetExtension` (raw value `"WidgetExtension"`), product `.appExtension`, bundle id
    `com.aptumtek.app.Paperless.WidgetExtension`, embedded in `.app`.
  - `struct ScanControl: ControlWidget` with `static let kind = "com.aptumtek.app.Paperless.ScanControl"`.
  - `struct ScanIntent: AppIntent` with `static let openAppWhenRun = true` and `init()`. Task 4 adds
    a `server` parameter and an `init(server:)`.
  - Localized keys `scanControlTitle` and `scanControlDescription`.

**Note on swift-sharing:** the Tuist external is `.external(.sharing)` but the Swift module is
`SwiftSharing` — `import Sharing` does not compile. 114 files in this repo already do it this way.

- [ ] **Step 1: Add the module case**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, add to the `Module` enum, in alphabetical order
after `case uiTestSupport`:

```swift
    case widgetExtension = "WidgetExtension"
```

- [ ] **Step 2: Add it to the exhaustive switches in `Module.swift`**

`codeCoverageTarget` — add `.widgetExtension` to the `false` list, after `.uiTestSupport`:

```swift
             .testSupport,
             .uiTestSupport,
             .widgetExtension:
            false
```

`entitlements` — the existing `.app, .shareApp, .shareExtension` case also grants keychain access.
The control never makes an authenticated request, and not granting it is how that stays true, so it
gets its own case. Insert before `default:`:

```swift
        // The app group and nothing else. This extension reads servers.json to name a server and
        // builds a URL; it never makes an authenticated request, so it has no business with the
        // keychain, and the way to keep that true is not to grant it.
        case .widgetExtension:
            .dictionary([
                "com.apple.security.application-groups": .array(["group.com.plunien.app.Paperless"]),
            ])
```

`product` — add to the `.appExtension` case:

```swift
        case .shareExtension,
             .widgetExtension:
            .appExtension
```

- [ ] **Step 3: Add the Info.plist**

In `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift`, add a case before `default:`:

```swift
        case .widgetExtension:
            .extendingDefault(with: [
                "CFBundleDisplayName": "Less Paper",
                "CFBundleShortVersionString": .string(.marketingVersion),
                "CFBundleLocalizations": [
                    "en",
                    "de",
                ],
                "CFBundleVersion": .string(.buildNumber),
                "NSExtension": [
                    "NSExtensionPointIdentifier": "com.apple.widgetkit-extension",
                ],
            ])
```

There is no `NSExtensionPrincipalClass`: a WidgetKit extension is entered through the `@main`
`WidgetBundle`, not a principal class.

- [ ] **Step 4: Add the dependencies and embed it in the app**

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add a case (alphabetical, after the
last case):

```swift
        case .widgetExtension:
            [
                .external(.sharing),
                .target(.apiInterface),
            ]
```

and add `.target(.widgetExtension)` to `case .app:` so it is embedded, after `.target(.snapshotSupport)`:

```swift
        case .app:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.appFeature),
                .target(.serversFeature),
                .target(.shareExtension),
                .target(.snapshotSupport),
                .target(.widgetExtension),
            ]
```

- [ ] **Step 5: Add the scheme**

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`, add a case mirroring `.shareExtension`:

```swift
        case .widgetExtension:
            [
                .scheme(
                    name: "WidgetExtension",
                    buildAction: .buildAction(
                        targets: [.target(self)],
                        postActions: [inspectBuildPostAction(target: .target(self))],
                        runPostActionsOnFailure: true
                    ),
                    runAction: .runAction(executable: .target(.app))
                )
            ]
```

The `schemes` switch is exhaustive and has no `default:`, so leaving this out is a compile error in
the manifest, not a silent omission.

- [ ] **Step 6: Add the localized strings**

Create `Modules/WidgetExtension/Resources/Localizable.xcstrings`:

```json
{
  "sourceLanguage" : "en",
  "strings" : {
    "scanControlDescription" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Öffnet Less Paper und startet den Dokumentenscanner."
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Opens Less Paper and starts the document scanner."
          }
        }
      }
    },
    "scanControlTitle" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Scannen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Scan"
          }
        }
      }
    }
  },
  "version" : "1.1"
}
```

- [ ] **Step 7: Write the extension's entry point**

Create `Modules/WidgetExtension/WidgetExtensionBundle.swift`:

```swift
import SwiftUI
import WidgetKit

@main
struct WidgetExtensionBundle: WidgetBundle {

    var body: some Widget {
        ScanControl()
    }
}
```

- [ ] **Step 8: Write the intent**

Create `Modules/WidgetExtension/ScanIntent.swift`:

```swift
import ApiInterface
import AppIntents
import Foundation
import SwiftSharing

struct ScanIntent: AppIntent {

    static let title: LocalizedStringResource = .scanControlTitle

    // The scanner is a view controller that has to run in the app, so every path here ends in the
    // app being opened. The URL only decides which server it opens on, and having none is not an
    // error: the app opens plainly and the user lands on the server list.
    static let openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        @Shared(.selectedServer)
        var selectedServer

        guard let url = DeepLink.scanURL(server: selectedServer) else {
            return .result()
        }

        return .result(opensIntent: OpenURLIntent(url))
    }

    init() {}
}
```

- [ ] **Step 9: Write the control**

Create `Modules/WidgetExtension/ScanControl.swift`:

```swift
import AppIntents
import SwiftUI
import WidgetKit

struct ScanControl: ControlWidget {

    static let kind = "com.aptumtek.app.Paperless.ScanControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: ScanIntent()) {
                Label(String(localized: .scanControlTitle), systemImage: "doc.viewfinder")
            }
        }
        .displayName(.scanControlTitle)
        .description(.scanControlDescription)
    }
}
```

If `.scanControlTitle` does not resolve, string-catalog symbol generation did not run for this
target: replace every `.scanControlTitle` / `.scanControlDescription` with
`LocalizedStringResource("scanControlTitle")` / `LocalizedStringResource("scanControlDescription")`
here and in every later task, and note it in the commit message.

- [ ] **Step 10: Generate the project and confirm the target exists**

Run: `tuist generate --no-open && grep -c WidgetExtension LessPaper.xcodeproj/project.pbxproj`
Expected: `tuist generate` succeeds and the grep count is greater than 0.

- [ ] **Step 11: Build the extension and the app**

Run: `tuist build WidgetExtension && tuist build "Less Paper"`
Expected: BUILD SUCCEEDED both times, with no warnings — CI treats them as errors.

- [ ] **Step 12: Run the unit suite**

Run: `mise run ci:test:unit`
Expected: PASS. Nothing in this task is unit-testable — `ControlWidget` bodies and
`AppIntent.perform()` have no test story in this project — which is exactly why
`DeepLink.scanURL(server:)` was extracted into `ApiInterface` in Task 1.

- [ ] **Step 13: Lint, including the implicit-dependency check**

Run: `mise run format && mise run ci:lint`
Expected: exit 0. `tuist inspect dependencies --only implicit` must report nothing — if it names
`WidgetExtension`, an import in the new sources has no matching entry in `Module+Dependencies.swift`.

- [ ] **Step 14: Commit**

```bash
git add Modules/WidgetExtension Tuist/ProjectDescriptionHelpers
git commit -m "feat: add a Control Center control that opens the scanner"
```

---

### Task 4: Pin a server to the control

iOS supports configurable controls, so two controls can point at two servers. Someone with a work
server and a home server wants one tap to the right one, not one tap plus a server switch — and
`AppReducer` already handles being asked to act on a server it is not currently showing.

`ControlConfigurationIntent` declares `associatedtype NeverResult where NeverResult == Never` and
supplies its own `perform()`, so it can only carry the user's choice; it cannot be the action. Hence
two intents: `ScanControlConfiguration` holds the pinned server, and the control's content closure
builds `ScanIntent` from it.

**Files:**
- Create: `Modules/WidgetExtension/ServerEntity.swift`
- Create: `Modules/WidgetExtension/ScanControlConfiguration.swift`
- Modify: `Modules/WidgetExtension/ScanIntent.swift`
- Modify: `Modules/WidgetExtension/ScanControl.swift`
- Modify: `Modules/WidgetExtension/Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `ScanControl.kind`, `ScanIntent`, `scanControlTitle`, `scanControlDescription` from
  Task 3; `DeepLink.scanURL(server:)` from Task 1; `SharedReaderKey.servers` / `.selectedServer`.
- Produces:
  - `struct ServerEntity: AppEntity` with `let alias: String`, `let id: String`, `let server: Server`,
    and `init(server: Server)`.
  - `struct ServerEntityQuery: EntityQuery` with `entities(for:)` and `suggestedEntities()`.
  - `struct ScanControlConfiguration: ControlConfigurationIntent` with `@Parameter var server: ServerEntity?`.
  - `ScanIntent` gains `@Parameter var server: ServerEntity?` and `init(server: ServerEntity?)`.

- [ ] **Step 1: Add the two new strings**

In `Modules/WidgetExtension/Resources/Localizable.xcstrings`, add two entries to the `strings`
object, keeping the keys in alphabetical order, and change `scanControlDescription` to mention the
server:

```json
    "scanControlServerParameter" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Server"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Server"
          }
        }
      }
    },
    "serverEntityTypeName" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Server"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Server"
          }
        }
      }
    },
```

and set `scanControlDescription`'s values to
`"Opens Less Paper and starts the document scanner on the chosen server."` (en) and
`"Öffnet Less Paper und startet den Dokumentenscanner auf dem gewählten Server."` (de).

- [ ] **Step 2: Write `ServerEntity`**

Create `Modules/WidgetExtension/ServerEntity.swift`:

```swift
import ApiInterface
import AppIntents
import SwiftSharing

struct ServerEntity: AppEntity {

    static let defaultQuery = ServerEntityQuery()

    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: .serverEntityTypeName)
    }

    // The alias is what the picker shows, because it is what the user named the server. The id is
    // what is stored, because an alias can be renamed and a placed control must survive that.
    let alias: String

    let id: String

    let server: Server

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(alias)")
    }

    init(server: Server) {
        self.alias = server.alias
        self.id = server.id
        self.server = server
    }
}

struct ServerEntityQuery: EntityQuery {

    func entities(for identifiers: [ServerEntity.ID]) async throws -> [ServerEntity] {
        servers()
            .filter { identifiers.contains($0.id) }
            .map(ServerEntity.init)
    }

    func suggestedEntities() async throws -> [ServerEntity] {
        servers().map(ServerEntity.init)
    }

    init() {}

    private func servers() -> [Server] {
        @Shared(.servers)
        var servers

        return servers.elements.sorted()
    }
}
```

- [ ] **Step 3: Write the configuration intent**

Create `Modules/WidgetExtension/ScanControlConfiguration.swift`:

```swift
import ApiInterface
import AppIntents
import SwiftSharing

// Carries the server the user pinned when they placed the control, and nothing else. A
// ControlConfigurationIntent's result type is Never by definition, so it cannot be the action -
// ScanIntent is.
struct ScanControlConfiguration: ControlConfigurationIntent {

    static let title: LocalizedStringResource = .scanControlTitle

    @Parameter(title: .scanControlServerParameter)
    var server: ServerEntity?

    init() {
        @Shared(.selectedServer)
        var selectedServer

        self.server = selectedServer.map(ServerEntity.init)
    }
}
```

- [ ] **Step 4: Give `ScanIntent` the pinned server**

Replace the whole of `Modules/WidgetExtension/ScanIntent.swift`:

```swift
import ApiInterface
import AppIntents
import Foundation

struct ScanIntent: AppIntent {

    static let title: LocalizedStringResource = .scanControlTitle

    // The scanner is a view controller that has to run in the app, so every path here ends in the
    // app being opened. The URL only decides which server it opens on, and having none is not an
    // error: the app opens plainly and the user lands on the server list.
    static let openAppWhenRun = true

    @Parameter(title: .scanControlServerParameter)
    var server: ServerEntity?

    func perform() async throws -> some IntentResult {
        guard let url = DeepLink.scanURL(server: server?.server) else {
            return .result()
        }

        return .result(opensIntent: OpenURLIntent(url))
    }

    init() {}

    init(server: ServerEntity?) {
        self.server = server
    }
}
```

- [ ] **Step 5: Make the control configurable**

Replace the `body` in `Modules/WidgetExtension/ScanControl.swift`:

```swift
    var body: some ControlWidgetConfiguration {
        AppIntentControlConfiguration(
            kind: Self.kind,
            intent: ScanControlConfiguration.self
        ) { configuration in
            // Labelled with the server the control is pinned to, so two controls for two servers
            // are told apart in Control Center without opening either.
            ControlWidgetButton(action: ScanIntent(server: configuration.server)) {
                Label(
                    configuration.server?.alias ?? String(localized: .scanControlTitle),
                    systemImage: "doc.viewfinder"
                )
            }
        }
        .displayName(.scanControlTitle)
        .description(.scanControlDescription)
    }
```

- [ ] **Step 6: Build the extension and the app**

Run: `tuist generate --no-open && tuist build WidgetExtension && tuist build "Less Paper"`
Expected: BUILD SUCCEEDED both times, no warnings.

- [ ] **Step 7: Run the unit suite**

Run: `mise run ci:test:unit`
Expected: PASS.

- [ ] **Step 8: Format and lint**

Run: `mise run format && mise run ci:lint`
Expected: exit 0, and `tuist inspect dependencies --only implicit` reports nothing.

- [ ] **Step 9: Commit**

```bash
git add Modules/WidgetExtension
git commit -m "feat: let each scan control pin its own server"
```

---

### Task 5: Sign and ship the new extension

A second app extension does not archive without its own App ID, provisioning profile and export
options entry. The spec does not mention this; without it, `mise run ci:build` fails at the export
step with "no profile for com.aptumtek.app.Paperless.WidgetExtension".

**Merge ordering — do not merge before this is done.** The `upload` job (`.github/workflows/ci.yml:131`)
that runs `mise ci:build` (line 151) is gated on `github.ref == 'refs/heads/main'` or the pull request
carrying a `TestFlight` label. A normal PR for this branch never exercises `ci:build`, so the branch
can go green and merge with no profile set, and only then does `main` fail on the next push with
`WIDGET_EXTENSION_PROVISIONING_PROFILE: unbound variable` — which also blocks TestFlight uploads
until it's fixed. The safe order is: create the App ID (Step 1) → generate and download the profile
(Step 1) → `fnox set WIDGET_EXTENSION_PROVISIONING_PROFILE` (Step 2) → *then* merge.

**Steps 1 and 2 can only be done by a human** — they need the Apple Developer portal and the
repository's `fnox` secrets. Do them first, or the rest cannot be verified.

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Targets.swift`
- Modify: `mise/tasks/ci/build`
- Modify: `fnox.toml` (human, via `fnox set WIDGET_EXTENSION_PROVISIONING_PROFILE` — not a hand edit)

**Interfaces:**
- Consumes: `Module.widgetExtension` from Task 3.
- Produces: `Environment.widgetExtensionProvisioningProfile`, read from
  `TUIST_WIDGET_EXTENSION_PROVISIONING_PROFILE`.

- [ ] **Step 1 (human): Create the App ID and provisioning profile**

In the Apple Developer portal:
1. Identifiers → new App ID `com.aptumtek.app.Paperless.WidgetExtension`, with the App Groups
   capability **enabled and assigned to `group.com.plunien.app.Paperless`**. This is not optional:
   an App ID without it still lets the archive sign and ship, but the extension then silently reads
   an empty container at runtime — the server picker shows no servers at all, with no error, and the
   symptom points at the entity query rather than at the missing entitlement.
2. Profiles → new App Store distribution profile for that App ID, named exactly
   `com.aptumtek.app.Paperless.WidgetExtension`.
3. Download it.

- [ ] **Step 2 (human): Add the CI secret**

`SHARE_EXTENSION_PROVISIONING_PROFILE` is not a GitHub repository secret — it lives, encrypted, in
`fnox.toml`'s `[secrets]` table, and `fnox exec -P ci -- mise ci:build` (`.github/workflows/ci.yml:157`)
decrypts the whole table into the environment before the build step runs. Add the new one the same
way, piping the base64 straight into `fnox set` rather than pasting it anywhere on GitHub:

```bash
base64 -i ~/Downloads/com.aptumtek.app.Paperless.WidgetExtension.mobileprovision | tr -d '\n' \
  | fnox set WIDGET_EXTENSION_PROVISIONING_PROFILE
```

- [ ] **Step 3: Read the profile name in the target settings**

In `Tuist/ProjectDescriptionHelpers/Module+Targets.swift`, after the existing `.shareExtension`
block:

```swift
        if case .widgetExtension = self {
            debugSettings.set(Environment.widgetExtensionProvisioningProfile, forKey: "PROVISIONING_PROFILE_SPECIFIER")
            releaseSettings.set(Environment.widgetExtensionProvisioningProfile, forKey: "PROVISIONING_PROFILE_SPECIFIER")
        }
```

`Environment.widgetExtensionProvisioningProfile` needs no declaration — Tuist's `Environment` is a
`@dynamicMemberLookup` over `TUIST_`-prefixed variables, which is how
`Environment.shareExtensionProvisioningProfile` resolves today.

- [ ] **Step 4: Install the profile and export with it in CI**

In `mise/tasks/ci/build`, after the `SHARE_EXTENSION_PROVISIONING_PROFILE` line:

```bash
printf '%s' "$WIDGET_EXTENSION_PROVISIONING_PROFILE" | base64 -d > "$HOME/Library/MobileDevice/Provisioning Profiles/com.aptumtek.app.Paperless.WidgetExtension.mobileprovision"
```

Note the capital `P` in `Provisioning Profiles` — the existing ShareExtension line writes to
`Provisioning profiles`, which works only because macOS's filesystem is case-insensitive by default.
Do not copy that typo.

In the same file, add to the `provisioningProfiles` dict in the export options plist:

```
		<key>com.aptumtek.app.Paperless.WidgetExtension</key>
		<string>com.aptumtek.app.Paperless.WidgetExtension</string>
```

and add the export next to the other two:

```bash
export TUIST_WIDGET_EXTENSION_PROVISIONING_PROFILE=com.aptumtek.app.Paperless.WidgetExtension
```

- [ ] **Step 5 (human): Confirm no workflow needs the secret named explicitly**

Step 2 already put `WIDGET_EXTENSION_PROVISIONING_PROFILE` where `SHARE_EXTENSION_PROVISIONING_PROFILE`
already lives — `fnox.toml`'s `[secrets]` table — and `fnox exec -P ci -- mise ci:build`
(`.github/workflows/ci.yml:157`) decrypts the whole table into the environment before the build step
runs, so there is nothing left to wire up here. The only `secrets.*` reference anywhere in
`.github/workflows` is `GITHUB_TOKEN` — a `grep -rn "SHARE_EXTENSION_PROVISIONING_PROFILE" .github/`
returns nothing today, and it should still return nothing after this task: no workflow file names
either provisioning-profile secret, and none needs to.

- [ ] **Step 6: Verify the archive signs**

Run: `mise run ci:build`
Expected: `build/LessPaper.ipa` is produced. Then confirm the extension is inside it and signed:

```bash
cd /tmp && rm -rf ipacheck && mkdir ipacheck && cd ipacheck \
  && unzip -q "$OLDPWD/build/LessPaper.ipa" \
  && ls Payload/*.app/PlugIns/ \
  && codesign -dv --verbose=2 Payload/*.app/PlugIns/WidgetExtension.appex 2>&1 | grep Identifier
```

Expected: `PlugIns/` lists both `ShareExtension.appex` and `WidgetExtension.appex`, and the
identifier is `com.aptumtek.app.Paperless.WidgetExtension`.

If this cannot be run locally (no distribution certificate), say so explicitly rather than marking
the step done, and verify it on the next CI run instead.

- [ ] **Step 7: Commit**

```bash
git add Tuist/ProjectDescriptionHelpers/Module+Targets.swift mise/tasks/ci/build
git commit -m "chore: sign and embed the widget extension in the release build"
```

---

### Task 6: Verify by hand, then finish the branch

Everything about how iOS presents and invokes a control is outside what the tests reach. The residual
risk is that the control appears and does nothing, and that is found by tapping it.

**Files:**
- Modify: `docs/superpowers/specs/2026-09-04-control-center-scan-design.md` (record the deviations)

- [ ] **Step 1: Install on a simulator or device with two servers configured**

Run: `tuist generate --no-open && tuist build "Less Paper"` then install and launch.
Configure **two** servers — a single-server setup cannot tell a pinned server from a default one,
which is the whole point of the per-control choice.

- [ ] **Step 2: Add the control and pin the non-selected server**

Control Center → edit → add "Scan". Long-press it and choose the server that is *not* currently
selected in the app. Confirm the button's label shows that server's alias.

- [ ] **Step 3: Tap it from a cold start**

Force-quit the app first. Tap the control.
Expected: the app launches, switches to the pinned server, lands on the Inbox tab, and the document
scanner is on screen.

- [ ] **Step 4: Tap it while the app is open on the other server**

Expected: the same, with the visible server switch.

- [ ] **Step 5: Check the two failure paths**

- Delete the pinned server in the app, then tap the control. Expected: the app opens and shows the
  "server not found" toast rather than scanning to a different server.
- Place a control with no servers configured at all. Expected: the app opens on the server list, with
  no error.

- [ ] **Step 6: Check three more manual cases**

- Pin server A, delete server A while server B stays selected, then tap the control.
  `ScanControlConfiguration.init()` seeds its parameter from `@Shared(.selectedServer)`, and
  AppIntents runs `init()` before applying persisted parameter values — so a control pinned to a
  now-deleted server may silently repoint at whatever is currently selected instead of falling back
  to opening the app plainly. This is the one case whose failure is "scans on the wrong server"
  rather than "does nothing", so it is worth checking by hand.
- Look at the tile with only one server configured. The button is labelled with the server's alias,
  so with a single server it never reads "Scan" and the icon carries the whole meaning. That follows
  the design, but the design's reasoning may not survive seeing it.
- If the server picker comes up empty, check the provisioning profile's App Groups capability first
  (Task 5, Step 1) — the symptom misdirects.

- [ ] **Step 7: Record the deviations in the spec**

Append a short "Implementation notes" section to
`docs/superpowers/specs/2026-09-04-control-center-scan-design.md` recording the three things this
plan changed: `scanURL` living in `ApiInterface`, the split into `ScanControlConfiguration` +
`ScanIntent`, and the provisioning work the spec omitted. Keep it to a paragraph each — the spec's
reasoning still stands, only these mechanics changed.

- [ ] **Step 8: Commit and open the pull request**

```bash
git add docs/superpowers/specs/2026-09-04-control-center-scan-design.md
git commit -m "docs: record how the control center scan design changed in the building"
git push -u origin feature/control-center-scan
```

Then use superpowers:finishing-a-development-branch.
