# Negotiate the Paperless API version

## Context

Every new server starts with a hardcoded `Accept: application/json; version=10` header, pre-filled
by `ServerFormInput.empty` (`Modules/ServersFeature/ServerForm/ServerFormInput.swift:54`) and
independently set as the default in `ApiClientDelegate.willSendRequest`
(`Modules/ApiImplementation/ApiClientDelegate.swift:24`).

Paperless versions its REST API through `AcceptHeaderVersioning`, and current paperless-ngx allows
only `["9", "10"]` with a default of `10`. Older servers had lower ceilings. Requesting a version a
server does not allow is not a soft failure — DRF answers **406 Not Acceptable on every request**,
so adding a paperless 2.x server today fails completely rather than degrading.

Paperless documents the handshake (`docs/api.md`, "API Versioning"):

> If a client wishes to verify whether it is compatible with any given server, the following
> procedure should be performed:
>
> 1. Perform an _authenticated_ request against any API endpoint. The server will add two custom
>    headers to the response:
>
>    ```
>    X-Api-Version: 10
>    X-Version: <server-version>
>    ```

The "authenticated" qualifier is load-bearing. `ApiVersionMiddleware` sets both headers only inside
`if request.user.is_authenticated`, so `/api/token/` — the first request this app ever makes to a
server — does not carry them.

### The app's real floor is 9, not 10

The API changelog lists one change for version 9:

> The document `created` field is now a date, not a datetime. The `created_date` field is considered
> deprecated and will be removed in a future version.

`Document.created` (`Modules/ApiInterface/Documents/Document.swift:18`) and `Document.createdDate`
(`:20`) are both non-optional `Date`. `created_date` still ships in v10, so both v9 and v10 decode.
Version 8 and below would hand back a datetime for `created`, so 9 is the oldest version this app
can serve without further work.

### What actually differs between 9 and 10

Version 10 makes several changes, but only one of them reaches this app:

- **Saved view visibility.** `show_on_dashboard` and `show_in_sidebar` were removed from saved views
  and moved into the UISettings model. *This is the change that matters.*
- Document-editing operations (`merge`, `rotate`, `edit_pdf`) moved off the bulk edit endpoint —
  still supported there for compatibility, and this app only calls `/api/documents/bulk_edit/`
  (`Modules/ApiImplementation/Documents/DocumentsRepository.swift:123`).
- `all` on list endpoints, and the `title_content` search parameter
  (`Modules/ApiInterface/Shared/FilterRuleType.swift:149`), are deprecated but functional.
- The task system was redesigned. This app has no tasks feature.

So a v9 branch is needed in exactly two places.

### Negotiation alone is not enough

`GetSavedViewsUseCase.swift:46` and `SetSavedViewVisibilityUseCase.swift:35` read and write saved
view visibility through UISettings exclusively — the v10 shape. `SavedView.swift:60` still decodes
`showInSidebar`/`showOnDashboard` with `decodeIfPresent ?? false`, so a v9 payload decodes without
error but the values are then overwritten by the UISettings overlay.

That means pinning v9 and stopping there would turn a loud failure into a quiet one: requests would
succeed, but the visibility toggles would write to UISettings, where a v9 server ignores them. The
toggle would appear to work and not work. Negotiation and the v9 read/write path ship together.

## Design

### `ApiVersion` and its storage

New `Modules/ApiInterface/Shared/ApiVersion.swift`:

```swift
public enum ApiVersion {
    public static let minimumSupported = 9
    public static let clientMaximum = 10
}
```

The negotiated value is discovered runtime state, not user configuration, so it stays off `Server`
and lives in a per-server cache alongside the existing ones in
`Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`:

```swift
public extension SharedReaderKey where Self == FileStorageKey<Int>.Default {

    static func apiVersion(_ server: Server) -> Self {
        Self[
            .fileStorage(
                .applicationGroupDirectory.appending(component: "\(server.id)-api-version.json"),
                decoder: .apiDecoder,
                encoder: .apiEncoder
            ),
            default: ApiVersion.minimumSupported
        ]
    }
}
```

**The default of 9 is deliberate.** It is the floor this app supports and is therefore accepted by
every server this app supports, so a server that has not yet been probed can never 406 on its first
request. A default of 10 would reintroduce the current bug for the window before the probe lands.

Keeping it off `Server` also avoids a backward-compatible decoding pass over the already-shipped
`servers.json`, which `Server` deliberately does not have (see
`docs/plans/2026-08-08-server-form-custom-http-headers.md`).

### Setting the value

Two mechanisms, one active and one passive.

**Active probe.** A `NegotiateApiVersionUseCase` (interface in `Modules/ApiInterface/`, live value in
`Modules/ApiImplementation/`) performs one authenticated `GET /api/ui_settings/` — an endpoint the
app already calls and that definitely authenticates — and reads `X-Api-Version` off the response.
`Get`'s `Response<T>` exposes `response: URLResponse`, so the header is reachable by casting to
`HTTPURLResponse`.

Outcomes:

| `X-Api-Version` | Result |
| --- | --- |
| absent | throw `unsupportedServer(nil)` |
| `< 9` | throw `unsupportedServer(value)` |
| `>= 9` | store `min(value, ApiVersion.clientMaximum)` |

It runs in `ServerFormReducer+Effect.swift` between `storeToken` and `updateCache`, so the version is
settled before the nine parallel cache requests go out and the first sync already uses the right
shape. A throw propagates into the existing `catch:` and reaches the user through `.toast(error)`;
the server is not saved.

**Passive refresh.** `ApiClientDelegate.client(_:validateResponse:data:task:)` sees every response.
It reads `X-Api-Version` and updates the cache when the value differs, so a paperless upgrade is
picked up on the next request with no re-probe. The method is synchronous and `@Shared`'s
`withLock` is synchronous, so this needs no restructuring.

### Sending the header

`willSendRequest` reads the cache instead of hardcoding:

```swift
@Shared(.apiVersion(server))
var apiVersion: Int

request.setValue("application/json; version=\(apiVersion)", forHTTPHeaderField: "Accept")

for header in server.headers {
    request.setValue(header.value, forHTTPHeaderField: header.name)
}
```

The `server.headers` loop still runs afterward, so a hand-typed `Accept` header continues to
override negotiation entirely. That remains the documented escape hatch for odd proxies or
deliberate pinning, and it is why the pre-fill can be removed without removing the capability.

### The v9 saved view path

Both use cases branch on the cached version. Two `if` statements, no strategy protocol — there are
exactly two call sites, and none of the other v10 changes affect this app.

**`GetSavedViewsUseCase`** — at v10, today's behaviour. At v9, take `showInSidebar` and
`showOnDashboard` straight off the decoded payload, which `SavedView.init(from:)` already produces,
and skip the `uiSettingsRepository.getUISettings` call entirely. One fewer request on v9.

**`SetSavedViewVisibilityUseCase`** — at v10, today's UISettings read-modify-write. At v9,
`PATCH /api/saved_views/{id}/` with `show_in_sidebar` and `show_on_dashboard`.

`SaveSavedViewInput` does **not** grow these two fields. It backs both create and update on the v10
path, where the fields no longer exist on the serializer, so adding them would leak a v9-only
concern into v10 requests. Instead a dedicated `SetSavedViewVisibilityInput` in `ApiInterface` and a
`setSavedViewVisibility(id:input:server:)` method on `SavedViewsRepository`, mirroring the existing
`updateSavedView`.

The `$cache.withLock` update at the end of `SetSavedViewVisibilityUseCase` is shared by both
branches — only the remote write differs.

### Server form

`ServerFormInput.empty` drops to `headers: []`. New servers start with no headers and negotiate.

Servers already saved with a pinned `Accept` header keep it and keep working. They do not benefit
from negotiation until the user clears the header, which is the correct outcome: a header the user
typed is a deliberate instruction, and silently migrating it away would discard intent.

### Errors

A new `ApiVersionError` in `ApiInterface`, following `ShareFormError`
(`Modules/ShareFeature/ShareForm/ShareFormError.swift`):

```swift
public enum ApiVersionError: Error, Equatable {
    case unsupportedServer(Int?)
}
```

with a `LocalizedError` conformance reading from `Shared/Framework/Resources/Localizable.xcstrings`.
The message names the server's actual maximum version when known, so the user learns *why* the
server was rejected and what to upgrade, rather than seeing a bare 406.

## Testing

- `ApiClientDelegateTests` — Accept header built from the cached version; a manual `Accept` header
  still overriding it (the existing `version=9` case at `:73` already covers the override, and keeps
  working); `validateResponse` writing `X-Api-Version` into the cache, and leaving it alone when the
  header is absent.
- `NegotiateApiVersionUseCase` — header absent, below the floor, at the floor, and above
  `clientMaximum` (clamped to 10).
- `GetSavedViewsUseCase` — v10 overlay path unchanged; v9 path using payload fields and making no
  UISettings request.
- `SetSavedViewVisibilityUseCase` — v10 UISettings write unchanged; v9 PATCH; cache updated in both.
- `ServerFormViewTests` — a new server's input starts with no headers.

## Known limitation

The use case reads the cached version to choose its branch while `ApiClientDelegate` independently
reads it to set the header, so a value changing between those two reads could in principle pair a v9
branch with a v10 request. That requires the server's API version to change mid-flight — in practice
only at the moment paperless is upgraded — and the next request self-corrects. Threading an explicit
version through every request to close it is not worth the cost.
