# UI testing rework

## Context

UI testing today runs against ten purpose-built harness apps. Each is a `@main` `App` that boots
straight into one feature's root view, and each has a matching XCUITest target:

```
CorrespondentsApp  CustomFieldsApp  DocumentsApp  DocumentTypesApp  SavedViewsApp
ServersApp         SettingsApp      ShareApp      StoragePathsApp   TagsApp
```

`TagsApp` is representative — it renders `TagListView` with a hardcoded `Server.testValue()`,
`authenticationProvider = .integrationTest`, and in-memory app and file storage. Twenty targets in
total, 37 tests, all driving views the real app never assembles.

Two problems follow, and they are the reason for this rework.

**The real app is never exercised.** `.integrationTest` resolves credentials via
`authenticationRepository.getToken(input: .testValue(), server: .testValue())` — hardcoded admin
credentials. The shipping app instead goes through `keychain.getCredentials(server:)`, reads
servers from `servers.json` in the app group, and negotiates an API version at bootstrap. None of
that path has UI coverage. The bug fixed in #190 — guessing an API version before negotiating one —
lived precisely there.

**The scaffolding grows with every feature.** A new feature means a new harness app, a new test
target, and entries in five `Module+*.swift` helpers. The harness count only ever goes up.

Runtime is the third irritant. `mise ci:test` gates the XCUITest targets behind `CI_UI_TESTS`
because they are ~4% of tests but ~70% of execution time, so they run on `main` and on labelled PRs
only. Measured from the checked-in result bundles:

| Bundle | Tests | Test-case time |
|---|---|---|
| `test-CustomFieldsApp.xcresult` | 8 | 142s |
| `test-CorrespondentsApp.xcresult` | 5 | 74s |
| `test-DocumentsApp.xcresult` | 1 | 10s |

At roughly 15–18s per test, 37 tests account for ~550s of test-case time. The rest of the ~70% is
overhead that scales with target count: ten app builds, ten XCUITest bundle builds, ten
install-and-launch cycles.

### What the server actually does

Probed against the `paperless-ngx:3.0.5` instance this repo runs in `docker/`. These five results
are what the design rests on:

1. **A fresh user sees nothing at all.** Creating a user with no `user_permissions` and querying
   `/api/tags/` returns a rejection, not an empty list. Paperless applies Django-style *global*
   permissions on top of object ownership; a test user needs an explicit permission set.

2. **A permissioned user sees only its own objects.** With `view_tag`/`add_tag`/`change_tag`/
   `delete_tag` granted, the probe user's `/api/tags/` returned `count: 0` while admin's returned
   `count: 11`. Ownership isolation is complete.

3. **Created objects are owned automatically.** `POST /api/tags/` as the probe user returned
   `owner: 4` — its own id. No explicit ownership bookkeeping is needed.

4. **Deleting a user does not delete its objects.** After `DELETE /api/users/4/`, the tag the probe
   user created was still present. Cleanup must delete objects first, then the user.

5. **Documents split by provenance.** Of 23 documents, 19 have `owner: null` and 4 have
   `owner: 2`. Documents consumed from the `consume/` folder get no owner and are therefore visible
   to every permissioned user; documents created through the API are owned by their creator.

6. **Custom fields have no owner at all.** A custom field serialises as
   `{data_type, document_count, extra_data, id, name}` — there is no `owner` key. A user granted
   every permission still saw all 4 custom fields while seeing 0 tags, 0 correspondents,
   0 document types, 0 storage paths and 0 saved views. Custom fields are global in
   paperless-ngx 3.0.5 and **cannot be isolated by ownership**.

Probes 2 and 6 were run with the full `Permission.allCases` set — all 72 values — not a subset, so
breadth of global permissions does not weaken ownership isolation.

One further measurement: `POST /api/documents/post_document/` with a small PDF was consumed and
queryable **3 seconds** later. A test that needs its own document can afford one.

## Decisions

Four choices were settled before the design took shape.

**Purpose: fidelity and scaffolding, not speed.** Runtime is a constraint to respect, not the goal.

**Scope: fewer, deeper journeys.** With 1283 feature-level tests already covering detail, the UI
layer's job is assembled-app behaviour. Per-entity CRUD grids do not belong there.

**Parallelism: designed for, not enabled.** Tests will be written so nothing prevents parallel
execution — no global mutation, no shared writable fixture — but the suite runs serially. Collapsing
ten app builds into one is expected to reclaim more time than parallelism would, without the
multi-container orchestration.

**Launch state: injected, with one real path.** Most journeys receive a pre-configured server
through the launch environment. One journey drives the add-server form for real.

## Architecture

### Target topology

Eighteen modules are deleted — nine harness apps and their nine test targets. Two are added.

| | Before | After |
|---|---|---|
| Harness apps | 10 | 1 (`ShareApp`) |
| XCUITest targets | 10 | 2 (`AppUITests`, `ShareAppTests`) |
| Shared config module | 0 | 0 — see below |
| **Total** | **20** | **3** |

This section originally called for a standalone `UITestConfiguration` module, making the total 4.
Implementation put the payload in `ApiInterface` instead: that module already carries the
`testValue()` factories and already reads `PAPERLESS_TEST_URL` from the bundle, and — the actual
constraint — it does not link XCTest. That saves a module and a test target.

`ShareApp` is a deliberate, permanent exception. It is not a feature harness: it stands in for the
*share extension*, presenting `ShareExtensionView` with buttons for "With server", "Without server"
and "Without context". The real `ShareExtension` target is reachable only through another app's
share sheet, which XCUITest drives slowly and flakily. `ShareApp` and `ShareAppTests` stay as they
are, with a comment recording why.

Tuist edits land in the five `Module+*.swift` helpers: enum cases, dependency entries, Info.plist
entries — two of the three `PAPERLESS_TEST_URL` injection sites belong to harness apps — and the
whole `featureAppTestTargets` mapping in `Module+Schemes.swift`.

Two wrinkles:

- `Module.allTestableTargets` filters on `product == .unitTests`, so `AppUITests` is not picked up
  automatically. Add it explicitly to the "Less Paper" scheme's test action. Widening the filter
  would sweep in `ShareAppTests` too.
- `mise ci:test` passes `--skip-ui-tests`, which Tuist resolves by product type. Both remaining
  XCUITest targets are `.uiTests`, so the `CI_UI_TESTS` gate keeps working untouched.

### Launch-state injection

`UITestConfiguration` is a new module holding one `Codable` payload and no XCTest. It cannot live in
the existing `UITestSupport`, which sets `ENABLE_TESTING_SEARCH_PATHS = YES` and links XCTest —
that must never reach a shipping binary. Both `App` and `AppUITests` depend on it.

The payload carries the server (alias, id, url, username), the credentials to pre-seed, and
behaviour flags. The test encodes it as JSON into `XCUIApplication.launchEnvironment`; the app
decodes it in `LessPaperApp.init()` and configures dependencies before `store.send(.bootstrap)`.

`Keychain` and its `DependencyValues` extension are **internal to `ApiImplementation`**, so the app
cannot assign `$0.keychain` directly. The seam is a public entry point in `ApiImplementation`, which
already owns the type; `App` depends on that module already:

```swift
init() {
    #if DEBUG
    if let configuration = UITestConfiguration.fromEnvironment() {
        prepareUITestDependencies(configuration)
    }
    #endif
    Self.store.send(.bootstrap)
}
```

`prepareUITestDependencies` sets `defaultAppStorage` and `defaultFileStorage` to `.inMemory` and
swaps in a keychain seeded with the configuration's credentials, then writes `@Shared(.servers)` and
`@Shared(.selectedServer)`. Order matters: file storage must be in-memory before the shared writes,
or the test would touch the real app-group container. Writing `.selectedServer` is what drives
`AppReducer.bootstrap`'s observer into `.selectedServerChanged`, building `MainReducer.State` and
running `updateCache` — the same path a real launch takes.

Three decisions inside this, each with a cost:

**The `#if DEBUG` guard** keeps the hook out of Release builds, so nothing test-related ships. The
cost is that the tested binary is not byte-identical to the shipped one. The alternative — a
shippable app that reconfigures its own storage from an environment variable — is worse.

**The keychain is in-memory, not the real one.** The Security-framework keychain is per-bundle-id
global state that survives app relaunch, exactly the shared mutable state this design exists to
remove. Swapping it keeps the flow covered — form → `StoreTokenUseCase` → write →
`GetCredentialsUseCase` → read — while the Security binding stays covered where it already is, in
`StoreTokenUseCaseTests` and `GetCredentialsUseCaseTests`.

**The onboarding journey passes a configuration with no seeded server** — not no configuration at
all. Implementation proved the difference matters: with no configuration the app reads the real
`servers.json` from the application group, so a developer machine with a configured app launches
straight into the document list and never shows the add-server form, while a clean CI runner passes.
A seedless configuration still swaps storage to memory, which is the only way to reach that form
deterministically. The journey then drives the real form, real keychain write, and real
`negotiateApiVersion`, typing a server URL the test process reads from its own Info.plist
`PAPERLESS_TEST_URL`.

For the same reason the UI-test keychain is a real in-memory store rather than a fixed answer: the
add-server flow writes through `StoreTokenUseCase` and reads back through `GetCredentialsUseCase`,
and a stub ignoring the write would report success without exercising either.

### Test data isolation

**The isolation primitive is a per-test Paperless user.** `setUp` creates `uit-<uuid8>` through the
admin API granting `Permission.allCases` — the enum is `String, CaseIterable` with 72 values, so the
grant set needs no hand-curation and cannot drift from what the app calls. Probes 2 and 6 confirm
that full breadth does not weaken ownership isolation. The launch configuration points the app at
those credentials. Fixtures are created *as that user*
through the existing `withTestDependencies` and repository pattern, so they are owned by it and
invisible to every other test. `tearDown` deletes the user's objects and then the user — in that
order, because probe 4 showed deletion does not cascade.

Every global-mutation helper — `deleteAllTags()` and its siblings in each `*AppTests` file — is
deleted outright rather than deprecated.

This also disposes of a problem the current tests do not have to face. None of the list features use
`.searchable`; there is no way to filter a list to one row. Under name-prefix namespacing a test's
entity could sit below the fold among 11 seeded tags. Under per-test users the list starts at
exactly zero entries, so the question never arises, and
`"No Tag matches the given query."` becomes the natural default state rather than something a test
has to engineer.

**Custom fields are the one entity ownership cannot isolate**, following from probe 6. They are
global: every test user sees every custom field, including those created by other tests. Journeys 9
and 12 therefore fall back to name-prefix namespacing for custom fields specifically — each test
creates fields named `uit-<uuid8>-<label>`, asserts only on those, and deletes them in `tearDown`.
Unique names keep this parallel-safe; what it costs is that a custom-field list is never empty, so
those two journeys cannot assert on list counts and may need to scroll to find their row.

**Documents get two tiers**, following from probe 5:

- The 19 unowned documents are a **shared read-only corpus**, visible identically to every test
  user. Journeys that list, open, filter, or view a PDF use it and assert only.
- A journey that **mutates** a document uploads its own PDF first, pays the measured ~3s, and gets
  an owned and therefore isolated document.

Three consequences worth stating plainly:

**Tests run as a non-superuser.** This is a behaviour change from today's admin, and a fidelity gain
— real users are not superusers, and the app has a `PermissionsFeature`. Granting
`Permission.allCases` rather than a curated subset means a new endpoint in the app cannot outrun the
grant set, at the cost of not catching genuine permission regressions; those belong in
`PermissionsFeatureTests`.

**The shared corpus is the last piece of global state.** Nothing enforces read-only except
discipline, and a test that edited a seeded document would corrupt its neighbours silently. Giving
every test its own document at 3s each is not worth it; instead the corpus is exposed through a
deliberately read-only-looking test-support API so mutating it is awkward by accident.

**Orphans accumulate without a sweep.** If `tearDown` dies — crash, timeout, a cancelled CI run —
the user and its objects leak. A sweep at suite start deletes `uit-*` users and their objects.

## Journeys

Thirty-seven tests become twelve journeys, plus the untouched Share test.

| # | Journey | Replaces |
|---|---|---|
| 1 | Onboarding — virgin app, add server, real negotiation and keychain, land on documents | part of `ServersApp.testCRUD`; bootstrap was never covered |
| 2 | Server management — add second, switch, edit, delete | rest of `testCRUD` |
| 3 | Settings overview — all sections present, version shown | `SettingsApp.testSettingsList` |
| 4 | Tag lifecycle — create, appears, edit, delete | `TagsApp` create/list/update/delete |
| 5 | Correspondent lifecycle | `CorrespondentsApp` create/list/update/delete |
| 6 | Document type lifecycle | `DocumentTypesApp` create/list/update/delete |
| 7 | Storage path lifecycle | `StoragePathsApp` create/list/update/delete |
| 8 | Saved view lifecycle | `SavedViewsApp` create/list/update/delete |
| 9 | Custom fields — text field, select field with options, edit, delete | 6 of 8 `CustomFieldsApp` tests |
| 10 | Stale-delete conflict — entity removed server-side, then deleted in UI | **all five** `testDeleteFailure` tests |
| 11 | Document browsing — list, open, view PDF, filter against the corpus | `DocumentsApp.testList`, expanded |
| 12 | Document custom-field editing — upload own document, edit field, verify | new; previously untested end to end |

Two collapses are deliberate.

**The five `testDeleteFailure` tests are one mechanism repeated five times**: delete behind the
app's back, confirm in the UI, expect the conflict surface. One journey covers the behaviour. If it
turns out to be entity-specific, that is a reducer concern.

**The four-tests-per-entity grid becomes one lifecycle journey** threading create → edit → delete.
Closer to real use, and one launch instead of four.

### What moves down to feature tests

`testCancelWithBlankOption` and `testDeleteBlankOption` from `CustomFieldsAppTests`, plus per-entity
validation, sort order, and per-entity empty states. These are assertions about a reducer and belong
in `CustomFieldsFeatureTests` and its siblings, where they are faster and deterministic. They must
be written **before** the corresponding harness app is deleted.

## Test authoring structure

`UITestSupport` grows from two `XCUIElement` extensions into the suite's vocabulary:

- **`UITestCase` base** owning the lifecycle: create the per-test user, build the launch
  configuration, launch, and clean up objects-then-user in `tearDown` even when the test fails.
- **Screen drivers** — `SettingsScreen`, `TagListScreen`, `DocumentListScreen` — exposing intent
  (`openTags()`, `createTag(named:)`) rather than raw element queries, so a changed button label is
  a one-line fix rather than a sweep.
- **Fixture factory** over the existing repositories, with the shared document corpus behind a
  read-only-looking API.

**Accessibility identifiers are the largest unknown in this project.** Today's tests match visible
labels — `app.buttons["Add tag"]`, `app.textFields["Name"]` — which is unambiguous because each
harness shows exactly one screen. In the assembled app `"Name"` may match several fields across a
navigation stack, and the tab bar adds further ambiguity. Some views will need explicit identifiers.
The size of that work cannot be estimated before the journeys are written; it is the most likely
source of unplanned effort.

## CI and migration

**No workflow changes.** `--skip-ui-tests` resolves by product type, so both remaining XCUITest
targets stay behind the `CI_UI_TESTS` gate. The gate stays as it is initially; once journeys 1–3
exist the real runtime gets measured, and only then is running on every PR decided. The arithmetic
says it should be affordable, but the number comes first.

**One seed change.** The corpus is currently unowned by accident — 19 documents have no owner
because they arrived through the consume folder. This design depends on that split, so `seed.py`
should state it explicitly rather than leave a load-bearing property emergent.

### Sequence

Ordered so `main` is never less covered than it is today.

1. `UITestConfiguration` module and the `LessPaperApp` launch hook. No tests, nothing deleted.
2. `AppUITests` target, `UITestCase` base, user lifecycle, fixture factory, orphan sweep. Prove the
   machinery with **journey 1**, which exercises every new piece at once.
3. Journeys 3–8. Delete each harness app pair only as its replacement lands — one commit per entity.
4. Move the CustomFields blank-option and cancel assertions into `CustomFieldsFeatureTests`, then
   write journeys 9 and 10, then delete `CustomFieldsApp`.
5. Journeys 11 and 12, including the upload-your-own-document helper.
6. Prune the five `Module+*.swift` helpers, delete the last harness modules, and record the
   isolation contract in `AGENTS.md`.
7. Measure runtime; revisit the CI gate.

Step 6's `AGENTS.md` entry carries more weight than its size suggests. "Never mutate global server
state in a UI test" is the rule the whole design rests on, and it needs to be written where the next
person will read it.

## Risks

**Accessibility identifiers** — unsized, discussed above. Mitigated by sequencing journey 1 first,
which surfaces the problem in the deepest navigation path before the harnesses are gone.

**Permission set drift** — eliminated by granting `Permission.allCases` rather than a curated list.

**Custom fields are global** — probe 6. Journeys 9 and 12 fall back to name-prefix namespacing and
cannot assert on list counts. Accepted; the alternative is a container per test.

**Corpus mutation** — a test that edits a seeded document corrupts its neighbours silently.
Mitigated by API shape, not enforcement. Accepted.

**Harness deletion outpacing replacement** — mitigated by the one-commit-per-entity rule in step 3
and by writing the moved-down feature tests before step 4's deletion.
