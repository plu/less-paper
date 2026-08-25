# Remember PDF passwords in the keychain

## Context

Importing a password-protected PDF already works. `ShareFormReducer.State.isLocked`
(`Modules/ShareFeature/ShareForm/ShareFormReducer.swift:84`) reports
`document?.isEncrypted == true && document?.isLocked == true`, and `ShareFormView` swaps the whole
form for `unlockView()` — a password field and an Unlock button. Tapping it runs `runUnlockFile`
(`ShareFormReducer+Effect.swift:21`), which calls `PDFDocument.unlock(withPassword:)` and, on
success, rewrites the file with empty owner and user passwords before reloading it.

The password is typed fresh every time. For anyone importing a recurring locked document — a monthly
bank statement, a payslip — that is the same password retyped every month.

This adds an opt-in store of PDF passwords in the keychain, tries them automatically before showing
the unlock form, and gives the user a settings screen to inspect and remove them.

### Both import paths converge

`DocumentImportReducer` (in-app, via `.fileImporter` and the document scanner) and
`ShareExtensionReducer` (the share sheet) both build a `ShareFormReducer.State`, so there is exactly
one place to change.

Both also route their URLs through `CopyFilesUseCase`
(`Modules/ShareFeature/ShareExtension/CopyFilesUseCase.swift`), which takes security-scoped access
and copies each file into the temporary directory. That matters here: `runUnlockFile` writes the
decrypted PDF back over its URL, and because that URL is a temporary copy, the user's original file
keeps its password. Auto-unlocking therefore does not silently strip protection from files in the
user's Files app.

### The keychain is already shared with the extension

`Keychain` (`Modules/ApiImplementation/Authentication/Keychain.swift:71`) is constructed with
`accessGroup: .keychainGroup(teamID:nameID:)`, so anything it stores is readable from both the app
and the share extension. A password saved during an in-app import is available the next time the
user shares a file from Safari, with no extra work.

## Design

### Model and storage

New `Modules/ApiInterface/PdfPasswords/PdfPassword.swift`:

```swift
public struct PdfPassword: Codable, Equatable, Identifiable, Sendable {
    public let filename: String
    public let id: String
    public let password: String
}
```

`filename` is captured at save time from the file being unlocked and is what the settings list shows.
A password reused across many documents keeps the name of the first file that used it.

Three use cases declared in `Modules/ApiInterface/PdfPasswords/`, live values in
`Modules/ApiImplementation/PdfPasswords/`:

| Use case | Signature |
| --- | --- |
| `GetPdfPasswordsUseCase` | `() async throws -> [PdfPassword]` |
| `SavePdfPasswordUseCase` | `(_ filename: String, _ password: String) async throws -> Void` |
| `DeletePdfPasswordUseCase` | `(_ id: PdfPassword.ID) async throws -> Void` |

This mirrors `GetCredentialsUseCase` and `StoreTokenUseCase`, which are the existing keychain-backed
use cases and follow exactly this interface/implementation split.

The existing `Keychain` client grows two methods rather than a second keychain wrapper being
introduced — it already owns the `SwiftSecurity.Keychain` instance and the access group:

```swift
var getPdfPasswords: @Sendable () async throws -> [PdfPassword]

var setPdfPasswords: @Sendable (_ pdfPasswords: [PdfPassword]) async throws -> Void
```

**One keychain item holds the whole list**, JSON-encoded, under `.credential(for: "pdf-passwords")`.
`Data` conforms to `SwiftSecurity`'s `SecDataConvertible`, so this needs no new conformance. The
alternative — one item per password plus `retrieveAll` — gives per-item writes but forces ordering
and the filename label into keychain attributes and `SecItemInfo` plumbing, which is a lot of
machinery for a list a user grows by hand, one entry at a time.

The blob is rewritten on every add or delete, so a simultaneous write from the app and the extension
is last-write-wins. Passwords are added one at a time, by hand, in a flow that requires the user to
be looking at one of the two processes, so this is theoretical rather than real.

`SavePdfPasswordUseCase` **deduplicates on the password string**: saving a password already in the
list is a no-op and keeps the original filename. Without this, importing the same recurring document
each month with the toggle left on would grow one duplicate entry per import.

The keychain access policy is SwiftSecurity's default, matching `storeCredentials`. That default
allows these to reach a new device through a keychain restore. Consistency with the existing
credential storage is the reason; tightening both to `ThisDeviceOnly` is a separate decision.

### Saving from the unlock form

`ShareFormInput` gains `var shouldRememberPassword = false`, rendered as a toggle beneath the
password field in `unlockView()`. It is off by default, so a secret reaches the keychain only after
a deliberate tap.

`runUnlockFile` saves after `PDFDocument.unlock(withPassword:)` returns true. Hanging persistence off
the success path means **a wrong password can never be stored** — no validation step is needed.

`ShareFormInput.reset()` does not currently clear `password`, and will not clear
`shouldRememberPassword` either; both are per-file values already replaced wholesale by
`selectNextFile()`, which assigns `input = .init()`.

### Trying stored passwords automatically

`selectFile(index:)` and `selectNextFile()` are mutating helpers on `State`
(`ShareFormReducer.swift:212-222`), called from `init` and from the `fileImported` and
`skipButtonTapped` cases. State cannot originate effects, so the auto-unlock attempt has nowhere to
hang.

Move the transition into the reducer as a new `.selectFile(Int)` case on `Action` — an internal
action, not a `View` one, since nothing in the view sends it directly:

```swift
case let .selectFile(index):
    state.selectFile(index: index)
    return state.isLocked ? .runAutoUnlock(document: state.document, url: state.files[state.currentIndex]) : .none
```

`fileImported` and `skipButtonTapped` send `.selectFile(state.currentIndex + 1)` instead of mutating
directly. `init` keeps its existing `selectFile(index:)` call — it must, because the first file has
to be on screen before any action can be sent — and a new `.view(.onAppear)` covers the first file's
auto-unlock. `ShareFormView` has no lifecycle hook today, so it gains a `.task`.

`runAutoUnlock` fetches the stored passwords and tries each against the document, stopping at the
first that unlocks and then reusing the existing write-and-reload path.

### Auto-unlock failures are silent

This is the constraint that shapes `runAutoUnlock`. `runUnlockFile` reports failure as
`.error(ShareFormError.unlockFailed)`, which `ShareFormReducer` turns into a toast. If auto-unlock
reused that path, a user with a dozen saved passwords opening an unrelated locked PDF would get a
dozen error toasts before the form appeared.

So `runAutoUnlock` reports nothing at all. Every password failing is the expected outcome for a
document the user has never unlocked before; it simply falls through to `unlockView()`, exactly as
today. Only an explicit tap on Unlock produces an error toast.

### Settings screen

A new `PdfPasswordsFeature` module, following `TagsFeature`'s shape minus the form:

- `PdfPasswordList/PdfPasswordListReducer.swift`, `+Effect.swift`, `+TestValue.swift`, `PdfPasswordListView.swift`
- `PdfPasswordRow/PdfPasswordRowReducer.swift`, `PdfPasswordRowView.swift`

Rows show the filename, with the password revealed on tap and swipe-to-delete. Every other list
screen in Settings is its own module (`TagsFeature`, `CorrespondentsFeature`,
`StoragePathsFeature`), so a new module keeps that consistent even though this one has no form.

`SettingListReducer.Path` gains a `pdfPasswordList` case, and `SettingListView` gains a
`NavigationLink` row alongside the existing Correspondents and Document types entries.

Unlike those lists, this screen takes no `server` — PDF passwords belong to documents, not to a
Paperless instance, and the same password is equally valid whichever server the file is imported to.

## Testing

- `PdfPassword` encode/decode round-trip.
- `Keychain` and the three use cases: an empty store returns `[]`; save appends; **save of an
  existing password is a no-op**; delete removes by id.
- `ShareFormReducer`:
  - auto-unlock stops at the first matching password and does not try the rest
  - every password failing leaves the form locked and emits **no toast**
  - a locked file with no stored passwords makes no unlock attempt
  - unlocking with the toggle on saves the password and the filename
  - unlocking with the toggle off saves nothing
  - a manually entered wrong password still toasts
- `PdfPasswordListReducer`: load populates the list, delete removes the row.
- Snapshot tests for `PdfPasswordListView` and the unlock form's new toggle, matching the existing
  view-test convention.

## Out of scope

- Editing a stored password. Delete and re-save covers it.
- Per-server scoping.
- Migrating the keychain access policy for existing credentials.
