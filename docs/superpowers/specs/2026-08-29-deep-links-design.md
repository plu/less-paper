# Deep links to a document

Open a document in Less Paper from a link — one the app itself produced, or one someone pasted into
a message a year ago — and land on that document, in its server, inside the ordinary navigation.

## Context

The shipping app (`~/paperless-ios`) has this and the rewrite does not. What it does today:

- `AppScene.onOpenURL` dismisses everything on screen, then presents a full-screen `DeeplinkView`.
- `Deeplink.parse` finds a configured server whose `url.host()` equals the link's host, matches the
  path `/documents/{id}/details`, fetches that document, and shows `DocumentDetailView` in a modal.
- `DocumentDetailModel` builds two links for the detail menu: `deeplinkWeb`, the server's own
  `https://…/documents/{id}/details`, and `deeplinkApp`, the same URL with the scheme swapped to
  `atlp`. That swap is why host matching works — an app link is a web link wearing a different
  scheme.

The rewrite registers `atlp` in `Info.plist`, but only as the OIDC callback that
`ASWebAuthenticationSession` consumes itself. No URL ever reaches the app, because nothing observes
one.

**Links already exist in the wild.** The rewrite replaces the same App Store listing, so users
upgrade in place, carrying whatever `atlp://` links they saved in notes, messages and shortcuts. A
scheme is a promise that outlives the codebase that made it.

## Decisions

**`lesspaper://` is what we emit; `atlp://` is what we still accept.** Parsing both costs one line —
the host and path shape is identical either way — and it keeps every link the old app ever produced
working. New links read as the app's name, which matters when someone sees one in a message and has
to guess what will open. `atlp://` is never advertised or documented; it is a compatibility alias.

**A link lands in the navigation stack, not in a modal.** Switch to the link's server if it is not
the current one, select the Documents tab, push the document onto that tab's path. Back goes to the
document list, so the document is somewhere you can navigate *from*.

The old app's modal was a dead end — no list behind it, nothing to go back to — and reproducing it
here would mean hosting `DocumentDetailReducer` a second way, as a `@Presents` destination beside
the `Path` case that already exists. One host, one set of behaviours to reason about.

**A link to a document already on the stack pops to it rather than pushing a copy.** Tapping the
same link twice is ordinary — a message thread, a second glance — and two identical screens stacked
on each other is a bug the user has to unwind by hand. Borrowed from BlytheMe's `openRoute`, which
solves exactly this.

**`DocumentListReducer` opens the document, not `AppReducer`.** `DocumentDetailReducer.State` takes
a `Shared<Document>`, which the list already owns: each row holds one, and
`presentDocumentDetail(Shared<Document>)` hands it over. A deep link that reached in from
`AppReducer` would have to build that shared value itself and would get it wrong — a fresh
`Shared(value:)` for a document the list *also* holds means two copies of one document, and an edit
made through the link would not show in the list behind it.

So `AppReducer` routes and `DocumentListReducer` decides: if the id is among the loaded documents,
present that row's shared document; otherwise fetch it with `GetDocumentUseCase` and present a
standalone one. The plumbing stays where the plumbing lives.

**The link is held until the app can act on it.** `selectedServer` is `@Shared`, and
`AppReducer` learns about a change through a publisher on the main run loop — so setting it and
pushing a document cannot happen in one reduction. A cold start is the same shape: the URL can
arrive before servers have loaded at all. `AppReducer.State` therefore holds a pending link and
applies it when `main` exists for the right server, which covers both without a special case for
either.

**Failures are toasts, and they name what failed.** An unmatched host says so with the host in it —
the old app's one genuinely good error. A document that no longer exists, or that this user cannot
see, surfaces the API error. In every case the app stays where it was: a link is a request, not an
instruction to abandon what the user was doing.

**Parsing and building live in one type.** `DeepLink` both reads a URL and writes one, and a
round-trip test pins them together. Two functions in two modules would drift the first time the path
changed, and the failure — links the app writes but cannot read — is invisible until someone taps
one.

**A server's path prefix is part of the match.** The old app whole-matched `/documents/{id}/details`
against the whole path, so a server hosted at `https://example.com/paperless` produced a web link
carrying that prefix and an app link that never parsed. The server is resolved first — host, port,
and its own path as a prefix — and only the remainder is matched.

**No URL-routing library.** BlytheMe uses swift-url-routing, whose `ParserPrinter` parses and prints
from one declaration and pays for itself across a dozen routes. There is one route here.
`init?(url:)` and `var url: URL` are about sixty lines, and the round-trip test does what the printer
would have guaranteed.

## Architecture

```
ApiInterface     DeepLink                          — the URL contract, read and written
AppFeature       .openURL, pending link, routing   — where a link becomes navigation
DocumentsFeature .openDocument(id)                 — find it or fetch it, then push
```

### `ApiInterface`

`DeepLink` carries what a URL says and nothing about which servers are configured:

```swift
public struct DeepLink: Equatable, Sendable {
    public let host: String
    public let port: Int?
    public let prefix: String
    public let route: Route

    public enum Route: Equatable, Sendable {
        case documentDetail(Document.Id)
    }
}
```

`init?(url: URL)` accepts either scheme and returns `nil` for anything else. **It matches the path
from the end** — `/documents/{id}/details` with an optional trailing slash — and whatever precedes
the match becomes `prefix`. That is what lets a server hosted under a subpath work without the
parser knowing any server exists: the prefix falls out of the match rather than having to be
subtracted from it.

`url(for: Server)` writes the `lesspaper://` form and `webURL(for: Server)` the `https://` one, both
from the server's own URL, so the prefix and port come back exactly as that server spells them.

A `DeepLink` resolves against a `Server` when the hosts are equal, the ports are equal (both `nil`
counts), and the server's own path equals `prefix` once trailing slashes are ignored. That check
lives with the reducer that owns the servers list; `DeepLink` stays a value that can be tested
without one.

### `AppFeature`

`AppView` gains `.onOpenURL { store.send(.openURL(url)) }` — the URL becomes an action, so every
step after it is testable without a view.

`AppReducer` parses, resolves the host and port against `@Shared(.servers)`, and stores the result
in `State.pendingLink`. If the named server is already selected and `main` exists, it applies
immediately; otherwise it sets `@Shared(.selectedServer)` and waits, applying from
`selectedServerChanged` once `main` has been rebuilt for that server. Applying means selecting the
Documents tab and sending `.main(.documentList(.openDocument(id)))`, then clearing the pending link.

An unresolved host never becomes a pending link: it toasts and is dropped.

### `DocumentsFeature`

`DocumentListReducer` gains `.openDocument(Document.Id)`. If the id is among `state.documents`, it
reuses that row's `Shared<Document>`; otherwise it fetches through `GetDocumentUseCase` and wraps the
result. Either way it then applies the same rules the list already applies to a tapped row: on a
split layout the path is cleared first, and — new for both paths — a detail already on the path for
that id is popped to instead of pushed again.

### The outbound side

`DocumentDetailView`'s existing `Menu` gains **Copy link** and **Copy web link**, the pair the old
app offered, built by `DeepLink` from the state's `document` and `server`. The file `ShareLink` stays
as it is; it shares a PDF, which is a different thing to want.

## Testing

`DeepLink` is a pure value, and that is where most of the tests go:

- both schemes parse to the same value, and an unknown scheme parses to `nil`
- a server hosted under a path prefix round-trips — the case the old app got wrong
- host, port and prefix mismatches fail to resolve
- a trailing slash, a missing `details` segment and a non-numeric id all fail rather than guess
- build → parse round-trips for a plain server and a prefixed one

`AppReducer` tests cover the routing: a link for the selected server applies at once; a link for
another server sets the selection and applies after `main` is rebuilt; a link arriving before
bootstrap waits rather than being dropped; an unknown host toasts and stores nothing.

`DocumentListReducer` tests cover the three open paths: a loaded document reuses its shared value, an
unloaded one is fetched, and a document already on the path pops rather than pushes.

No UI test. The journey would need a second app to send the URL, and every decision in it is covered
above.

## Out of scope

- **Universal `https://` links.** They need an `apple-app-site-association` file served from each
  server's domain, which is the user's own machine — unreliable by construction, and a feature that
  works for some servers and not others is worse than one that works the same everywhere.
- **Links to anything but a document.** Saved views, searches and tags are all plausible and none of
  them existed in the old app. The machinery generalises; add a case when someone asks.
- **A route stream.** BlytheMe funnels notifications and in-app navigation through the same route
  type. Less Paper has no notifications, and nothing else asks to navigate from a distance.
- **Paperless share links.** The `/api/share_links/` feature the old app also had — creating a public
  URL with an expiry and a file version. Its own gap, its own spec; it shares no machinery with this
  one, since a share link is a server URL and never opens the app.

## Risks

**A standalone document can diverge from the list.** A link to a document the list has not loaded
gets a `Shared(value:)` of its own. If the same document is later loaded into that list, there are
briefly two shared copies, and an edit through the deep-linked screen will not appear in the row
until the list reloads. Reusing the row's value whenever it exists keeps this to the case where the
list genuinely does not have the document, which is also the case where the divergence is least
visible.

**The server switch is observable.** Following a link to another server changes the selected server
for everything, not just for that document — the tab bar, the statistics, the next launch. This is
the same thing the server switcher does, and a link that opened a document without switching would
leave the app in a stranger state, but it is a bigger side effect than a tap on a link looks like it
should have.

**A link can raise a login.** If the link's server sits behind a forward-auth proxy whose session has
expired, fetching the document bounces and the login sheet appears over whatever the routing has just
done. The rendezvous handles it and the fetch replays, but the ordering — switch server, push
document, present login — has not been exercised together.

**Nothing validates the link's origin.** Any app or web page can send `lesspaper://…` and make the
app switch servers and open a document. Nothing here mutates data or exposes anything the user could
not already see, so the exposure is navigation only; it is worth remembering before a future case
does something less inert.
