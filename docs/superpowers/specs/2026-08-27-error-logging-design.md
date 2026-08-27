# Error logging

A local log the user can read and send on demand. No third-party dependency, no data leaving the
device unless someone chooses to share it.

## Context

The rewrite has no logging at all. Errors reach the UI through 26 `case error(Error)` actions across
the feature modules, get shown as a toast or an empty state, and are then gone. When someone reports
"it stopped loading my documents", there is nothing to ask them for.

The old app had one. `AppLogger` was an `XCGLogger` subclass with two destinations: Apple System Log
at debug level, and a file `error.log` in the caches directory at warning and above. Features logged
through two protocols, `PaperlessAPI.ErrorLogger` and `StorageKit.ErrorLogger`, each offering
`log(_ error:)` and `trace(_ string:)`. Settings had a Debug screen listing the log files; tapping
one showed its lines monospaced with alternating row backgrounds, and a toolbar menu offered
`ShareLink` and a clear action.

That shape was right. What it cost was a dependency — XCGLogger — for something the platform can now
mostly do.

## Decisions

**The shareable artefact is a file we write, not the unified log.** This is the decision everything
else follows from, and it is not about verbosity.

`OSLogStore.local()` is unavailable on iOS — the compiler rejects it outright:

```
error: 'local()' is unavailable in iOS
```

The only scope an app can open is `.currentProcessIdentifier`, which reads the current process and
nothing else. A relaunch therefore leaves an empty log, and a relaunch is exactly what someone does
after the app misbehaves. `os_log` still gets every line, because it costs nothing and makes Xcode
and Console useful during development. But what the user shares is a file this app owns.

**Errors, warnings, and one line per API call.** Method, path, status, duration. No request or
response bodies, no headers. Most failures here are paperless-ngx API drift or a specific endpoint
returning 4xx/5xx, and a bare error line rarely says which call produced it. Bodies would carry
document titles, correspondents and notes — the user's actual paperwork — into a file they are being
asked to email to a stranger.

**Never written, at any level:** `Authorization` headers, session cookies, passwords, PDF passwords,
client-certificate material, API tokens. The server's host is written, because knowing whether a
call went to the right place is half of diagnosing it.

**A `@DependencyClient`, like every other client in this repository.** Features already depend on
`getStatistics`, `updateCache` and the rest this way; logging arrives through the same door and is
overridable in tests, so "does this failure get logged" becomes an assertion rather than a hope.

**Capped at 1 MB with a single rotation.** Two files at most: `error.log` and `error.1.log`. An
install that runs for a year cannot quietly fill the caches directory, and a user who hits a bug
today still has yesterday's context.

## Architecture

```
LoggingInterface   LogClient (@DependencyClient) — what features call
LoggingImplementation  LogWriter (actor)  — formats, appends, rotates, reads back
ApiImplementation  ApiClientDelegate — one line per request, no bodies
DiagnosticsFeature Settings → Diagnostics — read, share, clear
```

### `LoggingInterface`

One dependency client, mirroring the shape the old `ErrorLogger` protocols had:

```swift
@DependencyClient
public struct LogClient: Sendable {
    public var error: @Sendable (_ message: String, _ category: LogCategory) -> Void
    public var warning: @Sendable (_ message: String, _ category: LogCategory) -> Void
    public var info: @Sendable (_ message: String, _ category: LogCategory) -> Void
    public var entries: @Sendable () async -> [LogEntry] = { [] }
    public var clear: @Sendable () async -> Void
    public var fileURLs: @Sendable () async -> [URL] = { [] }
}
```

`LogCategory` is an enum, not a string: `api`, `documents`, `server`, `share`, `storage`. It becomes
the `os_log` category and the column in the file, and being an enum means a typo cannot invent a new
category that only appears in one user's log.

Recording is fire-and-forget and non-throwing. A logger that can fail, or that a caller must `await`,
is a logger people stop calling from the paths that matter most.

### `LoggingImplementation`

A `LogWriter` actor owns the file handle. Serialising through an actor is what makes concurrent
writes safe without a lock, and the actor is also where rotation happens, so no caller has to know
the file has a size limit.

Format is one line per entry, fixed width, sortable, and readable without tooling:

```
2026-08-27 12:04:31.212  ERROR  api         getDocuments failed: 500
2026-08-27 12:04:31.198  INFO   api         GET /api/documents/?page=2 → 500 (1.21s)
```

Every line also goes to `Logger(subsystem:category:)` at the matching level.

Rotation: before appending, if the file exceeds 1 MB, `error.log` is moved to `error.1.log`,
replacing any previous one, and a fresh `error.log` is started. Checked on write rather than on a
timer, because a timer is a second thing that can be wrong.

Location: the caches directory, as the old app used. The system may reclaim it under storage
pressure, which is the correct trade for diagnostic data — it must never be the reason a user cannot
save a document.

### `ApiImplementation`

`ApiClientDelegate` already implements `client(_:willSendRequest:)` and
`client(_:validateResponse:data:task:)`. Those are the two hooks: note the start time on the way
out, write one line on the way back with method, path, status and elapsed time. Query strings are
kept — `?page=2` is often the whole story — but only after stripping any value that looks like a
credential.

One place produces every API line. The alternative was 26 call sites each remembering to log, which
is how logging rots.

### `DiagnosticsFeature`

Its own module, reached from Settings, matching `LicensesFeature` and `CertificatesFeature`. A TCA
reducer and two views: a list of entries, and the actions.

- **Read** — entries newest first, monospaced, level colour-coded. Alternating row backgrounds, as
  the old `LogFileView` had, because unbroken monospace is hard to scan.
- **Share** — `ShareLink` over the log files. The user sees the file in the share sheet and can read
  it first; nothing is transmitted by the app itself.
- **Clear** — behind a confirmation, using `ConfirmationPopupView` per this repository's convention.
- **Empty** — `EmptyListView`, saying that nothing has gone wrong yet rather than showing a blank
  screen.

Settings gains one row. It is not hidden behind a debug build or a gesture: the point is that a user
can find it when asked to.

## Testing

The client being a dependency is what makes this testable without touching a filesystem. Feature
tests assert that a failing use case produces a log entry, by overriding `LogClient` and recording
calls — the same pattern every other client in the repository uses.

`LogWriter` gets its own tests against a temporary directory: that a line round-trips, that rotation
happens at the threshold and not before, that the rotated file survives, that clearing removes both.

Redaction gets tests of its own, and they are the ones that matter most: a request carrying an
`Authorization` header, a URL with a token in the query, a PDF password — each asserted absent from
what is written. A redaction rule with no test is a rule that silently stops working.

`DiagnosticsFeature` gets snapshot references like every other view: populated, empty, and with a
long line that has to wrap.

## Out of scope

- **Crash reporting.** A crash is not an error the app gets to write down. Catching it means either a
  third-party SDK or shipping a signal handler, and both are their own decision.
- **Automatic upload.** Sharing stays user-initiated. That is what keeps the privacy policy's "the
  app collects no data about you" true.
- **A live console view.** `OSLogStore` could back one for the current session, but two readers that
  can disagree is worse than one that always tells the truth.
- **Log levels the user can change.** One level, always on. A setting here means bug reports arrive
  from people who had it turned off.

## Risks

**A log the user reads may still contain something they consider private** — document titles do not
appear, but a URL path can carry an ASN, and a server hostname can identify a person. Mitigated by
the file being human-readable and shared deliberately rather than sent automatically. Stated here so
it is a choice.

**Redaction is a denylist, and denylists miss things.** The mitigation is that bodies are never
written at all, so the surface is limited to headers and URLs, both of which are enumerable.

**Caches can be reclaimed by the system**, so a log may be shorter than the user expects. Accepted:
the alternative is competing with their documents for space.
