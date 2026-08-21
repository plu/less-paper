# API version negotiation implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the hardcoded `Accept: application/json; version=10` header with a per-server
negotiated API version, and make saved view visibility work correctly on both API v9 and v10.

**Architecture:** A per-server `@Shared` file cache holds the negotiated version, defaulting to 9 —
the floor this app supports, and therefore the one value no supported server can answer 406 to. It
is seeded by an authenticated probe that reads the `X-Api-Version` response header at add-server
time, and kept current by `ApiClientDelegate` reading that same header off every response.
`GetSavedViewsUseCase` and `SetSavedViewVisibilityUseCase` branch on the cached value, because v10
moved saved view visibility out of the saved view and into UISettings.

**Tech Stack:** Swift 6, Swift Testing, `swift-dependencies` (`@DependencyClient`, `withDependencies`),
`swift-sharing` (`@Shared`, `FileStorageKey`), `Get` (`APIClient`, `APIClientDelegate`),
`swift-composable-architecture` (`TestStore`), Tuist.

**Design doc:** `docs/plans/2026-08-21-api-version-negotiation.md`

## Global Constraints

- **Comments:** Never `///`, never `/** */`. Only `//`, and only when a future reader would
  otherwise stop and wonder why the code is the way it is. See `AGENTS.md`.
- **Version floor:** `ApiVersion.minimumSupported = 9`. **Client ceiling:**
  `ApiVersion.clientMaximum = 10`. Copy these exact numbers; do not inline literals elsewhere.
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro"`. Scheme names match the
  module: `ApiInterface`, `ApiImplementation`, `ServersFeature`.
- **Localization:** two languages, `en` (source) and `de`. Every new key needs both, with
  `"extractionState" : "manual"`, in `Shared/Framework/Resources/Localizable.xcstrings`.
- **`@Shared` in tests is isolated automatically** — `swift-sharing`'s `defaultFileStorage` is
  in-memory under a test context, so each suite starts from the key's `default:`.
- **New `.swift` files need no Tuist edit.** Targets glob their module directory; only new *modules*
  touch `Tuist/ProjectDescriptionHelpers/Module.swift`.

---

### Task 1: `ApiVersion`, `ApiVersionError`, and the shared key

**Files:**
- Create: `Modules/ApiInterface/Shared/ApiVersion.swift`
- Create: `Modules/ApiInterface/Shared/ApiVersionError.swift`
- Modify: `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift` (append a new extension)
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: Create `Modules/ApiInterfaceTests/Shared/ApiVersionTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `ApiVersion.minimumSupported: Int` (9), `ApiVersion.clientMaximum: Int` (10)
  - `ApiVersion.negotiated(from advertised: Int?) throws -> Int`
  - `ApiVersionError.unsupportedServer(Int?)`, `Error, Equatable, LocalizedError`
  - `SharedReaderKey.apiVersion(_ server: Server)` for `FileStorageKey<Int>.Default`

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiInterfaceTests/Shared/ApiVersionTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct ApiVersionTests {

    @Test
    func negotiated_clampsAServerAheadOfTheClientToTheClientMaximum() throws {
        #expect(try ApiVersion.negotiated(from: 11) == 10)
    }

    @Test
    func negotiated_acceptsTheClientMaximum() throws {
        #expect(try ApiVersion.negotiated(from: 10) == 10)
    }

    @Test
    func negotiated_acceptsTheFloor() throws {
        #expect(try ApiVersion.negotiated(from: 9) == 9)
    }

    @Test
    func negotiated_rejectsAServerBelowTheFloor() {
        #expect(throws: ApiVersionError.unsupportedServer(8)) {
            try ApiVersion.negotiated(from: 8)
        }
    }

    // A server old enough to predate ApiVersionMiddleware sends no X-Api-Version at all. That is
    // indistinguishable from "too old" and must not be treated as "assume the floor".
    @Test
    func negotiated_rejectsAMissingAdvertisedVersion() {
        #expect(throws: ApiVersionError.unsupportedServer(nil)) {
            try ApiVersion.negotiated(from: nil)
        }
    }

    @Test
    func errorDescription_namesTheServersVersionWhenKnown() {
        let description = ApiVersionError.unsupportedServer(6).errorDescription

        #expect(description?.contains("6") == true)
        #expect(description?.contains("9") == true)
    }

    @Test
    func errorDescription_isPresentWhenTheVersionIsUnknown() {
        #expect(ApiVersionError.unsupportedServer(nil).errorDescription?.isEmpty == false)
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro"`

Expected: FAIL — `cannot find 'ApiVersion' in scope`.

- [ ] **Step 3: Create `ApiVersion`**

Create `Modules/ApiInterface/Shared/ApiVersion.swift`:

```swift
import Foundation

public enum ApiVersion {

    public static let clientMaximum = 10

    public static let minimumSupported = 9

    public static func negotiated(from advertised: Int?) throws -> Int {
        guard let advertised, advertised >= minimumSupported else {
            throw ApiVersionError.unsupportedServer(advertised)
        }
        return min(advertised, clientMaximum)
    }
}
```

- [ ] **Step 4: Create `ApiVersionError`**

Create `Modules/ApiInterface/Shared/ApiVersionError.swift`:

```swift
import Foundation

public enum ApiVersionError: Error, Equatable {
    case unsupportedServer(Int?)
}

extension ApiVersionError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case let .unsupportedServer(advertised?):
            String(localized: .unsupportedServerApiVersion(advertised, ApiVersion.minimumSupported))
        case .unsupportedServer:
            String(localized: .unsupportedServerApiVersionUnknown)
        }
    }
}
```

- [ ] **Step 5: Add the two localization keys**

In `Shared/Framework/Resources/Localizable.xcstrings`, add these two entries to the `"strings"`
object, keeping the file's alphabetical key ordering and 2-space indentation:

```json
"unsupportedServerApiVersion" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Dieser Server unterstützt nur API-Version %1$lld. Less Paper benötigt mindestens Version %2$lld. Bitte aktualisiere Paperless-ngx."
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "This server only supports API version %1$lld. Less Paper needs at least version %2$lld. Please update Paperless-ngx."
      }
    }
  }
},
"unsupportedServerApiVersionUnknown" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Dieser Server hat seine API-Version nicht gemeldet. Er ist vermutlich zu alt für Less Paper. Bitte aktualisiere Paperless-ngx."
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "This server did not report its API version. It is most likely too old for Less Paper. Please update Paperless-ngx."
      }
    }
  }
},
```

Verify the file is still valid JSON:

```bash
python3 -c "import json; json.load(open('Shared/Framework/Resources/Localizable.xcstrings')); print('ok')"
```

- [ ] **Step 6: Add the shared key**

Append to `Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, above the
`private extension URL` block at the bottom:

```swift
public extension SharedReaderKey where Self == FileStorageKey<Int>.Default {

    // The default is the floor rather than the ceiling on purpose: an un-probed server must never
    // send a version it might answer 406 to, and every server this app supports accepts 9.
    static func apiVersion(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-api-version.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: ApiVersion.minimumSupported
        ]
    }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro"`

Expected: PASS, all seven `ApiVersionTests` cases green.

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface/Shared/ApiVersion.swift \
        Modules/ApiInterface/Shared/ApiVersionError.swift \
        Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift \
        Modules/ApiInterfaceTests/Shared/ApiVersionTests.swift \
        Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: add ApiVersion negotiation primitives and per-server cache"
```

---

### Task 2: The delegate sends and refreshes the negotiated version

**Files:**
- Modify: `Modules/ApiImplementation/ApiClientDelegate.swift:24` (Accept header) and the
  `validateResponse` method at `:38-47`
- Test: Modify `Modules/ApiImplementationTests/ApiClientDelegateTests.swift`

**Interfaces:**
- Consumes: `ApiVersion.negotiated(from:)`, `SharedReaderKey.apiVersion(_:)` from Task 1.
- Produces: no new symbols. After this task the Accept header is
  `"application/json; version=\(cachedVersion)"`, and every response with an `X-Api-Version` header
  updates that cache.

- [ ] **Step 1: Update the existing default-version test and add the new ones**

In `Modules/ApiImplementationTests/ApiClientDelegateTests.swift`, **replace** the first test —
`willSendRequest_setsDefaultVersion10AcceptHeader` — with the block below, and add the rest at the
end of the suite. Leave the four URL-rewriting tests and
`willSendRequest_customAcceptHeaderOverridesDefault` exactly as they are.

```swift
    @Test
    func willSendRequest_fallsBackToTheMinimumSupportedVersion() async throws {
        let server = Server.testValue(headers: [])
        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/token/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=9")
    }

    @Test
    func willSendRequest_usesTheNegotiatedVersion() async throws {
        let server = Server.testValue(headers: [])
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let delegate = ApiClientDelegate(server: server)
        var request = URLRequest(url: server.url.appending(path: "/api/documents/"))

        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)

        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json; version=10")
    }

    @Test
    func validateResponse_storesTheAdvertisedVersion() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: ["X-Api-Version": "10"]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == 10)
    }

    @Test
    func validateResponse_clampsAServerAheadOfTheClient() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: ["X-Api-Version": "12"]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == ApiVersion.clientMaximum)
    }

    // /api/token/ is unauthenticated, and ApiVersionMiddleware only sets the header for
    // authenticated users, so an absent header is routine and must not clobber a good value.
    @Test
    func validateResponse_leavesTheCacheAloneWhenTheHeaderIsAbsent() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: [:]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == 10)
    }

    // A version below the floor is not written to the cache — the probe is what rejects such a
    // server, and a passive read must never lower the app below what it can decode.
    @Test
    func validateResponse_ignoresAVersionBelowTheFloor() throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let delegate = ApiClientDelegate(server: server)
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: .testValue(server: server, headers: ["X-Api-Version": "6"]),
            data: Data(),
            task: URLSession.shared.dataTask(with: server.url)
        )

        #expect(apiVersion == 10)
    }
```

Add the imports `Dependencies` and `SwiftSharing` to the file's import block, and add this helper at
the bottom of the file, outside the suite:

```swift
private extension HTTPURLResponse {

    static func testValue(
        server: Server,
        statusCode: Int = 200,
        headers: [String: String]
    ) -> HTTPURLResponse {
        HTTPURLResponse(
            url: server.url,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: FAIL — `willSendRequest_fallsBackToTheMinimumSupportedVersion` gets
`application/json; version=10`, and the four `validateResponse_*` tests all see `apiVersion == 9`
because nothing writes the cache yet.

- [ ] **Step 3: Read the cached version when sending**

In `Modules/ApiImplementation/ApiClientDelegate.swift`, add `import SwiftSharing` to the import
block, then replace line 24:

```swift
        request.setValue("application/json; version=10", forHTTPHeaderField: "Accept")
```

with:

```swift
        @Shared(.apiVersion(server))
        var apiVersion: Int

        request.setValue("application/json; version=\(apiVersion)", forHTTPHeaderField: "Accept")
```

Leave the `for header in server.headers` loop directly below it untouched — it runs after this line,
which is what lets a hand-typed `Accept` header override negotiation.

- [ ] **Step 4: Refresh the cache from the response**

In the same file, replace the whole `validateResponse` method with:

```swift
    func client(_ client: APIClient, validateResponse response: HTTPURLResponse, data: Data, task: URLSessionTask) throws {
        storeAdvertisedApiVersion(from: response)

        if (400 ..< 500).contains(response.statusCode) {
            let error = try JSONDecoder().decode(ApiError.self, from: data)
            throw error
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            throw APIError.unacceptableStatusCode(response.statusCode)
        }
    }
```

and add this private method to the same extension:

```swift
    private func storeAdvertisedApiVersion(from response: HTTPURLResponse) {
        guard
            let header = response.value(forHTTPHeaderField: "X-Api-Version"),
            let advertised = Int(header),
            let negotiated = try? ApiVersion.negotiated(from: advertised)
        else {
            return
        }

        @Shared(.apiVersion(server))
        var apiVersion: Int

        guard apiVersion != negotiated else {
            return
        }
        $apiVersion.withLock { $0 = negotiated }
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: PASS. `willSendRequest_customAcceptHeaderOverridesDefault` must still be green — that is
the regression guard for the manual override.

- [ ] **Step 6: Commit**

```bash
git add Modules/ApiImplementation/ApiClientDelegate.swift \
        Modules/ApiImplementationTests/ApiClientDelegateTests.swift
git commit -m "feat: send and refresh the negotiated API version in ApiClientDelegate"
```

---

### Task 3: `NegotiateApiVersionUseCase` and its repository

**Files:**
- Create: `Modules/ApiInterface/ApiVersion/ApiVersionRepositoryInput.swift`
- Create: `Modules/ApiInterface/ApiVersion/NegotiateApiVersionUseCase.swift`
- Create: `Modules/ApiImplementation/ApiVersion/ApiVersionRepository.swift`
- Create: `Modules/ApiImplementation/ApiVersion/NegotiateApiVersionUseCase.swift`
- Test: Create `Modules/ApiImplementationTests/ApiVersion/NegotiateApiVersionUseCaseTests.swift`

**Interfaces:**
- Consumes: `ApiVersion.negotiated(from:)`, `ApiVersionError`, `SharedReaderKey.apiVersion(_:)`
  from Task 1.
- Produces:
  - `NegotiateApiVersionUseCase` with `execute: @Sendable (_ server: Server) async throws -> Int`,
    registered at `DependencyValues.negotiateApiVersion`
  - `ApiVersionRepository` (internal to `ApiImplementation`) with
    `getAdvertisedApiVersion: @Sendable (_ server: Server) async throws -> Int?`, registered at
    `DependencyValues.apiVersionRepository`

The repository returns the raw advertised `Int?` so all decision logic stays in the use case, where
it is testable without stubbing HTTP — this codebase has no URL-stubbing infrastructure.

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/ApiVersion/NegotiateApiVersionUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import SwiftSharing
import Testing

@Suite
struct NegotiateApiVersionUseCaseTests {

    @Test
    func execute_storesTheAdvertisedVersion() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        try await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in 10 }
        } operation: {
            let negotiated = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            #expect(negotiated == 10)
        }

        #expect(apiVersion == 10)
    }

    @Test
    func execute_clampsAServerAheadOfTheClient() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        try await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in 12 }
        } operation: {
            _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
        }

        #expect(apiVersion == ApiVersion.clientMaximum)
    }

    @Test
    func execute_throwsAndLeavesTheCacheAloneForAServerBelowTheFloor() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in 6 }
        } operation: {
            await #expect(throws: ApiVersionError.unsupportedServer(6)) {
                _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            }
        }

        #expect(apiVersion == ApiVersion.minimumSupported)
    }

    @Test
    func execute_throwsWhenTheServerAdvertisesNothing() async throws {
        let server = Server.testValue()

        await withDependencies {
            $0.apiVersionRepository.getAdvertisedApiVersion = { _ in nil }
        } operation: {
            await #expect(throws: ApiVersionError.unsupportedServer(nil)) {
                _ = try await NegotiateApiVersionUseCase.liveValue.execute(server: server)
            }
        }
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: FAIL — `cannot find 'NegotiateApiVersionUseCase' in scope`.

- [ ] **Step 3: Declare the use case in `ApiInterface`**

Create `Modules/ApiInterface/ApiVersion/NegotiateApiVersionUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct NegotiateApiVersionUseCase: Sendable {

    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Int
}

extension NegotiateApiVersionUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { _ in ApiVersion.clientMaximum }
    )

    public static let testValue = Self(
        execute: { _ in ApiVersion.clientMaximum }
    )
}

public extension DependencyValues {
    var negotiateApiVersion: NegotiateApiVersionUseCase {
        get { self[NegotiateApiVersionUseCase.self] }
        set { self[NegotiateApiVersionUseCase.self] = newValue }
    }
}
```

Create `Modules/ApiInterface/ApiVersion/ApiVersionRepositoryInput.swift`:

```swift
import Foundation

public struct GetAdvertisedApiVersionInput: Codable, Equatable, Sendable {

    public init() {}
}

public extension GetAdvertisedApiVersionInput {

    static func testValue() -> Self {
        .init()
    }
}
```

- [ ] **Step 4: Implement the repository**

Create `Modules/ApiImplementation/ApiVersion/ApiVersionRepository.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import Get

@DependencyClient
struct ApiVersionRepository: Sendable {

    var getAdvertisedApiVersion: @Sendable (
        _ server: Server
    ) async throws -> Int?
}

extension ApiVersionRepository: TestDependencyKey {
    static let previewValue = Self(
        getAdvertisedApiVersion: { _ in ApiVersion.clientMaximum }
    )

    static let testValue = Self(
        getAdvertisedApiVersion: { _ in ApiVersion.clientMaximum }
    )
}

extension DependencyValues {

    var apiVersionRepository: ApiVersionRepository {
        get { self[ApiVersionRepository.self] }
        set { self[ApiVersionRepository.self] = newValue }
    }
}

extension ApiVersionRepository: DependencyKey {
    static let liveValue = Self(
        getAdvertisedApiVersion: getAdvertisedApiVersion(server:)
    )
}

private extension ApiVersionRepository {

    // ApiVersionMiddleware only sets X-Api-Version for authenticated users, so the probe has to hit
    // an endpoint that actually authenticates — /api/token/ would always come back bare.
    static func getAdvertisedApiVersion(
        server: Server
    ) async throws -> Int? {
        let response = try await APIClient
            .client(server: server)
            .send(Request<GetUISettingsOutput>(
                path: "/api/ui_settings/",
                method: .get
            ))

        guard
            let httpResponse = response.response as? HTTPURLResponse,
            let header = httpResponse.value(forHTTPHeaderField: "X-Api-Version")
        else {
            return nil
        }
        return Int(header)
    }
}
```

- [ ] **Step 5: Implement the use case**

Create `Modules/ApiImplementation/ApiVersion/NegotiateApiVersionUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import SwiftSharing

extension NegotiateApiVersionUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension NegotiateApiVersionUseCase {

    static func execute(
        server: Server
    ) async throws -> Int {
        @Dependency(\.apiVersionRepository)
        var repository

        @Shared(.apiVersion(server))
        var apiVersion: Int

        let negotiated = try ApiVersion.negotiated(
            from: try await repository.getAdvertisedApiVersion(server: server)
        )

        $apiVersion.withLock { $0 = negotiated }

        return negotiated
    }
}
```

- [ ] **Step 6: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: PASS, all four `NegotiateApiVersionUseCaseTests` cases green.

- [ ] **Step 7: Commit**

```bash
git add Modules/ApiInterface/ApiVersion Modules/ApiImplementation/ApiVersion \
        Modules/ApiImplementationTests/ApiVersion
git commit -m "feat: probe X-Api-Version to negotiate a server's API version"
```

---

### Task 4: Probe on save, and drop the pre-filled Accept header

**Files:**
- Modify: `Modules/ServersFeature/ServerForm/ServerFormInput.swift:47-60` (the `empty` static)
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer+Effect.swift`
- Test: Modify `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.negotiateApiVersion` from Task 3.
- Produces: the save effect now runs `storeToken` → `negotiateApiVersion` → `updateCache`, in that
  order. A throw from the probe aborts the save and reaches the existing `catch:` handler.

- [ ] **Step 1: Write the failing tests**

In `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift`, add these two tests to the
suite. Also update the existing `test_view_saveButtonTapped_success` — its
`#expect(events.value == ["storeToken", "updateCache"])` becomes
`#expect(events.value == ["storeToken", "negotiateApiVersion", "updateCache"])`, and its
`withDependencies` block gains `$0.negotiateApiVersion.execute = { _ in events.withValue { $0.append("negotiateApiVersion") }; return 10 }`.

```swift
    // The probe runs before updateCache so the nine parallel cache requests already go out at the
    // negotiated version rather than the floor.
    @Test
    func test_view_saveButtonTapped_negotiatesBeforeFillingTheCache() async throws {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                events.withValue { $0.append("storeToken") }
            }
            $0.negotiateApiVersion.execute = { _ in
                events.withValue { $0.append("negotiateApiVersion") }
                return 10
            }
            $0.updateCache.execute = { _ in
                events.withValue { $0.append("updateCache") }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.serverSaved, .testValue())
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(events.value == ["storeToken", "negotiateApiVersion", "updateCache"])
    }

    @Test
    func test_view_saveButtonTapped_unsupportedServerAbortsTheSave() async throws {
        let events = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State(
            input: .testValue()
        )) {
            ServerFormReducer()
        } withDependencies: {
            $0.storeToken.execute = { _, _, _, _ in
                events.withValue { $0.append("storeToken") }
            }
            $0.negotiateApiVersion.execute = { _ in
                throw ApiVersionError.unsupportedServer(6)
            }
            $0.updateCache.execute = { _ in
                events.withValue { $0.append("updateCache") }
            }
        }

        await store.send(.view(.saveButtonTapped))
        await store.receive(\.binding, .set(\.isSaving, true)) {
            $0.isSaving = true
        }
        await store.receive(\.error)
        await store.receive(\.binding, .set(\.isSaving, false)) {
            $0.isSaving = false
        }

        #expect(events.value == ["storeToken"])
    }

    @Test
    func empty_startsWithNoHeaders() {
        withDependencies {
            $0.uuid = .incrementing
        } operation: {
            #expect(ServerFormInput.empty.headers.isEmpty)
        }
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ServersFeature -d "iPhone 17 Pro"`

Expected: FAIL — `value of type 'DependencyValues' has no member 'negotiateApiVersion'` is not the
failure (that member exists from Task 3); the failures are the event-order expectations and
`empty_startsWithNoHeaders`, because `.empty` still pre-fills one header and the effect does not
call the probe.

- [ ] **Step 3: Drop the pre-filled header**

In `Modules/ServersFeature/ServerForm/ServerFormInput.swift`, replace the `empty` static with:

```swift
public extension ServerFormInput {
    static var empty: ServerFormInput {
        @Dependency(\.uuid)
        var uuid

        return .init(
            alias: "",
            headers: [],
            id: uuid().uuidString,
            password: "",
            url: .empty,
            username: ""
        )
    }
}
```

- [ ] **Step 4: Call the probe in the save effect**

In `Modules/ServersFeature/ServerForm/ServerFormReducer+Effect.swift`, add the dependency and the
call:

```swift
    static func runSaveServer(
        input: ServerFormInput
    ) -> Self {
        @Dependency(\.negotiateApiVersion.execute)
        var negotiateApiVersion

        @Dependency(\.storeToken.execute)
        var storeToken

        @Dependency(\.updateCache.execute)
        var updateCache

        return .run { send in
            await send(.binding(.set(\.isSaving, true)))
            try await storeToken(input.code, input.password, input.server, input.username)
            _ = try await negotiateApiVersion(input.server)
            try await updateCache(input.server)
            await send(.delegate(.serverSaved(input.server)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
        } catch: { error, send in
            if error.isMfaCodeRequiredError {
                await send(.mfaCodeRequired)
                return
            }
            await send(.error(error))
            await send(.binding(.set(\.isSaving, false)))
        }
        .cancellable(id: CancelID.saveServer)
    }
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mise exec -- tuist test ServersFeature -d "iPhone 17 Pro"`

Expected: PASS. `ServerListReducerTests` at `ServerListReducerTests.swift:111` constructs
`input: .empty` and asserts state equality — if it fails on the now-empty `headers` array, update its
expected state to match. `ServerFormViewTests` snapshots pass explicit headers and are unaffected.

- [ ] **Step 6: Commit**

```bash
git add Modules/ServersFeature/ServerForm/ServerFormInput.swift \
        Modules/ServersFeature/ServerForm/ServerFormReducer+Effect.swift \
        Modules/ServersFeatureTests
git commit -m "feat: negotiate the API version when saving a server"
```

---

### Task 5: v9 read path for saved view visibility

**Files:**
- Modify: `Modules/ApiImplementation/SavedViews/GetSavedViewsUseCase.swift:42-53`
- Test: Modify `Modules/ApiImplementationTests/SavedViews/GetSavedViewsUseCaseTests.swift`

**Interfaces:**
- Consumes: `SharedReaderKey.apiVersion(_:)` from Task 1.
- Produces: no new symbols. On v9 the use case makes **no** `uiSettingsRepository.getUISettings`
  call and trusts the decoded payload fields; on v10 behaviour is unchanged.

- [ ] **Step 1: Write the failing tests**

In `Modules/ApiImplementationTests/SavedViews/GetSavedViewsUseCaseTests.swift`, add these two tests.
Note the existing `execute()` test relies on the default cache version of 9 — it stubs no
`uiSettingsRepository`, and under the new v9 branch that is exactly right, so leave it alone.

```swift
    @Test
    func execute_onVersion9_usesPayloadFieldsAndSkipsUiSettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let uiSettingsRequested = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.getSavedViews = { _, _ in
                .testValue(next: nil, results: [
                    .testValue(id: 1, showInSidebar: true, showOnDashboard: false)
                ])
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                uiSettingsRequested.setValue(true)
                return .testValue()
            }
        } operation: {
            let savedViews = try await GetSavedViewsUseCase.liveValue.execute(server: server)

            #expect(savedViews.first?.showInSidebar == true)
            #expect(savedViews.first?.showOnDashboard == false)
        }

        #expect(uiSettingsRequested.value == false)
    }

    @Test
    func execute_onVersion10_overlaysVisibilityFromUiSettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        try await withDependencies {
            $0.savedViewsRepository.getSavedViews = { _, _ in
                .testValue(next: nil, results: [
                    .testValue(id: 1, showInSidebar: true, showOnDashboard: true)
                ])
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                .init(
                    settings: .testValue(savedViews: .testValue(
                        dashboardViewsVisibleIds: [1],
                        sidebarViewsVisibleIds: []
                    )),
                    user: .testValue()
                )
            }
        } operation: {
            let savedViews = try await GetSavedViewsUseCase.liveValue.execute(server: server)

            // UISettings is authoritative on v10, so the payload's `true` for sidebar loses.
            #expect(savedViews.first?.showInSidebar == false)
            #expect(savedViews.first?.showOnDashboard == true)
        }
    }
```

Add `import SwiftSharing` and `import Dependencies` to the file if not already present (they are).

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: FAIL — `execute_onVersion9_usesPayloadFieldsAndSkipsUiSettings` reports
`uiSettingsRequested.value == true` and `showInSidebar == false`, because the use case always
overlays from UISettings today.

- [ ] **Step 3: Branch on the negotiated version**

In `Modules/ApiImplementation/SavedViews/GetSavedViewsUseCase.swift`, add
`@Shared(.apiVersion(server)) var apiVersion: Int` next to the other declarations at the top of
`execute`, then replace the block from `let uiSettings = try await uiSettingsRepository.getUISettings(`
through the closing brace of the `result = result.map { ... }` with:

```swift
        // v10 removed show_on_dashboard/show_in_sidebar from saved views and moved them into
        // UISettings. On v9 the payload is authoritative and the extra request is pure waste.
        if apiVersion >= 10 {
            let uiSettings = try await uiSettingsRepository.getUISettings(
                input: .init(),
                server: server
            )
            let sidebarIds = Set(uiSettings.settings.savedViews?.sidebarViewsVisibleIds ?? [])
            let dashboardIds = Set(uiSettings.settings.savedViews?.dashboardViewsVisibleIds ?? [])
            result = result.map {
                var savedView = $0
                savedView.showInSidebar = sidebarIds.contains(savedView.id)
                savedView.showOnDashboard = dashboardIds.contains(savedView.id)
                return savedView
            }
        }
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: PASS, including the pre-existing `execute()` test.

- [ ] **Step 5: Commit**

```bash
git add Modules/ApiImplementation/SavedViews/GetSavedViewsUseCase.swift \
        Modules/ApiImplementationTests/SavedViews/GetSavedViewsUseCaseTests.swift
git commit -m "feat: read saved view visibility from the payload on API v9"
```

---

### Task 6: v9 write path for saved view visibility

**Files:**
- Create: `Modules/ApiInterface/SavedViews/SetSavedViewVisibilityInput.swift`
- Modify: `Modules/ApiImplementation/SavedViews/SavedViewsRepository.swift` (add one client property,
  one `liveValue` entry, one `testValue`/`previewValue` entry, one private method)
- Modify: `Modules/ApiImplementation/SavedViews/SetSavedViewVisibilityUseCase.swift`
- Test: Modify `Modules/ApiImplementationTests/SavedViews/SetSavedViewVisibilityUseCaseTests.swift`
- Test: Modify `Modules/ApiImplementationTests/SavedViews/SavedViewsRepositoryTests.swift`

**Interfaces:**
- Consumes: `SharedReaderKey.apiVersion(_:)` from Task 1.
- Produces:
  - `SetSavedViewVisibilityInput(showInSidebar: Bool, showOnDashboard: Bool)`, `Codable, Equatable,
    Sendable`, encoding to `show_in_sidebar` / `show_on_dashboard`
  - `SavedViewsRepository.setSavedViewVisibility: @Sendable (_ id: SavedView.Id, _ input:
    SetSavedViewVisibilityInput, _ server: Server) async throws -> SaveSavedViewOutput`

`SaveSavedViewInput` deliberately does **not** grow these fields — it backs create and update on the
v10 path, where the fields no longer exist on the serializer.

- [ ] **Step 1: Write the failing tests**

In `Modules/ApiImplementationTests/SavedViews/SetSavedViewVisibilityUseCaseTests.swift`, add these
two tests. The existing `execute_preservesUnrelatedSettings_andMergesVisibility` must now pin the
version — add these three lines at the top of its body, before the `LockIsolated`:

```swift
        @Shared(.apiVersion(Server.testValue()))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }
```

```swift
    @Test
    func execute_onVersion9_patchesTheSavedViewAndSkipsUiSettings() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int

        let received = LockIsolated<(SavedView.Id, SetSavedViewVisibilityInput)?>(nil)
        let uiSettingsRequested = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.setSavedViewVisibility = { id, input, _ in
                received.setValue((id, input))
                return .testValue()
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in
                uiSettingsRequested.setValue(true)
                return .testValue()
            }
        } operation: {
            try await SetSavedViewVisibilityUseCase.liveValue.execute(
                savedViewId: 5,
                showInSidebar: true,
                showOnDashboard: false,
                server: server
            )
        }

        let (id, input) = try #require(received.value)

        #expect(id == 5)
        #expect(input == SetSavedViewVisibilityInput(showInSidebar: true, showOnDashboard: false))
        #expect(uiSettingsRequested.value == false)
        #expect(cache[id: 5]?.showInSidebar == true)
        #expect(cache[id: 5]?.showOnDashboard == false)
    }

    @Test
    func execute_onVersion10_doesNotPatchTheSavedView() async throws {
        let server = Server.testValue()
        @Shared(.apiVersion(server))
        var apiVersion: Int
        $apiVersion.withLock { $0 = 10 }

        let patched = LockIsolated(false)

        try await withDependencies {
            $0.savedViewsRepository.setSavedViewVisibility = { _, _, _ in
                patched.setValue(true)
                return .testValue()
            }
            $0.uiSettingsRepository.getUISettings = { _, _ in .testValue() }
            $0.uiSettingsRepository.updateUISettings = { _, _ in .testValue() }
        } operation: {
            try await SetSavedViewVisibilityUseCase.liveValue.execute(
                savedViewId: 5,
                showInSidebar: true,
                showOnDashboard: false,
                server: server
            )
        }

        #expect(patched.value == false)
    }
```

In `Modules/ApiImplementationTests/SavedViews/SavedViewsRepositoryTests.swift`, add:

```swift
    @Test
    func setSavedViewVisibility_returnsTestValue() async throws {
        let output = try await repository.setSavedViewVisibility(
            id: 1,
            input: .testValue(),
            server: .testValue()
        )

        expectNoDifference(output, .testValue())
    }
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: FAIL — `value of type 'SavedViewsRepository' has no member 'setSavedViewVisibility'`.

- [ ] **Step 3: Create the input type**

Create `Modules/ApiInterface/SavedViews/SetSavedViewVisibilityInput.swift`:

```swift
import Foundation

public struct SetSavedViewVisibilityInput: Codable, Equatable, Sendable {

    public var showInSidebar: Bool

    public var showOnDashboard: Bool

    public init(
        showInSidebar: Bool,
        showOnDashboard: Bool
    ) {
        self.showInSidebar = showInSidebar
        self.showOnDashboard = showOnDashboard
    }
}

public extension SetSavedViewVisibilityInput {

    static func testValue(
        showInSidebar: Bool = true,
        showOnDashboard: Bool = false
    ) -> Self {
        .init(
            showInSidebar: showInSidebar,
            showOnDashboard: showOnDashboard
        )
    }
}
```

No `CodingKeys` needed: `JSONEncoder.apiEncoder` sets
`keyEncodingStrategy = .convertToSnakeCase` (`Modules/ApiInterface/Extensions/JSONEncoder+Extensions.swift:10`),
so these encode as `show_in_sidebar` and `show_on_dashboard` on the wire.

- [ ] **Step 4: Add the repository method**

In `Modules/ApiImplementation/SavedViews/SavedViewsRepository.swift`:

Add to the `@DependencyClient` struct:

```swift
    var setSavedViewVisibility: @Sendable (
        _ id: SavedView.Id,
        _ input: SetSavedViewVisibilityInput,
        _ server: Server
    ) async throws -> SaveSavedViewOutput
```

Add `setSavedViewVisibility: { _, _, _ in .testValue() }` to both `previewValue` and `testValue`,
and `setSavedViewVisibility: setSavedViewVisibility(id:input:server:)` to `liveValue`.

Add to the `private extension`:

```swift
    static func setSavedViewVisibility(
        id: SavedView.Id,
        input: SetSavedViewVisibilityInput,
        server: Server
    ) async throws -> SaveSavedViewOutput {
        try await APIClient
            .client(server: server)
            .send(.init(
                path: "/api/saved_views/\(id)/",
                method: .patch,
                body: input
            ))
            .value
    }
```

- [ ] **Step 5: Branch the use case**

In `Modules/ApiImplementation/SavedViews/SetSavedViewVisibilityUseCase.swift`, add
`import SwiftSharing` if absent (it is already imported), then replace the existing
`static func execute(...)` inside `private extension SetSavedViewVisibilityUseCase` with the two
functions below — `execute` rewritten, plus a new sibling `updateUISettings` holding the v10 path
lifted verbatim out of the old body:

```swift
    static func execute(
        savedViewId: SavedView.Id,
        showInSidebar: Bool,
        showOnDashboard: Bool,
        server: Server
    ) async throws {
        @Shared(.apiVersion(server))
        var apiVersion: Int

        @Shared(.savedViews(server))
        var cache: IdentifiedArrayOf<SavedView> = []

        // v10 removed these fields from the saved view serializer; v9 has no saved_views entry in
        // UISettings, so writing there would be silently discarded.
        if apiVersion >= 10 {
            try await updateUISettings(
                savedViewId: savedViewId,
                showInSidebar: showInSidebar,
                showOnDashboard: showOnDashboard,
                server: server
            )
        } else {
            @Dependency(\.savedViewsRepository)
            var savedViewsRepository

            _ = try await savedViewsRepository.setSavedViewVisibility(
                id: savedViewId,
                input: .init(showInSidebar: showInSidebar, showOnDashboard: showOnDashboard),
                server: server
            )
        }

        $cache.withLock { cache in
            cache[id: savedViewId]?.showInSidebar = showInSidebar
            cache[id: savedViewId]?.showOnDashboard = showOnDashboard
        }
    }

    static func updateUISettings(
        savedViewId: SavedView.Id,
        showInSidebar: Bool,
        showOnDashboard: Bool,
        server: Server
    ) async throws {
        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        let uiSettings = try await uiSettingsRepository.getUISettings(
            input: .init(),
            server: server
        )

        var savedViews = uiSettings.settings.savedViews ?? .init()
        savedViews = .init(
            dashboardViewsVisibleIds: savedViews.dashboardViewsVisibleIds.updating(savedViewId, isIncluded: showOnDashboard),
            sidebarViewsVisibleIds: savedViews.sidebarViewsVisibleIds.updating(savedViewId, isIncluded: showInSidebar)
        )

        var settings = uiSettings.settings
        settings.savedViews = savedViews

        _ = try await uiSettingsRepository.updateUISettings(
            input: .init(settings: settings.raw),
            server: server
        )
    }
```

Leave the `private extension [SavedView.Id]` helper at the bottom of the file unchanged.

- [ ] **Step 6: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro"`

Expected: PASS, including the amended
`execute_preservesUnrelatedSettings_andMergesVisibility`.

- [ ] **Step 7: Run the full suite and lint**

```bash
mise exec -- tuist test -d "iPhone 17 Pro" --skip-ui-tests
mise ci:lint
```

Expected: PASS. Fix any SwiftFormat/SwiftLint findings with `mise format` before committing.

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface/SavedViews/SetSavedViewVisibilityInput.swift \
        Modules/ApiImplementation/SavedViews \
        Modules/ApiImplementationTests/SavedViews
git commit -m "feat: write saved view visibility to the saved view on API v9"
```

---

## Manual verification

The unit tests cover both branches, but neither branch has been exercised against a real v9 server.
`docker/` holds the seed-data setup used by the integration tests
(`docs/plans/2026-08-09-docker-seed-data.md`). Pin an older paperless-ngx image there — one whose
`ALLOWED_VERSIONS` tops out at 9 — add it as a second server, and confirm:

1. The server saves without a 406.
2. `{server-id}-api-version.json` in the app group container contains `9`.
3. Toggling a saved view's sidebar/dashboard switch persists across a cache refresh.

Then repeat against the current image and confirm the file contains `10`.
