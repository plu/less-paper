# Scanning from Control Center

A control that opens the app straight into the document scanner, on a server chosen when the control
is placed.

## Context

Getting paper in is what the app is for, and today every route to the scanner starts by opening the
app and finding a button: the document list's toolbar, or Settings. `DocumentImportReducer` owns that
step — `scanButtonTapped` sets `isPresentingDocumentScanner`, and `DocumentImportViewModifier`
presents `DocumentScannerView`, a `VNDocumentCameraViewController` wrapper. Scanned pages flow into
the share sheet that the share extension also uses, so upload, tagging and the review prompt are
already downstream of that one action.

iOS 18 added `ControlWidget`: a control the user can place in Control Center, on the Lock Screen, or
behind the Action Button, from a single declaration. The deployment target is already `iOS 18.0`, so
nothing has to move to adopt it.

Nothing in this repository uses App Intents or WidgetKit today. There is one app extension —
`ShareExtension` — which establishes how an extension target is declared, entitled and embedded, but
it is a share extension and shares none of the widget machinery.

Two pieces of existing work do most of the heavy lifting, and the design leans on both:

- **`DeepLink`** parses and builds `lesspaper://` URLs that name a server by host, port and path
  prefix, and carry a route. It has exactly one route today, `documentDetail`. `resolves(to:)`
  answers which configured server a link refers to.
- **`AppReducer.openURL`** already handles the hard case: a link naming a server that is not the
  selected one parks in `pendingLink`, the selected server changes, `MainReducer.State` is rebuilt
  asynchronously, and `applyPendingLink` fires when the two agree. That is precisely the behaviour a
  per-control server needs, and it is already tested.

## Decisions

**The control opens the app; it cannot scan by itself.** `VNDocumentCameraViewController` is a UI
that must run in the app. So every design here is a way of saying "open, and scan on this server",
and the only real question is how that sentence travels.

**It travels as a deep link.** The control's intent returns an `OpenURLIntent` for
`lesspaper://<host>/<prefix>/scan`. Three alternatives were considered:

- *A pending-action file in the app group.* Rejected: it invents a second mechanism for "something
  outside asked the app to do a thing", and needs its own staleness rules — a file that is never
  consumed fires the camera on some unrelated later launch.
- *An App Intent handled in-process.* Rejected: the intent runs in the extension, which cannot
  present the scanner, so it collapses into one of the other two with extra ceremony.
- *A deep link.* Chosen. It adds no new concept. The pinned server is encoded in the URL, so no
  second channel is needed to carry it, and server resolution, the unknown-server error and the
  wait-for-the-server-to-switch dance all already exist.

**The route enum stops being singular.** `DeepLink`'s parser matches `/documents/<id>/details` from
the end and returns `nil` for anything else. Adding `.scan` makes it branch. That is a real change to
a type that currently gets to assume one shape, and it is the main cost of choosing the deep link —
worth paying, because the alternative is a parallel mechanism.

**The server is chosen per control, not taken from the app's current selection.** iOS supports
configurable controls, so two controls can point at two servers. This is the more ambitious of the
two options and it is deliberate: someone with a work server and a home server wants one tap to the
right one, not one tap plus a server switch. The existing `pendingLink` machinery means the app
already handles being asked to act on a server it is not currently showing.

**The extension gets the app group and nothing else.** It reads `servers.json` to list servers by
alias. It has no business with the keychain, and not granting it is the way to keep that true —
`ShareExtension` takes both because it makes authenticated requests; this one never does.

**The target is named for the container, not the control.** `WidgetExtension`, not
`ControlExtension`. A widget extension target holds any number of widgets, so a later home-screen
widget belongs in this one rather than a second target. This is naming the thing iOS actually
creates, not speculative generality.

## Architecture

```
WidgetExtension (new, .appExtension)
  ScanControl            ControlWidget — the declaration iOS reads
  ScanControlConfiguration  ControlConfigurationIntent — holds the chosen server
  ServerEntity + Query   AppEntity over @Shared(.servers)
        |
        | depends on
        v
ApiInterface (existing)   Server, SharedReaderKey.servers, DeepLink.scanURL(server:)
        ^
        | route added
        |
AppFeature (existing)     AppReducer.applyPendingLink gains .scan
        |
        v
ShareFeature (existing)   DocumentImportReducer.scanButtonTapped — unchanged
```

The arrow that matters is the one that is missing: `WidgetExtension` does not depend on
`AppFeature`, `ShareFeature`, or anything that draws the app. It knows how to name a server and how
to build a URL, and that is all.

## Changes

### `Modules/ApiInterface/DeepLink/DeepLink.swift`

`Route` gains `case scan`. The parser branches on the last path segment: `scan` yields `.scan` with
everything before it as the prefix; otherwise the existing three-segment `documents/<id>/details`
match runs unchanged and still returns `nil` when it fails. `url(scheme:server:route:)` gains the
mirror case, appending `/scan` to the normalised server path.

A server hosted under a subpath must round-trip, because the prefix is what identifies the server:
`https://example.com/paperless` produces `lesspaper://example.com/paperless/scan`, and parsing that
must yield prefix `/paperless`, not a route the app then fails to resolve.

### `Modules/AppFeature/AppReducer.swift`

One case in `applyPendingLink`:

```swift
                case .scan:
                    state.main?.selectedTab = .inbox
                    return .send(.main(.inbox(.documentImport(.view(.scanButtonTapped)))))
```

Nothing else changes. `openURL` is route-agnostic — it parses, resolves the server, parks the link
and either applies it now or after the server switch.

**The inbox, not the documents tab.** `MainReducer` holds two separate `DocumentListReducer`
instances — `documentList` for the documents tab and `inbox` for the inbox, the latter filtered by
`.inbox(server:)`. Both own a `DocumentImportReducer`, so either could present the scanner, and the
choice decides which screen the user is looking at when the sheet closes.

The inbox wins on two counts. A freshly scanned document is unfiled, so it lands in the inbox — that
is where the user should be left when the import finishes. And `.inbox` is already
`MainReducer.State`'s default tab, so a cold launch from the control presents the scanner without a
visible tab switch behind it.

The `documentDetail` route selects `.documents` instead, and that is not an inconsistency to
reconcile: it goes there because the document being opened lives there. The tab follows the
destination in both cases.

### `Modules/WidgetExtension/` (new)

**`ScanControlURL.swift`** — the piece worth testing, extracted so it can be:

```swift
// Nil when there is no server to scan to, which is not an error: the intent opens the app plainly
// and the user lands on the server list. A control added before any server exists is the ordinary
// first-launch order of events, not a misconfiguration.
func scanURL(for server: Server?) -> URL? {
    guard let server else {
        return nil
    }
    return DeepLink.appURL(server: server, route: .scan)
}
```

**`ServerEntity.swift`** — an `AppEntity` wrapping `Server.ID` and the alias, with an `EntityQuery`
reading `@Shared(.servers)`. The alias is what the picker shows, because it is what the user named
the server; the id is what is stored, because an alias can be renamed.

**`ScanControlIntent.swift`** — a `ControlConfigurationIntent` with one `@Parameter` of
`ServerEntity`, defaulting to `@Shared(.selectedServer)`. Its `perform()` returns
`.result(opensIntent: OpenURLIntent(url))` when `scanURL(for:)` yields one, and otherwise opens the
app with no URL.

**`ScanControl.swift`** — the `ControlWidget` itself: a `ControlWidgetButton` labelled with the
server alias and the SF Symbol `doc.viewfinder`.

### `Tuist/ProjectDescriptionHelpers/`

`Module.swift` gains a `widgetExtension` case: `product: .appExtension`, entitlements carrying
`com.apple.security.application-groups` only, and the module's source path. `Module+InfoPlists.swift`
gains its plist with `NSExtensionPointIdentifier` of `com.apple.widgetkit-extension`, the marketing
version and build number the other targets use, and the `en`/`de` localizations.
`Module+Dependencies.swift` gives it `.target(.apiInterface)`, and adds it to the app's dependencies
so it is embedded. `Module+Schemes.swift` gains its scheme alongside the other modules'.

## Testing

**`DeepLink`** carries the load, and its tests are pure: `.scan` builds the expected URL for a
root-hosted and a subpath-hosted server; both parse back to `.scan` with the right prefix; a URL with
a trailing `scan` under a subpath resolves to the right server via `resolves(to:)`; and the existing
`documentDetail` cases still parse, which is the regression that matters when a parser learns a
second shape.

**`AppReducer`** gets two `TestStore` tests: a scan link for the selected server presents the
scanner, and a scan link for a *different* configured server parks in `pendingLink`, switches server,
and then presents it. The second is the one that justifies the design, so it is worth writing even
though the machinery under it is already tested for documents.

Both assert on the **inbox** instance — `\.main.inbox.documentImport.isPresentingDocumentScanner` —
and the first also asserts `selectedTab == .inbox`. Asserting the tab matters more than it looks:
`documentList` and `inbox` are the same reducer type, so a route that targeted the wrong one would
still compile, still present a scanner, and still pass a test that only checked "a scanner appeared".

**`DeepLink.scanURL(server:)`** gets tests for both branches — a server, and `nil` — in
`ApiInterfaceTests`.

**What is not covered, plainly.** `ControlWidget` bodies and `AppIntent.perform()` have no unit-test
story here: there is no snapshot support for controls, and the intent's real effect is "iOS opened
the app". The URL decision is extracted precisely so the untestable remainder is a declaration rather
than logic. That leaves one manual check before merge — add the control, pin a server, tap it, and
confirm the camera opens against that server — and it should be done on a device or simulator with
two servers configured, since a single-server setup cannot tell a pinned server from a default one.

## Out of scope

- **A home-screen widget.** The target is named so one could be added later; nothing here builds one.
- **Scanning without opening the app.** Not possible: the camera UI must run in the app.
- **A control for importing a file** rather than scanning. The document picker has the same
  constraint and would be a second control; if it is wanted, it is a separate change that reuses this
  one's shape.
- **Changing how scanning works once the app is open.** This adds an entry point and touches nothing
  downstream of `scanButtonTapped`.
- **Falling back to the selected server when a pinned server is deleted.** The link names a host the
  app no longer knows, `openURL` raises `serverNotFound`, and the user is told. Silently scanning to
  a different server than the control names would be worse than an error.

## Risks

**A parser that learns a second shape can forget its first.** `DeepLink` is the one type both the app
and this extension depend on for correctness, and its failure mode is quiet — links the app writes
but cannot read. Mitigated by keeping the existing `documentDetail` tests and adding the `.scan`
cases beside them rather than replacing anything.

**The control's own behaviour is verified by hand.** Everything about how iOS presents and invokes a
control is outside what these tests reach. The mitigation is the extraction above plus a named manual
check; the residual risk is that the control appears but does nothing, and that is discovered by
tapping it.

**An extension is a second process reading the app's shared files.** It only ever reads, and only
`servers.json`, but it does so while the app may be writing. `FileStorageKey` is the same mechanism
the share extension already relies on for the same file, so this adds a reader to an arrangement that
already has one.

## Implementation notes

This design's reasoning held up — the control still opens a deep link, the server is still pinned per
control, and the inbox is still where the scan lands. Four things changed between this doc and what
shipped.

**`scanURL` lives in `ApiInterface`, not `WidgetExtension`.** The design put it in the extension
"extracted so it can be tested". It cannot be: a `.appExtension` product cannot be linked into a
unit-test bundle, and every test target in this project is a `.unitTests` bundle over a framework. It
uses only `Server` and `DeepLink`, both already in `ApiInterface`, so it moved one box down the
dependency arrow, as `DeepLink.scanURL(server:)`, and `ApiInterfaceTests` covers it. The design's
intent — that the testable part stays testable — is preserved.

**There is no custom action intent, and `ControlConfigurationIntent` could never have been one.** The
design said `ScanControlIntent`'s `perform()` would return `.result(opensIntent: OpenURLIntent(url))`.
Two separate problems. First, `ControlConfigurationIntent` declares
`associatedtype NeverResult where NeverResult == Never` and supplies its own
`perform() async throws -> Never` — a configuration intent only carries the user's choice; it cannot
act. Second, even in a plain `AppIntent`, returning `.result()` from one branch and
`.result(opensIntent:)` from the other does not compile at this project's iOS 18.0 deployment target:
the only always-available `result(opensIntent:)` is an `@_disfavoredOverload` returning
`IntentResultContainer<Never, OpensAppIntent, Never, Never>`, while plain `.result()` returns
`IntentResultContainer<Never, Never, Never, Never>`; the overload that reconciles them requires
iOS 18.2.

What shipped instead is simpler than the design imagined: `ScanControlConfiguration` carries the
pinned server, and the button's action is `OpenURLIntent` directly — `OpenURLIntent: SystemIntent:
AppIntent`, so it satisfies `ControlWidgetButton`'s `Action: AppIntent` requirement, and iOS performs
the open. No `perform()` runs in the extension at all, which also removes the design's named risk of a
control that appears but does nothing: there is no extension code left in that path to fail.

The no-server case became `DeepLink.appLaunchURL` — a non-optional, scheme-only URL that
`DeepLink(url:)` deliberately cannot parse, so `AppReducer` ignores it and the user lands on the server
list. Both halves of that contract are unit-tested.

**The design said nothing about code signing, and a second app extension needs it.** A new
`.appExtension` needs its own App ID, provisioning profile and CI secret, or the release archive stops
exporting. `Module+Targets.swift` now reads `Environment.widgetExtensionProvisioningProfile`, and
`mise/tasks/ci/build` installs the profile and names it in the export options. Note that this repo
carries signing secrets in `fnox.toml`'s age-encrypted `[secrets]` table, injected by
`fnox exec -P ci -- mise ci:build` — not as GitHub Actions secrets — so the remaining step is
`fnox set WIDGET_EXTENSION_PROVISIONING_PROFILE`, not a workflow edit.

**String catalog symbols do not work in App Intents declarations.** The `ExtractAppIntentsMetadata`
build step statically parses `static var title`, `@Parameter(title:)` and
`TypeDisplayRepresentation(name:)`, and rejects a catalog-generated static member with
"'LocalizedStringResource' must be initialized with a call to its initializer or a string literal".
Those declarations spell `LocalizedStringResource("scanControlTitle")` in full. Everywhere else in the
extension the generated symbols work normally.
