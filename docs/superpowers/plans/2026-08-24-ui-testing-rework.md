# UI Testing Rework — Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the per-feature XCUITest harness apps with one suite driving the real app, proving the machinery end to end and retiring the first harness (`TagsApp`).

**Architecture:** A `UITestConfiguration` payload travels from the test process to the app through `XCUIApplication.launchEnvironment`. `ApiImplementation` decodes it and swaps storage to in-memory, seeds an in-memory keychain, and writes the shared `servers`/`selectedServer` state that `AppReducer.bootstrap` observes. Each test owns a freshly created Paperless user granted `Permission.allCases`, so fixtures it creates are owned by it and invisible to every other test.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing, Tuist 4.203.4, Swift Testing (unit), XCTest/XCUITest (UI), paperless-ngx 3.0.5 in Docker.

**Spec:** [2026-08-24-ui-testing-rework-design.md](../specs/2026-08-24-ui-testing-rework-design.md)

**Scope:** This plan covers spec sequence steps 1–3 plus journeys 1, 3 and 4. Journeys 2 and 5–12, and deletion of the remaining eight harness apps, are Plan 2 — deliberately deferred until the accessibility-identifier cost is known from real journeys.

## Execution notes

Written before implementation, corrected after it. Where a task below still describes the original
intent, this section wins.

**Accessibility identifiers cost nothing.** The one unsized risk, and the reason Plan 2 was split
off, turned out to be a non-issue: across all three journeys every element matched on an existing
label and not one identifier had to be added. Plan 2 is a smaller job than budgeted. The screens it
covers — the custom-field matrix and document browsing — are still the ones most likely to be
ambiguous in an assembled navigation stack, so the risk is reduced rather than retired.

**The launch contract changed.** "Unconfigured" cannot mean passing no environment at all: the app
then reads the real `servers.json` from the application group, so a machine with a configured app
launches past the add-server form while a clean CI runner does not. `UITestConfiguration` therefore
always travels, carrying an *optional* `seed`; a nil seed still swaps storage to memory. Task 1's
payload is `UITestConfiguration(seed: .init(password:server:token:))`, and `UITestCase.launch` takes
`seedingServer:` rather than `configured:`.

**The seam is three pieces, not one.** `prepareDependencies` is an app-launch API and fights a test
harness that already scopes dependencies, so Task 2 ships `applyUITestConfiguration` (a
`DependencyValues` mutation) and `seedUITestSharedState` (the shared writes) — both exercised
through `withDependencies` — with `prepareUITestDependencies` as the thin wrapper the app calls.

**The UI-test keychain is a real in-memory store**, keyed by server id, not a fixed answer. The
onboarding journey writes through `StoreTokenUseCase` and reads back through
`GetCredentialsUseCase`; a stub ignoring the write reports success while exercising neither.

**Four commands in the tasks below were wrong.** They are fixed inline; listed here so Plan 2 does
not repeat them:

| Wrong | Right |
|---|---|
| `tuist build App` | `tuist build "Less Paper" -d "iPhone 17 Pro"` — `App` is a target, not a scheme |
| Editing `Module+*.swift` then testing | Regenerate first: `tuist generate --no-open` |
| Leak check against `localhost:8000` | `localhost:9000` — 8000 is the dev instance, tests use ci |
| "Generation fails for an unreferenced folder" | It succeeds; Tuist ignores folders no `Module` case names |

**`SmokeTests` is deleted in Task 7, not Task 6.** Journey 1 launches *without* a seeded server, so
deleting the smoke test at the end of Task 6 would leave the seeded launch path uncovered until
Task 7's settings journey lands.

**Measured runtime:** onboarding 29s, settings 11s, tag lifecycle 44s — ~84s for three journeys.

## Global Constraints

- **Comments:** Only `//`. Never `///`, never `/** */`. Comment only when a future reader would otherwise stop and wonder why — never restate the code. (`AGENTS.md`)
- **Unit tests** use Swift Testing (`@Suite`, `@Test`, `#expect`) with `CustomDump`. **UI tests** use XCTest, because XCUITest requires it.
- **Test user grant** is exactly `Permission.allCases` — never a curated subset.
- **No UI test may mutate global server state.** No "delete all X". No assertion on a list's total count for custom fields or documents.
- **Custom fields are global** in paperless-ngx 3.0.5 (no `owner` field) — they are namespaced by name, not by user.
- **Deployment target** iOS 18.0. Destinations `.iPhone`, `.iPad`.
- **After any change to `Tuist/ProjectDescriptionHelpers/`**, regenerate: `mise exec -- tuist install && mise exec -- tuist generate --no-open`.
- **Test server URL** comes from the Info.plist key `PAPERLESS_TEST_URL`, defaulting to `http://localhost:9000`. The local dev instance is `http://localhost:8000`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Modules/ApiInterface/UITest/UITestConfiguration.swift` | The `Codable` payload and its environment encode/decode. |
| `Modules/ApiInterfaceTests/UITest/UITestConfigurationTests.swift` | Round-trip and malformed-input tests. |
| `Modules/ApiImplementation/UITest/UITestBootstrap.swift` | `prepareUITestDependencies` — the injection seam. Internal types stay internal. |
| `Modules/ApiImplementationTests/UITest/UITestBootstrapTests.swift` | Verifies storage swap, keychain seeding, shared writes. |
| `Modules/UITestSupport/TestUser.swift` | Per-test Paperless user create/delete and orphan sweep. |
| `Modules/UITestSupport/UITestCase.swift` | XCTestCase base: user lifecycle, launch configuration, cleanup. |
| `Modules/UITestSupport/Screens/SettingsScreen.swift` | Screen driver for the Settings tab. |
| `Modules/UITestSupport/Screens/TagListScreen.swift` | Screen driver for the tag list. |
| `Modules/UITestSupport/Screens/ServerFormScreen.swift` | Screen driver for the add-server form. |
| `Modules/AppUITests/OnboardingJourneyTests.swift` | Journey 1. |
| `Modules/AppUITests/SettingsJourneyTests.swift` | Journey 3. |
| `Modules/AppUITests/TagLifecycleJourneyTests.swift` | Journey 4. |

**Modified:**

| File | Change |
|---|---|
| `Modules/App/LessPaperApp.swift` | `#if DEBUG` launch hook before `store.send(.bootstrap)`. |
| `Tuist/ProjectDescriptionHelpers/Module.swift` | Add `appUITests`; remove `tagsApp`, `tagsAppTests`. |
| `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` | Wire `appUITests` and `uiTestSupport`; remove tags harness entries. |
| `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift` | Add `AppUITests` to the "Less Paper" scheme; remove `tagsApp` scheme and its `featureAppTestTargets` case. |
| `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift` | Remove the `TagsApp` Info.plist entry. |
| `AGENTS.md` | Record the UI-test isolation contract. |

**Deleted:** `Modules/TagsApp/`, `Modules/TagsAppTests/`.

**Deviation from the spec, flagged:** the spec proposed a standalone `UITestConfiguration` module. This plan puts the payload in `ApiInterface` instead. `ApiInterface` already carries `testValue()` factories throughout and already reads `PAPERLESS_TEST_URL` from the bundle, it does not link XCTest (the spec's actual constraint), and both `App` and `AppUITests` already depend on it. This avoids a new module *and* a new test target, taking the final count from 4 targets to 3.

---

## Task 1: `UITestConfiguration` payload

**Files:**
- Create: `Modules/ApiInterface/UITest/UITestConfiguration.swift`
- Test: `Modules/ApiInterfaceTests/UITest/UITestConfigurationTests.swift`

**Interfaces:**
- Consumes: `Server` (`Codable`, in `ApiInterface`), `JSONDecoder.apiDecoder`, `JSONEncoder.apiEncoder`.
- Produces:
  - `UITestConfiguration.environmentKey: String` = `"UI_TEST_CONFIGURATION"`
  - `UITestConfiguration.init(password: String, server: Server, token: String)`
  - `UITestConfiguration.fromEnvironment(_ environment: [String: String]) -> UITestConfiguration?`
  - `UITestConfiguration.environmentValue() throws -> String`

`Credentials` is deliberately **not** used here — it is `Equatable, Sendable` but not `Codable`, and widening it for a test payload is not worth it. The password and token travel as plain strings and `Credentials` is constructed at the point of use in Task 2.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiInterfaceTests/UITest/UITestConfigurationTests.swift`:

```swift
@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite
struct UITestConfigurationTests {

    @Test
    func roundTripsThroughEnvironment() async throws {
        let configuration = UITestConfiguration(
            password: "secret",
            server: .testValue(),
            token: "abc123"
        )

        let environment = [
            UITestConfiguration.environmentKey: try configuration.environmentValue()
        ]

        expectNoDifference(
            UITestConfiguration.fromEnvironment(environment),
            configuration
        )
    }

    @Test
    func returnsNilWhenKeyAbsent() async throws {
        #expect(UITestConfiguration.fromEnvironment([:]) == nil)
    }

    @Test
    func returnsNilWhenPayloadMalformed() async throws {
        #expect(
            UITestConfiguration.fromEnvironment(
                [UITestConfiguration.environmentKey: "not json"]
            ) == nil
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro"
```

Expected: FAIL — `cannot find 'UITestConfiguration' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Modules/ApiInterface/UITest/UITestConfiguration.swift`:

```swift
import Foundation

public struct UITestConfiguration: Codable, Equatable, Sendable {

    public static let environmentKey = "UI_TEST_CONFIGURATION"

    public let password: String

    public let server: Server

    public let token: String

    public init(
        password: String,
        server: Server,
        token: String
    ) {
        self.password = password
        self.server = server
        self.token = token
    }
}

public extension UITestConfiguration {

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        guard
            let value = environment[environmentKey],
            let data = value.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder.apiDecoder.decode(Self.self, from: data)
    }

    func environmentValue() throws -> String {
        String(
            decoding: try JSONEncoder.apiEncoder.encode(self),
            as: UTF8.self
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mise exec -- tuist test ApiInterface -d "iPhone 17 Pro"
```

Expected: PASS, 3 tests.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiInterface/UITest Modules/ApiInterfaceTests/UITest
git commit -m "feat: add UITestConfiguration launch payload"
```

---

## Task 2: `prepareUITestDependencies` injection seam

**Files:**
- Create: `Modules/ApiImplementation/UITest/UITestBootstrap.swift`
- Test: `Modules/ApiImplementationTests/UITest/UITestBootstrapTests.swift`

**Interfaces:**
- Consumes: `UITestConfiguration` (Task 1); `Keychain` and `DependencyValues.keychain` (both internal to `ApiImplementation`); `Credentials`, `SharedReaderKey.servers`, `SharedReaderKey.selectedServer` (public in `ApiInterface`).
- Produces: `public func prepareUITestDependencies(_ configuration: UITestConfiguration)`

This function is the reason the payload cannot be applied from `App`: `Keychain` is declared `struct Keychain: Sendable` with no `public`, and `extension DependencyValues { var keychain: Keychain }` is likewise internal. `ApiImplementation` owns them, so the seam lives here.

Order is load-bearing. `defaultFileStorage` must be `.inMemory` **before** the `@Shared` writes, or the writes land in the real app-group container and leak across launches.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/UITest/UITestBootstrapTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Sharing
import Testing

@Suite
struct UITestBootstrapTests {

    @Test
    func seedsSelectedServerFromConfiguration() async throws {
        let server = Server.testValue(alias: "seeded")

        prepareUITestDependencies(
            UITestConfiguration(
                password: "secret",
                server: server,
                token: "abc123"
            )
        )

        @Shared(.selectedServer)
        var selectedServer

        @Shared(.servers)
        var servers

        expectNoDifference(selectedServer, server)
        expectNoDifference(Array(servers), [server])
    }

    @Test
    func seedsKeychainFromConfiguration() async throws {
        let server = Server.testValue()

        prepareUITestDependencies(
            UITestConfiguration(
                password: "secret",
                server: server,
                token: "abc123"
            )
        )

        @Dependency(\.keychain)
        var keychain

        let credentials = try await keychain.getCredentials(server: server)

        expectNoDifference(
            credentials,
            Credentials(password: "secret", token: "abc123")
        )
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

```bash
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"
```

Expected: FAIL — `cannot find 'prepareUITestDependencies' in scope`.

- [ ] **Step 3: Write minimal implementation**

Create `Modules/ApiImplementation/UITest/UITestBootstrap.swift`:

```swift
import ApiInterface
import Dependencies
import Foundation
import Sharing

// The keychain and storage swaps must be in place before the shared writes below, or the writes
// land in the real application group container and survive the next launch.
public func prepareUITestDependencies(
    _ configuration: UITestConfiguration
) {
    let credentials = Credentials(
        password: configuration.password,
        token: configuration.token
    )

    prepareDependencies {
        $0.defaultAppStorage = .inMemory
        $0.defaultFileStorage = .inMemory
        $0.keychain = .uiTest(credentials: credentials)
    }

    @Shared(.servers)
    var servers

    @Shared(.selectedServer)
    var selectedServer

    $servers.withLock { $0 = [configuration.server] }
    $selectedServer.withLock { $0 = configuration.server }
}

private extension Keychain {

    static func uiTest(
        credentials: Credentials
    ) -> Self {
        let storage = LockIsolated([PdfPassword]())

        return Self(
            getCredentials: { _ in credentials },
            getPdfPasswords: { storage.value },
            setPdfPasswords: { storage.setValue($0) },
            storeCredentials: { _, _ in }
        )
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

```bash
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"
```

Expected: PASS, 2 tests.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementation/UITest Modules/ApiImplementationTests/UITest
git commit -m "feat: add UI test dependency bootstrap to ApiImplementation"
```

---

## Task 3: Launch hook in the real app

**Files:**
- Modify: `Modules/App/LessPaperApp.swift`

**Interfaces:**
- Consumes: `UITestConfiguration.fromEnvironment()` (Task 1), `prepareUITestDependencies` (Task 2).
- Produces: nothing new. Behaviour only.

`App` already depends on both `apiImplementation` and `apiInterface`, so no Tuist change is needed. There is no `AppTests` target; this task's verification is that the app still builds and launches unchanged without the environment variable, and Task 6 proves the hook works.

- [ ] **Step 1: Add the hook**

Modify `Modules/App/LessPaperApp.swift` — add `import ApiImplementation` to the imports and replace `init()`:

```swift
    init() {
        #if DEBUG
        if let configuration = UITestConfiguration.fromEnvironment() {
            prepareUITestDependencies(configuration)
        }
        #endif
        Self.store.send(.bootstrap)
    }
```

- [ ] **Step 2: Verify the app still builds**

```bash
mise exec -- tuist generate --no-open
mise exec -- tuist build "Less Paper" -d "iPhone 17 Pro"
```

Expected: Build Succeeded, no new warnings mentioning `LessPaperApp.swift`. The scheme is `"Less Paper"` — `App` is a target and `tuist build App` fails with "Couldn't find scheme". Regeneration is required after the helper edits, or xcodebuild reports "Supported platforms ... is empty".

- [ ] **Step 3: Verify a normal launch is unaffected**

```bash
mise exec -- tuist generate --no-open
```

Then run the "Less Paper" scheme on the iPhone 17 Pro simulator and confirm it shows the server list as before — no environment variable set means `fromEnvironment()` returns `nil` and nothing changes.

- [ ] **Step 4: Commit**

```bash
git add Modules/App/LessPaperApp.swift
git commit -m "feat: honour UI test configuration at launch"
```

---

## Task 4: `AppUITests` target and Tuist wiring

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`
- Create: `Modules/AppUITests/SmokeTests.swift`

**Interfaces:**
- Produces: the `Module.appUITests` case (raw value `"AppUITests"`), a target of product `.uiTests` whose test host is `App`, and its inclusion in the "Less Paper" scheme's test action.

`Module+Targets.swift` needs no change: `product` is derived from the module's own `product` property, and `bundleId`, `buildableFolders` and `settings` all fall through to their defaults.

- [ ] **Step 1: Write the failing test**

Create `Modules/AppUITests/SmokeTests.swift`:

```swift
import XCTest

@MainActor
final class SmokeTests: XCTestCase {

    func testAppLaunches() async throws {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 30))
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: FAIL — "The following targets were not found: AppUITests."

Note that `tuist generate` **succeeds** here: Tuist silently ignores a folder no `Module` case names, so generation is not the failing signal.

- [ ] **Step 3: Add the module case**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, add to the `Module` enum in alphabetical position, immediately after `case appFeatureTests`:

```swift
    case appUITests = "AppUITests"
```

Then add `appUITests` to the non-coverage list in `codeCoverageTarget`, alongside `.appFeatureTests`.

- [ ] **Step 4: Declare the product and test host**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, find the `product` property and add a case returning `.uiTests` for `.appUITests`, matching how the existing `*AppTests` modules are declared. Find the property that supplies the test host target and map `.appUITests` to `.app`.

If `product` and the test-host mapping are expressed as `switch self` over every case, add `.appUITests` to the same branch that already contains `.tagsAppTests`.

- [ ] **Step 5: Wire dependencies**

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add:

```swift
        case .appUITests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.app),
                .target(.uiTestSupport),
            ]
```

And replace the currently empty `uiTestSupport` dependency list:

```swift
        case .uiTestSupport:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
            ]
```

- [ ] **Step 6: Add to the "Less Paper" scheme**

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`, the `.app` case builds its test action from `Module.allTestableTargets`, which filters on `product == .unitTests` and therefore excludes UI tests. Append the UI test target explicitly:

```swift
                    testAction: .targets(
                        Module.allTestableTargets + [
                            .testableTarget(target: .target(.appUITests))
                        ],
                        arguments: .arguments(environmentVariables: .default),
                        options: .options(
                            language: .init(identifier: "en"),
                            region: "DE",
                            coverage: true,
                            codeCoverageTargets: Module.allCodeCoverageTargets
                        )
                    ),
```

Do not widen the `allTestableTargets` filter — that would sweep in `ShareAppTests`, which must stay on its own scheme.

- [ ] **Step 7: Run to verify it passes**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 1 test. The simulator boots, the app launches, and `SmokeTests.testAppLaunches` succeeds.

- [ ] **Step 8: Commit**

```bash
git add Tuist/ProjectDescriptionHelpers Modules/AppUITests
git commit -m "feat: add AppUITests target driving the real app"
```

---

## Task 5: Per-test user lifecycle

**Files:**
- Create: `Modules/UITestSupport/TestUser.swift`
- Create: `Modules/UITestSupport/UITestCase.swift`

**Interfaces:**
- Consumes: `UsersRepository.createUser(input:server:)` / `.deleteUser(id:server:)` / `.getUsers(input:server:)` (internal to `ApiImplementation`, reached via `@testable import`); `AuthenticationRepository.getToken(input:server:)`; `SaveUserInput`; `Permission.allCases`; `GetTokenInput(code:password:username:)`; `UITestConfiguration` (Task 1).
- Produces:
  - `TestUser.create() async throws -> TestUser`
  - `TestUser.delete() async throws`
  - `TestUser.sweepOrphans() async throws`
  - `TestUser.configuration: UITestConfiguration`
  - `TestUser.namespace: String`
  - `UITestCase` — an `XCTestCase` subclass exposing `app: XCUIApplication`, `user: TestUser`, `timeout: TimeInterval`, and `launch()`.

Two facts from probing the live server shape this file. Deleting a user does **not** delete objects it owns, so cleanup must delete objects first — that lands in Plan 2 per entity; here the user itself is removed and the sweep catches anything stranded by a crash. And the grant must be `Permission.allCases`; a user with no permissions is rejected outright rather than seeing an empty list.

- [ ] **Step 1: Write `TestUser`**

Create `Modules/UITestSupport/TestUser.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation

public struct TestUser: Sendable {

    public let configuration: UITestConfiguration

    public let id: User.Id

    public let namespace: String

    public static func create() async throws -> Self {
        let namespace = "uit-\(UUID().uuidString.prefix(8).lowercased())"
        let password = "T3st!\(UUID().uuidString.prefix(12))"
        let server = Server.testValue()

        let output = try await withAdminDependencies {
            @Dependency(\.usersRepository)
            var usersRepository

            return try await usersRepository.createUser(
                input: SaveUserInput(
                    email: "\(namespace)@example.com",
                    password: password,
                    userPermissions: Permission.allCases,
                    username: namespace
                ),
                server: server
            )
        }

        let token = try await withAdminDependencies {
            @Dependency(\.authenticationRepository)
            var authenticationRepository

            return try await authenticationRepository.getToken(
                input: GetTokenInput(
                    code: nil,
                    password: password,
                    username: namespace
                ),
                server: server
            ).token
        }

        return Self(
            configuration: UITestConfiguration(
                password: password,
                server: Server.testValue(username: namespace),
                token: token
            ),
            id: output.id,
            namespace: namespace
        )
    }

    public func delete() async throws {
        try await withAdminDependencies {
            @Dependency(\.usersRepository)
            var usersRepository

            _ = try await usersRepository.deleteUser(
                id: id,
                server: .testValue()
            )
        }
    }

    // A crashed or cancelled run leaves its user behind, and the container is long-lived across CI
    // runs. Sweeping at suite start keeps that from accumulating.
    public static func sweepOrphans() async throws {
        try await withAdminDependencies {
            @Dependency(\.usersRepository)
            var usersRepository

            let users = try await usersRepository.getUsers(
                input: .testValue(),
                server: .testValue()
            ).results

            for user in users where user.username.hasPrefix("uit-") {
                _ = try? await usersRepository.deleteUser(
                    id: user.id,
                    server: .testValue()
                )
            }
        }
    }
}

@discardableResult
public func withAdminDependencies<R>(
    isolation: isolated (any Actor)? = #isolation,
    operation: () async throws -> R
) async rethrows -> R {
    try await withDependencies {
        $0.authenticationProvider = .integrationTest
        $0.context = .live
    } operation: {
        try await operation()
    }
}
```

- [ ] **Step 2: Write `UITestCase`**

Create `Modules/UITestSupport/UITestCase.swift`:

```swift
import ApiInterface
import XCTest

@MainActor
open class UITestCase: XCTestCase {

    public let app = XCUIApplication()

    public let timeout = 10.0

    public private(set) var user: TestUser!

    // Launching without a configuration gives a virgin app — the state the onboarding journey needs.
    open func launch(configured: Bool = true) {
        if configured, let value = try? user.configuration.environmentValue() {
            app.launchEnvironment[UITestConfiguration.environmentKey] = value
        }
        app.launch()
    }

    override open func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
        user = try await TestUser.create()
    }

    override open func tearDown() async throws {
        try? await user?.delete()
        user = nil

        try await super.tearDown()
    }
}
```

- [ ] **Step 3: Prove it against the live container**

Replace the body of `Modules/AppUITests/SmokeTests.swift`:

```swift
import UITestSupport
import XCTest

@MainActor
final class SmokeTests: UITestCase {

    func testLaunchesConfiguredIntoTheApp() async throws {
        launch()

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout))
    }
}
```

- [ ] **Step 4: Run it**

Ensure the containers are up first:

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS. The injected configuration drives `AppReducer.bootstrap` straight past the server list into `MainView`, so the tab bar exists. If the tab bar never appears, the shared-state seeding in Task 2 is the thing to debug — not the test.

- [ ] **Step 5: Verify no user leaked**

```bash
curl -s -u admin:'T0PS3CR3T!!123' 'http://localhost:9000/api/users/' \
  | python3 -c "import json,sys; print([u['username'] for u in json.load(sys.stdin)['results']])"
```

Expected: `['admin']` — no `uit-*` user remains. Port 9000 is the `paperless-ci` instance the tests
target via `PAPERLESS_TEST_URL`; 8000 is the dev instance and would always look clean.

- [ ] **Step 6: Commit**

```bash
git add Modules/UITestSupport Modules/AppUITests
git commit -m "feat: add per-test Paperless user lifecycle for UI tests"
```

---

## Task 6: Journey 1 — onboarding

**Files:**
- Create: `Modules/UITestSupport/Screens/ServerFormScreen.swift`
- Create: `Modules/AppUITests/OnboardingJourneyTests.swift`
- Delete: `Modules/AppUITests/SmokeTests.swift`

**Interfaces:**
- Consumes: `UITestCase` and `TestUser` (Task 5).
- Produces: `ServerFormScreen(app:)` with `addServer(alias:url:username:password:)`.

This is the journey the whole rework exists for: a virgin app, the real add-server form, the real `negotiateApiVersion`, and the real `StoreTokenUseCase` keychain write — none of which any harness app has ever exercised. It launches **unconfigured**.

The element queries below are a first cut taken from `ServersAppTests` and `ServerFormView`. **Expect to adjust them**, and expect some to need accessibility identifiers added to the view — that is the known unsized risk in the spec, and this task is where it surfaces first. Add identifiers to the view rather than writing brittle index-based queries.

- [ ] **Step 1: Write the screen driver**

Create `Modules/UITestSupport/Screens/ServerFormScreen.swift`:

```swift
import XCTest

@MainActor
public struct ServerFormScreen {

    public let app: XCUIApplication

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.timeout = timeout
    }

    @discardableResult
    public func addServer(
        alias: String,
        url: String,
        username: String,
        password: String
    ) -> Bool {
        let addButton = app.buttons["Add server"].firstMatch
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        type(alias, into: app.textFields["Alias"])
        type(url, into: app.textFields["URL"])
        type(username, into: app.textFields["Username"])
        type(password, into: app.secureTextFields["Password"])

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    private func type(
        _ text: String,
        into element: XCUIElement
    ) {
        guard element.waitForExistence(timeout: timeout) else {
            return
        }
        element.tap()
        element.typeText(text)
    }
}
```

- [ ] **Step 2: Write the failing journey**

Create `Modules/AppUITests/OnboardingJourneyTests.swift`:

```swift
import ApiInterface
import UITestSupport
import XCTest

@MainActor
final class OnboardingJourneyTests: UITestCase {

    func testAddingAServerReachesTheDocumentList() async throws {
        launch(configured: false)

        let screen = ServerFormScreen(app: app, timeout: timeout)

        XCTAssertTrue(
            screen.addServer(
                alias: user.namespace,
                url: URL.testValue().absoluteString,
                username: user.namespace,
                password: user.configuration.password
            )
        )

        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: timeout))
    }
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: FAIL. Record *how* it fails — a missing element means an accessibility identifier is needed; a visible error in the app means the negotiation or credential path is genuinely broken.

- [ ] **Step 4: Make it pass**

Adjust the queries in `ServerFormScreen` to match `ServerFormView`, adding accessibility identifiers to that view where a label is ambiguous or absent. Change only what the test needs.

- [ ] **Step 5: Run to verify it passes**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS.

- [ ] **Step 6: Delete the smoke test**

`SmokeTests` existed to prove the target wiring. The onboarding journey now covers strictly more.

```bash
rm Modules/AppUITests/SmokeTests.swift
```

- [ ] **Step 7: Commit**

```bash
git add -A Modules/AppUITests Modules/UITestSupport Modules/ServersFeature
git commit -m "test: add onboarding journey driving the real add-server flow"
```

---

## Task 7: Journey 3 — settings overview

**Files:**
- Create: `Modules/UITestSupport/Screens/SettingsScreen.swift`
- Create: `Modules/AppUITests/SettingsJourneyTests.swift`

**Interfaces:**
- Consumes: `UITestCase` (Task 5).
- Produces: `SettingsScreen(app:timeout:)` with `open()` and `openTags()`.

`SettingListView` renders eight `NavigationLink`s — Servers, Correspondents, Custom fields, Document types, PDF passwords, Saved views, Storage paths, Tags — plus Import, Scan, Licenses and the app version. Reaching them is: select the Settings tab, then tap the row.

- [ ] **Step 1: Write the screen driver**

Create `Modules/UITestSupport/Screens/SettingsScreen.swift`:

```swift
import XCTest

@MainActor
public struct SettingsScreen {

    public let app: XCUIApplication

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.timeout = timeout
    }

    @discardableResult
    public func open() -> Bool {
        let tab = app.tabBars.buttons["Settings"].firstMatch
        guard tab.waitForExistence(timeout: timeout) else {
            return false
        }
        tab.tap()
        return app.staticTexts["Tags"].waitForExistence(timeout: timeout)
    }

    @discardableResult
    public func openTags() -> Bool {
        let row = app.staticTexts["Tags"].firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            return false
        }
        row.tap()
        return true
    }
}
```

- [ ] **Step 2: Write the failing journey**

Create `Modules/AppUITests/SettingsJourneyTests.swift`:

```swift
import UITestSupport
import XCTest

@MainActor
final class SettingsJourneyTests: UITestCase {

    func testSettingsListsEverySection() async throws {
        launch()

        let screen = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(screen.open())

        for section in [
            "Servers",
            "Correspondents",
            "Custom fields",
            "Document types",
            "PDF passwords",
            "Saved views",
            "Storage paths",
            "Tags",
            "Licenses"
        ] {
            XCTAssertTrue(
                app.staticTexts[section].exists,
                "Missing settings section: \(section)"
            )
        }
    }
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: FAIL on whichever labels differ from the real localised strings.

- [ ] **Step 4: Make it pass**

Correct the expected strings against `SettingListView` and the `en` localisation. Do not change the view to match the test — the localised copy is the source of truth here.

- [ ] **Step 5: Run to verify it passes**

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/AppUITests/SettingsJourneyTests.swift Modules/UITestSupport/Screens/SettingsScreen.swift
git commit -m "test: add settings overview journey"
```

---

## Task 8: Journey 4 — tag lifecycle, and retire `TagsApp`

**Files:**
- Create: `Modules/UITestSupport/Screens/TagListScreen.swift`
- Create: `Modules/AppUITests/TagLifecycleJourneyTests.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`, `Module+InfoPlists.swift`
- Modify: `AGENTS.md`
- Delete: `Modules/TagsApp/`, `Modules/TagsAppTests/`

**Interfaces:**
- Consumes: `UITestCase`, `SettingsScreen` (Task 7).
- Produces: `TagListScreen(app:timeout:)` with `createTag(named:)`, `editTag(named:to:)`, `deleteTag(named:)`.

This journey threads create → appears → edit → delete in one launch, replacing `TagsAppTests.testCreate`, `.testList`, `.testUpdate` and `.testDelete`. `testDeleteFailure` is **not** replaced here — it becomes journey 10 in Plan 2, which covers all five entities at once.

Because the test user owns nothing at start, the tag list begins empty. That is the isolation win: no `deleteAllTags()`, and no ambiguity about which row is ours.

- [ ] **Step 1: Write the screen driver**

Create `Modules/UITestSupport/Screens/TagListScreen.swift`:

```swift
import XCTest

@MainActor
public struct TagListScreen {

    public let app: XCUIApplication

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.timeout = timeout
    }

    @discardableResult
    public func createTag(named name: String) -> Bool {
        let addButton = app.buttons["Add tag"].firstMatch
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        let field = app.textFields["Name"]
        guard field.waitForExistence(timeout: timeout) else {
            return false
        }
        field.tap()
        field.typeText(name)

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func editTag(named name: String, appending suffix: String) -> Bool {
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        guard cell.waitForExistence(timeout: timeout) else {
            return false
        }
        app.tapSwipeAction("Edit tag", in: cell, timeout: timeout)

        let field = app.textFields["Name"]
        guard field.waitForExistence(timeout: timeout) else {
            return false
        }
        field.tap()
        field.typeText(suffix)

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func deleteTag(named name: String) -> Bool {
        let cell = app.cells.containing(.staticText, identifier: name).firstMatch
        guard cell.waitForExistence(timeout: timeout) else {
            return false
        }
        app.tapSwipeAction("Delete tag", in: cell, timeout: timeout)

        let confirm = app.buttons["Confirm"].firstMatch
        guard confirm.waitForExistence(timeout: timeout) else {
            return false
        }
        confirm.tap()
        return cell.waitForNonExistence(timeout: timeout)
    }
}
```

`tapSwipeAction` already exists in `Modules/UITestSupport/Extensions/XCUIApplication+SwipeActions.swift`.

- [ ] **Step 2: Write the failing journey**

Create `Modules/AppUITests/TagLifecycleJourneyTests.swift`:

```swift
import UITestSupport
import XCTest

@MainActor
final class TagLifecycleJourneyTests: UITestCase {

    func testCreateEditAndDeleteATag() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open())
        XCTAssertTrue(settings.openTags())

        let tags = TagListScreen(app: app, timeout: timeout)
        let name = "\(user.namespace)-tag"

        XCTAssertTrue(tags.createTag(named: name))
        XCTAssertTrue(app.staticTexts[name].waitForExistence(timeout: timeout))

        XCTAssertTrue(tags.editTag(named: name, appending: " Updated"))
        XCTAssertTrue(app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout))

        XCTAssertTrue(tags.deleteTag(named: "\(name) Updated"))
        XCTAssertFalse(app.staticTexts["\(name) Updated"].exists)
    }
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: FAIL.

- [ ] **Step 4: Make it pass**

Adjust queries against `TagListView` and `TagFormView`, adding accessibility identifiers where needed.

- [ ] **Step 5: Run to verify it passes**

Expected: PASS, 3 journeys total in `AppUITests`.

- [ ] **Step 6: Commit the journey**

```bash
git add Modules/AppUITests/TagLifecycleJourneyTests.swift Modules/UITestSupport/Screens/TagListScreen.swift
git commit -m "test: add tag lifecycle journey against the real app"
```

- [ ] **Step 7: Delete the TagsApp harness**

```bash
git rm -r Modules/TagsApp Modules/TagsAppTests
```

Then remove from `Tuist/ProjectDescriptionHelpers/`:
- `Module.swift`: the `tagsApp` and `tagsAppTests` enum cases, and their entries in `codeCoverageTarget` and `product`.
- `Module+Dependencies.swift`: the `case .tagsApp:` and `case .tagsAppTests:` blocks.
- `Module+Schemes.swift`: `tagsApp` from the feature-app scheme case list, `tagsApp`/`tagsAppTests` from the empty-scheme case list, and the `case .tagsApp:` branch of `featureAppTestTargets`.
- `Module+InfoPlists.swift`: the `TagsApp` entry, including its `PAPERLESS_TEST_URL` injection.

- [ ] **Step 8: Verify the project still generates and the full suite passes**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro"
```

Expected: PASS. `TagsFeatureTests` still runs — only the harness app and its XCUITests are gone.

- [ ] **Step 9: Record the isolation contract**

Append to `AGENTS.md`:

```markdown
## UI tests never mutate global server state

UI tests in `AppUITests` drive the real app against the Paperless container in `docker/`. Each test
creates its own Paperless user, so every tag, correspondent, document type, storage path and saved
view it creates is owned by that user and invisible to every other test. The list a test sees starts
empty.

**Never write a helper that deletes all of something.** `deleteAllTags()` and its kind are why the
old harness suites could not run in parallel, and they are gone.

Two exceptions, both verified against paperless-ngx 3.0.5:

- **Custom fields have no owner** and are global. Namespace them by name — `uit-<id>-<label>` — and
  never assert on the total count of the custom field list.
- **Documents consumed from `docker/consume/` have no owner** and form a shared read-only corpus.
  Read from it freely; a test that needs to *modify* a document must upload its own first.
```

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "refactor: retire the TagsApp UI test harness"
```

---

## Self-Review

**Spec coverage.** Sequence step 1 → Tasks 1–3. Step 2 → Tasks 4–6. The first slice of step 3 → Tasks 7–8. Step 6's `AGENTS.md` entry is pulled forward into Task 8 Step 9, because the contract needs to be written down the moment the first harness dies rather than after the last one. Steps 4, 5 and 7, and journeys 2 and 5–12, are Plan 2 — stated in Scope above.

**Placeholder scan.** No TBD/TODO. Every code step carries the code. Tasks 6, 7 and 8 direct the implementer to *adjust element queries after observing a real failure* — that is a genuine empirical step, not a placeholder: the spec identifies accessibility identifiers as the one cost that cannot be known before a journey runs, and each of those tasks pins down exactly what to run, what failure to expect, and which file to change.

**Type consistency.** `UITestConfiguration(password:server:token:)` is constructed identically in Tasks 1, 2 and 5. `environmentKey` is referenced in Tasks 1, 2 and 5 and defined once. `prepareUITestDependencies(_:)` is defined in Task 2 and called in Task 3. `TestUser.namespace` and `.configuration.password` are produced in Task 5 and consumed in Tasks 6 and 8. `SettingsScreen` is produced in Task 7 and consumed in Task 8. All screen drivers share the `init(app:timeout:)` shape.

**Known gap, deliberately left.** Task 5's `tearDown` deletes the user but not the objects it owns — probe 4 showed deletion does not cascade, so a tag created by journey 4 outlives its user as an orphan owned by a deleted account. This is invisible to other tests (nothing queries it, and the list a new user sees is still empty) and does not affect correctness. Per-entity object cleanup belongs with the per-entity fixture helpers in Plan 2; adding it here would mean writing five entity cleanup paths to serve one journey.
