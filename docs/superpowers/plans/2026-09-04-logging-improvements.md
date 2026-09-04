# Logging improvements implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Stop the log leaking server hostnames, cap it at 10,000 lines, and add launch, cache,
connection and lifecycle lines so an uneventful log is evidence rather than a blank page.

**Architecture:** The `Logging` module keeps its shape — a `LogClient` dependency over a `LogWriter`
actor — and gains two small dependency clients of its own: `DeviceContext` for launch facts and
`StorageUsageClient` for measuring files on disk. `ImageFeature` exposes the Nuke disk cache's size
through `ImageCacheUsage` so `AppFeature` can report it without importing Nuke. Every new line is
written from the module that already owns the fact, and no line anywhere contains a hostname.

**Tech Stack:** Swift 6, Swift Testing, `swift-dependencies` (`@DependencyClient`,
`withDependencies`), `swift-composable-architecture` (`TestStore`), `swift-sharing` (`@Shared`),
Nuke (`DataCache`), Tuist.

**Spec:** `docs/superpowers/specs/2026-09-04-logging-improvements-design.md`

## Global Constraints

- **Comments:** Never `///`, never `/** */`. Only `//`, and only when a future reader would
  otherwise stop and wonder why the code is the way it is. See `AGENTS.md`. Existing `///` comments
  in files you touch are not yours to convert unless you are rewriting that declaration anyway.
- **No hostname in any log message, ever.** Not redacted, not hashed, not truncated. If a message
  needs a URL, it goes through `LogRedaction.redact(_:)`, which returns path and query only.
- **Line cap:** `LogWriter.maximumLines` default `10_000`, trim triggered above `11_000`. Copy these
  exact numbers; do not inline the literals anywhere else.
- **Category rule:** a line about this app on this device is `.app` (launch, cache sizes, scene
  phase, memory warnings). A line about the app's relationship with a paperless instance is
  `.server` (connecting, cache update, OIDC discovery, certificate approval).
- **Separator in composed log lines:** ` · ` (space, U+00B7 MIDDLE DOT, space). `LogWriter` splits
  parsed columns on a double space, so never use two consecutive spaces inside a message.
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro"`. Scheme names match the
  module: `Logging`, `ImageFeature`, `AppFeature`, `ApiImplementation`, `ServersFeature`,
  `CertificatesFeature`, `SettingsFeature`.
- **New `.swift` files need no Tuist edit.** Targets glob their module directory. Changing which
  *modules* a module depends on edits `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`,
  and after editing it run `mise exec -- tuist generate` before building.
- **`@ViewAction` views send with `send`, never `store.send`.** `AppView` is not annotated, so it
  keeps using `store.send`.
- **`LogClient.testValue` is a no-op**, so any test asserting on log output must override
  `$0.log.record` and record the calls itself. Every logging assertion in this plan uses the same
  three-line closure appending to a `LockIsolated<[String]>`.

---

### Task 1: Stop the OIDC hostname leak

The headline fix. The log call inside the actor is deleted outright and replaced by an
outcome-only line written from the reducer, which is the one place that can tell discovery from
`login`'s preflight and that already knows the previous outcome.

**Files:**
- Modify: `Modules/ApiImplementation/Authentication/OIDC/OIDCClient+Live.swift:48` (delete the log
  call) and `:132-134` (delete the now-unused dependency)
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer.swift` (state field, log on
  `.providersLoaded`)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (`serversFeature` gains
  `.target(.logging)`; `serversFeatureTests` gains `.target(.logging)`)
- Test: Modify `Modules/ServersFeatureTests/ServerForm/ProviderLoadingTests.swift`
- Test: Modify `Modules/ApiImplementationTests/Authentication/OIDCSessionTests.swift`
- Test: Modify `Modules/LoggingTests/LogRedactionTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `ServerFormReducer.State.lastLoggedProviderCount: Int?`

Every test in this plan that asserts on logging overrides `$0.log.record` inline with a three-line
closure appending to a `LockIsolated<[String]>`. A shared helper was considered and rejected: the
suites live in seven different test targets, so it would need its own test-support target to be
importable, and the helper is shorter than the import.

- [ ] **Step 1: Write the failing test for the outcome line**

Add to `Modules/ServersFeatureTests/ServerForm/ProviderLoadingTests.swift`:

```swift
    @Test
    func test_providersLoaded_logsTheCountOnce() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([.testValue(), .testValue(id: "other")]))

        #expect(messages.value == ["OIDC discovery: 2 providers"])
    }

    @Test
    func test_providersLoaded_logsNoneOnTheFirstEmptyResult() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([]))

        #expect(messages.value == ["OIDC discovery: none"])
    }

    // Typing an address passes through several settled prefixes, each of which fails discovery the
    // same way. One line is the answer; six is noise that pushes real evidence out of the file.
    @Test
    func test_providersLoaded_doesNotRepeatAnUnchangedOutcome() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([]))
        await store.send(.providersLoaded([]))
        await store.send(.providersLoaded([]))

        #expect(messages.value == ["OIDC discovery: none"])
    }

    @Test
    func test_providersLoaded_logsAgainWhenTheOutcomeChanges() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([]))
        await store.send(.providersLoaded([.testValue()]))

        #expect(messages.value == ["OIDC discovery: none", "OIDC discovery: 1 provider"])
    }
```

`OIDCProvider.testValue(clientId:configurationURL:id:name:)` already exists in
`Modules/ApiInterface/Authentication/OIDC/OIDCProvider.swift` with every parameter defaulted, so
`.testValue(id: "other")` builds the second, distinct provider the first test needs. No fixture
work required.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ServersFeature -d "iPhone 17 Pro"`
Expected: FAIL — the four new tests see an empty `messages` array.

- [ ] **Step 3: Add the state field**

In `Modules/ServersFeature/ServerForm/ServerFormReducer.swift`, inside `State`, after `providersURL`:

```swift
        // Distinct from `providers`, which is cleared to [] before every load: comparing against
        // that would suppress the first "none" - the one worth having - while still logging later
        // ones. nil means nothing has been logged for this form yet.
        var lastLoggedProviderCount: Int?
```

- [ ] **Step 4: Log the outcome in the reducer**

Replace the `.providersLoaded` case in the same file:

```swift
            case let .providersLoaded(providers):
                state.providers = providers
                if state.lastLoggedProviderCount != providers.count {
                    state.lastLoggedProviderCount = providers.count
                    log.info(Self.discoveryMessage(count: providers.count), category: .server)
                }
                return .none
```

Add the message builder and the dependency at the bottom of the type, beside the existing
`@Dependency(\.dismiss)`:

```swift
    static func discoveryMessage(count: Int) -> String {
        switch count {
        case 0: "OIDC discovery: none"
        case 1: "OIDC discovery: 1 provider"
        default: "OIDC discovery: \(count) providers"
        }
    }

    @Dependency(\.log)
    private var log
```

Add `import Logging` to the file's imports, in alphabetical order.

- [ ] **Step 5: Delete the leaking call**

In `Modules/ApiImplementation/Authentication/OIDC/OIDCClient+Live.swift`, the `catch` block of
`providers(url:)` becomes bare:

```swift
        } catch {
            // Deliberately silent. A server with no single sign-on, one that is not paperless, and
            // one that cannot be reached are the same answer here, and the only line that could
            // distinguish them is the one that used to carry the user's hostname. ServerFormReducer
            // logs the outcome instead - from the one place that can tell discovery from the
            // preflight this method also serves.
            return []
        }
```

Then delete the now-unused dependency at the bottom of the file:

```swift
    @Dependency(\.log)
    private var log
```

Remove `import Logging` from that file if nothing else in it uses the module — grep the file for
`log` before deleting the import.

- [ ] **Step 6: Add the regression test that the actor writes nothing**

Add to `Modules/ApiImplementationTests/Authentication/OIDCSessionTests.swift`. Match the existing
suite's setup for stubbing the network — `OIDCStubProtocol` is already there; follow how the
neighbouring tests configure a failing response:

```swift
    // The hostname leak was this call site. A test that only checked the host was absent would pass
    // against a line that still carried the error text, and the error text is what made the host
    // look necessary. Nothing at all is the requirement.
    @Test
    func test_providers_writesNothingToTheLog() async {
        let messages = LockIsolated<[String]>([])

        await withDependencies {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            _ = await OIDCSession.shared.providers(url: URL(string: "https://paperless.example.com")!)
        }

        #expect(messages.value.isEmpty)
    }
```

- [ ] **Step 7: Add the redaction guard**

Add to `Modules/LoggingTests/LogRedactionTests.swift`:

```swift
    // The rule the OIDC line broke: a URL reaching the log through redact() never carries its host.
    @Test(arguments: [
        "https://paperless.example.com/api/documents/?page=2",
        "http://paperless.internal:8000/api/tags/",
        "https://docs.someones-surname.dev/api/auth/headless/app/v1/config",
    ])
    func test_redact_neverKeepsTheHost(address: String) throws {
        let url = try #require(URL(string: address))
        let host = try #require(url.host())

        #expect(!LogRedaction.redact(url).contains(host))
    }
```

- [ ] **Step 8: Declare the new module dependency**

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add `.target(.logging),` to the
`case .serversFeature:` array and to `case .serversFeatureTests:`, keeping each list alphabetical.
`ServersFeature` already reaches `Logging` transitively through `DiagnosticsFeature`, but a module
that imports it should declare it.

Then run: `mise exec -- tuist generate`

- [ ] **Step 9: Run the tests to verify they pass**

Run:
```
mise exec -- tuist test ServersFeature -d "iPhone 17 Pro"
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"
mise exec -- tuist test Logging -d "iPhone 17 Pro"
```
Expected: PASS, all three.

- [ ] **Step 10: Commit**

```bash
git add Modules/ApiImplementation Modules/ServersFeature Modules/ServersFeatureTests \
        Modules/ApiImplementationTests Modules/LoggingTests Tuist/ProjectDescriptionHelpers
git commit -m "fix: stop logging server hostnames from OIDC discovery"
```

---

### Task 2: Cap the log at 10,000 lines

**Files:**
- Modify: `Modules/Logging/LogWriter.swift`
- Test: Modify `Modules/LoggingTests/LogWriterTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `LogWriter.init(directory:fileManager:maximumLines:)` replacing the `maximumSize:`
  parameter. `fileURLs()` returns at most one URL.

- [ ] **Step 1: Write the failing tests**

In `Modules/LoggingTests/LogWriterTests.swift`, **delete** the two rotation tests
(`test_rotation_doesNotHappenBelowTheLimit`, `test_rotation_keepsTheOlderFileReadable`) and change
`test_clear_removesEverything` to construct `LogWriter(directory:)` with no size argument. Then add:

```swift
    @Test
    func test_record_keepsEveryLineBelowTheTrimThreshold() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)

        for index in 1 ... 10 {
            await writer.record("line \(index)", level: .info, category: .api)
        }

        #expect(await writer.entries().count == 10)
    }

    // The trim fires above maximumLines + 10%, not at maximumLines: rewriting the file on every
    // write past the cap is what the high-water mark exists to avoid.
    @Test
    func test_record_trimsToTheCapOnceTheThresholdIsCrossed() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)
        let start = Date(timeIntervalSince1970: 1_000_000)

        for index in 1 ... 12 {
            await writer.record(
                "line \(index)",
                level: .info,
                category: .api,
                date: start.addingTimeInterval(TimeInterval(index))
            )
        }

        let entries = await writer.entries()

        #expect(entries.count == 10)
        #expect(entries.first?.message == "line 12")
        #expect(entries.last?.message == "line 3")
        #expect(!entries.contains { $0.message == "line 1" })
    }

    @Test
    func test_record_leavesTheFileParseableAfterATrim() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)

        for index in 1 ... 12 {
            await writer.record("line \(index)", level: .warning, category: .storage)
        }

        let entries = await writer.entries()

        #expect(entries.allSatisfy { $0.level == .warning })
        #expect(entries.allSatisfy { $0.category == .storage })
    }

    @Test
    func test_fileURLs_returnsASingleFile() async {
        let writer = LogWriter(directory: Self.temporaryDirectory(), maximumLines: 10)

        for index in 1 ... 12 {
            await writer.record("line \(index)", level: .info, category: .api)
        }

        #expect(await writer.fileURLs().count == 1)
    }

    // A writer created against a directory that already holds a log must not start counting from
    // zero, or the file grows without bound across launches - which is the whole bug this replaces.
    @Test
    func test_record_countsLinesAlreadyOnDiskFromAPreviousLaunch() async {
        let directory = Self.temporaryDirectory()

        let first = LogWriter(directory: directory, maximumLines: 10)
        for index in 1 ... 9 {
            await first.record("old \(index)", level: .info, category: .api)
        }

        let second = LogWriter(directory: directory, maximumLines: 10)
        for index in 1 ... 3 {
            await second.record("new \(index)", level: .info, category: .api)
        }

        #expect(await second.entries().count == 10)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test Logging -d "iPhone 17 Pro"`
Expected: FAIL — `maximumLines` is not a parameter of `LogWriter.init`.

- [ ] **Step 3: Replace size rotation with the line cap**

In `Modules/Logging/LogWriter.swift`:

Change the initialiser signature and stored properties — `maximumSize` becomes `maximumLines`:

```swift
    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default,
        maximumLines: Int = 10_000
    ) {
        self.fileManager = fileManager
        self.maximumLines = maximumLines
        // Caches, as the old app used: the system may reclaim it under storage pressure, which is
        // the right trade for diagnostics. They must never be why a document cannot be saved.
        self.directory = directory ?? fileManager
            .urls(for: .cachesDirectory, in: .userDomainMask)
            .last!
            .appending(path: "log")
    }
```

Replace `private let maximumSize: Int` with:

```swift
    private let maximumLines: Int

    // Counted once from disk on the first write of a process, then tracked in memory. Recounting
    // per write would mean reading the whole file to append one line.
    private var lineCount: Int?
```

Delete `private var rotatedURL: URL { … }` and `rotateIfNeeded(adding:)` entirely.

Rewrite `append(_:)` and add the trim:

```swift
    private func append(_ line: String) {
        guard let data = line.data(using: .utf8) else {
            return
        }

        try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        if let handle = try? FileHandle(forWritingTo: currentURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: currentURL)
        }

        lineCount = (lineCount ?? contents(of: currentURL).count - 1) + 1
        trimIfNeeded()
    }

    // Above the cap plus a tenth, not at the cap: trimming on every write past 10,000 would mean
    // rewriting the whole file for each line. The overshoot is bounded and the cap still holds.
    private func trimIfNeeded() {
        guard let count = lineCount, count > maximumLines + maximumLines / 10 else {
            return
        }

        let kept = contents(of: currentURL).suffix(maximumLines)
        try? kept.joined(separator: "\n").appending("\n").write(to: currentURL, atomically: true, encoding: .utf8)
        lineCount = kept.count
    }
```

Note on the `lineCount` seed: `append` has already written the new line by the time the count is
taken, so seeding subtracts it before adding it back — the expression reads oddly and is why the
"counts lines already on disk" test exists.

Narrow the readers to the single file:

```swift
    public func entries() -> [LogEntry] {
        contents(of: currentURL)
            .compactMap(Self.parse)
            .sorted { $0.date > $1.date }
    }

    public func fileURLs() -> [URL] {
        [currentURL].filter { fileManager.fileExists(atPath: $0.path()) }
    }

    public func clear() {
        try? fileManager.removeItem(at: currentURL)
        lineCount = nil
    }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mise exec -- tuist test Logging -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 5: Check nothing else referenced the rotated file**

Run: `grep -rn "error.1.log\|maximumSize\|rotated" --include=*.swift Modules`
Expected: no matches outside comments you have already rewritten. `DiagnosticsListReducer` reads
`fileURLs()` and needs no change — it shares whatever it is given.

- [ ] **Step 6: Commit**

```bash
git add Modules/Logging Modules/LoggingTests
git commit -m "feat: cap the log at 10,000 lines instead of 1 MB"
```

---

### Task 3: `LogCategory.app` and `DeviceContext`

**Files:**
- Modify: `Modules/Logging/LogCategory.swift`
- Create: `Modules/Logging/DeviceContext.swift`
- Modify: `Modules/SettingsFeature/SettingList/GetAppVersionUseCase.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (`settingsFeature` gains
  `.target(.logging)`)
- Test: Create `Modules/LoggingTests/DeviceContextTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `LogCategory.app`
  - `public struct DeviceContext: Sendable` with `appName`, `appVersion`, `appBuild`,
    `systemVersion`, `deviceModel`, `locale`, `buildConfiguration` — each
    `@Sendable () -> String` — and `func launchLine() -> String`
  - `DependencyValues.deviceContext`

- [ ] **Step 1: Add the category**

In `Modules/Logging/LogCategory.swift`, add `case app` as the first case, keeping the list
alphabetical:

```swift
public enum LogCategory: String, CaseIterable, Sendable {
    case app
    case api
    case documents
    case server
    case share
    case storage
    case tips
}
```

- [ ] **Step 2: Write the failing test**

Create `Modules/LoggingTests/DeviceContextTests.swift`:

```swift
@testable import Logging

import Dependencies
import Foundation
import Testing

@Suite
struct DeviceContextTests {

    @Test
    func test_launchLine_readsAsOneScannableLine() {
        let context = DeviceContext(
            appName: { "LessPaper" },
            appVersion: { "2.4.1" },
            appBuild: { "312" },
            systemVersion: { "26.0" },
            deviceModel: { "iPhone17,2" },
            locale: { "de_DE" },
            buildConfiguration: { "release" }
        )

        #expect(context.launchLine() == "LessPaper 2.4.1 (312) · iOS 26.0 · iPhone17,2 · de_DE · release")
    }

    // LogWriter splits parsed columns on a double space, so a message containing one would come
    // back from entries() with its tail in the wrong field.
    @Test
    func test_launchLine_containsNoDoubleSpace() {
        let context = DeviceContext(
            appName: { "LessPaper" },
            appVersion: { "2.4.1" },
            appBuild: { "312" },
            systemVersion: { "26.0" },
            deviceModel: { "iPhone17,2" },
            locale: { "de_DE" },
            buildConfiguration: { "release" }
        )

        #expect(!context.launchLine().contains("  "))
    }

    @Test
    func test_liveValue_answersSomethingForEveryField() {
        let context = DeviceContext.liveValue

        #expect(!context.appVersion().isEmpty)
        #expect(!context.systemVersion().isEmpty)
        #expect(!context.deviceModel().isEmpty)
        #expect(!context.locale().isEmpty)
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `mise exec -- tuist test Logging -d "iPhone 17 Pro"`
Expected: FAIL — `DeviceContext` does not exist.

- [ ] **Step 4: Write `DeviceContext`**

Create `Modules/Logging/DeviceContext.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

// The facts every support thread opens by asking for. A dependency rather than free functions so a
// test can assert the line without its answer depending on the simulator it happens to run on.
@DependencyClient
public struct DeviceContext: Sendable {

    public var appName: @Sendable () -> String = { "LessPaper" }

    public var appVersion: @Sendable () -> String = { "0.0.0" }

    public var appBuild: @Sendable () -> String = { "0" }

    public var systemVersion: @Sendable () -> String = { "0.0" }

    public var deviceModel: @Sendable () -> String = { "unknown" }

    public var locale: @Sendable () -> String = { "en_US" }

    public var buildConfiguration: @Sendable () -> String = { "release" }

    public func launchLine() -> String {
        [
            "\(appName()) \(appVersion()) (\(appBuild()))",
            "iOS \(systemVersion())",
            deviceModel(),
            locale(),
            buildConfiguration(),
        ]
        .joined(separator: " · ")
    }
}

extension DeviceContext: DependencyKey {

    public static let liveValue = Self(
        appName: { Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "LessPaper" },
        appVersion: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" },
        appBuild: { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" },
        systemVersion: {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        },
        deviceModel: { modelIdentifier() },
        locale: { Locale.current.identifier },
        buildConfiguration: {
            #if DEBUG
            "debug"
            #else
            "release"
            #endif
        }
    )

    // The raw identifier, not UIDevice.model - which answers "iPhone" for every iPhone ever made -
    // and not a marketing-name lookup table, which goes stale every September.
    private static func modelIdentifier() -> String {
        // A simulator's uname reports the host architecture, so the identifier of the device being
        // simulated has to come from the environment instead.
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }

        var info = utsname()
        uname(&info)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(
                to: CChar.self,
                capacity: MemoryLayout.size(ofValue: info.machine)
            ) {
                String(cString: $0)
            }
        }
    }
}

extension DeviceContext: TestDependencyKey {

    public static let previewValue = testValue

    public static let testValue = Self(
        appName: { "LessPaper" },
        appVersion: { "1.0.0" },
        appBuild: { "1" },
        systemVersion: { "26.0" },
        deviceModel: { "iPhone17,2" },
        locale: { "en_US" },
        buildConfiguration: { "debug" }
    )
}

public extension DependencyValues {

    var deviceContext: DeviceContext {
        get { self[DeviceContext.self] }
        set { self[DeviceContext.self] = newValue }
    }
}
```

- [ ] **Step 5: Run the test to verify it passes**

Run: `mise exec -- tuist test Logging -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 6: Make `GetAppVersionUseCase` delegate, so one place reads the bundle**

`SettingsFeature` already reaches `Logging` transitively through `DiagnosticsFeature`. Add
`.target(.logging),` to `case .settingsFeature:` in `Module+Dependencies.swift`, then run
`mise exec -- tuist generate`.

Replace the private `execute` in `Modules/SettingsFeature/SettingList/GetAppVersionUseCase.swift`:

```swift
private extension GetAppVersionUseCase {
    static func execute() -> String {
        @Dependency(\.deviceContext)
        var deviceContext

        return [deviceContext.appVersion(), deviceContext.appBuild()]
            .joined(separator: "-")
    }
}
```

and add `import Logging` to that file. The returned format — `2.4.1-312` — is unchanged, so
`SettingListReducer` and its snapshots need no edit.

- [ ] **Step 7: Run the settings tests to verify nothing regressed**

Run: `mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Modules/Logging Modules/LoggingTests Modules/SettingsFeature Tuist/ProjectDescriptionHelpers
git commit -m "feat: add DeviceContext and an app log category"
```

---

### Task 4: `StorageUsageClient`

**Files:**
- Create: `Modules/Logging/StorageUsage.swift`
- Test: Create `Modules/LoggingTests/StorageUsageTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `public struct StorageUsage: Equatable, Sendable` with `bytes: Int`, `fileCount: Int`,
    `static let zero`, `func formatted() -> String` and `func formattedBytes() -> String`
  - `public struct StorageUsageClient: Sendable` with `measure: @Sendable ([URL]) -> StorageUsage`
  - `DependencyValues.storageUsage`

- [ ] **Step 1: Write the failing test**

Create `Modules/LoggingTests/StorageUsageTests.swift`:

```swift
@testable import Logging

import Foundation
import Testing

@Suite
struct StorageUsageTests {

    @Test
    func test_measure_sumsTheFilesInADirectory() throws {
        let directory = try Self.directory(withFiles: ["a": 100, "b": 250])

        let usage = StorageUsageClient.liveValue.measure([directory])

        #expect(usage.fileCount == 2)
        #expect(usage.bytes == 350)
    }

    @Test
    func test_measure_descendsIntoSubdirectories() throws {
        let directory = try Self.directory(withFiles: ["a": 100])
        let nested = directory.appending(path: "nested")
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try Data(count: 40).write(to: nested.appending(path: "b"))

        let usage = StorageUsageClient.liveValue.measure([directory])

        #expect(usage.fileCount == 2)
        #expect(usage.bytes == 140)
    }

    @Test
    func test_measure_acceptsIndividualFilesAsWellAsDirectories() throws {
        let directory = try Self.directory(withFiles: ["a": 100, "b": 250])

        let usage = StorageUsageClient.liveValue.measure([directory.appending(path: "a")])

        #expect(usage.fileCount == 1)
        #expect(usage.bytes == 100)
    }

    // A cache that has never been written is the normal state on first launch, and measuring it
    // must not be the thing that fails a launch line.
    @Test
    func test_measure_returnsZeroForAMissingPath() {
        let missing = URL.temporaryDirectory.appending(path: "absent-\(UUID().uuidString)")

        #expect(StorageUsageClient.liveValue.measure([missing]) == .zero)
    }

    @Test
    func test_measure_returnsZeroForNoPaths() {
        #expect(StorageUsageClient.liveValue.measure([]) == .zero)
    }

    // The log is read by whoever a user sends it to, not only by the user, so the units must not
    // change with the device's locale.
    @Test
    func test_formatted_isStableAcrossLocales() {
        #expect(StorageUsage(bytes: 1_200_000, fileCount: 14).formatted() == "1.2 MB / 14 files")
        #expect(StorageUsage(bytes: 1_200_000, fileCount: 1).formatted() == "1.2 MB / 1 file")
        #expect(StorageUsage(bytes: 0, fileCount: 0).formatted() == "0 bytes / 0 files")
    }

    private static func directory(withFiles files: [String: Int]) throws -> URL {
        let directory = URL.temporaryDirectory.appending(path: "StorageUsageTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for (name, size) in files {
            try Data(count: size).write(to: directory.appending(path: name))
        }
        return directory
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test Logging -d "iPhone 17 Pro"`
Expected: FAIL — `StorageUsage` does not exist.

- [ ] **Step 3: Write `StorageUsage`**

Create `Modules/Logging/StorageUsage.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

public struct StorageUsage: Equatable, Sendable {

    public static let zero = Self(bytes: 0, fileCount: 0)

    public let bytes: Int

    public let fileCount: Int

    public init(bytes: Int, fileCount: Int) {
        self.bytes = bytes
        self.fileCount = fileCount
    }

    public func formatted() -> String {
        "\(formattedBytes()) / \(fileCount) \(fileCount == 1 ? "file" : "files")"
    }

    public func formattedBytes() -> String {
        // en_US_POSIX so the separator and units cannot change with the reader's device: the file
        // is read by whoever the user sends it to.
        Int64(bytes).formatted(
            .byteCount(style: .file)
                .locale(Locale(identifier: "en_US_POSIX"))
        )
    }
}

@DependencyClient
public struct StorageUsageClient: Sendable {

    // Takes URLs rather than a directory so one call can answer for a cache directory and a
    // handful of loose files. Each URL may be either.
    public var measure: @Sendable (_ urls: [URL]) -> StorageUsage = { _ in .zero }
}

extension StorageUsageClient: DependencyKey {

    public static let liveValue = Self(
        measure: { urls in
            var bytes = 0
            var fileCount = 0

            for url in urls {
                var isDirectory: ObjCBool = false
                guard FileManager.default.fileExists(atPath: url.path(), isDirectory: &isDirectory) else {
                    continue
                }

                guard isDirectory.boolValue else {
                    bytes += size(of: url)
                    fileCount += 1
                    continue
                }

                let enumerator = FileManager.default.enumerator(
                    at: url,
                    includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey]
                )
                while let child = enumerator?.nextObject() as? URL {
                    guard (try? child.resourceValues(forKeys: [.isRegularFileKey]))?.isRegularFile == true else {
                        continue
                    }
                    bytes += size(of: child)
                    fileCount += 1
                }
            }

            return StorageUsage(bytes: bytes, fileCount: fileCount)
        }
    )

    private static func size(of url: URL) -> Int {
        (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
    }
}

extension StorageUsageClient: TestDependencyKey {

    public static let previewValue = testValue

    public static let testValue = Self(measure: { _ in .zero })
}

public extension DependencyValues {

    var storageUsage: StorageUsageClient {
        get { self[StorageUsageClient.self] }
        set { self[StorageUsageClient.self] = newValue }
    }
}
```

If `test_formatted_isStableAcrossLocales` fails on the exact string, run it once and copy the
formatter's actual output into the expectation rather than reformatting by hand — `byteCount` uses
decimal MB under `.file`, and the assertion exists to pin whatever that is, not to prescribe it.

- [ ] **Step 4: Run the test to verify it passes**

Run: `mise exec -- tuist test Logging -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add Modules/Logging Modules/LoggingTests
git commit -m "feat: add StorageUsageClient for measuring caches on disk"
```

---

### Task 5: `ImageCacheUsage`

**Files:**
- Create: `Modules/ImageFeature/ImageCacheUsage.swift`
- Test: Create `Modules/ImageFeatureTests/ImageCacheUsageTests.swift`

**Interfaces:**
- Consumes: `StorageUsage` from Task 4 (`Modules/Logging/StorageUsage.swift`).
- Produces:
  - `public struct ImageCacheUsage: Sendable` with `read: @Sendable () async -> StorageUsage`
  - `DependencyValues.imageCacheUsage`

Note: `PipelineProvider` and everything else in `ImageFeature` is `internal`; this one is `public`
because `AppFeature` reads it. `ImageFeature` gains `.target(.logging)` in this task.

- [ ] **Step 1: Write the failing test**

Create `Modules/ImageFeatureTests/ImageCacheUsageTests.swift`:

```swift
@testable import ImageFeature

import Foundation
import Logging
import Testing

@Suite
struct ImageCacheUsageTests {

    @Test
    func test_testValue_isZero() async {
        #expect(await ImageCacheUsage.testValue.read() == .zero)
    }

    // Nuke's totalSize and totalCount both walk the cache directory, so this must never be called
    // from a path that blocks a launch. The assertion here is only that it answers.
    @Test
    func test_liveValue_answersWithoutThrowing() async {
        let usage = await ImageCacheUsage.liveValue.read()

        #expect(usage.bytes >= 0)
        #expect(usage.fileCount >= 0)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ImageFeature -d "iPhone 17 Pro"`
Expected: FAIL — `ImageCacheUsage` does not exist.

- [ ] **Step 3: Write `ImageCacheUsage`**

Create `Modules/ImageFeature/ImageCacheUsage.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation
import Logging
import Nuke

// Exists so AppFeature can report the thumbnail cache without importing Nuke, and so the number is
// stubbable. It reads the same store PipelineProvider builds - DataCache(name: "default").
@DependencyClient
public struct ImageCacheUsage: Sendable {

    public var read: @Sendable () async -> StorageUsage = { .zero }
}

extension ImageCacheUsage: DependencyKey {

    public static let liveValue = Self(
        read: {
            guard let cache = try? DataCache(name: "default") else {
                return .zero
            }

            // Both properties enumerate the directory, so this hops off whatever actor called it.
            return await Task.detached(priority: .utility) {
                StorageUsage(bytes: cache.totalSize, fileCount: cache.totalCount)
            }.value
        }
    )
}

extension ImageCacheUsage: TestDependencyKey {

    public static let previewValue = testValue

    public static let testValue = Self(read: { .zero })
}

public extension DependencyValues {

    var imageCacheUsage: ImageCacheUsage {
        get { self[ImageCacheUsage.self] }
        set { self[ImageCacheUsage.self] = newValue }
    }
}
```

- [ ] **Step 4: Declare the new module dependency**

In `Module+Dependencies.swift`, add `.target(.logging),` to `case .imageFeature:` and to
`case .imageFeatureTests:`, keeping each list alphabetical.

Then run: `mise exec -- tuist generate`

- [ ] **Step 5: Run the test to verify it passes**

Run: `mise exec -- tuist test ImageFeature -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add Modules/ImageFeature Modules/ImageFeatureTests Tuist/ProjectDescriptionHelpers
git commit -m "feat: expose image cache usage for diagnostics"
```

---

### Task 6: Launch context lines

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift` (merge the new effect into `.bootstrap`)
- Modify: `Modules/AppFeature/AppReducer+Effect.swift` (add `runLogLaunchContext`)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (`appFeature` and
  `appFeatureTests` gain `.target(.logging)` and `.target(.imageFeature)`)
- Test: Modify `Modules/AppFeatureTests/AppReducerTests.swift`

**Interfaces:**
- Consumes: `DeviceContext.launchLine()` (Task 3), `StorageUsageClient.measure(_:)` (Task 4),
  `ImageCacheUsage.read()` (Task 5), `URL.applicationGroupDirectory` (existing, `ApiInterface`),
  `LogClient.fileURLs()` (existing).
- Produces: `Effect<AppReducer.Action>.runLogLaunchContext()`.

- [ ] **Step 1: Write the failing test**

Add to `Modules/AppFeatureTests/AppReducerTests.swift`:

```swift
    @Test
    func test_bootstrap_logsTheLaunchContext() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
                $0.deviceContext = .testValue
                $0.imageCacheUsage.read = { StorageUsage(bytes: 42_100_000, fileCount: 318) }
                $0.storageUsage.measure = { _ in StorageUsage(bytes: 1_200_000, fileCount: 14) }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.bootstrap)
        await store.finish()

        #expect(messages.value.contains("LessPaper 1.0.0 (1) · iOS 26.0 · iPhone17,2 · en_US · debug"))
    }

    @Test
    func test_bootstrap_logsCacheSizes() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
                $0.imageCacheUsage.read = { StorageUsage(bytes: 42_100_000, fileCount: 318) }
                $0.storageUsage.measure = { _ in StorageUsage(bytes: 1_200_000, fileCount: 14) }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.bootstrap)
        await store.finish()

        #expect(messages.value.contains { $0.hasPrefix("caches: images 42.1 MB / 318 files · app group ") })
    }
```

Add `import Logging` and `import ImageFeature` to the test file's imports.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro"`
Expected: FAIL — `deviceContext` is not a member of `DependencyValues` in this target.

- [ ] **Step 3: Declare the new module dependencies**

In `Module+Dependencies.swift`, add `.target(.imageFeature),` and `.target(.logging),` to
`case .appFeature:` and to `case .appFeatureTests:`, keeping the lists alphabetical.

Then run: `mise exec -- tuist generate`

- [ ] **Step 4: Write the effect**

Add to `Modules/AppFeature/AppReducer+Effect.swift`:

```swift
    // Two lines, written detached: measuring walks the caches directory and a launch must not wait
    // on it. Nothing downstream depends on the result, so there is nothing to send back.
    static func runLogLaunchContext() -> Self {
        @Dependency(\.deviceContext)
        var deviceContext

        @Dependency(\.imageCacheUsage)
        var imageCacheUsage

        @Dependency(\.log)
        var log

        @Dependency(\.storageUsage)
        var storageUsage

        return .run { _ in
            log.info(deviceContext.launchLine(), category: .app)

            let images = await imageCacheUsage.read()
            let appGroup = storageUsage.measure([.applicationGroupDirectory])
            let logFiles = storageUsage.measure(await log.fileURLs())

            log.info(
                [
                    "caches: images \(images.formatted())",
                    "app group \(appGroup.formatted())",
                    "log \(logFiles.formattedBytes())",
                ]
                .joined(separator: " · "),
                category: .app
            )
        }
    }
```

Add `import ImageFeature` and `import Logging` to that file's imports, in alphabetical order.

- [ ] **Step 5: Merge it into bootstrap**

In `Modules/AppFeature/AppReducer.swift`, extend the `.bootstrap` case:

```swift
            case .bootstrap:
                return .runSelectedServerObserver()
                    .merge(with: .run { send in
                        await send(.certificateApproval(.bootstrap))
                    })
                    .merge(with: .run { send in
                        await send(.forwardAuth(.bootstrap))
                    })
                    .merge(with: .runTipObserver())
                    .merge(with: .runLogLaunchContext())
```

- [ ] **Step 6: Run the test to verify it passes**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add Modules/AppFeature Modules/AppFeatureTests Tuist/ProjectDescriptionHelpers
git commit -m "feat: log app version, device and cache sizes at launch"
```

---

### Task 7: Lifecycle lines

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift` (new `AppLifecyclePhase`, new action, log)
- Modify: `Modules/AppFeature/AppReducer+Effect.swift` (memory warning observer)
- Modify: `Modules/AppFeature/AppView.swift:23-28`
- Test: Modify `Modules/AppFeatureTests/AppReducerTests.swift`

**Interfaces:**
- Consumes: `LogCategory.app` (Task 3).
- Produces: `AppReducer.Action.lifecyclePhaseChanged(AppLifecyclePhase)`,
  `public enum AppLifecyclePhase: String, Sendable { case active, inactive, background }`,
  `Effect<AppReducer.Action>.runMemoryWarningObserver()`.

- [ ] **Step 1: Write the failing test**

Add to `Modules/AppFeatureTests/AppReducerTests.swift`:

```swift
    @Test
    func test_lifecyclePhaseChanged_logsTheTransition() async {
        let messages = LockIsolated<[String]>([])

        let store = TestStore(
            initialState: AppReducer.State(),
            reducer: { AppReducer() },
            withDependencies: {
                $0.log.record = { message, _, _ in
                    messages.withValue { $0.append(message) }
                }
            }
        )
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.lifecyclePhaseChanged(.background))
        await store.send(.lifecyclePhaseChanged(.active))

        #expect(messages.value == ["scene phase: background", "scene phase: active"])
    }
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro"`
Expected: FAIL — no `lifecyclePhaseChanged` action.

- [ ] **Step 3: Add the phase type and the action**

In `Modules/AppFeature/AppReducer.swift`, above `@Reducer public struct AppReducer`:

```swift
// Mirrors SwiftUI's ScenePhase rather than using it, so the reducer and its tests do not depend on
// SwiftUI. AppView does the mapping.
public enum AppLifecyclePhase: String, Sendable {
    case active
    case background
    case inactive
}
```

Add to `Action`, keeping the list alphabetical:

```swift
        case lifecyclePhaseChanged(AppLifecyclePhase)
```

Add the case to the reducer, beside `.didBecomeActive`:

```swift
            case let .lifecyclePhaseChanged(phase):
                log.info("scene phase: \(phase.rawValue)", category: .app)
                return .none
```

Add the dependency at the bottom of the type:

```swift
    @Dependency(\.log)
    private var log
```

and `import Logging` to the file's imports.

- [ ] **Step 4: Send it from the view**

In `Modules/AppFeature/AppView.swift`, replace the `onChange` modifier:

```swift
        .onChange(of: scenePhase) { _, newPhase in
            switch newPhase {
            case .active:
                store.send(.lifecyclePhaseChanged(.active))
                store.send(.didBecomeActive)
            case .background:
                store.send(.lifecyclePhaseChanged(.background))
            case .inactive:
                store.send(.lifecyclePhaseChanged(.inactive))
            @unknown default:
                break
            }
        }
```

`didBecomeActive` keeps firing exactly when it did, so the refresh behaviour is unchanged.

- [ ] **Step 5: Add the memory warning observer**

Add to `Modules/AppFeature/AppReducer+Effect.swift`:

```swift
    // A background termination and a crash look identical from the user's side, and a memory
    // warning shortly before the log ends is the difference.
    static func runMemoryWarningObserver() -> Self {
        @Dependency(\.log)
        var log

        return .run { _ in
            let warnings = NotificationCenter.default.notifications(
                named: await UIApplication.didReceiveMemoryWarningNotification
            )
            for await _ in warnings {
                log.warning("memory warning", category: .app)
            }
        }
    }
```

Add `import UIKit` to that file's imports.

Merge it into `.bootstrap` in `AppReducer.swift`:

```swift
                    .merge(with: .runLogLaunchContext())
                    .merge(with: .runMemoryWarningObserver())
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro"`
Expected: PASS. `AppViewTests` snapshots are unaffected — the change is in a modifier, not the
rendered view.

- [ ] **Step 7: Commit**

```bash
git add Modules/AppFeature Modules/AppFeatureTests
git commit -m "feat: log scene phase transitions and memory warnings"
```

---

### Task 8: Connect and cache-update lines

**Files:**
- Modify: `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`
- Test: Modify `Modules/ApiImplementationTests/Cache/UpdateCacheUseCaseTests.swift`

**Interfaces:**
- Consumes: `authenticationProvider.getToken(server:)` (existing),
  `SharedReaderKey.apiVersion(_:)` (existing), `LogCategory.server` (existing).
- Produces: nothing later tasks rely on.

- [ ] **Step 1: Write the failing test**

In `Modules/ApiImplementationTests/Cache/UpdateCacheUseCaseTests.swift`, first add a file-local
helper so the three new tests do not each repeat eight stubs. `executeSurvivesUsersAndGroupsBeingForbidden`
already shows the minimal set that compiles, so this is that set with the counts made settable:

```swift
    // UpdateCacheUseCase awaits every one of these, so a test that omits one fails on an
    // unimplemented dependency rather than on what it meant to assert.
    private static func cachingStubs(
        count: Int = 1
    ) -> (inout DependencyValues) -> Void {
        { values in
            values.getCorrespondents.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getCurrentUser.execute = { _ in .testValue() }
            values.getDocumentTypes.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getGroups.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getSavedViews.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getStoragePaths.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getTags.execute = { _ in Array(repeating: .testValue(), count: count) }
            values.getUsers.execute = { _ in Array(repeating: .testValue(), count: count) }
        }
    }
```

If `getCustomFields` or `getStatistics` turn out to be unimplemented in this context, add them to the
helper the same way — `executeSurvivesUsersAndGroupsBeingForbidden` compiles without them today, so
start from this set and only widen it if the build says to.

Then add the three tests:

```swift
    @Test
    func test_execute_logsTheConnectionShape() async throws {
        let messages = LockIsolated<[String]>([])

        try await withDependencies {
            Self.cachingStubs()(&$0)
            $0.authenticationProvider.getToken = { _ in "a-token" }
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(Server.testValue())
        }

        #expect(messages.value.contains { $0.hasPrefix("connected · API version ") })
        #expect(messages.value.contains { $0.hasSuffix(" · auth: token") })
    }

    // Remote-user mode has no token: a forward-auth proxy authenticates and paperless takes the
    // injected identity. The line has to say so rather than fail.
    @Test
    func test_execute_reportsRemoteUserWhenThereIsNoToken() async throws {
        let messages = LockIsolated<[String]>([])

        try await withDependencies {
            Self.cachingStubs()(&$0)
            $0.authenticationProvider.getToken = { _ in nil }
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(Server.testValue())
        }

        #expect(messages.value.contains { $0.hasSuffix(" · auth: remote-user") })
    }

    @Test
    func test_execute_logsWhatItCached() async throws {
        let messages = LockIsolated<[String]>([])

        try await withDependencies {
            Self.cachingStubs(count: 1)(&$0)
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        } operation: {
            try await UpdateCacheUseCase.liveValue.execute(Server.testValue())
        }

        let summary = try #require(messages.value.first { $0.hasPrefix("cache updated in ") })

        #expect(summary.contains("1 tag"))
        #expect(summary.contains("1 correspondent"))
        #expect(summary.contains("1 saved view"))
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: FAIL — `messages` is empty.

- [ ] **Step 3: Log the connection shape**

In `Modules/ApiImplementation/Cache/UpdateCacheUseCase.swift`, move the `@Dependency(\.log)`
declaration from the bottom of `execute` to the top of the function, and add above the `async let`
block:

```swift
        @Dependency(\.authenticationProvider)
        var authenticationProvider

        @Dependency(\.continuousClock)
        var clock

        @Dependency(\.log)
        var log

        @Shared(.apiVersion(server))
        var apiVersion: Int?

        // Derived, not stored: a token means token auth, and its absence means remote-user mode,
        // where a forward-auth proxy authenticates and no token exists. This does not distinguish a
        // token obtained through OIDC from one obtained with a password - nothing records that.
        let token = try? await authenticationProvider.getToken(server: server)

        log.info(
            [
                "connected",
                "API version \(apiVersion.map(String.init) ?? "unknown")",
                "auth: \(token == nil ? "remote-user" : "token")",
            ]
            .joined(separator: " · "),
            category: .server
        )

        let started = clock.now
```

Add `import SwiftSharing` to the file's imports if it is not already there.

Delete the later `@Dependency(\.log) var log` block that currently sits just above the `groups`
`do`/`catch`, and its explanatory comment stays where it is — it explains the `catch`, not the
dependency.

- [ ] **Step 4: Log what was cached**

Capture the results instead of discarding them. Replace the eight `_ = try await …` lines:

```swift
        let correspondentsCount = try await correspondents.count
        let customFieldsCount = try await customFields.count
        let documentTypesCount = try await documentTypes.count
        _ = try await currentUser
        let savedViewsCount = try await savedViews.count
        _ = try await statistics
        let storagePathsCount = try await storagePaths.count
        let tagsCount = try await tags.count
```

and add, after the `users` `do`/`catch` at the end of the function:

```swift
        log.info(
            [
                "cache updated in \(started.duration(to: clock.now).formatted(.units(allowed: [.seconds], fractionalPart: .show(length: 1))))",
                Self.pluralised(tagsCount, "tag"),
                Self.pluralised(correspondentsCount, "correspondent"),
                Self.pluralised(documentTypesCount, "document type"),
                Self.pluralised(savedViewsCount, "saved view"),
                Self.pluralised(storagePathsCount, "storage path"),
                Self.pluralised(customFieldsCount, "custom field"),
            ]
            .joined(separator: " · "),
            category: .server
        )
```

Add the helper to the same `private extension UpdateCacheUseCase`:

```swift
    static func pluralised(_ count: Int, _ noun: String) -> String {
        "\(count) \(noun)\(count == 1 ? "" : "s")"
    }
```

If the duration formatting above does not compile against this Swift version, fall back to
`String(format: "%.1fs", Double(started.duration(to: clock.now).components.seconds))` — the
requirement is one fractional digit and a stable unit, not a particular API.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`
Expected: PASS, including the pre-existing tests in the suite.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiImplementation Modules/ApiImplementationTests
git commit -m "feat: log server connection shape and cache update results"
```

---

### Task 9: Certificate approval line

**Files:**
- Modify: `Modules/CertificatesFeature/CertificateApproval/CertificateApprovalReducer.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (`certificatesFeature` and
  `certificatesFeatureTests` gain `.target(.logging)`)
- Test: Modify the suite under `Modules/CertificatesFeatureTests/CertificateApproval/`

**Interfaces:**
- Consumes: `LogCategory.server` (existing).
- Produces: nothing.

- [ ] **Step 1: Write the failing test**

Add to `Modules/CertificatesFeatureTests/CertificateApproval/CertificateApprovalReducerTests.swift`.
`CertificateApprovalRequest.testValue()` already exists and carries a real certificate — the suite's
`test_multipleRequests` relies on it producing a `TrustedCertificate` with issuer
`ST=Delaware,CN=Proxyman CA …`, which is the same path this test takes:

```swift
    @Test
    func test_certificateApprovalResponse_logsAnApproval() async {
        let messages = LockIsolated<[String]>([])
        let request = CertificateApprovalRequest.testValue()

        let store = TestStore(initialState: CertificateApprovalReducer.State()) {
            CertificateApprovalReducer()
        } withDependencies: {
            $0.approveCertificate.execute = { _ in true }
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.certificateApprovalResponse(request, true))

        #expect(messages.value == ["self-signed certificate trusted"])
    }

    @Test
    func test_certificateApprovalResponse_logsNothingWhenDeclined() async {
        let messages = LockIsolated<[String]>([])
        // approveCertificate's testValue answers false, which is the declined path.
        let request = CertificateApprovalRequest.testValue()

        let store = TestStore(initialState: CertificateApprovalReducer.State()) {
            CertificateApprovalReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.certificateApprovalResponse(request, false))

        #expect(messages.value.isEmpty)
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test CertificatesFeature -d "iPhone 17 Pro"`
Expected: FAIL — `messages` is empty in the first test.

- [ ] **Step 3: Log the approval**

In `CertificateApprovalReducer.swift`, inside the `if` branch of `.certificateApprovalResponse`,
after the `withLock` block:

```swift
                    // Written here rather than from ApproveCertificateUseCase, which also runs for
                    // an already-trusted certificate on every later challenge and would log each
                    // one. No hostname: the fact that matters is that trust was granted at all.
                    log.info("self-signed certificate trusted", category: .server)
```

Add the dependency beside the existing `@Dependency(\.approveCertificate.execute)`:

```swift
    @Dependency(\.log)
    private var log
```

and `import Logging` to the file's imports.

- [ ] **Step 4: Declare the new module dependency**

In `Module+Dependencies.swift`, add `.target(.logging),` to `case .certificatesFeature:` and
`case .certificatesFeatureTests:`, keeping each list alphabetical.

Then run: `mise exec -- tuist generate`

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mise exec -- tuist test CertificatesFeature -d "iPhone 17 Pro"`
Expected: PASS.

- [ ] **Step 6: Run the whole suite**

```
mise exec -- tuist test Logging -d "iPhone 17 Pro"
mise exec -- tuist test ImageFeature -d "iPhone 17 Pro"
mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"
mise exec -- tuist test ServersFeature -d "iPhone 17 Pro"
mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro"
mise exec -- tuist test AppFeature -d "iPhone 17 Pro"
mise exec -- tuist test CertificatesFeature -d "iPhone 17 Pro"
```
Expected: PASS, all seven.

- [ ] **Step 7: Verify the leak is gone by reading a real log**

Build and run the app on a simulator, add a server with a hostname you will recognise, then open
Settings → Diagnostics and read the file. Confirm:
- the hostname appears nowhere,
- exactly one `OIDC discovery:` line was written while typing the address,
- the launch line and the `caches:` line are both present,
- `connected · API version … · auth: …` appears once for the server.

This is the acceptance check the unit tests cannot make: they assert what each site writes, not what
the file ends up containing.

- [ ] **Step 8: Commit**

```bash
git add Modules/CertificatesFeature Modules/CertificatesFeatureTests Tuist/ProjectDescriptionHelpers
git commit -m "feat: log when a self-signed certificate is trusted"
```
