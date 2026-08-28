# Forward auth through a reverse proxy

Sign in to a paperless-ngx server that sits behind an authenticating reverse proxy — Authelia,
Authentik's proxy provider, or anything else speaking the same forward-auth shape — and recover
without an error when that session expires.

## Context

A forward-auth proxy gates *every* request. Caddy's `forward_auth`, nginx's `auth_request` and
Traefik's `forwardauth` middleware all work the same way: the proxy asks an identity provider about
each incoming request, and unless the request carries a valid session cookie, the answer is "send
them to the portal" rather than the resource.

The app has no idea this is happening. `ApiClientDelegate` sends `Authorization: Token <value>`,
`URLSession` follows whatever redirect comes back, and the app ends up trying to decode Authelia's
login page as JSON. The one workaround today is the custom HTTP headers feature — a long-lived
header the proxy accepts — which works, requires the administrator to punch a hole for it, and is
not what anyone means by "supports Authelia".

**A bounce arrives in two shapes, and both have to be handled.** This is the thing the previous
attempts each got half of:

- **Non-2xx carrying a `Location`.** Authelia's `ForwardAuth` endpoint answers `401` with a
  `Location` header, and Caddy's `forward_auth` copies status and headers straight through. `401`
  is not a redirect status, so `URLSession` never treats this as a redirect and no redirect hook
  fires.
- **A genuine `3xx` to a foreign host.** Other proxies answer with a real `302`. `URLSession`
  follows it silently, the login page comes back `200`, and the failure surfaces as a decode error
  pointing at the wrong thing entirely.

**Two deployment modes sit behind the proxy**, and they differ in whether a paperless login is still
needed at all:

- **Gate only.** The proxy authenticates the human; paperless still does its own authentication. The
  app needs the SSO cookie *and* its API token, exactly as it uses one today.
- **Remote user.** `PAPERLESS_ENABLE_HTTP_REMOTE_USER_API` is set, the proxy injects a trusted
  `Remote-User` header, and paperless takes it as the identity. There is no token to fetch and no
  password to store: the cookie is the whole login.

Both are real deployments. The app cannot ask which one it is, so it finds out.

## Decisions

**The bounced request is parked and replayed, not failed.** When a request is bounced,
`ApiClientDelegate` throws `ForwardAuthError.required`, and `client(_:shouldRetry:)` awaits the
completion of the login before returning `true` — so Get replays the original request with the
cookie in place. The user sees a spinner, a login, then their documents.

The alternative — fail the request, sign in, then reload everything — is less machinery and is what
both earlier attempts did. It is rejected because of *when* this fires. Authelia sessions expire on
a timer measured in hours, so the common case is not first-time setup but a session dying while
someone is halfway down a document list. Parking the request makes that a pause. Failing it makes
it an error toast, a broken screen, and a manual refresh, every few hours, forever.

**One reactive path, for setup and for expiry both.** There is no "sign in with a reverse proxy"
button in the server form. Any bounced request raises the same event, and the same popup and web
view answer it, whether the server is being added or has been in use for a month. A proxy is not a
sign-in method the user chooses; it is a fact about the network that the app discovers. Discovering
it in one place means one code path to build, test and reason about.

**Concurrent bounces produce one login.** Every bounced request parks on `ForwardAuthCoordinator`,
which holds one continuation per waiting request keyed by server; the first to park raises the
login and the rest join it. One resolution releases them all. Ten parallel calls at launch is the
ordinary case, not the edge case. A cancelled login resolves them too, with "do not replay" — it
fails the parked requests rather than hanging them.

**Not a channel, for the rendezvous.** `AsyncChannel` hands each element to exactly one consumer,
which is right for `certificateApprovalChannel` — each request carries its own completion and is
addressed to one presenter — and wrong here, where one login has to answer many waiting requests.
Built on a channel, this released one request per login and left the rest waiting forever, and a
parked request could swallow the redirect the reducer was meant to see.

**Holding the coordinator's redirect stream is what registers a presenter.** A process with no
presenter — the share extension, which deliberately has none — fails a bounced request immediately
instead of parking it against a login that can never appear. This is what makes the dead-end
message below reachable rather than an endless spinner.

**One replay per bounce.** `shouldRetry` gives up after the first. A cookie the proxy never accepts
— a session scoped to a domain that does not cover paperless, the misconfiguration the dev-stack
notes warn about — would otherwise loop through bounce, login and replay for as long as the app is
open.

**The mode is settled by one probe, once, after the cookie lands.** `GET /api/ui_settings/` with no
`Authorization` header. A `200` means the proxy is injecting a trusted identity and the server is
stored with no token. A `401` means the proxy is only a gate, and the existing password or OIDC
login runs as it does today. One request at setup, not a check on every call.

**`Credentials.token` becomes optional.** Remote-user mode has no token, and a type that can say so
beats storing an empty string and hoping nothing reads it — which is the reasoning already written
above `password` in that same file, for the same situation. `ApiClientDelegate` omits the
`Authorization` header when there is no token rather than sending `Token ` with nothing after it.

**Remote-user mode costs one more request to learn the username.** `UISettings.User` carries only an
`id`, so the probe proves who is authenticated without naming them. `GET /api/users/{id}/` follows,
at setup only. An unnamed server in the switcher is worse than one extra request.

**A `WKWebView`, not `ASWebAuthenticationSession`.** The OIDC login uses the latter and should keep
using it: it wants a callback URL, and it deliberately gets an ephemeral browser session. Forward
auth wants the opposite — the *cookie* is the entire point, and `ASWebAuthenticationSession` will
not hand one over. This is why the two flows do not share a mechanism despite looking alike.

**The web view honours `@Shared(.trustedCertificates)`.** Both earlier attempts returned
`.useCredential` for any server trust the login host presented, one of them with a `FIXME` admitting
it. A self-signed proxy is exactly the deployment this feature targets, so the login host routes
through `certificateApprovalChannel` like everything else. Trusting every certificate at the one
moment credentials are being typed is the hole the approval flow exists to close.

**Thumbnails refuse the redirect but do not raise a login.** `ImageLoader` shares the session
delegate, so a bounced thumbnail stops at the redirect instead of caching a login page as an image.
It does not raise a login: only a request that parks in `client(_:shouldRetry:)` does, and
thumbnails go through Nuke's `DataLoader` rather than Get, so they never reach it. A failed
thumbnail recovers on the next render once the session is back, and a scrolling list does not raise
a login popup per visible row.

**The share extension shares the cookie and never presents a login.** App-group cookie storage means
the extension is authenticated whenever the app's session is live, which is the normal case. When it
is not, the extension says so and stops. An SSO login with a second factor inside a
memory-constrained extension is a bad place to be, and the app is one tap away.

## Architecture

```
ApiInterface        ForwardAuthRedirect, ForwardAuthError, ForwardAuthCoordinator,
                    ApiSessionDelegate                              — the vocabulary and the hook
ApiImplementation   the bounce rule, the retry await, cookie storage,
                    GetForwardAuthIdentityUseCase                   — the mechanism
ForwardAuthFeature  the popup, the web view, the cookie handoff     — what the user sees
ShareFeature        one error case                                  — the dead end, made legible
```

### `ApiInterface`

`ForwardAuthRedirect` (`server`, `url`), and `ForwardAuthCoordinator`, an actor holding the
continuations of every parked request keyed by server. `redirects()` hands the reducer an
`AsyncStream` of logins to present and registers it as the presenter; `awaitSignIn(for:)` parks a
request; `resolve(_:signedIn:)` releases every request parked against that server at once.

`ForwardAuthError.required(URL)`, whose `errorDescription` names the host the user is being sent to.

`ApiSessionDelegate` replaces `CertificateDelegate`. It keeps that type's certificate challenge
handling unchanged and adds `urlSession(_:task:willPerformHTTPRedirection:)`, which calls
`completionHandler(nil)` for any redirect whose host differs from the server's, completing the task
with the `3xx` itself. `movedToOrigin(of:)` continues to handle paperless's absolute-URL problem and
is not touched.

**The comparison is on host alone, not on the origin.** A server configured as `http://` that
redirects to `https://` on the same host is paperless doing something legitimate, and refusing it
would break every such setup to catch a bounce that never goes there — a proxy sends the user to its
portal, which lives at a different name. Same host, different scheme or port: followed. The rename is because a type called
`CertificateDelegate` that also decides redirect policy is a type named after one of its two jobs —
there are two call sites (`APIClient+Extensions`, `ImageLoader`).

### `ApiImplementation`

`ApiClientDelegate.validateResponse` gains one rule ahead of the existing status-code branches: a
non-2xx carrying a `Location` to a host that is not the server's is a forward-auth bounce. It sends
`.redirect` and throws `ForwardAuthError.required`. This single rule covers both bounce shapes,
because refusing the `3xx` in the session delegate turns the second shape into the first.

`client(_:shouldRetry:)` catches `ForwardAuthError.required` and parks on the coordinator, which
answers `true` once the login landed a cookie and `false` when it was dismissed, when no presenter
exists, or after the first replay.

`APIClient+Extensions` sets `sessionConfiguration.httpCookieStorage` to the app-group store. The
group `group.com.plunien.app.Paperless` is already entitled for `.app`, `.shareApp` and
`.shareExtension`.

`GetForwardAuthIdentityUseCase` is the probe: `Server` in, an optional username out. `nil` means the
proxy is a gate and the ordinary login is still required.

### `ForwardAuthFeature`

A new module, scoped into `AppReducer` beside `CertificateApprovalReducer` and bootstrapped the same
way. On `.redirect` it presents a `ConfirmationPopupView` naming the host — never a system dialog —
and on confirm, a full-screen sheet holding the web view, titled with the host, with a close button.
Not a fixed frame: a login with a second factor does not fit a box sized in advance.

The web view seeds itself from app-group cookie storage on open, so a live session does not force a
pointless re-login, and copies cookies back when a response arrives from the server's host. Its
certificate challenges go through `certificateApprovalChannel`.

### `ShareFeature`

`ShareFormError.forwardAuthRequired`, mapped from `ForwardAuthError.required`, saying the session
has expired and to sign in again in Less Paper.

## Testing

The bounce rule is a pure function of a response and a server, and that is where the tests go:

- a `401` with a `Location` to a foreign host is a bounce
- a `302` to a foreign host, after the delegate refuses it, is a bounce
- a `401` with no `Location` is an ordinary unauthorized, not a bounce — a wrong token must not open
  a browser
- a `302` to the *same* host is followed, not intercepted, including an `http` → `https` upgrade —
  paperless's own redirects still work
- a `403` from paperless's permission system is not a bounce

Tests cover the rendezvous where it lives, in `ApiClientDelegateTests`: ten concurrent bounces
released by one login (the case a channel got wrong), a dismissed login answering "do not replay"
rather than hanging, a login for another server not releasing this one's requests, a process with
no presenter failing fast, and the replay cap. Reducer tests cover the popup preceding the browser,
and a declined popup dropping the waiters. Snapshot references for the popup and the sheet.

`GetForwardAuthIdentityUseCase` gets `URLProtocol` stubs for the `200` and `401` answers and for the
follow-up user fetch.

**Closing the gap.** Stubs prove each piece; they cannot prove the sequence works against a real
proxy. `docker/docker-compose.authelia.yml` stands Authelia and Caddy up beside the development
paperless, in its own project on its own ports, as `docker-compose.oidc.yml` already does for
Authentik. `docs/forward-auth-development.md` documents it.

The thing that has to be right there is the **cookie domain**. Authelia's session cookie must cover
both the portal and paperless, so both need hostnames under one registrable domain — `auth.…` and
`paperless.…` behind Caddy with `tls internal`. The simulator must resolve both names and trust the
internal CA. Getting this wrong produces a login loop that looks like a bug in the app.

## Out of scope

- **Signing in from the share extension.** It shares the cookie and reports a clear error; it does
  not present a login.
- **A UI test journey.** It would need the whole proxy stack running in CI.
- **Basic-auth proxies.** A different mechanism — a challenge, not a redirect — and a different
  design.
- **Signing out of the proxy.** Its own change — and note there is no lever at all today: nothing
  in the app clears cookies or website data, so the only way to force a fresh bounce is to wait the
  session out or delete the app. That makes a sign-out worth more than this list implies.
- **Remembering that a server sits behind a proxy.** The reactive path costs one bounced request to
  rediscover it, and per-server state that can go stale is worse than that request.

## Risks

**The proxy's bounce does not match either shape.** The two shapes come from reading Authelia's and
Caddy's behaviour, not from a specification — nothing obliges a proxy to send a `Location` at all. A
proxy that answers `401` with a login page and no `Location` is indistinguishable from an expired
token, and this design will not detect it. The dev stack proves Authelia; Authentik's proxy provider
should be run by hand before this is called done.

**Cookies are a shared, mutable, ambient dependency.** App-group cookie storage is visible to the
app, both share targets, and every server the user has configured. A proxy setting a cookie for a
broad domain reaches requests to other servers under that domain. This is how cookies work
everywhere, but it is new to this app, whose credentials have until now been per-server keychain
entries with no ambient state at all.

**The web view is a second HTTP stack with its own trust decisions.** Routing its challenges through
`certificateApprovalChannel` keeps one policy, but `WKWebView` reaches the network by paths
`URLSession` does not — subresources, redirects to third parties, an identity provider's own assets.
The certificate approval popup can appear for hosts the user has never heard of.

**`Credentials.token` becoming optional touches every read.** The compiler finds them, but a
`try?`-shaped read that silently degrades instead of failing would turn a missing token into
unauthenticated requests. Each site gets looked at rather than unwrapped.
