# Remember PDF passwords in the keychain — implementation plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development
> (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use
> checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let the user opt into storing a PDF's password in the keychain, try every stored password
automatically before showing the unlock form, and give them a settings screen to inspect and delete
what is stored.

**Architecture:** A `PdfPassword` model and three use cases live in `ApiInterface`/`ApiImplementation`
next to the existing keychain-backed credential use cases, storing the whole list as one JSON-encoded
keychain item. `ShareFormReducer` gains an opt-in toggle that saves on successful unlock, and a
`.selectFile` action that triggers a silent auto-unlock attempt for each file. A new
`PdfPasswordsFeature` module supplies the settings list screen.

**Tech Stack:** Swift 6, Swift Testing, `swift-dependencies` (`@DependencyClient`, `withDependencies`),
`swift-composable-architecture` (`TestStore`, `@Reducer`, `IdentifiedAction`), `SwiftSecurity`,
`PDFKit`, `swift-snapshot-testing`, Tuist.

**Design doc:** `docs/plans/2026-08-21-pdf-password-keychain.md`

## Global Constraints

- **Comments:** Never `///`, never `/** */`. Only `//`, and only where a future reader would
  otherwise wonder why the code is as it is. See `AGENTS.md`.
- **`@ViewAction` views send with `send`, never `store.send`.** See `AGENTS.md`.
- **Auto-unlock never reports an error.** Every stored password failing is the normal case for a
  document the user has not unlocked before. It must produce no toast and no `.error` action.
- **Save only after `PDFDocument.unlock(withPassword:)` returns true**, so a wrong password can
  never be persisted.
- **Save deduplicates on the password string**, keeping the original filename.
- **Run tests with:** `mise exec -- tuist test <Scheme> -d "iPhone 17 Pro" --no-selective-testing`.
  The `--no-selective-testing` flag is required: without it Tuist silently skips unchanged modules
  and reports success having run nothing.
- **Localization:** `Shared/Framework/Resources/Localizable.xcstrings`, two languages, `en` (source)
  and `de`, every entry `"extractionState" : "manual"`. The file uses `"key" : {` — **a space before
  the colon**. Insert entries by hand in alphabetical order; do not reformat the file with a JSON
  dumper, which rewrites all 3700 lines.
- **New `.swift` files in an existing module need no Tuist edit** — targets glob their module
  directory. A new *module* requires the edits enumerated in Task 4.

---

### Task 1: `PdfPassword`, keychain storage, and the three use cases

**Files:**
- Create: `Modules/ApiInterface/PdfPasswords/PdfPassword.swift`
- Create: `Modules/ApiInterface/PdfPasswords/GetPdfPasswordsUseCase.swift`
- Create: `Modules/ApiInterface/PdfPasswords/SavePdfPasswordUseCase.swift`
- Create: `Modules/ApiInterface/PdfPasswords/DeletePdfPasswordUseCase.swift`
- Modify: `Modules/ApiImplementation/Authentication/Keychain.swift`
- Create: `Modules/ApiImplementation/PdfPasswords/GetPdfPasswordsUseCase.swift`
- Create: `Modules/ApiImplementation/PdfPasswords/SavePdfPasswordUseCase.swift`
- Create: `Modules/ApiImplementation/PdfPasswords/DeletePdfPasswordUseCase.swift`
- Test: Create `Modules/ApiImplementationTests/PdfPasswords/PdfPasswordUseCaseTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `PdfPassword(filename: String, id: String, password: String)`, `Codable, Equatable, Identifiable, Sendable`, plus `PdfPassword.testValue(filename:id:password:)`
  - `DependencyValues.getPdfPasswords` — `execute: () async throws -> [PdfPassword]`
  - `DependencyValues.savePdfPassword` — `execute: (_ filename: String, _ password: String) async throws -> Void`
  - `DependencyValues.deletePdfPassword` — `execute: (_ id: String) async throws -> Void`
  - `Keychain.getPdfPasswords` / `Keychain.setPdfPasswords` (internal to `ApiImplementation`)

- [ ] **Step 1: Write the failing test**

Create `Modules/ApiImplementationTests/PdfPasswords/PdfPasswordUseCaseTests.swift`:

```swift
@testable import ApiImplementation

import ApiInterface
import CustomDump
import Dependencies
import Foundation
import Testing
import TestSupport

@Suite(
    .dependencies()
)
struct PdfPasswordUseCaseTests {

    @Test
    func get_returnsWhatTheKeychainHolds() async throws {
        let stored = [PdfPassword.testValue()]

        try await withDependencies {
            $0.keychain.getPdfPasswords = { stored }
        } operation: {
            let result = try await GetPdfPasswordsUseCase.liveValue.execute()
            expectNoDifference(result, stored)
        }
    }

    @Test
    func save_appendsToTheStoredList() async throws {
        let written = LockIsolated<[PdfPassword]?>(nil)

        try await withDependencies {
            $0.keychain.getPdfPasswords = { [.testValue(filename: "old.pdf", id: "1", password: "old")] }
            $0.keychain.setPdfPasswords = { written.setValue($0) }
            $0.uuid = .incrementing
        } operation: {
            try await SavePdfPasswordUseCase.liveValue.execute(filename: "new.pdf", password: "new")
        }

        expectNoDifference(written.value, [
            .testValue(filename: "old.pdf", id: "1", password: "old"),
            .testValue(filename: "new.pdf", id: UUID(0).uuidString, password: "new")
        ])
    }

    // Importing the same recurring document every month with the toggle left on would otherwise
    // grow one duplicate entry per import.
    @Test
    func save_isANoOpWhenThePasswordIsAlreadyStored() async throws {
        let written = LockIsolated<[PdfPassword]?>(nil)

        try await withDependencies {
            $0.keychain.getPdfPasswords = { [.testValue(filename: "january.pdf", id: "1", password: "secret")] }
            $0.keychain.setPdfPasswords = { written.setValue($0) }
            $0.uuid = .incrementing
        } operation: {
            try await SavePdfPasswordUseCase.liveValue.execute(filename: "february.pdf", password: "secret")
        }

        #expect(written.value == nil, "an already-stored password must not be written again")
    }

    @Test
    func delete_removesTheMatchingId() async throws {
        let written = LockIsolated<[PdfPassword]?>(nil)

        try await withDependencies {
            $0.keychain.getPdfPasswords = {
                [
                    .testValue(filename: "a.pdf", id: "1", password: "a"),
                    .testValue(filename: "b.pdf", id: "2", password: "b")
                ]
            }
            $0.keychain.setPdfPasswords = { written.setValue($0) }
        } operation: {
            try await DeletePdfPasswordUseCase.liveValue.execute(id: "1")
        }

        expectNoDifference(written.value, [.testValue(filename: "b.pdf", id: "2", password: "b")])
    }
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — `cannot find 'PdfPassword' in scope`.

- [ ] **Step 3: Create the model**

Create `Modules/ApiInterface/PdfPasswords/PdfPassword.swift`:

```swift
import Foundation

public struct PdfPassword: Codable, Equatable, Identifiable, Sendable {

    public let filename: String

    public let id: String

    public let password: String

    public init(
        filename: String,
        id: String,
        password: String
    ) {
        self.filename = filename
        self.id = id
        self.password = password
    }
}

public extension PdfPassword {

    static func testValue(
        filename: String = "statement.pdf",
        id: String = "9E2B1B2E-2F0B-4C9E-8B0E-1B2E2F0B4C9E",
        password: String = "s3cr3t"
    ) -> Self {
        .init(
            filename: filename,
            id: id,
            password: password
        )
    }
}
```

- [ ] **Step 4: Declare the three use cases**

Create `Modules/ApiInterface/PdfPasswords/GetPdfPasswordsUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct GetPdfPasswordsUseCase: Sendable {

    public var execute: @Sendable () async throws -> [PdfPassword]
}

extension GetPdfPasswordsUseCase: TestDependencyKey {

    public static let previewValue = Self(
        execute: { [.testValue()] }
    )

    public static let testValue = Self(
        execute: { [] }
    )
}

public extension DependencyValues {
    var getPdfPasswords: GetPdfPasswordsUseCase {
        get { self[GetPdfPasswordsUseCase.self] }
        set { self[GetPdfPasswordsUseCase.self] = newValue }
    }
}
```

Create `Modules/ApiInterface/PdfPasswords/SavePdfPasswordUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct SavePdfPasswordUseCase: Sendable {

    public var execute: @Sendable (
        _ filename: String,
        _ password: String
    ) async throws -> Void
}

extension SavePdfPasswordUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var savePdfPassword: SavePdfPasswordUseCase {
        get { self[SavePdfPasswordUseCase.self] }
        set { self[SavePdfPasswordUseCase.self] = newValue }
    }
}
```

Create `Modules/ApiInterface/PdfPasswords/DeletePdfPasswordUseCase.swift`:

```swift
import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
public struct DeletePdfPasswordUseCase: Sendable {

    public var execute: @Sendable (
        _ id: String
    ) async throws -> Void
}

extension DeletePdfPasswordUseCase: TestDependencyKey {

    public static let previewValue = Self()

    public static let testValue = Self()
}

public extension DependencyValues {
    var deletePdfPassword: DeletePdfPasswordUseCase {
        get { self[DeletePdfPasswordUseCase.self] }
        set { self[DeletePdfPasswordUseCase.self] = newValue }
    }
}
```

- [ ] **Step 5: Extend `Keychain`**

In `Modules/ApiImplementation/Authentication/Keychain.swift`, add `import Foundation` to the imports,
then add these two properties to the `@DependencyClient struct Keychain`, keeping the existing
alphabetical order (`getCredentials`, `getPdfPasswords`, `setPdfPasswords`, `storeCredentials`):

```swift
    var getPdfPasswords: @Sendable () async throws -> [PdfPassword]

    var setPdfPasswords: @Sendable (
        _ pdfPasswords: [PdfPassword]
    ) async throws -> Void
```

Add to `testValue`:

```swift
        getPdfPasswords: { [] },
        setPdfPasswords: { _ in },
```

Add to `liveValue`:

```swift
        getPdfPasswords: getPdfPasswords,
        setPdfPasswords: setPdfPasswords(pdfPasswords:),
```

And add to the `private extension Keychain`:

```swift
    // The whole list lives in one item. SwiftSecurity stores any SecDataConvertible, and Data
    // conforms, so the array is JSON-encoded rather than spread across per-password items whose
    // ordering and labels would have to ride along in keychain attributes.
    static func getPdfPasswords() async throws -> [PdfPassword] {
        guard let data: Data = try keychain.retrieve(.credential(for: pdfPasswordsKey)) else {
            return []
        }
        return try JSONDecoder.apiDecoder.decode([PdfPassword].self, from: data)
    }

    static func setPdfPasswords(pdfPasswords: [PdfPassword]) async throws {
        _ = try? keychain.remove(.credential(for: pdfPasswordsKey))
        try keychain.store(
            JSONEncoder.apiEncoder.encode(pdfPasswords),
            query: .credential(for: pdfPasswordsKey)
        )
    }

    private static let pdfPasswordsKey = "pdf-passwords"
```

- [ ] **Step 6: Implement the three live use cases**

Create `Modules/ApiImplementation/PdfPasswords/GetPdfPasswordsUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension GetPdfPasswordsUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute
    )
}

private extension GetPdfPasswordsUseCase {

    static func execute() async throws -> [PdfPassword] {
        @Dependency(\.keychain)
        var keychain

        return try await keychain.getPdfPasswords()
    }
}
```

Create `Modules/ApiImplementation/PdfPasswords/SavePdfPasswordUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension SavePdfPasswordUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(filename:password:)
    )
}

private extension SavePdfPasswordUseCase {

    static func execute(
        filename: String,
        password: String
    ) async throws {
        @Dependency(\.keychain)
        var keychain

        @Dependency(\.uuid)
        var uuid

        let stored = try await keychain.getPdfPasswords()

        guard !stored.contains(where: { $0.password == password }) else {
            return
        }

        try await keychain.setPdfPasswords(
            stored + [PdfPassword(filename: filename, id: uuid().uuidString, password: password)]
        )
    }
}
```

Create `Modules/ApiImplementation/PdfPasswords/DeletePdfPasswordUseCase.swift`:

```swift
import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation

extension DeletePdfPasswordUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(
        execute: execute(id:)
    )
}

private extension DeletePdfPasswordUseCase {

    static func execute(
        id: String
    ) async throws {
        @Dependency(\.keychain)
        var keychain

        let stored = try await keychain.getPdfPasswords()

        try await keychain.setPdfPasswords(stored.filter { $0.id != id })
    }
}
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `mise exec -- tuist test ApiImplementation -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, all four `PdfPasswordUseCaseTests` cases green.

- [ ] **Step 8: Commit**

```bash
git add Modules/ApiInterface/PdfPasswords Modules/ApiImplementation/PdfPasswords \
        Modules/ApiImplementation/Authentication/Keychain.swift \
        Modules/ApiImplementationTests/PdfPasswords
git commit -m "feat: store PDF passwords in the keychain"
```

---

### Task 2: Save the password from the unlock form

**Files:**
- Modify: `Modules/ShareFeature/ShareForm/ShareFormInput.swift`
- Modify: `Modules/ShareFeature/ShareForm/ShareFormReducer+Effect.swift` (`runUnlockFile`, line 21)
- Modify: `Modules/ShareFeature/ShareForm/ShareFormReducer.swift` (`unlockButtonTapped` case)
- Modify: `Modules/ShareFeature/ShareForm/ShareFormView.swift` (`unlockView()`, line 207)
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: Create `Modules/ShareFeatureTests/ShareForm/ShareFormRememberPasswordTests.swift`
- Test: Create `Modules/ShareFeatureTests/ShareForm/PdfFixture.swift`

**Interfaces:**
- Consumes: `DependencyValues.savePdfPassword` from Task 1.
- Produces: `ShareFormInput.shouldRememberPassword: Bool` (default `false`), and
  `Effect.runUnlockFile(document:filename:password:shouldRemember:url:)` — note the two new
  parameters; Task 3 calls a different effect and is unaffected.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ShareFeatureTests/ShareForm/ShareFormRememberPasswordTests.swift`. The existing
`ShareFormReducerTests.swift` stays untouched — these are a separate concern and belong in their own
file.

```swift
@testable import ShareFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import PDFKit
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct ShareFormRememberPasswordTests {

    @Test
    func unlockButtonTapped_withRememberOn_savesThePassword() async throws {
        let saved = LockIsolated<[String]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "s3cr3t")

        var state = ShareFormReducer.State(files: [url], server: .testValue())
        state.input.password = "s3cr3t"
        state.input.shouldRememberPassword = true

        let store = TestStore(initialState: state) {
            ShareFormReducer()
        } withDependencies: {
            $0.savePdfPassword.execute = { filename, password in
                saved.withValue { $0.append("\(filename):\(password)") }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.unlockButtonTapped))
        await store.finish()

        #expect(saved.value == ["statement.pdf:s3cr3t"])
    }

    @Test
    func unlockButtonTapped_withRememberOff_savesNothing() async throws {
        let saved = LockIsolated<[String]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "s3cr3t")

        var state = ShareFormReducer.State(files: [url], server: .testValue())
        state.input.password = "s3cr3t"
        state.input.shouldRememberPassword = false

        let store = TestStore(initialState: state) {
            ShareFormReducer()
        } withDependencies: {
            $0.savePdfPassword.execute = { filename, password in
                saved.withValue { $0.append("\(filename):\(password)") }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.unlockButtonTapped))
        await store.finish()

        #expect(saved.value.isEmpty)
    }

    // A password that does not open the document must never reach the keychain, which is why the
    // save hangs off the success branch of unlock(withPassword:) rather than off the button tap.
    @Test
    func unlockButtonTapped_withWrongPassword_savesNothingAndToasts() async throws {
        let saved = LockIsolated<[String]>([])
        let toasts = LockIsolated<[Toast]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "s3cr3t")

        var state = ShareFormReducer.State(files: [url], server: .testValue())
        state.input.password = "wrong"
        state.input.shouldRememberPassword = true

        let store = TestStore(initialState: state) {
            ShareFormReducer()
        } withDependencies: {
            $0.savePdfPassword.execute = { filename, password in
                saved.withValue { $0.append("\(filename):\(password)") }
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.unlockButtonTapped))
        await store.finish()

        #expect(saved.value.isEmpty)
        #expect(toasts.value.count == 1)
    }
}
```

Create the fixture helper `Modules/ShareFeatureTests/ShareForm/PdfFixture.swift`:

```swift
import Foundation
import PDFKit

enum PdfFixture {

    static func locked(name: String, password: String) throws -> URL {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        document.write(
            to: url,
            withOptions: [
                .ownerPasswordOption: password,
                .userPasswordOption: password
            ]
        )
        return url
    }

    static func unlocked(name: String) throws -> URL {
        let document = PDFDocument()
        document.insert(PDFPage(), at: 0)

        let url = FileManager.default.temporaryDirectory.appendingPathComponent(name)
        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        document.write(to: url)
        return url
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ShareFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — `value of type 'ShareFormInput' has no member 'shouldRememberPassword'`.

- [ ] **Step 3: Add the input field**

In `Modules/ShareFeature/ShareForm/ShareFormInput.swift`, add below `var password = ""`:

```swift
    var shouldRememberPassword = false
```

Leave `reset()` alone — it does not clear `password` either, because both are per-file values and
`selectNextFile()` replaces the whole input with `.init()`.

- [ ] **Step 4: Save on successful unlock**

In `Modules/ShareFeature/ShareForm/ShareFormReducer+Effect.swift`, replace `runUnlockFile` with:

```swift
    static func runUnlockFile(
        document: PDFDocument?,
        filename: String,
        password: String,
        shouldRemember: Bool,
        url: URL
    ) -> Self {
        guard let document, document.unlock(withPassword: password) == true else {
            return .send(.error(ShareFormError.unlockFailed))
        }

        guard document.write(
            to: url,
            withOptions: [.ownerPasswordOption: "", .userPasswordOption: ""]
        ) == true else {
            return .send(.error(ShareFormError.unlockFailed))
        }

        return .run { send in
            if shouldRemember {
                @Dependency(\.savePdfPassword.execute)
                var savePdfPassword

                try? await savePdfPassword(filename, password)
            }
            await send(.fileUnlocked, animation: .snappy)
        }
    }
```

The save is `try?` on purpose: a keychain write failing must not block an unlock the user has already
completed successfully.

- [ ] **Step 5: Pass the new arguments from the reducer**

In `Modules/ShareFeature/ShareForm/ShareFormReducer.swift`, replace the `.unlockButtonTapped` case:

```swift
                case .unlockButtonTapped:
                    return .runUnlockFile(
                        document: state.document,
                        filename: state.files[state.currentIndex].lastPathComponent,
                        password: state.input.password,
                        shouldRemember: state.input.shouldRememberPassword,
                        url: state.files[state.currentIndex]
                    )
```

- [ ] **Step 6: Add the toggle to the unlock view**

In `Modules/ShareFeature/ShareForm/ShareFormView.swift`, inside `unlockView()`, insert between the
`Field(.password)` block and the `Text(.fileLocked)` block:

```swift
                Toggle(isOn: $store.input.shouldRememberPassword) {
                    Text(.rememberPassword)
                }
                .tint(Color.m3Primary)
                .padding(.horizontal, .x3)
```

- [ ] **Step 7: Add the localization key**

In `Shared/Framework/Resources/Localizable.xcstrings`, insert this entry **between the `"reload"` and
`"reset"` entries** — that is where it sorts. Match the file's exact style: 4-space indent for the
key, `" : "` separator.

```json
    "rememberPassword" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Passwort merken"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Remember password"
          }
        }
      }
    },
```

Verify: `python3 -c "import json; json.load(open('Shared/Framework/Resources/Localizable.xcstrings')); print('ok')"`

- [ ] **Step 8: Run the tests to verify they pass**

Run: `mise exec -- tuist test ShareFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS.

- [ ] **Step 9: Commit**

```bash
git add Modules/ShareFeature Modules/ShareFeatureTests Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: offer to remember a PDF password when unlocking"
```

---

### Task 3: Try stored passwords automatically

**Files:**
- Modify: `Modules/ShareFeature/ShareForm/ShareFormReducer.swift` (`Action`, `fileImported`,
  `skipButtonTapped`, new `.selectFile` and `.view(.onAppear)` cases)
- Modify: `Modules/ShareFeature/ShareForm/ShareFormReducer+Effect.swift` (new `runAutoUnlock`)
- Modify: `Modules/ShareFeature/ShareForm/ShareFormView.swift` (add `.task`)
- Test: Create `Modules/ShareFeatureTests/ShareForm/ShareFormAutoUnlockTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.getPdfPasswords` from Task 1; `PdfFixture` from Task 2.
- Produces: `ShareFormReducer.Action.selectFile(Int)` — an internal action, not a `View` one — and
  `ShareFormReducer.Action.View.onAppear`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/ShareFeatureTests/ShareForm/ShareFormAutoUnlockTests.swift`:

```swift
@testable import ShareFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import PDFKit
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct ShareFormAutoUnlockTests {

    @Test
    func onAppear_unlocksWithTheFirstMatchingStoredPassword() async throws {
        let url = try PdfFixture.locked(name: "statement.pdf", password: "second")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [url],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [
                    .testValue(filename: "a.pdf", id: "1", password: "first"),
                    .testValue(filename: "b.pdf", id: "2", password: "second"),
                    .testValue(filename: "c.pdf", id: "3", password: "third")
                ]
            }
        }
        store.exhaustivity = .off

        #expect(store.state.isLocked)

        await store.send(.view(.onAppear))
        await store.finish()

        #expect(store.state.isLocked == false)
    }

    // Every stored password failing is the normal case for a document the user has never unlocked.
    // It must fall through to the unlock form in silence rather than toasting once per password.
    @Test
    func onAppear_whenNoStoredPasswordMatches_staysLockedAndSaysNothing() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let url = try PdfFixture.locked(name: "statement.pdf", password: "actual")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [url],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [
                    .testValue(filename: "a.pdf", id: "1", password: "nope"),
                    .testValue(filename: "b.pdf", id: "2", password: "also-nope")
                ]
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.finish()

        #expect(store.state.isLocked)
        #expect(toasts.value.isEmpty, "auto-unlock must not toast")
    }

    @Test
    func onAppear_withAnUnlockedFile_readsNoStoredPasswords() async throws {
        let wasAsked = LockIsolated(false)
        let url = try PdfFixture.unlocked(name: "plain.pdf")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [url],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                wasAsked.setValue(true)
                return []
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))
        await store.finish()

        #expect(wasAsked.value == false)
    }

    @Test
    func skipButtonTapped_autoUnlocksTheNextFile() async throws {
        let first = try PdfFixture.unlocked(name: "first.pdf")
        let second = try PdfFixture.locked(name: "second.pdf", password: "s3cr3t")

        let store = TestStore(initialState: ShareFormReducer.State(
            files: [first, second],
            server: .testValue()
        )) {
            ShareFormReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [.testValue(filename: "b.pdf", id: "1", password: "s3cr3t")]
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.skipButtonTapped))
        await store.finish()

        #expect(store.state.currentIndex == 1)
        #expect(store.state.isLocked == false)
    }
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run: `mise exec -- tuist test ShareFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — `type 'ShareFormReducer.Action.View' has no member 'onAppear'`.

- [ ] **Step 3: Add the actions**

In `Modules/ShareFeature/ShareForm/ShareFormReducer.swift`, add to `Action`, keeping alphabetical
order (after `case nextArchiveSerialNumber`):

```swift
        case selectFile(Int)
```

and add to `Action.View`, after `case importButtonTapped`:

```swift
            case onAppear
```

- [ ] **Step 4: Handle the new cases**

In the same file, replace the `.fileImported` case:

```swift
            case .fileImported:
                guard state.hasMoreFiles else {
                    return .send(.delegate(.dismiss))
                }
                return .send(.selectFile(state.currentIndex + 1))
```

Add a `.selectFile` case next to it:

```swift
            case let .selectFile(index):
                state.selectNextFile(index: index)
                guard state.isLocked else {
                    return .none
                }
                return .runAutoUnlock(
                    document: state.document,
                    url: state.files[state.currentIndex]
                )
```

Replace the `.skipButtonTapped` case:

```swift
                case .skipButtonTapped:
                    guard state.hasMoreFiles else {
                        return .send(.delegate(.dismiss))
                    }
                    return .send(.selectFile(state.currentIndex + 1))
```

Add an `.onAppear` case in the same `switch viewAction` block:

```swift
                case .onAppear:
                    guard state.isLocked else {
                        return .none
                    }
                    return .runAutoUnlock(
                        document: state.document,
                        url: state.files[state.currentIndex]
                    )
```

At the bottom of the file, replace `selectNextFile()` — the reducer now owns the index, so the helper
takes it as a parameter:

```swift
    mutating func selectNextFile(index: Int) {
        input = .init()
        selectFile(index: index)
    }
```

`init` keeps calling `selectFile(index: currentIndex)` unchanged: the first file has to be on screen
before any action can be sent, which is why `.view(.onAppear)` covers its auto-unlock rather than
`init` doing it.

- [ ] **Step 5: Add the effect**

In `Modules/ShareFeature/ShareForm/ShareFormReducer+Effect.swift`, add:

```swift
    // Silent by design. Every stored password failing is the expected outcome for a document the
    // user has never unlocked, so this reports nothing and lets the unlock form appear.
    static func runAutoUnlock(
        document: PDFDocument?,
        url: URL
    ) -> Self {
        .run { send in
            @Dependency(\.getPdfPasswords.execute)
            var getPdfPasswords

            guard let document else {
                return
            }

            for stored in try await getPdfPasswords() {
                guard document.unlock(withPassword: stored.password) else {
                    continue
                }
                guard document.write(
                    to: url,
                    withOptions: [.ownerPasswordOption: "", .userPasswordOption: ""]
                ) else {
                    return
                }
                await send(.fileUnlocked, animation: .snappy)
                return
            }
        } catch: { _, _ in
        }
    }
```

- [ ] **Step 6: Add the view lifecycle hook**

In `Modules/ShareFeature/ShareForm/ShareFormView.swift`, attach a `.task` to the top-level view in
`body`. `ShareFormView` is annotated `@ViewAction(for: ShareFormReducer.self)`, so use `send`, never
`store.send`:

```swift
        .task { await send(.onAppear).finish() }
```

- [ ] **Step 7: Run the tests to verify they pass**

Run: `mise exec -- tuist test ShareFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, including the Task 2 tests.

- [ ] **Step 8: Commit**

```bash
git add Modules/ShareFeature Modules/ShareFeatureTests
git commit -m "feat: try stored PDF passwords before showing the unlock form"
```

---

### Task 4: `PdfPasswordsFeature` module with the list screen

**Files:**
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift` (enum cases, `codeCoverageTarget`, `product`)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`
- Create: `Modules/PdfPasswordsFeature/PdfPasswordList/PdfPasswordListReducer.swift`
- Create: `Modules/PdfPasswordsFeature/PdfPasswordList/PdfPasswordListReducer+Effect.swift`
- Create: `Modules/PdfPasswordsFeature/PdfPasswordList/PdfPasswordListView.swift`
- Create: `Modules/PdfPasswordsFeature/PdfPasswordRow/PdfPasswordRowReducer.swift`
- Create: `Modules/PdfPasswordsFeature/PdfPasswordRow/PdfPasswordRowView.swift`
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Test: Create `Modules/PdfPasswordsFeatureTests/PdfPasswordList/PdfPasswordListReducerTests.swift`

**Interfaces:**
- Consumes: `DependencyValues.getPdfPasswords`, `DependencyValues.deletePdfPassword`, `PdfPassword`
  from Task 1.
- Produces: `PdfPasswordListReducer` with `State.init(isLoaded:pdfPasswords:)` and
  `PdfPasswordRowReducer.State(pdfPassword:)`, both `public`.

**The Tuist switches are exhaustive.** Missing any one of them is a compile error in the manifest,
not a silent skip. Every switch that needs both new cases is listed explicitly below.

- [ ] **Step 1: Register the module with Tuist**

In `Tuist/ProjectDescriptionHelpers/Module.swift`:

Add to the `Module` enum, in alphabetical order after `case permissionsFeatureTests`:

```swift
    case pdfPasswordsFeature = "PdfPasswordsFeature"
    case pdfPasswordsFeatureTests = "PdfPasswordsFeatureTests"
```

In `codeCoverageTarget`, add `.pdfPasswordsFeature,` to the `true` case list and
`.pdfPasswordsFeatureTests,` to the `false` case list.

In `product`, add `.pdfPasswordsFeature,` to the framework case list (the one returning
`Environment.staticFrameworks.getBoolean(default: false) ? .staticFramework : .framework`) and
`.pdfPasswordsFeatureTests,` to the unit-test case list.

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add:

```swift
        case .pdfPasswordsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.components),
            ]
        case .pdfPasswordsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.pdfPasswordsFeature),
                .target(.testSupport),
            ]
```

and add `.target(.pdfPasswordsFeature),` to the `.settingsFeature` dependency list.

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`, add `.pdfPasswordsFeature,` to the
feature-module case list in `schemes` (the one containing `.apiImplementation,`) and
`.pdfPasswordsFeatureTests,` to the test-module case list (the one containing
`.apiImplementationTests,`).

Verify the manifest still compiles:

```bash
mise exec -- tuist generate --no-open
```

Expected: success, with `PdfPasswordsFeature` appearing in the generated project.

- [ ] **Step 2: Write the failing test**

Create `Modules/PdfPasswordsFeatureTests/PdfPasswordList/PdfPasswordListReducerTests.swift`:

```swift
@testable import PdfPasswordsFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct PdfPasswordListReducerTests {

    @Test
    func onAppear_loadsStoredPasswords() async throws {
        let store = TestStore(initialState: PdfPasswordListReducer.State()) {
            PdfPasswordListReducer()
        } withDependencies: {
            $0.getPdfPasswords.execute = {
                [.testValue(filename: "a.pdf", id: "1", password: "a")]
            }
        }

        await store.send(.view(.onAppear))
        await store.receive(\.getPdfPasswordsResult) {
            $0.isLoaded = true
            $0.pdfPasswords = [
                PdfPasswordRowReducer.State(
                    pdfPassword: .testValue(filename: "a.pdf", id: "1", password: "a")
                )
            ]
        }
    }

    @Test
    func deletingARow_removesItFromTheListAndTheKeychain() async throws {
        let deleted = LockIsolated<[String]>([])
        var state = PdfPasswordListReducer.State()
        state.pdfPasswords = [
            PdfPasswordRowReducer.State(pdfPassword: .testValue(filename: "a.pdf", id: "1", password: "a")),
            PdfPasswordRowReducer.State(pdfPassword: .testValue(filename: "b.pdf", id: "2", password: "b"))
        ]

        let store = TestStore(initialState: state) {
            PdfPasswordListReducer()
        } withDependencies: {
            $0.deletePdfPassword.execute = { id in
                deleted.withValue { $0.append(id) }
            }
        }

        await store.send(.pdfPasswords(.element(id: "1", action: .delegate(.deletePdfPassword))))
        await store.receive(\.pdfPasswordDeleted) {
            $0.pdfPasswords.remove(id: "1")
        }

        #expect(deleted.value == ["1"])
    }
}
```

- [ ] **Step 3: Run the test to verify it fails**

Run: `mise exec -- tuist test PdfPasswordsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — `no such module 'PdfPasswordsFeature'` or `cannot find 'PdfPasswordListReducer'`.

- [ ] **Step 4: Write the row reducer**

Create `Modules/PdfPasswordsFeature/PdfPasswordRow/PdfPasswordRowReducer.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

@Reducer
public struct PdfPasswordRowReducer: Sendable {

    public enum Action: ViewAction {
        case delegate(Delegate)
        case view(View)

        public enum Delegate {
            case deletePdfPassword
        }

        public enum View {
            case deleteButtonTapped
            case revealButtonTapped
        }
    }

    @ObservableState
    public struct State: Equatable, Identifiable {

        public var id: String { pdfPassword.id }

        var isRevealed = false

        let pdfPassword: PdfPassword

        public init(
            isRevealed: Bool = false,
            pdfPassword: PdfPassword
        ) {
            self.isRevealed = isRevealed
            self.pdfPassword = pdfPassword
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .deleteButtonTapped:
                    return .send(.delegate(.deletePdfPassword))
                case .revealButtonTapped:
                    state.isRevealed.toggle()
                    return .none
                }
            case .delegate:
                return .none
            }
        }
    }

    public init() {}
}
```

- [ ] **Step 5: Write the list reducer and its effect**

Create `Modules/PdfPasswordsFeature/PdfPasswordList/PdfPasswordListReducer.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct PdfPasswordListReducer: Sendable {

    public enum Action: ViewAction {
        case error(Error)
        case getPdfPasswordsResult([PdfPassword])
        case pdfPasswordDeleted(String)
        case pdfPasswords(IdentifiedActionOf<PdfPasswordRowReducer>)
        case view(View)

        public enum View {
            case onAppear
            case onRefresh
        }
    }

    @ObservableState
    public struct State: Equatable {

        var isLoaded: Bool

        var pdfPasswords: IdentifiedArrayOf<PdfPasswordRowReducer.State>

        public init(
            isLoaded: Bool = false,
            pdfPasswords: IdentifiedArrayOf<PdfPasswordRowReducer.State> = []
        ) {
            self.isLoaded = isLoaded
            self.pdfPasswords = pdfPasswords
        }
    }

    public var body: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case let .error(error):
                return .toast(error)
            case let .getPdfPasswordsResult(pdfPasswords):
                state.isLoaded = true
                state.pdfPasswords = IdentifiedArray(
                    uniqueElements: pdfPasswords.map { PdfPasswordRowReducer.State(pdfPassword: $0) }
                )
                return .none
            case let .pdfPasswordDeleted(id):
                state.pdfPasswords.remove(id: id)
                return .none
            case let .pdfPasswords(.element(id: id, action: .delegate(.deletePdfPassword))):
                return .runDeletePdfPassword(id: id)
            case let .view(viewAction):
                switch viewAction {
                case .onAppear, .onRefresh:
                    return .runGetPdfPasswords()
                }
            case .pdfPasswords:
                return .none
            }
        }
        .forEach(\.pdfPasswords, action: \.pdfPasswords) { PdfPasswordRowReducer() }
    }

    public init() {}
}
```

Create `Modules/PdfPasswordsFeature/PdfPasswordList/PdfPasswordListReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect where Action == PdfPasswordListReducer.Action {

    static func runGetPdfPasswords() -> Self {
        @Dependency(\.getPdfPasswords.execute)
        var getPdfPasswords

        return .run { send in
            await send(.getPdfPasswordsResult(try await getPdfPasswords()))
        } catch: { error, send in
            await send(.error(error))
        }
    }

    static func runDeletePdfPassword(id: String) -> Self {
        @Dependency(\.deletePdfPassword.execute)
        var deletePdfPassword

        return .run { send in
            try await deletePdfPassword(id)
            await send(.pdfPasswordDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
        }
    }
}
```

- [ ] **Step 6: Write the views**

Create `Modules/PdfPasswordsFeature/PdfPasswordRow/PdfPasswordRowView.swift`:

```swift
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PdfPasswordRowReducer.self)
struct PdfPasswordRowView: View {

    @Bindable var store: StoreOf<PdfPasswordRowReducer>

    var body: some View {
        VStack(alignment: .leading, spacing: .x1) {
            Text(store.pdfPassword.filename)
                .font(.body)

            Text(store.isRevealed ? store.pdfPassword.password : "••••••••")
                .font(.footnote.monospaced())
                .foregroundStyle(Color.m3OnSurface.opacity(0.7))
        }
        .contentShape(Rectangle())
        .onTapGesture {
            send(.revealButtonTapped, animation: .default)
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                send(.deleteButtonTapped)
            } label: {
                Label(.delete, systemImage: "trash")
            }
        }
    }
}
```

Create `Modules/PdfPasswordsFeature/PdfPasswordList/PdfPasswordListView.swift`:

```swift
import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: PdfPasswordListReducer.self)
public struct PdfPasswordListView: View {

    @Bindable var store: StoreOf<PdfPasswordListReducer>

    public init(store: StoreOf<PdfPasswordListReducer>) {
        self.store = store
    }

    public var body: some View {
        List {
            ForEach(
                store.scope(state: \.pdfPasswords, action: \.pdfPasswords),
                id: \.state.id
            ) { rowStore in
                PdfPasswordRowView(store: rowStore)
                    .listRowBackground(Color.m3SurfaceContainer)
            }
        }
        .scrollContentBackground(.hidden)
        .background(Color.m3Surface)
        .navigationTitle(Text(.pdfPasswords))
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await send(.onRefresh).finish() }
        .task { await send(.onAppear).finish() }
        .overlay {
            if store.isLoaded, store.pdfPasswords.isEmpty {
                ContentUnavailableView(
                    String(localized: .pdfPasswordsEmpty),
                    systemImage: "key"
                )
            }
        }
    }
}
```

- [ ] **Step 7: Add the localization keys**

In `Shared/Framework/Resources/Localizable.xcstrings`, insert both entries **between the `"path"` and
`"permissions"` entries** — that is where they sort. Match the file's `" : "` style:

```json
    "pdfPasswords" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "PDF-Passwörter"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "PDF passwords"
          }
        }
      }
    },
    "pdfPasswordsEmpty" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Keine gespeicherten Passwörter"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "No saved passwords"
          }
        }
      }
    },
```

Verify: `python3 -c "import json; json.load(open('Shared/Framework/Resources/Localizable.xcstrings')); print('ok')"`

- [ ] **Step 8: Run the tests to verify they pass**

Run: `mise exec -- tuist test PdfPasswordsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS, both `PdfPasswordListReducerTests` cases green.

- [ ] **Step 9: Commit**

```bash
git add Tuist Modules/PdfPasswordsFeature Modules/PdfPasswordsFeatureTests \
        Shared/Framework/Resources/Localizable.xcstrings
git commit -m "feat: add a PDF passwords list screen"
```

---

### Task 5: Wire the screen into Settings

**Files:**
- Modify: `Modules/SettingsFeature/SettingList/SettingListReducer.swift` (`Path` enum)
- Modify: `Modules/SettingsFeature/SettingList/SettingListView.swift` (nav row and `switch` over path)
- Test: Modify `Modules/SettingsFeatureTests/SettingList/SettingListViewTests.swift`

**Interfaces:**
- Consumes: `PdfPasswordListReducer` and `PdfPasswordListView` from Task 4.
- Produces: `SettingListReducer.Path.pdfPasswordList` case.

- [ ] **Step 1: Write the failing test**

Add to `Modules/SettingsFeatureTests/SettingList/SettingListViewTests.swift`. If a snapshot test for
the settings list already exists there, this new test sits alongside it:

```swift
    @Test
    func path_pdfPasswordList_isReachable() async throws {
        let store = TestStore(initialState: SettingListReducer.State(server: .testValue())) {
            SettingListReducer()
        }
        store.exhaustivity = .off

        await store.send(.path(.push(id: 0, state: .pdfPasswordList(PdfPasswordListReducer.State()))))

        #expect(store.state.path.count == 1)
    }
```

Add `import PdfPasswordsFeature` to the file's imports.

- [ ] **Step 2: Run the test to verify it fails**

Run: `mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: FAIL — `type 'SettingListReducer.Path' has no member 'pdfPasswordList'`.

- [ ] **Step 3: Add the path case**

In `Modules/SettingsFeature/SettingList/SettingListReducer.swift`, add `import PdfPasswordsFeature`
to the imports and add to the `Path` enum in alphabetical order (after `case licenseList`):

```swift
        case pdfPasswordList(PdfPasswordListReducer)
```

- [ ] **Step 4: Add the navigation row and destination**

In `Modules/SettingsFeature/SettingList/SettingListView.swift`, add `import PdfPasswordsFeature`,
then add this `NavigationLink` to the same `Section` that holds Correspondents and Document types:

```swift
                    NavigationLink(
                        state: SettingListReducer.Path.State.pdfPasswordList(PdfPasswordListReducer.State())
                    ) {
                        Label(.pdfPasswords, systemImage: "key")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
```

and add the matching case to the `switch` over the path destination (near `case let .serverList(store):`
at line 126):

```swift
            case let .pdfPasswordList(store):
                PdfPasswordListView(store: store)
```

- [ ] **Step 5: Run the tests to verify they pass**

Run: `mise exec -- tuist test SettingsFeature -d "iPhone 17 Pro" --no-selective-testing`

Expected: PASS. The settings-list snapshot test will now fail on the new row — that is a legitimate
change. Re-record it by deleting the stale image under `Snapshots/SettingsFeatureTests/` and running
the suite twice, then inspect the diff before committing.

- [ ] **Step 6: Run the full suite and lint**

```bash
mise exec -- tuist test -d "iPhone 17 Pro" --skip-ui-tests --no-selective-testing
mise ci:lint
```

Expected: PASS. Fix any SwiftFormat findings with `mise format` and re-run the affected scheme.

- [ ] **Step 7: Commit**

```bash
git add Modules/SettingsFeature Modules/SettingsFeatureTests Snapshots
git commit -m "feat: reach the PDF passwords screen from Settings"
```

---

## Manual verification

The unit tests exercise `PDFDocument` against real generated PDFs, but nothing exercises the actual
keychain — `Keychain.liveValue` is stubbed out in every test. Before shipping:

1. Import a password-protected PDF, enter the password with **Remember password** on, confirm it
   imports.
2. Re-import the same file and confirm the unlock form never appears.
3. Open Settings → PDF passwords, confirm the entry shows the filename, tap to reveal the password.
4. Share the same file from another app via the share sheet and confirm it auto-unlocks there too —
   this is what proves the keychain access group is working across processes.
5. Delete the entry, re-import, confirm the unlock form comes back.
6. Import an unrelated locked PDF with several passwords stored and confirm **no error toasts**
   appear before the unlock form.
