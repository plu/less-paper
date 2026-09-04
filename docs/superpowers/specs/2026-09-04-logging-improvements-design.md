# Logging improvements

Stop the log leaking server hostnames, and make it worth reading when nothing has gone wrong.

## Context

[Error logging](2026-08-27-error-logging-design.md) shipped: a `Logging` module with a `LogClient`
dependency, a `LogWriter` actor owning a rotating file in the caches directory, a `LogRedaction`
denylist, and a Diagnostics screen in Settings that lists, shares and clears it. That design is
sound and none of it is being replaced.

Two things are wrong with what it produces.

**It leaks hostnames.** `LogRedaction.redact(_ url:)` reduces a URL to path and query, dropping the
host — a tightening of the original spec, which had said the host would be written. Every API line
goes through it. One call site does not:

```swift
log.info("no OIDC providers from \(url.host() ?? "server"): \(error.localizedDescription)", category: .server)
```

Because OIDC discovery re-runs whenever the URL field settles, adding a server writes the hostname —
and every half-typed prefix of it — repeatedly:

```
INFO  server  no OIDC providers from apps: The Internet connection appears to be offline.
INFO  server  no OIDC providers from paperless: A server with the specified hostname could not be found.
INFO  server  no OIDC providers from paperless.apps: A server with the specified hostname could not be found.
INFO  server  no OIDC providers from paperless.apps.: A server with the specified hostname could not be found.
```

A user sending that file to a stranger is handing over the address of their document archive. The
earlier spec listed this under Risks — "a server hostname can identify a person" — and accepted it.
This reverses that decision.

**It is close to empty when nothing has failed.** Only errors, warnings and API request lines get
written. Nothing records what the app is, what it is running on, or that its ordinary work
succeeded. A log in which the cache update silently never ran is indistinguishable from one in which
it ran perfectly, so the most common support answer — "it is working, the problem is elsewhere" —
cannot be reached from the evidence.

## Decisions

**No hostname reaches the log, ever.** Not redacted, not truncated, not hashed: absent. A hash still
correlates two reports from the same server, and a "redacted" host in the middle of a sentence
invites a later author to write the real one beside it. The rule is easier to keep than to qualify,
and `LogRedaction` already implements it for URLs — the only work is bringing the last call site
under it and adding a test that fails if another escapes.

**OIDC discovery logs its outcome, not its error.** What a support reader needs is whether single
sign-on was offered:

```
INFO  server  OIDC discovery: 2 providers
INFO  server  OIDC discovery: none
```

The `localizedDescription` goes with the host. It read as a diagnosis but was not one: "The Internet
connection appears to be offline", "A server with the specified hostname could not be found" and
"Could not connect to the server" are all the same answer to the only question the form asks, and
`providers(url:)` already documents that it treats them identically. Keeping the string would also
keep the temptation to keep the host that makes it meaningful.

**A 10,000-line cap replaces the 1 MB two-file rotation.** One file, `error.log`, holding the newest
10,000 lines. Lines are the unit a person reads, scrolls and pastes into a bug report; bytes are not,
and a byte budget says nothing about how much history it buys — a chatty release silently buys less.
Two generations existed to soften a hard cut at 1 MB; a trim that drops only the oldest lines has no
cut to soften, so `error.1.log` goes and `fileURLs()` returns a single file. That also makes sharing
one attachment instead of two.

Trimming on every write would mean reading and rewriting a 10,000-line file continuously. The actor
tracks its own line count and trims down to 10,000 only on crossing 11,000, which is amortised and
still a hard ceiling on what can be shared.

**Success is logged, not only failure.** One line when a cache update completes, with counts and
duration, and one when a server connects. This is the change that makes an uneventful log useful: it
turns "nothing in the file" from ambiguous into evidence.

**Launch context is logged, and it is not a hostname.** App version and build, iOS version, device
model, locale, build configuration — the questions every support thread opens with. None of it names
a person or a server. Device model plus locale plus version narrows a population, which is noted
under Risks; it does not identify an archive, which is what the OIDC line did.

**Everything new is measured or read, never estimated.** Cache sizes come from the stores
themselves — Nuke's `DataCache` publishes `totalSize` and `totalCount` — or from enumerating a
directory. A logged number that is a guess is worse than no number, because a reader cannot tell.

## Changes

### `Logging`

**`LogCategory` gains `app`.** Launch, lifecycle and storage lines have no honest home among `api`,
`documents`, `server`, `share` and `storage`; without a new case they would be filed under `server`
and mislead exactly the reader they are for.

The split between the two categories this feature writes to is by subject, not by module: a line
about this app on this device is `app` — launch context, cache sizes, scene phase, memory warnings.
A line about the app's relationship with a paperless instance is `server` — connecting, the cache
update that follows it, OIDC discovery, certificate approval.

**`LogWriter` swaps size rotation for a line cap.** `maximumSize`, `rotatedURL` and
`rotateIfNeeded(adding:)` go. The actor gains a `lineCount`, seeded on first write by counting the
existing file, incremented per appended line, and a `trimIfNeeded()` that on `lineCount > 11_000`
rewrites the file with its last 10,000 lines and resets the count. `entries()`, `fileURLs()` and
`clear()` each narrow to the one file — `entries()` in particular stops concatenating two
generations, so its "newest first, current file then rotated" ordering note goes with it. The
initialiser takes `maximumLines: Int = 10_000` in place of `maximumSize`, so tests can drive the
boundary without writing eleven thousand lines.

**`DeviceContext` (new).** A `@DependencyClient` over `Bundle` and `UIDevice` returning the launch
facts, and a formatted line:

```
INFO  app  LessPaper 2.4.1 (312) · iOS 26.0 · iPhone17,2 · de_DE · release
```

The raw model identifier, not the marketing name: `UIDevice.model` answers "iPhone" for every iPhone
ever made, and a lookup table mapping `iPhone17,2` to "iPhone 16 Pro Max" is a table that goes stale
every September. Being a dependency client is what lets a test assert the line without the answer
depending on the simulator it runs in.

**`StorageUsage` (new).** Measures a directory by URL, returning total bytes and file count, using
`FileManager.enumerator` with `.fileSizeKey`. Given a URL and nothing else, so it knows nothing about
which caches exist.

### `ImageFeature`

**`ImageCacheUsage` (new).** A `@DependencyClient` exposing the Nuke disk cache's `totalSize` and
`totalCount`. It exists so `AppFeature` can report image cache usage without importing Nuke, and so
the number is stubbable in tests. `PipelineProvider` already builds `DataCache(name: "default")`;
this reads the same store.

### `AppFeature`

**`bootstrap` logs launch context.** Two lines, from an effect merged into the existing `.bootstrap`
handling — the device line above, and:

```
INFO  app  caches: images 42.1 MB / 318 files · app group 1.2 MB / 14 files · log 210 KB
```

Measuring runs off the main actor in a detached effect. It enumerates directories, and a launch must
not wait on it.

**Lifecycle transitions are logged.** `AppView` already observes `scenePhase` and sends
`.didBecomeActive` for `.active` only; it gains a `.scenePhaseChanged(ScenePhase)` send covering
background and inactive too, with the reducer logging the transition and `didBecomeActive` left
exactly as it is. A `UIApplication.didReceiveMemoryWarningNotification` observer logs memory
warnings. Both are cheap and both explain reports that otherwise have no evidence at all: a
termination in the background looks identical to a crash from the user's side.

**Module dependencies.** `AppFeature` gains `.target(.logging)` and `.target(.imageFeature)` in
`Module+Dependencies.swift`. Neither module depends on `AppFeature`, so no cycle.

### `ApiImplementation`

**`UpdateCacheUseCase` logs a connect line and a completion line.** It is the single point where the
app starts talking to a server — reached from adding a server and from selecting one, including at
cold launch — and it already holds every count and a `log`:

```
INFO  server  connected · API version 9 · auth: token · trusted certificate: yes
INFO  server  cache updated in 1.8s · 34 tags · 12 correspondents · 8 document types · 5 saved views · 3 storage paths · 6 custom fields
```

Auth mode is derived, not stored: `authenticationProvider.getToken(server:)` returning a token means
token auth, and returning `nil` means remote-user mode, where a forward-auth proxy authenticates and
no token exists. This does not distinguish a token obtained through OIDC from one obtained with a
password — nothing records that today, and adding it means changing the `Server` model, which is out
of scope here and noted below.

The existing failure paths are untouched. The `groups` and `users` warnings stay as they are.

**`OIDCSession.providers(url:)` stops logging.** The call is deleted, not rewritten. Logging from
inside the actor cannot tell discovery from the preflight that `login(provider:url:)` runs before
opening the browser, so every login would log twice.

### `ServersFeature`

**`ServerFormReducer` logs the discovery outcome.** The `.providersLoaded` case is where the outcome
arrives, where the preflight never reaches, and where the previous outcome is already in state — so
duplicate suppression costs one field rather than a second actor.

State gains `lastLoggedProviderCount: Int?`. On `.providersLoaded(providers)`, the line is written
only when `providers.count != lastLoggedProviderCount`, and the field is then set. The field is
distinct from `state.providers`, which is cleared to `[]` before every load: comparing against it
would suppress the first `none` — the one worth having — while still logging later ones.

Typing a URL through several settled prefixes therefore produces one `OIDC discovery: none`, and a
server that does offer providers produces one more line when the count changes.

### `CertificatesFeature`

**`ApproveCertificateUseCase` logs an approval**, hostname-free: `INFO server self-signed
certificate trusted`. The fact lives here, where the certificate is actually approved. Reading
`trustedCertificates` from `UpdateCacheUseCase` instead would mean making a key that is deliberately
internal to this module public, to answer a question this module can answer itself.

## Testing

Test-driven throughout, and the redaction tests are the ones that matter most — a redaction rule
without a test is a rule that silently stops working.

**`LogWriter`**, against a temporary directory, with a small `maximumLines`: that the file holds the
cap after crossing it, that the lines it keeps are the newest, that the oldest are gone, that a trim
leaves the file parseable by `entries()`, that no trim happens below the threshold, and that
`fileURLs()` returns one URL.

**`LogRedaction`** gains a test asserting that no host appears in a message built from a URL, and
`OIDCClient` tests assert the discovery path writes nothing at all.

**`DeviceContext`** formatting, against stubbed values, so the assertion does not depend on the
simulator.

**`StorageUsage`** against a temporary directory with known file sizes, including an empty
directory and one that does not exist — both must return zero rather than fail, because a cache that
has never been written is the normal state on first launch.

**`ServerFormReducer`**, with an overridden `LogClient` recording calls: one line for the first
`none`, none for a repeat, one more when the count changes. This is the duplicate-suppression rule,
and it is the part most likely to regress.

**`UpdateCacheUseCase`** for the connect and completion lines, including remote-user mode, where
`getToken` returns `nil` and the line must say `remote-user` rather than fail.

**`AppReducer`** for the launch lines and the scene-phase transitions, with `DeviceContext` and
`ImageCacheUsage` stubbed.

## Out of scope

- **Recording how a token was obtained.** It would make the connect line say `oidc` instead of
  `token`, and it means adding a field to `Server` and a migration for every stored server. Worth
  doing, not worth doing here.
- **Level and category filters on the Diagnostics screen.** More lines make a filter more useful,
  but the screen is for a user who has been asked to send a file, not to read one. If the added
  volume makes it hard to scan, that is the moment to add filtering, with evidence.
- **Writing the device block at share time.** Considered, because under the old 1 MB cap the launch
  line was the first thing to scroll away. At 10,000 lines it survives far longer, and one way of
  getting a fact into the file is better than two that can disagree.
- **A separate log for the share extension.** It runs in its own process against its own caches
  directory, so it already has one; unifying them means moving the log into the app group, which is
  a change with its own storage and privacy questions.
- **Log levels the user can change.** Unchanged from the original spec: a setting here means reports
  arrive from people who had it turned off.

## Risks

**Launch context is a weak fingerprint.** Device model, iOS version, locale and app version together
narrow a population, and the log is shared with a stranger. Accepted: none of it identifies a server
or a person, all of it is what a support thread asks for first, and the file remains human-readable
and shared deliberately rather than transmitted by the app.

**Success lines add volume, and volume evicts history.** Every launch and every server connection
now writes several lines that previously wrote none. At 10,000 lines this is not close to binding,
but it is the number to revisit if a future change starts logging per document rather than per
session.

**Trimming rewrites the file.** A crash mid-rewrite could truncate the log. Accepted: the writer is
an actor, so no concurrent write interleaves, and the cost of losing diagnostics is bounded by what
diagnostics are for. It is the same trade the caches directory already makes — the system may
reclaim the whole file at any time.

**Deleting the OIDC error text loses a genuine signal in one case:** a reachable server that answers
the config endpoint with something unparseable. That is a paperless or proxy misconfiguration, and
`OIDC discovery: none` does not distinguish it from an unreachable host. The API request line for
that endpoint still records method, path and status, which is where a reader should be looking
anyway.
