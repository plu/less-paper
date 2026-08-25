# Password-manager hints on the server form

## Context

`ServerFormView` collects everything needed to authenticate against a Paperless instance: URL,
username, password and a local alias. Not one of those fields carries a `textContentType`
(`ServerFormView.swift:74-113`). The only content type anywhere in the feature is
`MfaFormView.swift:61`'s `.oneTimeCode`.

Without a content type iOS does not know these are credential fields, so the QuickType bar offers
nothing and the Passwords key never appears. A user with 1Password or iCloud Keychain has to switch
apps, copy, and paste — twice.

### What cannot be done

There is no public API to tell iOS, or a third-party manager, that a given field belongs to
`https://paperless.example.com`. The domain association comes exclusively from the
`com.apple.developer.associated-domains` entitlement (`webcredentials:` service), which is fixed at
build time and verified against an `apple-app-site-association` file on a domain you control.
Wildcards only reach sub-domains of a domain already listed. This is deliberate: credentials
autofill only in the app that provably owns the domain, so a look-alike cannot harvest them.

For a self-hosted server at an address the user types in, that is structurally out of reach. The
deprecated `SecAddSharedWebCredential` / `SecRequestSharedWebCredential` pair took an FQDN argument
but required the same entitlement anyway.

The app's own credentials in `Keychain.swift` are generic passwords keyed `"<server.id>.password"`
inside a private access group, invisible to the system Passwords app by design. Rewriting them as
`kSecClassInternetPassword` with `kSecAttrServer` would file them under the host but would not make
them visible outside this app either — cosmetic, so not done.

## Goal

Mark the fields with the right content types so the Passwords key appears and the user can pick
their entry in one tap, and chain keyboard focus through the form.

This gets the *manual* pick. The manager still will not know which entry matches the server, and
iOS still will not offer to save the credential afterwards — both need associated domains. The only
route to genuine domain-aware autofill is moving login into `ASWebAuthenticationSession` against an
OIDC provider, which is out of scope.

## Design

### Content types

| Field | Type | Reason |
|---|---|---|
| URL address | `.URL` | Lets managers and QuickType offer stored URLs |
| username | `.username` | Covers usernames and email logins alike; `.emailAddress` would be wrong |
| password | `.password` | See below |
| alias | none | A local nickname. `.nickname` would make iOS offer contact names |

`.password` rather than `.newPassword`: this form authenticates against an account that already
exists. `.newPassword` drives the strong-password generator and would propose a random string the
server has never heard of.

`ShareFormView.swift:217` is deliberately untouched. Its `SecureField` unlocks an encrypted
document; typing it `.password` would put document passwords into the user's credential
suggestions.

### `URLField` gains a focus binding

`ServerFormField` declares a `.url` case that nothing uses, because `URLField` accepts no focus
binding and `.focused` on the wrapper does not reach the `TextField` nested inside `Field`.

`ServerFormField` lives in `ServersFeature`; `URLField` lives in `Components`, which cannot depend
upwards. So the component becomes generic over the focus value:

```swift
public struct URLField<Focus: Hashable>: View {

    public init(
        title: LocalizedStringResource? = nil,
        url: Binding<URL>,
        focus: FocusState<Focus?>.Binding,
        equals: Focus
    )
}
```

The binding is applied to the address `TextField` itself:

```swift
TextField(String(localized: .domain), text: $address)
    .autocorrectionDisabled()
    .focused(focus, equals: equals)
    .keyboardType(.URL)
    .textContentType(.URL)
    .textFieldStyle(.plain)
    .textInputAutocapitalization(.never)
    .padding(.trailing, .x2)
```

`focus` is required rather than optional. An optional `FocusState.Binding` would leave `Focus`
uninferrable at call sites that omit it, and would need the field built twice behind an
`if let`. There are only two call sites to update — the preview and the snapshot test.

### Focus chain

URL → username → password → alias, each `.submitLabel(.next)` with an `onSubmit` moving focus on.
Alias takes `.submitLabel(.done)` and clears focus.

Done does **not** fire `saveButtonTapped`. The form can be invalid, and a Return key silently
creating a server is a surprising amount of consequence for a keyboard dismissal. The Save button
stays the only way to submit.

`.submitLabel` and `.onSubmit` travel through the environment, so on `urlField()` they can sit on
the `URLField` wrapper; `.focused` cannot, which is what forces the binding parameter above.

## Out of scope

- Associated domains, and any attempt to fake dynamic ones.
- Rewriting keychain storage as `kSecClassInternetPassword`.
- `ASWebAuthenticationSession` / OIDC login.
- `ShareFormView`'s document-unlock password.
- Auto-focusing a field when the sheet opens.

## Testing

`textContentType`, `submitLabel`, `focused` and `onSubmit` are all non-visual, so no snapshot
changes: `ServerFormViewTests`' three snapshots stay as recorded.

`URLFieldTests` needs the new signature. `@FocusState` is only valid inside a `View`, so the test
gets a small harness whose body is nothing but the `URLField` — it adds no layout, so the recorded
snapshot is unchanged.

No new tests. None of this is assertable in a snapshot, and the reducer is untouched.

## Files

Changed:

- `Modules/Components/Field/Generic/URLField.swift` — generic over `Focus`; `focus` / `equals`
  parameters; `.textContentType(.URL)`; preview updated with `@Previewable @FocusState`
- `Modules/ServersFeature/ServerForm/ServerFormView.swift` — content types on username and
  password; submit labels and `onSubmit` chain across all four fields; `urlField()` passes focus
- `Modules/ComponentsTests/Field/URLFieldTests.swift` — focus harness
