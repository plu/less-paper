# Everything the app knows about a server

A read-only screen, reached from a server row, showing what this app holds about one server and the
account it connects with — versions, identity, permissions and content counts.

## Context

The app knows a great deal about each configured server and shows almost none of it. `Server` holds
the alias, URL, username and any custom headers; `@Shared` keys hold the negotiated API version, the
current user, the permission list, and cached copies of every entity type; the keychain holds a token
when the server uses one. All of it is reachable only by inference — from what works and what does
not.

That matters most when something is wrong. "Why can I not add a tag here" and "why does this server
behave differently from my other one" are both answered by facts the app already has.

`DiagnosticsFeature` is not that screen: it is the log viewer, and it is app-wide rather than
per-server.

## Decisions

**Existence, never values, for anything secret.** The screen reports that a token exists and which
custom headers are set, and masks their values. People screenshot a screen like this when asking for
help, and custom headers routinely carry proxy credentials. Knowing a header is set is what
diagnosis needs; knowing its value is what a leak needs. The logging work removed hostnames from
logs for the same reason, and this screen must not undo it.

**Cached first, then refreshed.** The screen renders what is cached the instant it opens, fires a
refresh, and updates as results land. The caches are filled by `UpdateCacheUseCase`, which runs when
a server is *selected* — so for a server the user has not opened recently, the cache is stale, and
for one never selected it is empty. Blocking on a fetch would make the screen slow and useless
offline; showing only the cache would make it wrong.

**A value never fetched says so; it never prints `0`.** "0 tags" and "we have never asked" are
different facts, and on this screen the difference is the whole point. Anything unknown renders as
unknown.

**A failed refresh costs nothing.** It never clears a cached value and never replaces the screen —
the last known numbers stay, with a quiet note. Per-endpoint tolerance comes free: after the
add-server bug, `UpdateCacheUseCase` catches each fetch separately, so an account without
`view_user` simply has no user count while everything else fills in.

**Permissions are grouped by type, not listed.** 166 codenames is a wall nobody reads. `Tag — view,
add` across the ~40 types answers "what can this account do here", which is the question being
asked.

**Both versions come from one request.** `x-version` and `x-api-version` arrive on the same
response, and the app already makes that request to negotiate the API version. Reading a second
header there costs nothing; a separate fetch for the paperless version would be a round trip for
data already in hand.

## Architecture

```
ApiInterface
  .paperlessVersion(server)     new @Shared key, beside .apiVersion(server)
  ApiVersionRepository          returns both headers from the one probe          [changed]
        ^
        |
ServersFeature
  ServerRowView                 third swipe action -> .delegate(.showDetails)    [changed]
  ServerListReducer             gains a serverDetail navigation destination      [changed]
  ServerDetailReducer.State     holds the @Shared caches; renders them directly  [new]
  ServerDetailView              five sections                                    [new]
```

The State holds the shared caches rather than a snapshot of them, so the screen updates itself as
the refresh lands. Project 2 established that a nested `@Shared` inside `@ObservableState` notifies
observation; this relies on the same behaviour and adds no new mechanism.

## Changes

### `ApiVersionRepository`

`getAdvertisedApiVersion(server:) -> Int?` becomes a call returning both versions from the one
`/api/ui_settings/` probe it already makes. The existing comment on that method explains why the
probe must authenticate and must not name a version; both constraints are unchanged and still apply.

`NegotiateApiVersionUseCase` writes `.apiVersion(server)` as it does today and `.paperlessVersion(server)`
alongside it. A server that sends no `x-version` leaves the key `nil`, which renders as unknown.

### Navigation

`ServerRowView` gains a third swipe action beside Edit and Delete, sending `.delegate(.showDetails)`
in the same shape Edit already uses. `ServerListView` presents it with `navigationDestination`,
matching how it already presents `diagnosticsList` — Edit's sheet is for a form the user submits;
this is a screen they drill into and leave.

### `ServerDetailView`

| Section | Contents |
|---|---|
| Server | alias, URL, id, auth mode (token or remote-user), custom header names with masked values |
| Versions | paperless-ngx, API |
| User | username, superuser, staff, groups |
| Permissions | grouped by type: the actions granted on each |
| Content | documents, inbox, characters, current ASN, file-type breakdown; counts for tags, correspondents, document types, storage paths, custom fields, saved views, users, groups, favourites |

Auth mode is derived exactly as `UpdateCacheUseCase` derives it — a token means token auth, its
absence means a forward-auth proxy supplies the identity. Nothing records which.

## Testing

**Reducer tests** for the three behaviours the decisions above turn on: `onAppear` triggers the
refresh; a failed refresh leaves cached values in place; and a never-fetched value reports unknown
rather than zero.

**Snapshots for three states** — fully populated, never fetched, and a restricted account with gaps
(no `view_user`, so no user or group counts). All of this sits in the rendered list body, which this
harness does render, so unlike the toolbar chrome of earlier projects these images genuinely
discriminate. Each must differ from the others by hash; a reference byte-identical to a sibling
asserts nothing.

**One test asserts no secret reaches the screen**: a fixture with a token and a custom header whose
value is a recognisable string, asserting that string appears nowhere in the rendered output.

## Out of scope

- **Editing anything.** The screen is read-only; Edit already exists on the same row.
- **Server-wide diagnostics.** The log stays in `DiagnosticsFeature`.
- **Historical data.** No trends, no "last seen" — current facts only.
- **Permission gating of this screen.** It reports what the account can do; hiding it from an account
  would defeat its purpose. Missing data renders as missing, which is the honest outcome.

## Risks

**The screen invites screenshots, which is what makes the masking decision load-bearing.** A future
addition that prints a header value, a token, or a full URL with embedded credentials would undo it
quietly. The test asserting no secret reaches the output is the guard, and it must grow whenever a
field is added.

**Counts come from two sources that can disagree.** `/api/statistics/` reports its own totals while
the cached arrays have their own lengths, and a stale cache will differ from a fresh statistic. The
screen prefers the statistic where one exists and labels cache-derived counts as what they are, so a
disagreement reads as staleness rather than a bug.
