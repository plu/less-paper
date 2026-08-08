# Custom HTTP headers per server

## Context

The server form (`Modules/ServersFeature/ServerForm/`) currently only captures URL, username, password, and alias. There's no way to attach custom HTTP headers to a server, which is needed for setups behind a reverse proxy/auth gateway or for pinning a specific Paperless-ngx API version. The request is to add an "Advanced" section to the form (toggled via a segmented control alongside the existing "Basic" fields) where the user can maintain an arbitrary array of `name`/`value` header pairs, persisted with the server. New servers should start with one default header pre-filled: `Accept: application/json; version=9`. These headers should be sent on every request to that server — both regular API calls and thumbnail/preview image loads.

Investigation confirmed: there is currently no header-injection concept anywhere in the app (no existing `Accept` header, no `version=9`). `Server` (`Modules/ApiInterface/Shared/Server.swift`) is a plain `Codable` struct persisted as JSON (`servers.json`, via `swift-sharing`'s `FileStorageKey`). `ApiClientDelegate.willSendRequest` (`Modules/ApiImplementation/ApiClientDelegate.swift`) is the single choke point for outgoing headers on the main API client; `ImageLoader.swift` (`Modules/ImageFeature/`) independently injects `Authorization` for Nuke-based thumbnail loading and needs the same treatment (per user decision — custom headers apply to both).

**No backward-compatible decoding.** An earlier version of this plan added a custom `Codable` implementation to `Server` (hand-written `init(from:)`/`encode(to:)`) so a `servers.json` written by an already-installed build (no `headers` key) would still decode, defaulting to `[]`. Per explicit user decision, this feature hasn't shipped yet, so there's no such file in the wild to protect — `Server` keeps plain synthesized `Codable`, and `headers` is a normal required key like every other field. If this ever needs to become backward-compatible after a real release, that's a deliberate future change, not something to build defensively now.

`TagsFeature`'s `TagFormView`/`TagFormSection`/`TagFormReducer` already implement the exact "segmented control switches between two sections of the same form" pattern this feature needs (`Picker` + `.pickerStyle(.segmented)` bound to a plain enum on `@ObservableState`) — this is the template to copy.

## New model: `HTTPHeader`

New file `Modules/ApiInterface/Shared/HTTPHeader.swift`, colocated with `Server.swift`, following the same conventions (public struct, `Codable`/`Equatable`/`Hashable`/`Identifiable`/`Sendable`, a `testValue()` extension):

```swift
public struct HTTPHeader: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let id: String
    public var name: String
    public var value: String

    public init(id: String, name: String, value: String) {
        self.id = id
        self.name = name
        self.value = value
    }
}

public extension HTTPHeader {
    static func testValue(
        id: String = "9E2B1B2E-2F0B-4C9E-8B0E-1B2E2F0B4C9E",
        name: String = "Accept",
        value: String = "application/json; version=9"
    ) -> Self {
        .init(id: id, name: name, value: value)
    }
}
```

`name`/`value` are `var` (unlike `Server`'s `let` fields) so SwiftUI can bind directly to array elements in the form.

## `Server` model changes

`Modules/ApiInterface/Shared/Server.swift`: add `public let headers: IdentifiedArrayOf<HTTPHeader>` (consistent with the app's existing use of `IdentifiedArrayOf` for collections, e.g. `IdentifiedArrayOf<Server>` for `.servers`). `Codable` stays fully synthesized — no custom `init(from:)`/`encode(to:)`/`CodingKeys`:

```swift
public struct Server: Codable, Equatable, Hashable, Identifiable, Sendable {
    public let alias: String
    public let headers: IdentifiedArrayOf<HTTPHeader>
    public let id: String
    public let username: String
    public let url: URL

    public init(
        alias: String,
        headers: IdentifiedArrayOf<HTTPHeader> = [],
        id: String,
        username: String,
        url: URL
    ) {
        self.alias = alias
        self.headers = headers
        self.id = id
        self.username = username
        self.url = url
    }
}
```

Update `Server.testValue(...)` to add a `headers: IdentifiedArrayOf<HTTPHeader> = []` parameter (default keeps all existing call sites/tests green).

## `ServerFormInput` changes

`Modules/ServersFeature/ServerForm/ServerFormInput.swift`:
- Add `public var headers: IdentifiedArrayOf<HTTPHeader>`.
- `var server: Server` — pass `headers` through, filtering out rows with a blank (whitespace-trimmed) name so an unfinished "add row" the user never filled in doesn't get persisted:
  ```swift
  var server: Server {
      .init(
          alias: alias,
          headers: headers.filter { !$0.name.trimmingCharacters(in: .whitespaces).isEmpty },
          id: id,
          username: username,
          url: url
      )
  }
  ```
- `.empty` — seed the default header for new servers:
  ```swift
  public extension ServerFormInput {
      static var empty: ServerFormInput {
          @Dependency(\.uuid) var uuid

          return .init(
              alias: "",
              headers: [
                  HTTPHeader(id: uuid().uuidString, name: "Accept", value: "application/json; version=9")
              ],
              id: uuid().uuidString,
              password: "",
              url: .empty,
              username: ""
          )
      }
  }
  ```
- `.testValue(...)` — add `headers: IdentifiedArrayOf<HTTPHeader> = []` parameter, default keeps existing tests green.

`isValid` is unaffected — header validity isn't required to save (blank rows are just dropped, per above).

## `ServerFormReducer` / new `ServerFormSection`

New file `Modules/ServersFeature/ServerForm/ServerFormSection.swift`, mirroring `TagFormSection.swift`:

```swift
enum ServerFormSection: CaseIterable {
    case form
    case advanced
}

extension ServerFormSection: CustomStringConvertible {
    var description: String {
        switch self {
        case .form:
            String(localized: .server)
        case .advanced:
            String(localized: .advanced)
        }
    }
}
```

`ServerFormReducer.swift`:
- `State`: add `var section = ServerFormSection.form`.
- `Action.View`: add `case addHeaderButtonTapped`, `case deleteHeaderButtonTapped(HTTPHeader.ID)`, `case headerNameChanged(HTTPHeader.ID, String)`, `case headerValueChanged(HTTPHeader.ID, String)`.
- `reduce`:
  ```swift
  case .view(.addHeaderButtonTapped):
      @Dependency(\.uuid) var uuid
      state.input.headers.append(HTTPHeader(id: uuid().uuidString, name: "", value: ""))
      return .none
  case let .view(.deleteHeaderButtonTapped(id)):
      state.input.headers.remove(id: id)
      return .none
  case let .view(.headerNameChanged(id, name)):
      state.input.headers[id: id]?.name = name
      return .none
  case let .view(.headerValueChanged(id, value)):
      state.input.headers[id: id]?.value = value
      return .none
  ```

**Do not bind header text fields via `$store.input.headers[id:]` / `Binding($store...)!`.** That subscript-binding pattern force-unwraps an optional that can legitimately become `nil` mid-render (e.g. right after a delete, while SwiftUI is still tearing down the row's view identity) — this crashed the app when adding then removing a header. Instead, drive each header's `name`/`value` through the explicit `headerNameChanged`/`headerValueChanged` actions above via a hand-built `Binding` in the view (see below) whose `get` defaults to `""` and whose `set` dispatches the action; the reducer's optional-chained assignment (`state.input.headers[id: id]?.name = name`) is a safe no-op if the row is already gone, so there is no crash window and no force-unwrap anywhere in this feature.

## `ServerFormView` UI

`Modules/ServersFeature/ServerForm/ServerFormView.swift`:
- Add a `sectionPicker()` identical in shape to `TagFormView.sectionPicker()`:
  ```swift
  @ViewBuilder
  private func sectionPicker() -> some View {
      Picker("", selection: $store.section) {
          ForEach(ServerFormSection.allCases, id: \.self) {
              Text($0.description)
          }
      }
      .pickerStyle(.segmented)
      .labelsHidden()
  }
  ```
- `formView()` (renamed conceptually to the "basic" section) stays as-is; wrap the top-level `content:` closure to switch on `store.section`, matching `TagFormView`'s body:
  ```swift
  } content: {
      VStack(spacing: .x4) {
          sectionPicker()
          switch store.section {
          case .form:
              formView()
          case .advanced:
              advancedSection()
          }
      }
  }
  ```
- New `advancedSection()` + `headerRow(_:)`, styled as a titled card grouping — mirroring `PermissionsFormView`'s `changePermissions()`/`viewPermissions()` sections (a bold section `Text`, then content in a `VStack` with a `RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer)` background) — so it reads as a distinct "HTTP Headers" group rather than a bare list of fields. Each header row stacks its Name/Value fields **vertically** (not side-by-side — an `HStack` left the value field too narrow to read), with a small trailing delete control above the fields:
  ```swift
  @ViewBuilder
  private func advancedSection() -> some View {
      VStack(alignment: .leading, spacing: .x0) {
          Text(.httpHeaders)
              .fontWeight(.semibold)
              .padding(.horizontal)

          VStack(spacing: .x4) {
              ForEach(store.input.headers) { header in
                  headerRow(header)
                  if header.id != store.input.headers.last?.id {
                      Divider()
                  }
              }

              Button {
                  send(.addHeaderButtonTapped)
              } label: {
                  Label(String(localized: .addHeader), systemImage: "plus")
                      .frame(maxWidth: .infinity)
              }
              .buttonStyle(.secondary())
          }
          .padding()
          .background(RoundedRectangle(cornerRadius: Constants.cornerRadius).foregroundStyle(Color.m3SurfaceContainer))
      }
  }

  @ViewBuilder
  private func headerRow(_ header: HTTPHeader) -> some View {
      VStack(alignment: .leading, spacing: .x2) {
          HStack {
              Spacer()
              Button {
                  send(.deleteHeaderButtonTapped(header.id))
              } label: {
                  Image(systemName: "trash")
                      .foregroundColor(.m3Error)
              }
              .accessibilityLabel(.deleteHeader)
          }

          Field(.headerName) {
              TextField(String(localized: .headerName), text: headerNameBinding(header.id))
                  .textFieldStyle(.plain)
                  .textInputAutocapitalization(.never)
          }

          Field(.headerValue) {
              TextField(String(localized: .headerValue), text: headerValueBinding(header.id))
                  .textFieldStyle(.plain)
          }
      }
  }

  private func headerNameBinding(_ id: HTTPHeader.ID) -> Binding<String> {
      Binding(
          get: { store.input.headers[id: id]?.name ?? "" },
          set: { send(.headerNameChanged(id, $0)) }
      )
  }

  private func headerValueBinding(_ id: HTTPHeader.ID) -> Binding<String> {
      Binding(
          get: { store.input.headers[id: id]?.value ?? "" },
          set: { send(.headerValueChanged(id, $0)) }
      )
  }
  ```
  `Constants.cornerRadius` is the existing shared constant from `Modules/Components/Constants.swift` (already used by `PermissionsFormView`/`ButtonSize`), available here since `ServersFeature` already imports `Components`.

## Networking: apply headers to outgoing requests

`Modules/ApiImplementation/ApiClientDelegate.swift` — merge `server.headers` in `willSendRequest`, applied **before** the `Authorization` header so the app's real auth token always wins even if a user-defined header is also named `Authorization`:

```swift
func client(_ client: APIClient, willSendRequest request: inout URLRequest) async throws {
    for header in server.headers {
        request.setValue(header.value, forHTTPHeaderField: header.name)
    }

    guard request.url?.path().contains("/api/token/") == false else {
        return
    }

    let token = try await authenticationProvider.getToken(server: server)
    request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
}
```

`Modules/ImageFeature/ImageLoader.swift` — same merge, gated by the existing same-host check so headers only apply to requests actually going to the paperless server (not arbitrary external images):

```swift
let token = try await getToken(server)
var request = request
if server.url.host() == request.url?.host() {
    for header in server.headers {
        request.setValue(header.value, forHTTPHeaderField: header.name)
    }
    request.setValue("Token \(token)", forHTTPHeaderField: "Authorization")
}
```

## Edit flow

`Modules/ServersFeature/ServerList/ServerListReducer.swift`, `getCredentialsResult` case — thread the existing server's headers into the reconstructed form input so editing a server shows its current headers:

```swift
case let .getCredentialsResult(credentials, server):
    state.destination = .serverForm(ServerFormReducer.State(input: .init(
        alias: server.alias,
        headers: server.headers,
        id: server.id,
        password: credentials?.password ?? "",
        url: server.url,
        username: server.username
    )))
    return .none
```

## Localization

Add new keys to `Shared/Framework/Resources/Localizable.xcstrings` (en/de), following the existing manual-extraction format:
- `advanced` — "Advanced" / "Erweitert"
- `httpHeaders` — "HTTP Headers" / "HTTP-Header" (section title in the Advanced card)
- `headerName` — "Name" / "Name"
- `headerValue` — "Value" / "Wert"
- `addHeader` — "Add Header" / "Header hinzufügen"
- `deleteHeader` — "Delete Header" / "Header löschen"

(`.server` already exists with value "Server" and is reused for the "Basic" tab label, matching how `TagFormSection.form` reuses `.tag`.)

## Test updates

- `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift` — existing tests using `ServerFormInput.testValue()`/`Server.testValue()` stay green (new params default to `[]`). Add new cases: add-header appends a row with a fresh id via the `uuid` test dependency, delete-header removes by id, and save filters out a blank-name row.
- `Modules/ServersFeatureTests/ServerList/ServerListReducerTests.swift` — update the `getCredentialsResult` test to assert `headers` is carried through from the existing `Server` into the reconstructed `ServerFormInput`.
- `Modules/ApiInterfaceTests/Shared/ServerTests.swift` — decode-with-headers and encode/decode round-trip tests against plain synthesized `Codable`.

## Verification

1. `swift build` / build the app via XcodeBuildMCP to confirm everything compiles.
2. Run `Modules/ServersFeatureTests` and any `ApiInterfaceTests`/`ApiImplementationTests` covering `Server` decoding.
3. Manually in the simulator: create a new server, confirm the Advanced tab shows one pre-filled `Accept: application/json; version=9` row; add/remove header rows; save; edit the server again and confirm headers persisted; use Charles/a debug proxy or a log point in `ApiClientDelegate` to confirm the header is actually sent on a real API request.
