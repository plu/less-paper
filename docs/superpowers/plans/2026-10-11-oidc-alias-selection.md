# OIDC Alias Selection Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the OIDC provider buttons selectable without an alias, with selection driving the form (hide credentials, focus alias) instead of a disabled state nobody understands.

**Architecture:** Add a single optional `selectedProvider` to `ServerFormReducer.State`; `providerButtonTapped` becomes a synchronous select/deselect/switch, and the save action branches on it (provider login vs. password save). The view renders selection (`.primary` + checkmark), hides credentials while selected, and moves focus to the alias only when it is empty.

**Tech Stack:** SwiftUI, ComposableArchitecture (TCA), Swift Testing, swift-snapshot-testing

**Spec:** `docs/superpowers/specs/2026-10-11-oidc-alias-selection-design.md`

## Global Constraints

- No new user-facing strings: no `Localizable.xcstrings` change, no new keys in any module catalogue.
- Comment style is `//` only, and only for non-obvious constraints or traps — never restate the code.
- In `ServerFormView` (`@ViewAction`), use `send(...)`, never `store.send(...)`.
- Selection identity is the provider `id` (`OIDCProvider.id`), matched against freshly fetched configs.
- Tapping a provider only selects; it never starts a login. Login is always the separate save action.
- Run `mise run ci:lint` before pushing, not just the touched schemes.

## Review Focus

- Second tap must preserve the alias text — deselecting with `alias == "mine"` keeps `"mine"` (Task 1 deselect test).
- Switching providers must preserve username/password text — the switch test uses distinct credentials pinned by the state assertion (Task 1).
- Changing the URL must clear the selection immediately, not strand it until the refetch lands (Task 1 URL test).
- A refetch that reorders the same provider ids must keep the selection — matching is by `id`, not position (Task 1 reorder test).
- A whitespace-only alias still counts as non-empty under the unchanged `isProviderLoginValid` (`!alias.isEmpty`) rule — pinned so nobody silently tightens validation here (Task 1 rule test).

## File Structure

- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer.swift` — add `selectedProvider`, retarget `providerButtonTapped` to selection, branch `saveButtonTapped`, clear stale selection on `providersLoaded` and URL change.
- Modify: `Modules/ServersFeature/ServerForm/ServerFormView.swift` — selectable buttons (no alias gate), selected style, hidden credentials, save-button enablement branch, focus on select.
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer+TestValue.swift` — accept a `selectedProvider` so view snapshots can render the selected state.
- Test: `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift` (or a new `ProviderSelectionTests.swift` beside it if the file keeps growing) — reducer selection and branching tests.
- Test: `Modules/ServersFeatureTests/ServerForm/ServerFormViewTests.swift` — snapshot with a selected provider (credentials hidden).

Each task below ends with an independently testable deliverable; Task 1 (state) is required by Tasks 2 (login branch) and 3 (view).

---

### Task 1: Selection state in the reducer

**Files:**
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer.swift`
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer+TestValue.swift`
- Test: `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift`

**Interfaces:**
- Consumes: `OIDCProvider` (`id: String`, `Equatable, Hashable, Identifiable`), existing `State.providers: [OIDCProvider]`, `State.input.alias: String`.
- Produces: `State.selectedProvider: OIDCProvider?` — `nil` means the password path; non-nil means the OIDC path. Later tasks branch on it.

- [ ] **Step 1: Write the failing tests**

```swift
@Test
func test_providerButtonTapped_selectsProvider() async throws {
    let provider = OIDCProvider.testValue()
    let store = TestStore(initialState: ServerFormReducer.State.testValue(
        input: .testValue(alias: ""),
        providers: [provider]
    )) {
        ServerFormReducer()
    }
    await store.send(.view(.providerButtonTapped(provider))) {
        $0.selectedProvider = provider
    }
}

@Test
func test_providerButtonTapped_secondTapClearsSelection() async throws {
    let provider = OIDCProvider.testValue()
    var initial = ServerFormReducer.State.testValue(
        input: .testValue(alias: "mine"),
        providers: [provider]
    )
    initial.selectedProvider = provider
    let store = TestStore(initialState: initial) {
        ServerFormReducer()
    }
    await store.send(.view(.providerButtonTapped(provider))) {
        $0.selectedProvider = nil
    }
}

@Test
func test_providerButtonTapped_switchMovesSelection() async throws {
    let first = OIDCProvider.testValue(id: "authentik")
    let second = OIDCProvider.testValue(id: "keycloak", name: "Keycloak")
    var initial = ServerFormReducer.State.testValue(
        input: .testValue(alias: "mine", username: "typed-user", password: "typed-pass"),
        providers: [first, second]
    )
    initial.selectedProvider = first
    let store = TestStore(initialState: initial) {
        ServerFormReducer()
    }
    await store.send(.view(.providerButtonTapped(second))) {
        $0.selectedProvider = second
    }
}

@Test
func test_changingUrl_clearsSelection() async throws {
    let clock = TestClock()
    var initial = ServerFormReducer.State.testValue(
        input: .testValue(),
        providers: [.testValue()]
    )
    initial.selectedProvider = .testValue()
    let store = TestStore(initialState: initial) {
        ServerFormReducer()
    } withDependencies: {
        $0.continuousClock = clock
        $0.oidcClient.providers = { _ in [] }
    }
    store.exhaustivity = .off(showSkippedAssertions: false)
    await store.send(.binding(.set(\.input.url, URL(string: "http://other.example.com")!))) {
        $0.input.url = URL(string: "http://other.example.com")!
        $0.providers = []
        $0.providersURL = URL(string: "http://other.example.com")!
        $0.selectedProvider = nil
    }
    await clock.advance(by: .milliseconds(600))
    await store.receive(\.loadProviders)
    await store.receive(\.providersLoaded)
}

@Test
func test_providersLoaded_reorderedIdsKeepsSelection() async throws {
    let first = OIDCProvider.testValue(id: "authentik")
    let second = OIDCProvider.testValue(id: "keycloak", name: "Keycloak")
    var initial = ServerFormReducer.State.testValue(
        input: .testValue(),
        providers: [first, second]
    )
    initial.selectedProvider = second
    let store = TestStore(initialState: initial) {
        ServerFormReducer()
    }
    await store.send(.providersLoaded([second, first])) {
        $0.providers = [second, first]
    }
}

@Test
func test_isProviderLoginValid_whitespaceAliasCountsAsNonEmpty() {
    // Pins the unchanged rule: only truly empty aliases gate. A person would expect
    // whitespace blocked; changing that is a separate validation change, not this one.
    #expect(ServerFormInput.testValue(alias: " ").isProviderLoginValid)
}

@Test
func test_providersLoaded_clearsSelectionForMissingId() async throws {
    var initial = ServerFormReducer.State.testValue(
        input: .testValue(),
        providers: [.testValue(id: "authentik")]
    )
    initial.selectedProvider = .testValue(id: "authentik")
    let store = TestStore(initialState: initial) {
        ServerFormReducer()
    }
    await store.send(.providersLoaded([.testValue(id: "keycloak", name: "Keycloak")])) {
        $0.providers = [.testValue(id: "keycloak", name: "Keycloak")]
        $0.selectedProvider = nil
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tuist test ServersFeature`
Expected: FAIL — `selectedProvider` does not exist.

- [ ] **Step 3: Implement `selectedProvider` in `Modules/ServersFeature/ServerForm/ServerFormReducer.swift`**

Add `var selectedProvider: OIDCProvider?` next to `providers`, defaulting to `nil`. Retarget `.view(.providerButtonTapped(provider))` to synchronous selection: same `id` clears to `nil`, otherwise sets to `provider`. No effect is returned (no login starts here). In `.providersLoaded`, after assigning `providers`, clear `selectedProvider` when its `id` is absent from the new list. In the `.binding` URL-change branch, alongside `state.providers = []` also set `state.selectedProvider = nil`. Extend the `State` `init` and `testValue` helper with a `selectedProvider` parameter defaulting to `nil`.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tuist test ServersFeature`
Expected: PASS

- [ ] **Step 5: Commit**

```bash
git add Modules/ServersFeature/ServerForm/ServerFormReducer.swift Modules/ServersFeature/ServerForm/ServerFormReducer+TestValue.swift Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift
git commit -m "feat: select OIDC provider instead of logging in on tap"
```

---

### Task 2: Save branches on the selection

**Files:**
- Modify: `Modules/ServersFeature/ServerForm/ServerFormReducer.swift`
- Test: `Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift`

**Interfaces:**
- Consumes: `State.selectedProvider: OIDCProvider?` from Task 1; existing effects `.runProviderLogin(input:provider:)` and `.runSaveServer(input:)`.
- Produces: branched save behavior — `saveButtonTapped` with a selection runs the provider login; without, the password save. No new effect types.

- [ ] **Step 1: Write the failing tests**

```swift
@Test
func test_saveButtonTapped_withSelection_runsProviderLogin() async throws {
    let provider = OIDCProvider.testValue()
    var initial = ServerFormReducer.State.testValue(
        input: .testValue(alias: "mine", username: "", password: ""),
        providers: [provider]
    )
    initial.selectedProvider = provider
    let store = TestStore(initialState: initial) {
        ServerFormReducer()
    } withDependencies: {
        $0.oidcClient.login = { _, _ in .token("the-token") }
        $0.storeProviderToken.execute = { _, _ in }
        $0.getCurrentUser.execute = { _ in .testValue(username: "paperless-user") }
        $0.negotiateApiVersion.execute = { _ in 10 }
        $0.updateCache.execute = { _ in }
    }
    await store.send(.view(.saveButtonTapped))
    await store.receive(\.binding, .set(\.isSaving, true))
    // The provider login effect answers through the action, not directly: runProviderLogin
    // sends .providerTokenReceived, whose own effect then saves and announces the server.
    await store.receive(.providerTokenReceived("the-token"))
    await store.receive(\.delegate.serverSaved)
    await store.receive(\.binding, .set(\.isSaving, false))
}

@Test
func test_providerButtonTapped_neverStartsLogin() async throws {
    let provider = OIDCProvider.testValue()
    let store = TestStore(initialState: ServerFormReducer.State.testValue(
        input: .testValue(alias: "mine"),
        providers: [provider]
    )) {
        ServerFormReducer()
    } withDependencies: {
        $0.oidcClient.login = { _, _ in
            Issue.record("selection must not start a login")
            return .token("unused")
        }
    }
    await store.send(.view(.providerButtonTapped(provider))) {
        $0.selectedProvider = provider
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `tuist test ServersFeature`
Expected: FAIL — save with a selection still runs the password path (calls `storeToken`, fails on empty credentials).

- [ ] **Step 3: Branch `saveButtonTapped` on `selectedProvider` in `Modules/ServersFeature/ServerForm/ServerFormReducer.swift`**

In the `.view(.saveButtonTapped)` case, when `state.selectedProvider` is non-nil return `.runProviderLogin(input: state.input, provider: state.selectedProvider)`; otherwise return `.runSaveServer(input: state.input)` as today. One branch, no new effects.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tuist test ServersFeature`
Expected: PASS (also confirms the Task 1 selection tests still pass and no existing password-path test regressed)

- [ ] **Step 5: Commit**

```bash
git add Modules/ServersFeature/ServerForm/ServerFormReducer.swift Modules/ServersFeatureTests/ServerForm/ServerFormReducerTests.swift
git commit -m "feat: route server save through the selected OIDC provider"
```

---

### Task 3: Form shows the selection and points at the alias

**Files:**
- Modify: `Modules/ServersFeature/ServerForm/ServerFormView.swift`
- Test: `Modules/ServersFeatureTests/ServerForm/ServerFormViewTests.swift`

**Interfaces:**
- Consumes: `State.selectedProvider: OIDCProvider?` and `ServerFormInput.isProviderLoginValid` (unchanged — whitespace alias still counts as non-empty, per spec).
- Produces: the visible behavior — selectable buttons, selected style, hidden credentials, branched save enablement, alias focus. No new strings, no catalogue change.

- [ ] **Step 1: Write the failing snapshot test**

```swift
@Test
func testSnapshot_withSelectedProvider() async throws {
    var selected = ServerFormReducer.State.testValue(
        input: .testValue(alias: "", username: "", password: ""),
        providers: [OIDCProvider.testValue(id: "authentik", name: "Authentik")]
    )
    selected.selectedProvider = .testValue(id: "authentik", name: "Authentik")
    assertSnapshot(
        of: ScrollView {
            ServerFormView(
                store: Store(
                    initialState: selected,
                    reducer: { ServerFormReducer() }
                )
            )
        }
        .background(Color.m3Surface),
        as: .image(layout: .device(config: .iPhone12)),
        named: "withSelectedProvider"
    )
}
```

Record the reference after implementing (per `AGENTS.md`, record mode fails by design; the task restores captures on failure): `mise run snapshots:record ServersFeature --only ServersFeatureTests/ServerFormViewTests`, then inspect the recorded reference — credentials hidden, Authentik button `.primary` with checkmark, alias field visible — before trusting the second run.

- [ ] **Step 2: Run test to verify it fails**

Run: `tuist test ServersFeature`
Expected: FAIL — snapshot mismatch (selected state renders like today: secondary buttons, credentials visible).

- [ ] **Step 3: Implement the view in `Modules/ServersFeature/ServerForm/ServerFormView.swift`**

`providerButtons()`: drop the `!store.input.isProviderLoginValid` gate so every button is tappable whenever `!store.isSaving`. Render the selected provider (`store.selectedProvider?.id == provider.id`) with `.buttonStyle(.primary())` and a checkmark (`Label` with `systemImage: "checkmark"`, matching the existing `Label(.edit, systemImage:)` pattern), others with `.secondary()` as today. Add an accessibility label for the selected state (e.g. the existing selected-pattern value, no new strings — reuse the provider name plus the system-selected trait via `.accessibilityAddTraits(.isSelected)`).

`formView()`: wrap `usernameField()` and `passwordField()` in `if store.selectedProvider == nil`.

`buttons()` save button: `.disabled(store.isSaving || !(store.selectedProvider != nil ? store.input.isProviderLoginValid : store.input.isValid))`.

Focus: add `.onChange(of: store.selectedProvider?.id) { _, newValue in if newValue != nil, store.input.alias.isEmpty { focus = .alias } }` on the form stack, using the existing `@FocusState private var focus: ServerFormField?` and `send(...)` for all actions (no `store.send`). The `newValue != nil` guard is load-bearing: clearing the selection (second tap, URL change, stale refetch) must leave focus alone per the spec. Focus itself is not unit-testable in this stack — verify by hand in the recorded snapshot run that selecting with an empty alias focuses the alias field, selecting with a filled alias steals nothing, and VoiceOver announces the selected button as selected.

- [ ] **Step 4: Run tests to verify they pass**

Run: `tuist test ServersFeature`
Expected: PASS, including all pre-existing `ServerFormViewTests` references unchanged (no-provider form looks exactly as before)

- [ ] **Step 5: Run lint**

Run: `mise run ci:lint`
Expected: PASS — note `--fix` makes real edits (e.g. `aspectRatio` rewrites), so re-run the touched scheme's tests if it changed `ServerFormView.swift`

- [ ] **Step 6: Commit**

```bash
git add Modules/ServersFeature/ServerForm/ServerFormView.swift Modules/ServersFeatureTests/ServerForm/ServerFormViewTests.swift Snapshots/
git commit -m "feat: point at the alias when an OIDC provider is selected"
```
