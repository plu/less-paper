# Login with an OIDC provider

Sign in to a paperless-ngx server through its configured single sign-on provider, instead of a
username and password.

## Context

`ServerForm` collects an alias, a URL, a username and a password. `authenticationRepository.getToken`
trades those for a paperless API token, the token goes into the keychain as `Credentials`, and
`ApiClientDelegate` sends it as `Authorization: Token <value>` on every request.

paperless-ngx supports social login through **django-allauth's headless API**, mounted at
`api/auth/headless`. The steps below were established by probing the development instance directly —
each endpoint, its status codes and its response shape — against allauth's headless documentation and
the OpenID Connect and PKCE specifications (RFC 6749, RFC 7636).

**The flow ends with an ordinary paperless API token.** That is the decision this whole design rests
on: OIDC is a different way to *obtain* the same credential the app already uses, not a new
authentication scheme. Nothing downstream changes — not the keychain, not `AuthenticationProvider`,
not the delegate, not a single feature module.

Verified against the development instance before designing:

```json
"socialaccount": {"providers": []},
"mfa": {"supported_types": ["recovery_codes", "totp"]}
```

The endpoint answers, MFA is real, and no provider is configured — which the design has to handle as
the ordinary case, not an error.

## The flow

Seven steps, only one of which the user sees:

1. `GET {server}/api/auth/headless/app/v1/config` — the providers, each with an `id`, a `name`, a
   `client_id` and an `openid_configuration_url`. This also validates the provider the user picked.
2. `GET {openid_configuration_url}` — the provider's discovery document, for its authorization and
   token endpoints.
3. Build the authorization URL with `scope=openid profile email`, a PKCE challenge and a random
   `state`.
4. `ASWebAuthenticationSession` — the only step the user sees. Returns a callback URL.
5. Verify `state` matches, take the `code`.
6. `POST {token_endpoint}` with `client_id` and the PKCE verifier, and no secret — the provider's
   `id_token`.
7. `POST {server}/api/auth/headless/…/provider/token` with the `id_token` — the paperless API token,
   **or** a `session_token` meaning a second factor is required.

If step 7 asks for a second factor, `POST …/auth/2fa/authenticate` with an `x-session-token` header
and the user's six-digit code returns the API token.

## Decisions

**The server is asked what it supports.** After the URL is entered, the form fetches the headless
config. Providers become "Sign in with …" buttons above the username and password fields; no
providers, and the form looks exactly as it does today. The user should not have to know whether
their server does SSO — the server knows.

The cost is one request when the URL field is committed. It must fail silently: a server that is not
paperless, is unreachable, or predates the headless API is an ordinary case, and the password form
must still work.

**MFA is included.** paperless can interrupt the login for a TOTP code, and the development instance
advertises `totp` support. Stopping at "cannot complete this" would turn a supported server into a
dead end.

**PKCE is written here, not imported.** RFC 7636 is a random verifier and its SHA256 challenge —
about fifty lines of CryptoKit. A dependency for that would be a poor trade, and this repository has
none it does not need.

**The scope is `openid profile email`, not fetched from the server.**

The scope a server wants can in principle be discovered: allauth's *browser* endpoint
`browser/v1/auth/provider/redirect` answers with a `Location` header holding the authorization URL
the server would itself have built, `scope` parameter included. Reading it means not following that
redirect, and it costs more than it returns — the browser endpoints are session-authenticated and
Django-CSRF-protected, so obtaining the value drags in a CSRF token from `/accounts/login`, a cookie
jar, a `URLSession` configured for cookies and a `Referer` header. Four moving parts for one string.

Measured against the development instance: that endpoint answers `403` without the token and `401`
with it.

`app/v1/config` does not publish the scope, so there is no cheaper way to read it. We send allauth's
own default instead, and keep the one useful side effect that discovery had — rejecting an unknown
provider before the browser opens — by validating the chosen provider against `config`, which is
fetched anyway.

`openid` is not optional: without it the provider runs a plain OAuth2 flow and returns no `id_token`,
and step 7 exists to trade exactly that.

> **The limitation this accepts**, stated because it fails quietly rather than loudly: an
> administrator can set `SCOPE` in `PAPERLESS_SOCIALACCOUNT_PROVIDERS`. If they have added one — say
> `groups`, to drive permissions — we will request less than paperless expects, and the `id_token`
> will arrive without that claim. The user is logged in, but mapped on less information than the
> server intended. If that turns up in practice, the redirect call is the fix, and it brings its CSRF
> machinery back with it.

**The callback scheme is `atlp`, which the app already registers.** `Info.plist` declares it under
`CFBundleURLTypes` today, so the redirect URI is `atlp://oidc-callback` and nothing new is claimed.
Inventing a second scheme would have meant a plist change and two identities for one app.

> **This has a deployment consequence.** The redirect URI must be registered in the identity
> provider by whoever administers it — Authelia, Keycloak, Authentik. A login will fail at step 6
> with the provider's own error until they add it. It goes in the README, and the error message says
> so rather than reporting a generic failure.

**No password is stored for an OIDC server.** `Credentials` carries `password` and `token`. Rather
than storing an empty string and hoping nothing reads it, `Credentials.password` becomes optional.
That is a small change with one honest reason: for these servers there is no password, and a type
that can say so is better than a placeholder that cannot.

## Architecture

```
ApiInterface        OIDCProvider, OIDCLoginResult, OIDCError   — the vocabulary
ApiImplementation   OIDCClient (the nine steps), PKCE          — the mechanism
ServersFeature      provider buttons, the TOTP sheet           — what the user sees
```

### `ApiInterface`

`OIDCProvider` (`id`, `name`, `clientId`, `openidConfigurationUrl`), and an `OIDCError` whose cases
are the things that actually go wrong — `noProvidersConfigured`, `redirectURINotRegistered`,
`stateMismatch`, `secondFactorRequired`, `cancelled`. Each maps to a sentence a user can act on;
`redirectURINotRegistered` names `atlp://oidc-callback` so the administrator is told exactly what to
register.

A `@DependencyClient` in the established shape:

```swift
@DependencyClient
public struct OIDCClient: Sendable {
    public var providers: @Sendable (_ url: URL) async throws -> [OIDCProvider]
    public var login: @Sendable (_ provider: OIDCProvider, _ url: URL) async throws -> OIDCLoginResult
    public var confirmSecondFactor: @Sendable (_ code: String) async throws -> String
}
```

`login` returns `.token(String)` or `.secondFactorRequired`, so the reducer branches on a value
rather than catching an error for a case that is not a failure.

### `ApiImplementation`

The live client: an actor holding the pending session token between the login and the TOTP
confirmation — the only state the flow carries. No cookie jar and no shared `URLSession`, because
dropping the scope lookup dropped the only request that needed them. Each step is its own private
method, because each is separately wrong-able and separately testable.

`ASWebAuthenticationSession` arrives through its own tiny dependency so the reducer can be tested
without a browser:

```swift
@DependencyClient
struct WebAuthentication: Sendable {
    var authenticate: @Sendable (_ url: URL, _ callbackScheme: String) async throws -> URL
}
```

### `ServersFeature`

`ServerFormReducer` gains: providers fetched when the URL commits, a `signInWithProvider` action, and
a presented TOTP sheet. The existing username and password path is untouched — it is the fallback
when a server has no providers, and the only path when the browser flow is cancelled.

## Testing

The client is seven steps, six of them testable without a browser and without a server:
`URLProtocol` stubs for each response shape, asserting the request that goes out and the value that
comes back. The ninth is the `WebAuthentication` dependency, stubbed to return a callback URL.

The tests worth writing first are the ones about being lied to:

- a callback whose `state` does not match is rejected — the check that makes PKCE worth having
- a callback with no `code`
- `provider/token` answering `mfa_required` produces `.secondFactorRequired`, not a thrown error
- a config with no providers produces an empty list, not a failure
- a provider id that is not in `config` is rejected before the browser opens, not after
- a server that is not paperless, or is unreachable, leaves the password form working

Reducer tests cover the branches; `ServerFormView` gets snapshot references with providers, without
providers, and with the TOTP sheet presented.

**Closing the gap.** Stubs prove each step in isolation; they cannot prove the sequence works against
a real identity provider. `docker/docker-compose.oidc.yml` and `docs/oidc-development.md` stand
Authentik up beside the development paperless so the whole flow can be run by hand, including the
second factor - the one part that stubs model rather than prove.

The provider has to be a **public client**: the app exchanges its code with `client_id` and a PKCE
verifier and no secret, which is correct for a native app and which a confidential client rejects.

## Out of scope

- **Re-authentication when a token stops working.** The API token allauth returns behaves like any
  other; if that turns out to be false in practice, expiry handling is its own change.
- **Passkeys.** The config advertises `passkey_login_enabled`. A different flow, a different design.
- **Login by code and email verification.** Also in the headless config, also not this.
- **Signing up.** `is_open_for_signup` exists; creating accounts from the app does not.

## Risks

**The redirect URI is registered by someone else.** The single most likely failure is an
administrator who has not added `atlp://oidc-callback`. Mitigated by naming the URI in the
error rather than reporting that authentication failed.

**allauth's headless API is versioned in its path** — `app/v1`, `browser/v1`. A future paperless
could move it. The provider fetch failing softly means such a server degrades to the password form
rather than breaking.

**The flow leaves the app.** A user who cancels in the browser, backgrounds the app, or loses the
network mid-flow must land back on a working form with an explanation, not a spinner. The cancelled
case is a test, not an afterthought.
