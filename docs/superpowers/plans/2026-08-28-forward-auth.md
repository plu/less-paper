# Forward auth through a reverse proxy — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Sign in to a paperless server behind a forward-auth proxy (Authelia, Authentik's proxy
provider, anything speaking the same shape), and recover from an expired session by parking the
bounced request and replaying it after a web login.

**Architecture:** `ApiSessionDelegate` (renamed from `CertificateDelegate`) refuses redirects that
leave the server's host, so both bounce shapes collapse to one: a non-2xx response carrying a
`Location` to a foreign host. `ApiClientDelegate.validateResponse` names that shape, sends
`.redirect` on a channel, and throws `ForwardAuthError.required`; `client(_:shouldRetry:)` awaits
the login's `.finish` and returns `true`. A new `ForwardAuthFeature` module owns the popup, the
`WKWebView` and the app-group cookie handoff. `Credentials.token` becomes optional to accommodate
remote-user mode, which a `GET /api/ui_settings/` probe selects at server setup.

**Tech Stack:** Swift 6, Swift Testing, `swift-dependencies` (`@DependencyClient`,
`withDependencies`), `swift-composable-architecture` (`TestStore`, `@Reducer`), Get (HTTP client),
`swift-async-algorithms` (`AsyncChannel`), `swift-sharing`, `SwiftSecurity`, WebKit,
`swift-snapshot-testing`, Tuist.

**Spec:** [2026-08-28-forward-auth-design.md](../specs/2026-08-28-forward-auth-design.md)

## Global Constraints

- **Comments:** Never `///`, never `/** */`. Only `//`, and only where a future reader would
  otherwise wonder why the code is as it is. See `AGENTS.md`.
- **`@ViewAction` views send with `send`, never `store.send`.** See `AGENTS.md`.
- **Confirmations use `ConfirmationPopupView`, never `.confirmationDialog` or `.alert`.** See
  `AGENTS.md`.
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing`.
  The `--no-selective-testing` flag is required; without it Tuist silently skips unchanged modules.
- **Localization:** `Shared/Framework/Resources/Localizable.xcstrings`, two languages, `en` (source)
  and `de`, every entry `"extractionState" : "manual"`. The file uses `"key" : {` — a space before
  the colon. Insert entries by hand in alphabetical order; do not reformat with a JSON dumper, which
  rewrites all thousands of lines.
- **New `.swift` files in an existing module need no Tuist edit** — targets glob their module
  directory. A new *module* requires the edits enumerated in Task 8.
- **App group:** `group.com.plunien.app.Paperless`, already entitled for `.app`, `.shareApp`, and
  `.shareExtension` in `Module.swift`.
- **Same-host redirects (including `http` → `https` on the same host) are followed.** The
  comparison is on `host()` alone. Refusing a scheme upgrade would break every server configured as
  `http://` that redirects internally.
- **The bounce rule fires only from `ApiClientDelegate`, not from `ImageLoader`.** A scrolling list
  must not raise one login popup per visible thumbnail; a bounced thumbnail simply fails and
  recovers on the next render.
- **`Credentials.token` becoming optional touches every read** — look at each site rather than
  reflexively unwrapping. A `try?` that silently degrades would turn a missing token into
  unauthenticated requests.

---

### Task 1: Vocabulary in `ApiInterface`

**Files:**
- Create: `Modules/ApiInterface/ForwardAuth/ForwardAuthRedirect.swift`
- Create: `Modules/ApiInterface/ForwardAuth/ForwardAuthEvent.swift`
- Create: `Modules/ApiInterface/ForwardAuth/ForwardAuthError.swift`
- Create: `Modules/ApiInterface/ForwardAuth/ForwardAuthChannel.swift`
- Modify: `Modules/ApiInterface/Resources/Localizable.xcstrings` (add
  `forwardAuthRequired` and `forwardAuthRequiredWithHost`)

**Interfaces:**
- Consumes: `Server` (existing).
- Produces:
  - `ForwardAuthRedirect(server: Server, url: URL)` — `Equatable, Sendable`, with
    `.testValue(server:url:)`.
  - `ForwardAuthEvent` — `Equatable, Sendable`, cases `.redirect(ForwardAuthRedirect)` and
    `.finish(ForwardAuthRedirect)`.
  - `ForwardAuthError.required(URL)` — `Equatable, Error, LocalizedError, Sendable`.
    `errorDescription` returns "Sign in required at <host>" localized.
  - `DependencyValues.forwardAuthChannel` — `AsyncChannel<ForwardAuthEvent>`, same shape as
    `certificateApprovalChannel`.

- [ ] **Step 1: Write the failing test for `ForwardAuthError`**

Create `Modules/ApiInterfaceTests/ForwardAuth/ForwardAuthErrorTests.swift`:

```swift
import ApiInterface
import Foundation
import Testing

@Suite
struct ForwardAuthErrorTests {

    @Test
    func errorDescription_namesTheHost() {
        let error = ForwardAuthError.required(URL(string: "https://auth.example.com/login")!)
        #expect(error.errorDescription?.contains("auth.example.com") == true)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing --test-plan ApiInterface --skip-testing ApiInterfaceTests/ForwardAuthErrorTests || true`

Expected: FAIL — `ForwardAuthError` is not defined.

- [ ] **Step 3: Add the two localization keys**

In `Modules/ApiInterface/Resources/Localizable.xcstrings`, insert two entries in alphabetical
order. Insert by hand — do not reformat the file.

```json
"forwardAuthRequired" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Anmeldung erforderlich"
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Sign in required"
      }
    }
  }
},
"forwardAuthRequiredWithHost" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Anmeldung bei %@ erforderlich"
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Sign in required at %@"
      }
    }
  }
},
```

- [ ] **Step 4: Create `ForwardAuthError`**

Create `Modules/ApiInterface/ForwardAuth/ForwardAuthError.swift`:

```swift
import Foundation

public enum ForwardAuthError: Equatable, Error, LocalizedError, Sendable {
    case required(URL)
}

public extension ForwardAuthError {

    var errorDescription: String? {
        switch self {
        case let .required(url):
            guard let host = url.host() else {
                return String(localized: .forwardAuthRequired)
            }
            return String(localized: .forwardAuthRequiredWithHost(host))
        }
    }
}
```

- [ ] **Step 5: Run the error test to verify it passes**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 6: Create the redirect, event and channel**

Create `Modules/ApiInterface/ForwardAuth/ForwardAuthRedirect.swift`:

```swift
import Foundation

public struct ForwardAuthRedirect: Equatable, Sendable {

    public let server: Server

    public let url: URL

    public init(
        server: Server,
        url: URL
    ) {
        self.server = server
        self.url = url
    }
}

public extension ForwardAuthRedirect {

    static func testValue(
        server: Server = .testValue(),
        url: URL = .testValue()
    ) -> Self {
        .init(
            server: server,
            url: url
        )
    }
}
```

Create `Modules/ApiInterface/ForwardAuth/ForwardAuthEvent.swift`:

```swift
public enum ForwardAuthEvent: Equatable, Sendable {
    case finish(ForwardAuthRedirect)
    case redirect(ForwardAuthRedirect)
}
```

Create `Modules/ApiInterface/ForwardAuth/ForwardAuthChannel.swift`:

```swift
import AsyncAlgorithms
import Dependencies

public extension DependencyValues {

    var forwardAuthChannel: AsyncChannel<ForwardAuthEvent> {
        get { self[ForwardAuthChannelKey.self] }
        set { self[ForwardAuthChannelKey.self] = newValue }
    }

    private enum ForwardAuthChannelKey: DependencyKey {
        static let liveValue = AsyncChannel<ForwardAuthEvent>()
        static let testValue = AsyncChannel<ForwardAuthEvent>()
    }
}
```

- [ ] **Step 7: Run the full ApiInterface suite**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface/ForwardAuth Modules/ApiInterfaceTests/ForwardAuth \
    Modules/ApiInterface/Resources/Localizable.xcstrings
git commit -m "feat: name the forward-auth vocabulary in ApiInterface"
```

---

### Task 2: Rename `CertificateDelegate` to `ApiSessionDelegate`

**Files:**
- Rename: `Modules/ApiInterface/Certificates/CertificateDelegate.swift` →
  `Modules/ApiInterface/Session/ApiSessionDelegate.swift`
- Modify: `Modules/ApiImplementation/Extensions/APIClient+Extensions.swift`
- Modify: `Modules/ImageFeature/ImageLoader.swift`
- Modify: `Modules/ApiInterface/Resources/Localizable.xcstrings` (no change — this task is a rename)

**Interfaces:**
- Consumes: `certificateApprovalChannel` (existing, unchanged).
- Produces:
  - `ApiSessionDelegate` — the exact same behaviour as the current `CertificateDelegate`, only
    renamed. No redirect logic yet; that is Task 3.
  - `DependencyValues.apiSessionDelegate` — replaces `certificateDelegate`.

This task is a mechanical rename with **no behaviour change**. Splitting it out means Task 3 is a
diff about redirect handling, not about naming.

- [ ] **Step 1: Rename the file and the type**

Move `Modules/ApiInterface/Certificates/CertificateDelegate.swift` to
`Modules/ApiInterface/Session/ApiSessionDelegate.swift`.

Rename inside the file:

- `class CertificateDelegate` → `class ApiSessionDelegate`
- `extension CertificateDelegate: DependencyKey` → `extension ApiSessionDelegate: DependencyKey`
- `var certificateDelegate: CertificateDelegate` → `var apiSessionDelegate: ApiSessionDelegate`
- The private key type inside the extension — rename to match.

- [ ] **Step 2: Update the two call sites**

In `Modules/ApiImplementation/Extensions/APIClient+Extensions.swift`, change:

```swift
$0.sessionDelegate = Dependency(\.certificateDelegate).wrappedValue
```

to:

```swift
$0.sessionDelegate = Dependency(\.apiSessionDelegate).wrappedValue
```

In `Modules/ImageFeature/ImageLoader.swift` line 40 and line 52, change:

```swift
dataLoader.delegate = certificateDelegate
...
@Dependency(\.certificateDelegate)
private var certificateDelegate
```

to:

```swift
dataLoader.delegate = apiSessionDelegate
...
@Dependency(\.apiSessionDelegate)
private var apiSessionDelegate
```

- [ ] **Step 3: Build to verify nothing else references the old name**

Run: `mise exec -- tuist test ApiImplementation ImageFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS. If a test file still names `certificateDelegate`, rename there too and rerun.

- [ ] **Step 4: Commit**

```bash
git add -A
git commit -m "refactor: rename CertificateDelegate to ApiSessionDelegate

The delegate is about to grow a redirect hook, at which point the current name
covers half of what the type does. Same behaviour, new home."
```

---

### Task 3: Refuse foreign-host redirects in the session delegate

**Files:**
- Modify: `Modules/ApiInterface/Session/ApiSessionDelegate.swift`
- Create: `Modules/ApiInterfaceTests/Session/ApiSessionDelegateTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces: `ApiSessionDelegate.urlSession(_:task:willPerformHTTPRedirection:newRequest:completionHandler:)`.

The comparison is on `host()` alone — a same-host `http` → `https` upgrade is still followed. Only
the *task* stores the server the request belongs to; the delegate is a singleton and gets the host
from the original request's URL.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ApiInterfaceTests/Session/ApiSessionDelegateTests.swift`:

```swift
@testable import ApiInterface

import Foundation
import Testing

@Suite
struct ApiSessionDelegateRedirectTests {

    // A proxy sends the user to its portal on a different name. That is the bounce we must catch.
    @Test
    func foreignHostRedirect_isRefused() async {
        let delegate = ApiSessionDelegate()
        let original = URLRequest(url: URL(string: "https://paperless.example.com/api/documents/")!)
        let task = URLSession.shared.dataTask(with: original)
        let response = HTTPURLResponse(
            url: original.url!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://auth.example.com/login"]
        )!
        let newRequest = URLRequest(url: URL(string: "https://auth.example.com/login")!)

        let handed = await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: newRequest,
                completionHandler: { request in continuation.resume(returning: request) }
            )
        }

        #expect(handed == nil)
    }

    // http → https on the same host is paperless behaving legitimately. Follow it.
    @Test
    func sameHostSchemeUpgrade_isFollowed() async {
        let delegate = ApiSessionDelegate()
        let original = URLRequest(url: URL(string: "http://paperless.example.com/api/documents/")!)
        let task = URLSession.shared.dataTask(with: original)
        let response = HTTPURLResponse(
            url: original.url!,
            statusCode: 301,
            httpVersion: nil,
            headerFields: ["Location": "https://paperless.example.com/api/documents/"]
        )!
        let newRequest = URLRequest(url: URL(string: "https://paperless.example.com/api/documents/")!)

        let handed = await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: newRequest,
                completionHandler: { request in continuation.resume(returning: request) }
            )
        }

        #expect(handed?.url == newRequest.url)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — the delegate has no `willPerformHTTPRedirection` method, so the default
implementation follows the foreign redirect.

- [ ] **Step 3: Add the redirect hook**

In `Modules/ApiInterface/Session/ApiSessionDelegate.swift`, add inside the
`ApiSessionDelegate: NSObject, URLSessionTaskDelegate` class:

```swift
public func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    willPerformHTTPRedirection response: HTTPURLResponse,
    newRequest request: URLRequest,
    completionHandler: @escaping @Sendable (URLRequest?) -> Void
) {
    // Refuse redirects that leave the original request's host. Same host with a different scheme
    // or port is fine — paperless behind a proxy that terminates TLS answers with an https URL for
    // an http request all the time. The proxy's login lives at a different name, and that is the
    // one this catches.
    let originalHost = task.originalRequest?.url?.host()
    let redirectHost = request.url?.host()

    if let originalHost, let redirectHost, originalHost == redirectHost {
        completionHandler(request)
        return
    }

    completionHandler(nil)
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiInterface -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add -A
git commit -m "feat: refuse foreign-host redirects in ApiSessionDelegate

Both bounce shapes collapse to one once the delegate refuses to follow a 3xx
whose Location leaves the request's host. The task then completes with the
3xx itself, which validateResponse turns into the forward-auth error."
```

---

### Task 4: `Credentials.token` becomes optional

**Files:**
- Modify: `Modules/ApiInterface/Authentication/Credentials.swift`
- Modify: `Modules/ApiImplementation/Authentication/Keychain.swift`
- Modify: `Modules/ApiImplementation/Authentication/AuthenticationProvider.swift`
- Modify: `Modules/ApiImplementation/ApiClientDelegate.swift`
- Modify: `Modules/ApiInterface/Authentication/AuthenticationProvider.swift` — signature changes to
  `String?`
- Modify: every test that constructs `Credentials(password:token:)` or asserts on
  `credentials.token` — the compiler will find them.

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `Credentials.token: String?` (was `String`)
  - `Credentials.init(password: String?, token: String?)` (both optional)
  - `Credentials.testValue(password: String? = "T0PS3CR3T!!123", token: String? = "c0ff33")`
  - `AuthenticationProvider.getToken` returns `String?`.

The `Keychain.getCredentials` implementation already reads `password` with `try?`. Reading `token`
the same way is correct here: an entry with no token stored is what remote-user mode looks like.

- [ ] **Step 1: Write the failing test**

Add to `Modules/ApiImplementationTests/ApiClientDelegateTests.swift`:

```swift
@Test
func willSendRequest_omitsAuthorizationWhenThereIsNoToken() async throws {
    let server = Server.testValue()
    let delegate = ApiClientDelegate(server: server)
    var request = URLRequest(url: server.url.appending(path: "/api/documents/"))

    try await withDependencies {
        $0.authenticationProvider.getToken = { _ in nil }
    } operation: {
        try await delegate.client(APIClient(baseURL: server.url), willSendRequest: &request)
    }

    #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — `getToken` currently returns `String`, not `String?`.

- [ ] **Step 3: Make `Credentials.token` optional**

In `Modules/ApiInterface/Authentication/Credentials.swift`, change the type and update the
init and `testValue`. Copy the reasoning comment from `password`:

```swift
public struct Credentials: Equatable, Sendable {

    // Absent for a server signed in through a provider: there is no password to keep, and a type
    // that can say so beats storing an empty string and hoping nothing reads it.
    public let password: String?

    // Absent for a server behind a forward-auth proxy in remote-user mode: the proxy injects a
    // trusted identity header and there is no token to store. Same reasoning as `password` above.
    public let token: String?

    public init(
        password: String?,
        token: String?
    ) {
        self.password = password
        self.token = token
    }
}

public extension Credentials {

    static func testValue(
        password: String? = "T0PS3CR3T!!123",
        token: String? = "c0ff33"
    ) -> Self {
        .init(
            password: password,
            token: token
        )
    }
}
```

- [ ] **Step 4: Widen `AuthenticationProvider.getToken` to return `String?`**

In `Modules/ApiInterface/Authentication/AuthenticationProvider.swift`, change the closure return
type to `String?`, and the `testValue` to `{ _ in "c0ff33" }` (Swift infers `String?`).

- [ ] **Step 5: Update the `AuthenticationProvider` implementations**

In `Modules/ApiImplementation/Authentication/AuthenticationProvider.swift`, change the return
types of both `liveValue`'s helper and `integrationTest`'s closure so they compile against
`Credentials.token: String?` — they already return whatever the keychain gives them.

Change the private `getToken(server:)` to:

```swift
private extension AuthenticationProvider {

    static func getToken(
        server: Server
    ) async throws -> String? {
        @Dependency(\.keychain)
        var keychain

        return try await keychain.getCredentials(
            server: server
        ).token
    }
}
```

- [ ] **Step 6: Update `Keychain.getCredentials` to tolerate a missing token**

In `Modules/ApiImplementation/Authentication/Keychain.swift`, change the token read to `try?`,
mirroring the existing `password` read directly below it. Copy the reasoning:

```swift
private extension Keychain {
    static func getCredentials(
        server: Server
    ) async throws -> Credentials {
        Credentials(
            password: try? keychain.retrieve(
                .credential(for: "\(server.id).password")
            ).get(),
            // Optional for the same reason password is: remote-user mode stores no token, and a
            // read that fails must not fail the whole lookup.
            token: try? keychain.retrieve(
                .credential(for: "\(server.id).token")
            ).get()
        )
    }
}
```

If the surrounding function currently has a different shape (a `try Credentials(...)` with `.get()`
on the token), keep the same outer shape and swap only the token line to `try?`.

- [ ] **Step 7: Update `ApiClientDelegate.willSendRequest`**

In `Modules/ApiImplementation/ApiClientDelegate.swift`, at the current
`let token = try await authenticationProvider.getToken(server: server)` line, change to:

```swift
guard let token = try await authenticationProvider.getToken(server: server) else {
    // Remote-user mode: the proxy injects the identity, and paperless refuses a bare `Token `
    // header with nothing after it. The cookie is what authenticates the request.
    return
}
request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
```

- [ ] **Step 8: Fix the rest of the callers the compiler names**

Run: `mise exec -- tuist test ApiInterface ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

For each compile error, look at what the site does:

- Test setup that constructs `.testValue()` — no change; defaults are still populated.
- Code that reads `credentials.token` and passes it on — the callee likely also takes `String?`
  after this task, or the site is legitimately gate-only (password login) and can unwrap. Prefer
  `guard let token = credentials.token else { throw ... }` at boundaries where a missing token is
  genuinely a bug, and pass `String?` through where it is not.
- **Never `try?` a token read to make the compiler happy.** A silent drop would send
  unauthenticated requests in gate-only mode.

- [ ] **Step 9: Run the whole test suite**

Run: `mise exec -- tuist test -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS. Every existing behaviour still works; the new
`willSendRequest_omitsAuthorizationWhenThereIsNoToken` also passes.

- [ ] **Step 10: Commit**

```bash
git add -A
git commit -m "feat: Credentials.token becomes optional for remote-user mode

Paperless behind a forward-auth proxy with PAPERLESS_ENABLE_HTTP_REMOTE_USER_API
authenticates the injected Remote-User header, so there is no token to store.
Send Authorization only when a token exists; a bare 'Token ' header is worse
than no header at all."
```

---

### Task 5: Detect the bounce, throw `ForwardAuthError`, retry

**Files:**
- Modify: `Modules/ApiImplementation/ApiClientDelegate.swift`
- Modify: `Modules/ApiImplementationTests/ApiClientDelegateTests.swift`

**Interfaces:**
- Consumes:
  - `ForwardAuthEvent`, `ForwardAuthRedirect`, `ForwardAuthError` (Task 1)
  - `DependencyValues.forwardAuthChannel` (Task 1)
- Produces:
  - `ApiClientDelegate.validateResponse` now throws `ForwardAuthError.required(url)` for any
    non-2xx carrying a `Location` header pointing at a different host, after sending
    `.redirect(ForwardAuthRedirect(server:, url:))` on the channel.
  - `ApiClientDelegate.client(_:shouldRetry:task:error:attempts:)` awaits a `.finish` for its own
    server and returns `true`; any other error returns `false`.

**Rendezvous is per-server.** `.finish` for a different server must not release this server's
waiter. The comparison is on `server.id`.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/ApiImplementationTests/ApiClientDelegateTests.swift`:

```swift
@Test
func validateResponse_401WithForeignLocation_throwsForwardAuthRequired() async throws {
    let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
    let delegate = ApiClientDelegate(server: server)
    let response = HTTPURLResponse(
        url: URL(string: "https://paperless.example.com/api/documents/")!,
        statusCode: 401,
        httpVersion: nil,
        headerFields: ["Location": "https://auth.example.com/login"]
    )!
    let task = URLSession.shared.dataTask(with: URLRequest(url: response.url!))

    await withDependencies {
        $0.forwardAuthChannel = AsyncChannel<ForwardAuthEvent>()
    } operation: {
        #expect(throws: ForwardAuthError.required(URL(string: "https://auth.example.com/login")!)) {
            try delegate.client(
                APIClient(baseURL: server.url),
                validateResponse: response,
                data: Data(),
                task: task
            )
        }
    }
}

@Test
func validateResponse_302WithForeignLocation_throwsForwardAuthRequired() async throws {
    let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
    let delegate = ApiClientDelegate(server: server)
    let response = HTTPURLResponse(
        url: URL(string: "https://paperless.example.com/api/documents/")!,
        statusCode: 302,
        httpVersion: nil,
        headerFields: ["Location": "https://auth.example.com/login"]
    )!
    let task = URLSession.shared.dataTask(with: URLRequest(url: response.url!))

    await withDependencies {
        $0.forwardAuthChannel = AsyncChannel<ForwardAuthEvent>()
    } operation: {
        #expect(throws: ForwardAuthError.required(URL(string: "https://auth.example.com/login")!)) {
            try delegate.client(
                APIClient(baseURL: server.url),
                validateResponse: response,
                data: Data(),
                task: task
            )
        }
    }
}

// A 401 with no Location is an ordinary unauthorized — a stale token, a wrong password. Opening
// a browser for that would be worse than reporting it.
@Test
func validateResponse_401WithoutLocation_isOrdinaryUnauthorized() throws {
    let server = Server.testValue()
    let delegate = ApiClientDelegate(server: server)
    let response = HTTPURLResponse(
        url: server.url.appending(path: "/api/documents/"),
        statusCode: 401,
        httpVersion: nil,
        headerFields: nil
    )!
    let task = URLSession.shared.dataTask(with: URLRequest(url: response.url!))
    let apiError = try! JSONEncoder().encode(["detail": "Invalid token"])

    #expect(throws: (any Error).self) {
        try delegate.client(
            APIClient(baseURL: server.url),
            validateResponse: response,
            data: apiError,
            task: task
        )
    }

    // The thrown error must not be ForwardAuthError.
    do {
        try delegate.client(APIClient(baseURL: server.url), validateResponse: response, data: apiError, task: task)
    } catch is ForwardAuthError {
        Issue.record("a 401 without Location must not raise a forward-auth login")
    } catch {
        // Expected: the ordinary ApiError.
    }
}

// Same-origin redirects are what the session delegate follows silently, not what
// validateResponse ever sees — but if a proxy answers 302 back to the same host, that is not a
// forward-auth bounce either.
@Test
func validateResponse_sameHostLocation_isNotABounce() throws {
    let server = Server.testValue(url: URL(string: "https://paperless.example.com")!)
    let delegate = ApiClientDelegate(server: server)
    let response = HTTPURLResponse(
        url: URL(string: "https://paperless.example.com/api/documents/")!,
        statusCode: 302,
        httpVersion: nil,
        headerFields: ["Location": "https://paperless.example.com/api/documents/?page=2"]
    )!
    let task = URLSession.shared.dataTask(with: URLRequest(url: response.url!))

    do {
        try delegate.client(APIClient(baseURL: server.url), validateResponse: response, data: Data(), task: task)
    } catch is ForwardAuthError {
        Issue.record("a same-host redirect must not raise a forward-auth login")
    } catch {
        // Expected: the ordinary 3xx-outside-2xx range error.
    }
}
```

- [ ] **Step 2: Run to verify the tests fail**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — the delegate does not recognize the bounce shape.

- [ ] **Step 3: Add the bounce rule to `validateResponse`**

In `Modules/ApiImplementation/ApiClientDelegate.swift`, add ahead of the existing status-code
branches inside `validateResponse`:

```swift
if !(200 ..< 300).contains(response.statusCode),
   let location = response.value(forHTTPHeaderField: "Location"),
   let redirectURL = URL(string: location),
   let redirectHost = redirectURL.host(),
   let serverHost = server.url.host(),
   redirectHost != serverHost {
    // Any non-2xx with a Location leaving the server's host is a proxy telling us to sign in.
    // Both bounce shapes end up here: the 401+Location one directly, and the 3xx one after
    // ApiSessionDelegate refused to follow it.
    Task { [server] in
        @Dependency(\.forwardAuthChannel)
        var channel
        await channel.send(.redirect(ForwardAuthRedirect(server: server, url: redirectURL)))
    }
    throw ForwardAuthError.required(redirectURL)
}
```

Also add the import at the top if not already present:

```swift
import AsyncAlgorithms
```

- [ ] **Step 4: Add `shouldRetry` that awaits `.finish`**

Add to the `extension ApiClientDelegate: Get.APIClientDelegate` in the same file:

```swift
func client(
    _ client: APIClient,
    shouldRetry task: URLSessionTask,
    error: any Error,
    attempts: Int
) async throws -> Bool {
    guard case ForwardAuthError.required = error else {
        return false
    }

    // Every parked request awaits the same event. Ten concurrent bounces at launch produce one
    // login, and each request replays as soon as it finishes.
    @Dependency(\.forwardAuthChannel)
    var channel

    for await event in channel {
        if case let .finish(redirect) = event, redirect.server.id == server.id {
            return true
        }
    }

    return false
}
```

- [ ] **Step 5: Add a reducer-shaped test for the rendezvous**

Add to `Modules/ApiImplementationTests/ApiClientDelegateTests.swift`:

```swift
@Test
func shouldRetry_waitsForFinishForItsOwnServer() async throws {
    let server = Server.testValue(id: "waiter")
    let delegate = ApiClientDelegate(server: server)
    let channel = AsyncChannel<ForwardAuthEvent>()

    let result = await withDependencies {
        $0.forwardAuthChannel = channel
    } operation: {
        async let retry = delegate.client(
            APIClient(baseURL: server.url),
            shouldRetry: URLSession.shared.dataTask(with: URLRequest(url: server.url)),
            error: ForwardAuthError.required(URL(string: "https://auth.example.com/login")!),
            attempts: 1
        )

        // A finish for a different server must not release this waiter.
        await channel.send(.finish(ForwardAuthRedirect(
            server: .testValue(id: "someone-else"),
            url: URL(string: "https://auth.example.com/login")!
        )))
        try? await Task.sleep(for: .milliseconds(50))

        await channel.send(.finish(ForwardAuthRedirect(
            server: server,
            url: URL(string: "https://auth.example.com/login")!
        )))

        return try? await retry
    }

    #expect(result == true)
}

@Test
func shouldRetry_returnsFalseForAnyOtherError() async throws {
    let server = Server.testValue()
    let delegate = ApiClientDelegate(server: server)

    let result = try await delegate.client(
        APIClient(baseURL: server.url),
        shouldRetry: URLSession.shared.dataTask(with: URLRequest(url: server.url)),
        error: URLError(.notConnectedToInternet),
        attempts: 1
    )

    #expect(result == false)
}
```

- [ ] **Step 6: Run all delegate tests**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: detect the forward-auth bounce and park the request

validateResponse throws ForwardAuthError for a non-2xx carrying a Location to
a foreign host - one rule covering both bounce shapes, because
ApiSessionDelegate turns the 3xx shape into the 401+Location shape by
refusing to follow it. shouldRetry awaits the login's .finish for the same
server and replays the request; sessions expiring mid-scroll are a pause, not
an error toast."
```

---

### Task 6: App-group cookie storage on the session

**Files:**
- Modify: `Modules/ApiImplementation/Extensions/APIClient+Extensions.swift`
- Test: no unit test — this is a `URLSessionConfiguration` wiring, and asserting
  `HTTPCookieStorage.sharedCookieStorage(forGroupContainerIdentifier:)` in a unit test would just
  restate the code. Verified end to end in Task 12.

**Interfaces:**
- Consumes: nothing.
- Produces: `URLSession` on every `APIClient` reads and writes cookies to the app-group store.

- [ ] **Step 1: Update the extension**

In `Modules/ApiImplementation/Extensions/APIClient+Extensions.swift`:

```swift
public extension APIClient {

    static func liveValue(
        server: Server
    ) -> APIClient {
        APIClient(baseURL: server.url) {
            $0.decoder = .apiDecoder
            $0.delegate = ApiClientDelegate(server: server)
            $0.encoder = .apiEncoder
            $0.sessionConfiguration = .apiClient
            $0.sessionDelegate = Dependency(\.apiSessionDelegate).wrappedValue
        }
    }
}

private extension URLSessionConfiguration {

    // Shared with the share extension through the app group, so a live session in the app
    // authenticates a share without a second login.
    static let apiClient: URLSessionConfiguration = {
        let configuration = URLSessionConfiguration.default
        configuration.httpCookieStorage = HTTPCookieStorage.sharedCookieStorage(
            forGroupContainerIdentifier: "group.com.plunien.app.Paperless"
        )
        return configuration
    }()
}
```

- [ ] **Step 2: Build**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: share the API session cookies through the app group

The share extension is entitled for the same group. Once the user has signed
in through the proxy in the main app, a share is authenticated for free."
```

---

### Task 7: `GetForwardAuthIdentityUseCase` — the mode probe

**Files:**
- Create: `Modules/ApiInterface/ForwardAuth/GetForwardAuthIdentityUseCase.swift`
- Create: `Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift`
- Create: `Modules/ApiImplementationTests/ForwardAuth/GetForwardAuthIdentityUseCaseTests.swift`

**Interfaces:**
- Consumes: `Server` (existing), `UISettings` and its repository (existing), `UsersRepository`
  (existing — the `/api/users/{id}/` follow-up).
- Produces:
  - `GetForwardAuthIdentityUseCase.execute: (_ server: Server) async throws -> String?`
  - `DependencyValues.getForwardAuthIdentity`

`nil` means the proxy is gate-only and the ordinary login path applies. A non-`nil` string is the
username to store on the `Server` so remote-user mode shows a real name in the switcher.

The use case makes one request without an `Authorization` header:
`GET {server.url}/api/ui_settings/`. A 200 answer means the proxy is injecting a trusted identity;
its `.user.id` is then fed through `GET /api/users/{id}/` to fetch the username. A 401 means the
proxy is a gate only; the use case returns `nil`.

- [ ] **Step 1: Confirm the existing repositories**

Run: `find Modules/ApiInterface -name "UISettings*" -o -name "Users*" -o -name "User.swift"`
and read `Modules/ApiImplementation/UISettings/UISettingsRepository.swift` and
`Modules/ApiImplementation/Users/UsersRepository.swift`. Note the exact method names for
"get UI settings" and "get user by id" — this task uses them.

If either repository does not expose the needed operation, that is a separate task before this
one; stop and report before implementing.

- [ ] **Step 2: Write the failing tests**

Create `Modules/ApiImplementationTests/ForwardAuth/GetForwardAuthIdentityUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(.dependencies())
struct GetForwardAuthIdentityUseCaseTests {

    // A 200 without an Authorization header means the proxy is injecting Remote-User; the app
    // stores a server with no token and shows that username.
    @Test
    func remoteUser_returnsTheUsername() async throws {
        let username = try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                UISettings(settings: .init(), user: .init(id: 42))
            }
            $0.usersRepository.getUser = { _, id in
                #expect(id.rawValue == 42)
                return User.testValue(id: 42, username: "authelia-user")
            }
        } operation: {
            try await GetForwardAuthIdentityUseCase.liveValue.execute(server: .testValue())
        }

        #expect(username == "authelia-user")
    }

    // 401 means the proxy is only a gate: the app has to run the ordinary token login next.
    @Test
    func gateOnly_returnsNil() async throws {
        let username = try await withDependencies {
            $0.uiSettingsRepository.getUISettings = { _, _ in
                throw ApiError.unauthorized
            }
        } operation: {
            try await GetForwardAuthIdentityUseCase.liveValue.execute(server: .testValue())
        }

        #expect(username == nil)
    }
}
```

Adjust `ApiError.unauthorized` to whatever the repository actually throws for a 401 — read
`ApiClientDelegate.validateResponse` for the shape.

- [ ] **Step 3: Run to verify tests fail**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — the use case does not exist.

- [ ] **Step 4: Add the interface**

Create `Modules/ApiInterface/ForwardAuth/GetForwardAuthIdentityUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros

@DependencyClient
public struct GetForwardAuthIdentityUseCase: Sendable {

    // `nil` when the proxy only gates the request; the caller then runs the ordinary token login.
    // A non-nil username means paperless authenticated the proxy-injected identity, and no token
    // needs to be stored.
    public var execute: @Sendable (
        _ server: Server
    ) async throws -> String?
}

extension GetForwardAuthIdentityUseCase: TestDependencyKey {

    public static let testValue = Self()
}

public extension DependencyValues {

    var getForwardAuthIdentity: GetForwardAuthIdentityUseCase {
        get { self[GetForwardAuthIdentityUseCase.self] }
        set { self[GetForwardAuthIdentityUseCase.self] = newValue }
    }
}
```

- [ ] **Step 5: Add the live implementation**

Create `Modules/ApiImplementation/ForwardAuth/GetForwardAuthIdentityUseCase.swift`:

```swift
import ApiInterface
import Dependencies

extension GetForwardAuthIdentityUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension GetForwardAuthIdentityUseCase {

    static func execute(server: Server) async throws -> String? {
        @Dependency(\.uiSettingsRepository)
        var uiSettingsRepository

        @Dependency(\.usersRepository)
        var usersRepository

        do {
            let settings = try await uiSettingsRepository.getUISettings(
                input: .init(),
                server: server
            )
            let user = try await usersRepository.getUser(server, settings.user.id)
            return user.username
        } catch {
            // A 401 without a Location header is what a gate-only proxy answers when there is no
            // cookie: the API rejects an unauthenticated call. Anything else — the network, a bad
            // certificate, the server being off — is a real failure and belongs to the caller.
            if error.isUnauthorized {
                return nil
            }
            throw error
        }
    }
}

private extension Error {
    var isUnauthorized: Bool {
        // Match whatever ApiClientDelegate.validateResponse throws for 401 — read that file and
        // adjust. If it decodes an ApiError, this is `(self as? ApiError)?.statusCode == 401`.
        (self as NSError).code == 401
    }
}
```

Read `Modules/ApiImplementation/ApiClientDelegate.swift`'s 401 branch and update
`isUnauthorized` to actually match what that path throws. This shim exists because the exact
type is not visible without opening that file, not because it should be an `NSError` check.

- [ ] **Step 6: Wire the dependencies onto `ApiImplementation`**

The dependency lists in `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` under
`.apiImplementation` already include everything this needs. No Tuist change.

- [ ] **Step 7: Run to verify tests pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: probe for remote-user mode with GetForwardAuthIdentityUseCase

Once the cookie lands, one unauthenticated GET /api/ui_settings/ decides
whether the server needs a paperless token as well. 200 -> the proxy is
injecting a trusted identity; fetch the user's name and store the server
with no token. 401 -> the proxy is only a gate; the caller runs the ordinary
login next."
```

---

### Task 8: New `ForwardAuthFeature` module skeleton

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift` (enum cases, `codeCoverageTarget`,
  `product`)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`
- Create: `Modules/ForwardAuthFeature/Placeholder.swift` (deleted in Task 9 when the reducer lands)
- Create: `Modules/ForwardAuthFeatureTests/Placeholder.swift` (deleted in Task 9)

**Interfaces:**
- Consumes: nothing yet.
- Produces: a compilable `ForwardAuthFeature` module and its test target.

The Tuist switches are **exhaustive** — missing a case is a manifest compile error, not a silent
skip.

- [ ] **Step 1: Register the enum cases**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, add in alphabetical order after
`case documentsFeatureTests`:

```swift
    case forwardAuthFeature = "ForwardAuthFeature"
    case forwardAuthFeatureTests = "ForwardAuthFeatureTests"
```

- [ ] **Step 2: Register `codeCoverageTarget`**

In the same file's `codeCoverageTarget`, add `.forwardAuthFeature,` to the `true` list (with the
other feature modules, alphabetical order) and `.forwardAuthFeatureTests,` to the `false` list.

- [ ] **Step 3: Register `product`**

Add `.forwardAuthFeature,` to the framework list, and `.forwardAuthFeatureTests,` to the unit-test
list.

- [ ] **Step 4: Register the dependencies**

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add in the alphabetical position
between `documentsFeatureTests` and `imageFeature`:

```swift
        case .forwardAuthFeature:
            [
                .external(.asyncAlgorithms),
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.certificatesFeature),
                .target(.components),
            ]
        case .forwardAuthFeatureTests:
            [
                .external(.asyncAlgorithms),
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.forwardAuthFeature),
                .target(.testSupport),
            ]
```

`certificatesFeature` is a dependency because the web view routes challenges through
`certificateApprovalChannel`, and reusing that channel means depending on the module that owns it.

- [ ] **Step 5: Register the schemes**

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`, add `.forwardAuthFeature` to the
alphabetized list in the `case .apiImplementation, .apiInterface, …` block (feature scheme).

- [ ] **Step 6: Add `.forwardAuthFeature` to `AppFeature`'s dependencies**

In `Module+Dependencies.swift` under `.appFeature`, add `.target(.forwardAuthFeature),` after
`.certificatesFeature`. This is what Task 10 wires into `AppReducer`.

- [ ] **Step 7: Create placeholder files so the module compiles**

Create `Modules/ForwardAuthFeature/Placeholder.swift`:

```swift
// Placeholder so the module compiles. Removed when ForwardAuthReducer lands in the next task.
```

Create `Modules/ForwardAuthFeatureTests/Placeholder.swift`:

```swift
// Placeholder so the test target has at least one source. Removed when real tests land.
```

- [ ] **Step 8: Generate and build**

Run: `mise exec -- tuist install && mise exec -- tuist generate`

Then: `mise exec -- tuist test ForwardAuthFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS (the empty target compiles).

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "chore: add ForwardAuthFeature module skeleton"
```

---

### Task 9: `ForwardAuthReducer` and the popup

**Files:**
- Create: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthReducer.swift`
- Create: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthReducer+Effect.swift`
- Create: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthPresenter.swift`
- Create: `Modules/ForwardAuthFeatureTests/ForwardAuth/ForwardAuthReducerTests.swift`
- Delete: `Modules/ForwardAuthFeature/Placeholder.swift`
- Delete: `Modules/ForwardAuthFeatureTests/Placeholder.swift`

**Interfaces:**
- Consumes: `ForwardAuthEvent`, `ForwardAuthRedirect`, `forwardAuthChannel` (Task 1),
  `PopupPresenter` (Components).
- Produces:
  - `ForwardAuthReducer` — `@Reducer public struct` with `.bootstrap`, `.finish(ForwardAuthRedirect)`,
    `.redirect(ForwardAuthRedirect)`, and `.confirmed(ForwardAuthRedirect)` /
    `.cancelled(ForwardAuthRedirect)` actions from the popup.
  - `ForwardAuthReducer.State` — `@ObservableState`, holds an optional `redirect:
    ForwardAuthRedirect?`.
  - `Effect.runForwardAuthObserver()` — subscribes to the channel and forwards `.finish` and
    `.redirect` into the reducer.

The web view is not built in this task — the confirmation popup and the channel plumbing are. The
`.confirmed` action's effect is a `TODO` in this task; Task 10 replaces it.

- [ ] **Step 1: Delete the placeholders**

```bash
git rm Modules/ForwardAuthFeature/Placeholder.swift
git rm Modules/ForwardAuthFeatureTests/Placeholder.swift
```

- [ ] **Step 2: Write the failing reducer tests**

Create `Modules/ForwardAuthFeatureTests/ForwardAuth/ForwardAuthReducerTests.swift`:

```swift
import ApiInterface
import AsyncAlgorithms
import ComposableArchitecture
@testable import ForwardAuthFeature
import Testing

@Suite
struct ForwardAuthReducerTests {

    @Test
    func redirect_setsStateAndPresents() async {
        let store = await TestStore(initialState: ForwardAuthReducer.State()) {
            ForwardAuthReducer()
        }

        let redirect = ForwardAuthRedirect.testValue()

        await store.send(.redirect(redirect)) {
            $0.redirect = redirect
        }
    }

    // A .redirect arriving while one is presented is discarded. Ten concurrent bounces at launch
    // produce one login, not ten.
    @Test
    func redirect_isIgnoredWhileOneIsAlreadyPresented() async {
        let first = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-1.example.com")!)
        let second = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-2.example.com")!)

        let store = await TestStore(initialState: ForwardAuthReducer.State()) {
            ForwardAuthReducer()
        }

        await store.send(.redirect(first)) {
            $0.redirect = first
        }
        await store.send(.redirect(second))
    }

    // .finish for the same redirect clears the state so the next request can raise a fresh login.
    @Test
    func finish_clearsMatchingRedirect() async {
        let redirect = ForwardAuthRedirect.testValue()

        let store = await TestStore(
            initialState: ForwardAuthReducer.State(redirect: redirect)
        ) {
            ForwardAuthReducer()
        }

        await store.send(.finish(redirect)) {
            $0.redirect = nil
        }
    }

    // .finish for a different redirect is ignored — the presented one still needs its own finish.
    @Test
    func finish_forDifferentRedirect_isIgnored() async {
        let presented = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-1.example.com")!)
        let other = ForwardAuthRedirect.testValue(url: URL(string: "https://auth-2.example.com")!)

        let store = await TestStore(
            initialState: ForwardAuthReducer.State(redirect: presented)
        ) {
            ForwardAuthReducer()
        }

        await store.send(.finish(other))
    }
}
```

- [ ] **Step 3: Run to verify tests fail**

Run: `mise exec -- tuist test ForwardAuthFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — the reducer does not exist.

- [ ] **Step 4: Write the reducer**

Create `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthReducer.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture

@Reducer
public struct ForwardAuthReducer: Sendable {

    @CasePathable
    public enum Action {

        case bootstrap

        case cancelled(ForwardAuthRedirect)

        case confirmed(ForwardAuthRedirect)

        case finish(ForwardAuthRedirect)

        case redirect(ForwardAuthRedirect)
    }

    @ObservableState
    public struct State: Equatable {

        public var redirect: ForwardAuthRedirect?

        public init(redirect: ForwardAuthRedirect? = nil) {
            self.redirect = redirect
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .bootstrap:
                return .runForwardAuthObserver()

            case let .cancelled(redirect):
                // A user who dismisses the popup is a user who has decided not to sign in. The
                // parked request has to be released - a .finish is the only signal shouldRetry
                // waits for, and this returns false to it.
                return .runReleaseWaiters(redirect: redirect)

            case let .confirmed(redirect):
                // TODO(Task 10): present the WKWebView. For now, the popup confirming is treated
                // as if the login completed instantly; the test suite covers the state machine,
                // not the web view.
                return .runReleaseWaiters(redirect: redirect)

            case let .finish(redirect):
                guard state.redirect == redirect else {
                    return .none
                }
                state.redirect = nil
                return .none

            case let .redirect(redirect):
                guard state.redirect == nil else {
                    return .none
                }
                state.redirect = redirect
                return .runPresentConfirmation(redirect: redirect)
            }
        }
    }

    public init() {}
}
```

Create `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthReducer+Effect.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture

extension Effect where Action == ForwardAuthReducer.Action {

    static func runForwardAuthObserver() -> Self {
        .run { send in
            @Dependency(\.forwardAuthChannel)
            var channel

            for await event in channel {
                switch event {
                case let .finish(redirect):
                    await send(.finish(redirect))

                case let .redirect(redirect):
                    await send(.redirect(redirect))
                }
            }
        }
    }

    static func runPresentConfirmation(redirect: ForwardAuthRedirect) -> Self {
        .run { send in
            @Dependency(\.forwardAuthConfirmation.present)
            var presentConfirmation

            let confirmed = await presentConfirmation(host: redirect.url.host() ?? redirect.url.absoluteString)

            if confirmed {
                await send(.confirmed(redirect))
            } else {
                await send(.cancelled(redirect))
            }
        }
    }

    static func runReleaseWaiters(redirect: ForwardAuthRedirect) -> Self {
        .run { _ in
            @Dependency(\.forwardAuthChannel)
            var channel

            await channel.send(.finish(redirect))
        }
    }
}
```

Create `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthPresenter.swift`:

```swift
import Components
import Dependencies
import DependenciesMacros
import SwiftUI

@DependencyClient
struct ForwardAuthConfirmationPresenter: Sendable {

    // Returns true if the user tapped "Sign in", false if they dismissed the popup.
    var present: @Sendable (_ host: String) async -> Bool = { _ in false }
}

extension ForwardAuthConfirmationPresenter: TestDependencyKey {

    static let testValue = Self()
}

extension DependencyValues {

    var forwardAuthConfirmation: ForwardAuthConfirmationPresenter {
        get { self[ForwardAuthConfirmationPresenter.self] }
        set { self[ForwardAuthConfirmationPresenter.self] = newValue }
    }
}

extension ForwardAuthConfirmationPresenter: DependencyKey {

    static let liveValue = Self(
        present: { host in
            await withCheckedContinuation { continuation in
                @Dependency(\.popupPresenter)
                var popupPresenter

                Task {
                    await popupPresenter.present {
                        ConfirmationPopupView(
                            title: .forwardAuthPopupTitle,
                            message: .forwardAuthPopupMessage(host),
                            confirmTitle: .forwardAuthPopupSignIn,
                            confirm: {
                                Task {
                                    await popupPresenter.dismiss()
                                    continuation.resume(returning: true)
                                }
                            },
                            cancel: {
                                Task {
                                    await popupPresenter.dismiss()
                                    continuation.resume(returning: false)
                                }
                            }
                        )
                    }
                }
            }
        }
    )
}
```

Add three strings to `Shared/Framework/Resources/Localizable.xcstrings` in alphabetical order —
`forwardAuthPopupMessage` (with `%@` for the host), `forwardAuthPopupSignIn`, and
`forwardAuthPopupTitle`. Follow the localization format described in Global Constraints and copy
the exact JSON block shape from an entry already in the file.

Match the exact `ConfirmationPopupView` initializer that exists — read
`Modules/Components/Popup/ConfirmationPopupView.swift` and adjust if the parameter names differ.

- [ ] **Step 5: Run to verify reducer tests pass**

Run: `mise exec -- tuist test ForwardAuthFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: ForwardAuthReducer plus the confirmation popup

The reducer observes forwardAuthChannel and manages one redirect at a time.
Ten concurrent bounces produce one popup; a cancelled popup releases waiters
with a .finish so shouldRetry can return false rather than hang. The web view
is a TODO for the next task - confirming currently completes the login
immediately."
```

---

### Task 10: The `WKWebView` and the cookie handoff

**Files:**
- Create: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthWebView.swift`
- Create: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthSheetView.swift`
- Create: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthSheetPresenter.swift`
- Modify: `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthReducer.swift` (replace the `.confirmed`
  effect)
- Create: `Modules/ForwardAuthFeatureTests/ForwardAuth/ForwardAuthWebViewCookieTests.swift`

**Interfaces:**
- Consumes: `ForwardAuthRedirect`, `certificateApprovalChannel`.
- Produces:
  - `ForwardAuthWebView` — `UIViewRepresentable` wrapping `WKWebView`, seeded from and writing back
    to the app-group cookie store, with a completion callback fired when the response host matches
    the server's.
  - `ForwardAuthSheetView` — the modal chrome: title with host, close button, `ForwardAuthWebView`.
  - `ForwardAuthSheetPresenter` — presents the sheet and returns when it dismisses.

The web view **seeds cookies from app-group storage before the first load** so a live session does
not force a re-login. On every navigation response whose host matches `redirect.server.url.host()`,
it copies `WKHTTPCookieStore` back into app-group `HTTPCookieStorage`.

Certificate challenges route through `certificateApprovalChannel` — do not `.useCredential` on any
`serverTrust` unconditionally, which is what both prior attempts got wrong. Reuse
`CertificateApprovalRequest` exactly as `ApiSessionDelegate` does.

- [ ] **Step 1: Write the seed test**

Create `Modules/ForwardAuthFeatureTests/ForwardAuth/ForwardAuthWebViewCookieTests.swift`:

```swift
@testable import ForwardAuthFeature

import Foundation
import Testing
import WebKit

@Suite
struct ForwardAuthWebViewCookieTests {

    // Seeding is what makes a live session not force a re-login. Without this test, a change to
    // `makeUIView` that skipped the copy would go unnoticed until someone manually re-authed.
    @Test
    @MainActor
    func makeUIView_seedsCookiesFromTheAppGroupStore() async throws {
        let store = HTTPCookieStorage.sharedCookieStorage(
            forGroupContainerIdentifier: "group.com.plunien.app.Paperless"
        )
        store.cookies?.forEach { store.deleteCookie($0) }

        let cookie = HTTPCookie(properties: [
            .domain: "auth.example.com",
            .path: "/",
            .name: "authelia_session",
            .value: "seeded",
        ])!
        store.setCookie(cookie)

        let view = ForwardAuthWebView(
            redirect: .testValue(url: URL(string: "https://auth.example.com/")!),
            onFinished: {}
        )
        let webView = view.makeUIView(context: makeContext(for: view))

        // Give the WebKit process a beat to accept the seeded cookies.
        try await Task.sleep(for: .milliseconds(100))
        let seeded = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()

        #expect(seeded.contains(where: { $0.name == "authelia_session" }))
    }

    @MainActor
    private func makeContext(for view: ForwardAuthWebView) -> ForwardAuthWebView.Context {
        // UIViewRepresentableContext cannot be constructed directly. Use the coordinator's own
        // hook — the test only exercises makeUIView, and the context is unused in the body of
        // makeUIView for cookie seeding.
        fatalError("Provide a Context substitute per the SwiftUI helpers in TestSupport")
    }
}
```

The `makeContext` fatal is a placeholder — Swift does not let a test construct a
`UIViewRepresentableContext` directly. Choose one of:

1. Refactor `ForwardAuthWebView` to take a small `configure(_ webView: WKWebView)` helper that
   does the seed, and call **that** from the test on a stub `WKWebView`. This is the cleanest
   option and what the test above is really asking for.
2. Keep everything inline and change the test to construct the `UIViewController` hosting the
   representable.

Option 1 is the target; adjust the test accordingly once the view is refactored.

- [ ] **Step 2: Run to verify the test fails**

Run: `mise exec -- tuist test ForwardAuthFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — the view does not exist.

- [ ] **Step 3: Implement the web view**

Create `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthWebView.swift`:

```swift
import ApiInterface
import Dependencies
import SwiftUI
import WebKit

struct ForwardAuthWebView: UIViewRepresentable {

    let redirect: ForwardAuthRedirect

    let onFinished: () -> Void

    static let appGroupCookieStorage = HTTPCookieStorage.sharedCookieStorage(
        forGroupContainerIdentifier: "group.com.plunien.app.Paperless"
    )

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.navigationDelegate = context.coordinator

        seed(webView) {
            webView.load(URLRequest(url: redirect.url))
        }

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.navigationDelegate = context.coordinator
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // Extracted so a test can exercise the seed without constructing a Context.
    func seed(_ webView: WKWebView, then next: @escaping () -> Void) {
        Task { @MainActor in
            let cookies = Self.appGroupCookieStorage.cookies ?? []
            for cookie in cookies {
                await webView.configuration.websiteDataStore.httpCookieStore.setCookie(cookie)
            }
            next()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {

        let parent: ForwardAuthWebView

        init(_ parent: ForwardAuthWebView) {
            self.parent = parent
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse
        ) async -> WKNavigationResponsePolicy {
            guard let response = navigationResponse.response as? HTTPURLResponse,
                  response.url?.host() == parent.redirect.server.url.host()
            else {
                return .allow
            }

            let cookies = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()
            for cookie in cookies {
                Self.appGroupCookieStorage.setCookie(cookie)
            }

            await MainActor.run { parent.onFinished() }

            return .allow
        }

        @MainActor
        func webView(
            _ webView: WKWebView,
            respondTo challenge: URLAuthenticationChallenge
        ) async -> (URLSession.AuthChallengeDisposition, URLCredential?) {
            await withCheckedContinuation { continuation in
                Task {
                    @Dependency(\.certificateApprovalChannel)
                    var channel

                    let request = CertificateApprovalRequest(
                        challenge: challenge,
                        completion: { disposition, credential in
                            continuation.resume(returning: (disposition, credential))
                        },
                        url: webView.url
                    )
                    await channel.send(.request(request))
                }
            }
        }
    }
}

private let appGroupCookieStorage = HTTPCookieStorage.sharedCookieStorage(
    forGroupContainerIdentifier: "group.com.plunien.app.Paperless"
)
```

Create `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthSheetView.swift`:

```swift
import ApiInterface
import Components
import SwiftUI

struct ForwardAuthSheetView: View {

    let redirect: ForwardAuthRedirect

    let onFinished: () -> Void

    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            ForwardAuthWebView(redirect: redirect, onFinished: onFinished)
                .navigationBarTitleDisplayMode(.inline)
                .navigationTitle(redirect.url.host() ?? "")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: onCancel) {
                            Label(.close, systemImage: "xmark.circle")
                        }
                    }
                }
        }
    }
}
```

Reuse the existing `close` string in `Localizable.xcstrings`. If it does not exist, add it.

Create `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthSheetPresenter.swift` following the same
`@DependencyClient` shape as `ForwardAuthConfirmationPresenter`, with:

```swift
var present: @Sendable (_ redirect: ForwardAuthRedirect) async -> Void
```

The live implementation presents `ForwardAuthSheetView` through `PopupPresenter` (or the
project's sheet-presentation abstraction — read `Modules/Components/Popup/` for the pattern) and
returns when either `onFinished` or `onCancel` fires. The web view's `onFinished` sends `.finish`
on `forwardAuthChannel`; the cancel path does the same, so waiters are released either way.

- [ ] **Step 4: Replace the `.confirmed` effect**

In `Modules/ForwardAuthFeature/ForwardAuth/ForwardAuthReducer+Effect.swift`, add:

```swift
static func runPresentLogin(redirect: ForwardAuthRedirect) -> Self {
    .run { send in
        @Dependency(\.forwardAuthSheet.present)
        var presentSheet

        await presentSheet(redirect: redirect)

        // The sheet dismisses on either finish or cancel; both paths already sent .finish on the
        // channel so shouldRetry can decide. This send updates the reducer's own state.
        await send(.finish(redirect))
    }
}
```

In `ForwardAuthReducer.swift`, change the `.confirmed` case to:

```swift
case let .confirmed(redirect):
    return .runPresentLogin(redirect: redirect)
```

Leave `.cancelled` as-is — it still needs to release the parked requests.

- [ ] **Step 5: Refactor the test to exercise `seed(_:then:)`**

Rewrite the test to call `seed` directly on a `WKWebView` stub rather than going through
`makeUIView` and `Context`:

```swift
@Test
@MainActor
func seed_copiesAppGroupCookiesIntoTheWebView() async throws {
    let store = HTTPCookieStorage.sharedCookieStorage(
        forGroupContainerIdentifier: "group.com.plunien.app.Paperless"
    )
    store.cookies?.forEach { store.deleteCookie($0) }

    let cookie = HTTPCookie(properties: [
        .domain: "auth.example.com",
        .path: "/",
        .name: "authelia_session",
        .value: "seeded",
    ])!
    store.setCookie(cookie)

    let view = ForwardAuthWebView(
        redirect: .testValue(url: URL(string: "https://auth.example.com/")!),
        onFinished: {}
    )
    let webView = WKWebView()
    let expectation = LockIsolated(false)
    view.seed(webView) { expectation.setValue(true) }

    try await Task.sleep(for: .milliseconds(200))
    let seeded = await webView.configuration.websiteDataStore.httpCookieStore.allCookies()

    #expect(seeded.contains(where: { $0.name == "authelia_session" }))
    #expect(expectation.value == true)
}
```

- [ ] **Step 6: Run to verify tests pass**

Run: `mise exec -- tuist test ForwardAuthFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "feat: WKWebView, cookie handoff, and certificate approval

Seed cookies from app-group storage before the first load; copy them back
whenever a response comes from the server's host. Certificate challenges
route through certificateApprovalChannel like every other trust decision in
this app - the two earlier attempts trusted any serverTrust the login host
presented, which is exactly the hole the approval flow closes."
```

---

### Task 11: Scope `ForwardAuthReducer` into `AppReducer`

**Files:**
- Modify: `Modules/AppFeature/AppReducer.swift`
- Modify: `Modules/AppFeatureTests/AppReducerTests.swift` (add the bootstrap assertion)

**Interfaces:**
- Consumes: `ForwardAuthReducer` (Task 9), `AppFeature`'s existing `.bootstrap` action.
- Produces: `AppReducer.State.forwardAuth` and `AppReducer.Action.forwardAuth`.

- [ ] **Step 1: Add the scope**

In `Modules/AppFeature/AppReducer.swift`, add the import:

```swift
import ForwardAuthFeature
```

Add to `enum Action`:

```swift
case forwardAuth(ForwardAuthReducer.Action)
```

Add to `struct State`:

```swift
var forwardAuth = ForwardAuthReducer.State()
```

Add the scope inside `body`, next to the existing `certificateApproval` scope:

```swift
Scope(state: \.forwardAuth, action: \.forwardAuth) {
    ForwardAuthReducer()
}
```

Chain the bootstrap in `case .bootstrap`:

```swift
case .bootstrap:
    return .runSelectedServerObserver()
        .merge(with: .run { send in
            await send(.certificateApproval(.bootstrap))
        })
        .merge(with: .run { send in
            await send(.forwardAuth(.bootstrap))
        })
```

Add `.forwardAuth` to the `case .certificateApproval, .main, .serverList:` ignored branch:

```swift
case .certificateApproval, .forwardAuth, .main, .serverList:
    return .none
```

- [ ] **Step 2: Build**

Run: `mise exec -- tuist test AppFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 3: Commit**

```bash
git add -A
git commit -m "feat: bootstrap ForwardAuthReducer from AppReducer

Same shape as CertificateApprovalReducer - the observer starts on
.bootstrap and the reducer handles its own events for the rest of the
session."
```

---

### Task 12: Use the identity probe when saving a server

**Files:**
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer+Effect.swift`
- Modify: `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift`
- Modify: `Modules/ApiImplementation/Authentication/StoreProviderTokenUseCase.swift` (or wherever
  `Server` is materialized) so it can take an optional username override.

**Interfaces:**
- Consumes: `GetForwardAuthIdentityUseCase` (Task 7), the existing token/OIDC login effects.
- Produces: `runSaveServer` and `runSaveProviderToken` first call `getForwardAuthIdentity`; a
  non-nil result stores the server with no token and the returned username, a nil result runs the
  existing login as today.

- [ ] **Step 1: Read the current save path**

Read `Modules/ServersFeature/ServerForm/ServerFormReducer+Effect.swift`'s `runSaveServer` and
`runSaveProviderToken`, and read whatever `storeToken` and `storeProviderToken` do with `Server`
in `ApiImplementation`. This task inserts an extra decision at the top of both paths.

- [ ] **Step 2: Write a failing reducer test**

In `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift`, add:

```swift
@Test
func save_probesForwardAuthIdentity_andStoresServerWithoutTokenIfRemoteUser() async throws {
    let store = await TestStore(
        initialState: ServerFormReducer.State(input: .testValue())
    ) {
        ServerFormReducer()
    } withDependencies: {
        $0.getForwardAuthIdentity.execute = { _ in "authelia-user" }
        $0.storeToken.execute = { _, _, _, _ in
            Issue.record("storeToken must not run when the proxy authenticated the identity")
        }
        // storeProviderToken likewise, if the flow reaches it
    }

    await store.send(.view(.saveButtonTapped))
    // Assertions on the delegate action or on state ending on the "saved" branch — read the
    // existing test file for the shape.
}
```

Adjust action names to what the file actually uses.

- [ ] **Step 3: Run to verify it fails**

Run: `mise exec -- tuist test ServersFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL.

- [ ] **Step 4: Insert the probe at the top of `runSaveServer`**

```swift
static func runSaveServer(
    input: ServerFormInput
) -> Self {
    @Dependency(\.getForwardAuthIdentity.execute)
    var getForwardAuthIdentity

    @Dependency(\.storeToken.execute)
    var storeToken

    @Dependency(\.negotiateApiVersion.execute)
    var negotiateApiVersion

    @Dependency(\.updateCache.execute)
    var updateCache

    return .run { send in
        await send(.binding(.set(\.isSaving, true)))

        // The proxy may have injected a trusted identity when the cookie landed. If so, no
        // paperless credentials need to be stored - the server is saved with the username the
        // API returned. If not, the ordinary login runs.
        if let username = try await getForwardAuthIdentity(server: input.server) {
            let servedServer = input.server.with(username: username)
            try await storeServerWithoutToken.execute(servedServer)
            _ = try await negotiateApiVersion(servedServer)
            try await updateCache(servedServer)
            await send(.delegate(.serverSaved(servedServer)), animation: .default)
            await send(.binding(.set(\.isSaving, false)))
            return
        }

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

Where `Server.with(username:)` is a helper this task adds if none exists, and
`storeServerWithoutToken` is a new use case that persists a `Server` with a `Credentials`
carrying `nil` token. If an existing use case already writes credentials, this task adds a
sibling that takes no token rather than complicating the existing signature.

Do the same at the top of `runSaveProviderToken`.

- [ ] **Step 5: Add `Server.with(username:)`**

If not present, in `Modules/ApiInterface/Servers/Server.swift`:

```swift
public extension Server {

    func with(username: String) -> Self {
        Self(
            alias: alias,
            headers: headers,
            id: id,
            username: username,
            url: url
        )
    }
}
```

- [ ] **Step 6: Add `StoreServerWithoutTokenUseCase`**

Create `Modules/ApiInterface/Authentication/StoreServerWithoutTokenUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros

@DependencyClient
public struct StoreServerWithoutTokenUseCase: Sendable {

    // Persists the Server and its (tokenless) credentials for remote-user mode. Split from
    // StoreTokenUseCase because a use case named "store token" that stores nothing is worse than
    // a second use case.
    public var execute: @Sendable (
        _ server: Server
    ) async throws -> Void
}

extension StoreServerWithoutTokenUseCase: TestDependencyKey {

    public static let testValue = Self()
}

public extension DependencyValues {

    var storeServerWithoutToken: StoreServerWithoutTokenUseCase {
        get { self[StoreServerWithoutTokenUseCase.self] }
        set { self[StoreServerWithoutTokenUseCase.self] = newValue }
    }
}
```

Create `Modules/ApiImplementation/Authentication/StoreServerWithoutTokenUseCase.swift`:

```swift
import ApiInterface
import Dependencies

extension StoreServerWithoutTokenUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: execute(server:)
    )
}

private extension StoreServerWithoutTokenUseCase {

    static func execute(server: Server) async throws {
        @Dependency(\.keychain)
        var keychain

        @Dependency(\.serversRepository)
        var serversRepository

        try await keychain.storeCredentials(
            Credentials(password: nil, token: nil),
            server
        )
        try await serversRepository.upsert(server)
    }
}
```

Adjust `serversRepository.upsert` to the actual name for the server-list write — read
`ServersFeature` or `AppFeature` for the current persistence method.

- [ ] **Step 7: Run reducer tests**

Run: `mise exec -- tuist test ServersFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "feat: probe for the proxy-injected identity before storing a server

Runs at the top of both password and provider save paths. When the proxy has
already authenticated the user through Remote-User, no token is stored and
the username comes from paperless. Otherwise the existing login path runs
unchanged."
```

---

### Task 13: A dead-end message for the share extension

**Files:**
- Modify: `Modules/ShareFeature/ShareForm/ShareFormError.swift`
- Modify: `Modules/ShareFeature/ShareForm/ShareFormReducer+Effect.swift` (catch
  `ForwardAuthError.required` and translate it)
- Modify: `Shared/Framework/Resources/Localizable.xcstrings` (`shareFormForwardAuthRequired`)
- Modify: `Modules/ShareFeatureTests/ShareForm/ShareFormReducerTests.swift`

**Interfaces:**
- Consumes: `ForwardAuthError` (Task 1).
- Produces: `ShareFormError.forwardAuthRequired`, surfaced as an error toast in the extension.

- [ ] **Step 1: Write the failing test**

Add to `Modules/ShareFeatureTests/ShareForm/ShareFormReducerTests.swift`:

```swift
@Test
func upload_forwardAuthRequired_translatesToDedicatedError() async {
    let store = await TestStore(initialState: /* ... */) {
        ShareFormReducer()
    } withDependencies: {
        $0.uploadDocument.execute = { _, _ in
            throw ForwardAuthError.required(URL(string: "https://auth.example.com/login")!)
        }
    }

    await store.send(/* whatever action triggers the upload */)

    await store.receive(\.error) {
        $0.error = ShareFormError.forwardAuthRequired
    }
}
```

Adjust dependency name and action names to what `ShareFormReducer` uses today.

- [ ] **Step 2: Run to verify it fails**

Expected: FAIL.

- [ ] **Step 3: Add the error case and its localization**

In `Modules/ShareFeature/ShareForm/ShareFormError.swift`:

```swift
enum ShareFormError: Error, Equatable {
    case forwardAuthRequired
    case unlockFailed
}

extension ShareFormError: LocalizedError {

    var errorDescription: String? {
        switch self {
        case .forwardAuthRequired:
            String(localized: .shareFormForwardAuthRequired)
        case .unlockFailed:
            String(localized: .unlockFailed)
        }
    }
}
```

Add to `Shared/Framework/Resources/Localizable.xcstrings` (alphabetical, hand-inserted):

```json
"shareFormForwardAuthRequired" : {
  "extractionState" : "manual",
  "localizations" : {
    "de" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Deine Sitzung ist abgelaufen. Bitte melde dich in Less Paper neu an, bevor du teilst."
      }
    },
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "Your session has expired. Please sign in again in Less Paper before sharing."
      }
    }
  }
},
```

- [ ] **Step 4: Translate the error in the effect**

In `Modules/ShareFeature/ShareForm/ShareFormReducer+Effect.swift`, in each `catch: { error, send
in ... }` that already exists, add ahead of the existing branches:

```swift
if case ForwardAuthError.required = error {
    await send(.error(ShareFormError.forwardAuthRequired))
    return
}
```

- [ ] **Step 5: Run to verify tests pass**

Run: `mise exec -- tuist test ShareFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: show a dead-end message when the share extension is bounced

An SSO login with a second factor inside a memory-constrained extension is a
bad place to be. The main app is one tap away; this tells the user to go
there."
```

---

### Task 14: The Authelia dev stack

**Files:**
- Create: `docker/docker-compose.authelia.yml`
- Create: `docker/authelia/configuration.yml`
- Create: `docker/authelia/users_database.yml`
- Modify: `docker/caddy/Caddyfile` — add the two forward-auth hostnames alongside the existing
  `localhost:443` block
- Modify: `.gitignore` — ignore `docker/authelia/db.sqlite3` and
  `docker/authelia/notification.txt`
- Create: `docs/forward-auth-development.md`

**Interfaces:** none. This is dev infrastructure.

The Caddy edit is additive — the existing `localhost:443` block for the vanilla dev stack still
works. The forward-auth stack is a **separate compose project** on its own ports, following
`docker-compose.oidc.yml`.

Read the reference notes in the earlier spike and in `docs/oidc-development.md`. The cookie-domain
requirement is why both hostnames sit under one registrable domain (`local.plunien.com` in the
spike). `mise run docker:start` is left alone; this stack is brought up by hand, documented in
`forward-auth-development.md`.

- [ ] **Step 1: Add the compose file**

Create `docker/docker-compose.authelia.yml` modeled on `docker-compose.oidc.yml`. It brings up
Authelia, Caddy (its own instance, on the forward-auth port), and a paperless configured with
`PAPERLESS_ENABLE_HTTP_REMOTE_USER`, `PAPERLESS_ENABLE_HTTP_REMOTE_USER_API`,
`PAPERLESS_HTTP_REMOTE_USER_HEADER_NAME=Remote-User`, its own project and its own ports so it does
not disturb `paperless-dev`. Refer to the spike patch's `docker/dev.yml` for the exact env vars.

Add a header comment following `docker-compose.oidc.yml`'s pattern, naming the one thing that has
to be right — the cookie domain — and why.

- [ ] **Step 2: Add the Authelia config and users database**

Create `docker/authelia/configuration.yml` following the spike patch. Regenerate
`jwt_secret`, `encryption_key`, and the argon2id password hash — the spike patch's are
committed to that patch; a real repo should not reuse them. Use `openssl rand -hex 32` for the
secrets and `docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'secret'`
for the hash.

Create `docker/authelia/users_database.yml`:

```yaml
users:
  admin:
    disabled: false
    displayname: admin
    email: admin@example.com
    groups:
      - admin
    password: '<argon2id hash from above>'
```

- [ ] **Step 3: Extend the Caddyfile**

Add two blocks to `docker/caddy/Caddyfile`, keeping the existing `localhost:443` intact:

```caddyfile
auth.local.plunien.com:443 {
    tls internal
    reverse_proxy authelia:9091
}

paperless.local.plunien.com:443 {
    tls internal
    forward_auth authelia:9091 {
        uri /api/authz/forward-auth
        copy_headers Remote-User Remote-Groups Remote-Email Remote-Name
    }
    reverse_proxy paperless:8000
}
```

The hostnames are whatever the developer running the stack has arranged to resolve to their
Docker host. `docs/forward-auth-development.md` explains how.

- [ ] **Step 4: Update `.gitignore`**

Add:

```
docker/authelia/db.sqlite3
docker/authelia/notification.txt
```

- [ ] **Step 5: Write the doc**

Create `docs/forward-auth-development.md` modeled on `docs/oidc-development.md`. It covers:

- **The one thing to get right:** the cookie domain, both hostnames under one registrable domain,
  simulator resolution and trust of the internal CA.
- **Bringing the stack up:**

  ```sh
  cd docker
  docker compose -f docker-compose.authelia.yml -p less-paper-authelia up -d
  ```
- **Adding the hostnames to `/etc/hosts` on the host, and how the simulator inherits that.**
- **Installing Caddy's internal root CA into the simulator** (`xcrun simctl keychain booted add-root-cert`).
- **The admin credentials, and where to add more users** (`authelia/users_database.yml`, with the
  argon2 command line).
- **Verifying the flow:** log in through the browser, then open Less Paper and add
  `https://paperless.local.plunien.com` — the app should not ask for a password.
- **Turning off remote-user mode** to test gate-only: unset `PAPERLESS_ENABLE_HTTP_REMOTE_USER_API`
  in the compose file, restart, add the server — the app should now ask for a paperless password
  after the SSO login.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "feat: dev stack for testing forward auth against Authelia

Its own compose project, its own ports, does not disturb paperless-dev or
paperless-ci. Both remote-user and gate-only modes can be exercised by
toggling PAPERLESS_ENABLE_HTTP_REMOTE_USER_API. Documented in
forward-auth-development.md; the one thing to get right is the cookie
domain, and the note names it up front."
```

---

### Task 15: Final integration pass

**Files:** whatever is still broken.

- [ ] **Step 1: Run the whole suite**

Run: `mise exec -- tuist test -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS across every scheme.

- [ ] **Step 2: Bring the Authelia stack up and add a server by hand**

Follow `docs/forward-auth-development.md`. Both modes:

- With `PAPERLESS_ENABLE_HTTP_REMOTE_USER_API` on, adding
  `https://paperless.local.plunien.com:8010` should open the browser, complete the login, and land
  in the app with a server named `admin` — **no password prompt**.
- With that variable off, the same flow should open the browser, complete the login, then present
  the app's ordinary paperless password field.

- [ ] **Step 3: Force an expiry**

With the app running against the Authelia stack, in a browser sign out of Authelia (or clear the
cookie in the simulator's Safari). Reload a document list in the app: the confirmation popup
should appear, the login sheet should present, the login should complete, and the list should
refresh **without an error toast**.

- [ ] **Step 4: Verify the share extension**

While signed in, share a PDF to Less Paper from another app — it should upload without prompting.
Then sign out of Authelia in the browser, share again — the extension should show the
`shareFormForwardAuthRequired` message and not attempt a web login.

- [ ] **Step 5: Verify the certificate approval flow still runs**

Delete the trusted certificate for `auth.local.plunien.com` from the simulator keychain. Trigger a
bounce. The certificate approval popup should appear (not the web view), and the login should
proceed only after the user approves the cert.

- [ ] **Step 6: Commit anything the manual verification uncovered**

Nothing to commit if everything passed. Otherwise open the failing behaviour, add a failing test,
fix it, commit.

- [ ] **Step 7: Open the pull request**

```bash
GIT_TERMINAL_PROMPT=0 mise exec -- fnox exec -- git \
  -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=$GH_TOKEN"; };f' \
  push -u origin feat/forward-auth

mise exec -- fnox exec -- gh pr create --base main --head feat/forward-auth \
  --title "feat: sign in through a forward-auth reverse proxy" \
  --body "$(cat docs/superpowers/specs/2026-08-28-forward-auth-design.md | head -40)"
```

---

## Self-review notes

Ran the review checks against the spec after writing all fifteen tasks:

**Spec coverage.** Every "Decisions" bullet in the spec maps to a task:

- Parked and replayed → Task 5
- One reactive path → the reducer's state machine, Task 9
- Concurrent bounces produce one login → tested in Task 9, waiter behaviour in Task 5
- Probe settles the mode → Task 7 (probe) and Task 12 (wired into save)
- `Credentials.token` optional → Task 4
- Extra request for the username → Task 7's use case
- `WKWebView`, not `ASWebAuthenticationSession` → Task 10
- Web view honours `@Shared(.trustedCertificates)` → Task 10, via
  `certificateApprovalChannel`
- Thumbnails refuse redirect but do not raise login → Task 2's `ImageLoader` update inherits the
  rename; Task 5's rule fires only from `ApiClientDelegate.validateResponse`, so `ImageLoader`
  refuses the redirect (Task 3) without raising a login. Documented in Global Constraints.
- Share extension shares cookie, no login → Task 6 (cookie) and Task 13 (dead-end message)

**Placeholder scan.** Two `TODO` markers survive on purpose:

- Task 7's `isUnauthorized` shim, explicitly labelled as an "open the file and match the exact
  type" instruction rather than shipped code
- Task 9's `.confirmed` effect is a deliberate TODO that Task 10 replaces — the split lets Task 9
  ship a working state machine with tests before the web view exists

**Type consistency.** `ForwardAuthEvent` cases are `.finish` / `.redirect` throughout, both action
names match, `ForwardAuthRedirect(server:url:)` fields are consistent between Tasks 1, 5, 9 and
10. `Server.with(username:)` introduced in Task 12 is a new helper, not renamed from anything.

## Execution note

Task 12 depends on reading three files that I did not open when writing this plan
(`Modules/ServersFeature/ServerForm/ServerFormReducer+Effect.swift`'s current shape,
`storeToken`'s exact side effects, and how servers are persisted). The task's first step is to
read them; the code in the later steps is the shape it should take, and adjustments to match
existing names are expected. This is the one task most likely to need a course correction during
execution.
