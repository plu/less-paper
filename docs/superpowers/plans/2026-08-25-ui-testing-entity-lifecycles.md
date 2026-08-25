# UI Testing Entity Lifecycles Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the correspondent, document type, storage path and saved view XCUITest harness apps with journeys in `AppUITests`, add the stale-delete conflict journey, and retire five harness pairs — ten targets.

**Architecture:** One `EntityListScreen` driver parameterised by three per-entity labels replaces `TagListScreen` and the four drivers that would have followed it. One `EntityLifecycleJourneyTests` file holds five lifecycle methods over a shared private helper plus the stale-delete journey. Each harness pair is deleted in its own commit, immediately after its replacement journey passes.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing, Tuist 4.205.0, Swift Testing (unit), XCTest/XCUITest (UI), paperless-ngx 3.0.5 in Docker.

**Spec:** [2026-08-25-ui-testing-rework-entity-lifecycles-design.md](../specs/2026-08-25-ui-testing-rework-entity-lifecycles-design.md)

**Parent spec:** [2026-08-24-ui-testing-rework-design.md](../specs/2026-08-24-ui-testing-rework-design.md)

**Scope:** Journeys 5–8 and 10, plus deletion of the `SettingsApp`, `CorrespondentsApp`, `DocumentTypesApp`, `StoragePathsApp` and `SavedViewsApp` pairs. Journeys 2, 9, 11 and 12 — and the `CustomFieldsApp`, `DocumentsApp` and `ServersApp` deletions that depend on them — are a later slice.

## Execution notes

Executed 2026-08-25. All ten targets landed; every task verified green before its harness was
deleted.

### Measured runtime

`AppUITests` is nine journeys in **333s** wall clock, serial. Per journey, from the final full run:

| Journey | Duration |
|---|---|
| `testTappingADocumentLinkFieldOpensThePicker` | 42s |
| `testCorrespondentLifecycle` | 44s |
| `testDeletingATagRemovedServerSideSurfacesTheConflict` | 29s |
| `testDocumentTypeLifecycle` | 43s |
| `testSavedViewLifecycle` | 46s |
| `testStoragePathLifecycle` | 46s |
| `testTagLifecycle` | 43s |
| `testAddingAServerReachesTheMainScreen` | 28s |
| `testSettingsListsEverySection` | 9s |

Plan 1 measured 29s / 11s / 44s for its three journeys, so the five added here cost roughly 210s and
the per-journey figure is unchanged — each lifecycle is dominated by the per-test user creation and
app launch, not by what it then does. The whole suite, unit targets included, is **1160 tests**.

That is the number the parent spec's sequence step 7 wanted before revisiting the `CI_UI_TESTS`
gate. It wants it again once `CustomFieldsApp`, `DocumentsApp` and `ServersApp` are gone.

### Corrections to this plan

- **Every `tuist test` command here is missing `--no-selective-testing`.** Tuist hashes the test
  targets and skips those unchanged since the last green run, so the second run of an untouched
  `AppUITests` exits with *"The scheme Less Paper's test action has no tests to run, finishing
  early"* and a success status. That reads as a pass and is not one. Every verification step needs
  the flag.
- **`mise run docker:start` cannot be run from the agent VM**, which has no nested virtualization.
  The dev instance on the host stands in via `TUIST_PAPERLESS_TEST_URL`; see `AGENTS.md`.
- **Task 6's steps jump from 3 to 6.** Numbering only — no step is missing.
- **Task 7 names the journey `testDeletingATagRemovedServerSideSurfacesTheConflict`** while the spec
  calls it `testDeletingATagRemovedServerSide`. The plan's name is the one in the tree.

### One defect found, in the test driver rather than the app

`testDocumentTypeLifecycle` failed on its first run: *the renamed
uit-6dda3227-document-types never appeared in the list*. The UI hierarchy captured at failure showed
the list held `uit-6dda3227-document Updated-types` — the suffix inserted **mid-name**.

`EntityListScreen.type` tapped the centre of the field, which on edit already holds the name, so the
caret landed between whichever two characters sat under the midpoint. It looked entity-specific and
is not: the namespace is eight random hex characters, so whether the text ends before or after the
midpoint shifts run to run. Tags passed only because the shorter name clears the midpoint every
time, and correspondents passed by the same luck. Latent flakiness in all five journeys, not a
document-type quirk.

Fixed in `f5c7831` by tapping the trailing edge, where an append has to start. An empty field still
focuses at position 0, so `create` is unaffected.

### Accessibility identifiers added

One, as the spec predicted: `Toast` on `ToastView`, for journey 10. The four entity lifecycles
needed none — every element matched on an existing label, which now holds across seven journeys.

## Global Constraints

- **Comments:** Only `//`. Never `///`, never `/** */`. Comment only when a future reader would otherwise stop and wonder why — never restate the code. (`AGENTS.md`)
- **UI tests use XCTest**, because XCUITest requires it. Unit tests elsewhere use Swift Testing.
- **No UI test may mutate global server state.** No "delete all X". (`AGENTS.md`)
- **Tests always launch with a `UITestConfiguration`**, never with no environment at all. (`AGENTS.md`)
- **Deployment target** iOS 18.0. Destinations `.iPhone`, `.iPad`.
- **After any change to `Tuist/ProjectDescriptionHelpers/`**, regenerate before building or testing: `mise exec -- tuist install && mise exec -- tuist generate --no-open`. Skipping this makes `xcodebuild` report "Supported platforms ... is empty".
- **The test scheme is `"Less Paper"`.** `App` is a target, not a scheme; `tuist build App` fails with "Couldn't find scheme".
- **Test server URL** comes from the Info.plist key `PAPERLESS_TEST_URL`, defaulting to `http://localhost:9000` — the `paperless-ci` instance. `http://localhost:8000` is the dev instance and must not be used for verification.
- **The containers must be running** for every UI test step: `mise run docker:start`.

---

## File Structure

**Created:**

| File | Responsibility |
|---|---|
| `Modules/UITestSupport/Screens/EntityListScreen.swift` | The one list driver, parameterised by `Entity`. |
| `Modules/AppUITests/EntityLifecycleJourneyTests.swift` | Journeys 4–8 and 10. |

**Modified:**

| File | Change |
|---|---|
| `Modules/UITestSupport/Fixtures.swift` | Add `deleteTag(named:)`. |
| `Modules/Components/Toast/ToastView.swift` | Add the `Toast` accessibility identifier. |
| `Tuist/ProjectDescriptionHelpers/Module.swift` | Remove five app cases and five test cases from the enum, `codeCoverageTarget`, `product` and `entitlements`. |
| `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` | Remove the ten matching `case` blocks. |
| `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift` | Remove the app cases from the feature-app scheme list, the ten cases from the empty-scheme list, and five `featureAppTestTargets` branches. |
| `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift` | Remove the five app cases from the shared harness-app branch. |

**Deleted:** `Modules/UITestSupport/Screens/TagListScreen.swift`, `Modules/AppUITests/TagLifecycleJourneyTests.swift`, `Modules/SettingsApp/`, `Modules/SettingsAppTests/`, `Modules/CorrespondentsApp/`, `Modules/CorrespondentsAppTests/`, `Modules/DocumentTypesApp/`, `Modules/DocumentTypesAppTests/`, `Modules/StoragePathsApp/`, `Modules/StoragePathsAppTests/`, `Modules/SavedViewsApp/`, `Modules/SavedViewsAppTests/`.

### The five places a harness deletion touches

Every deletion task below refers back to this list. `Module+Targets.swift` is **not** one of them — it derives everything from the module's own properties.

1. `Module.swift` — the two enum cases; their entries in the `false` branch of `codeCoverageTarget`; the app case in the `.app` branch of `product` and the test case in the `.uiTests` branch. **`SettingsApp` additionally appears in `entitlements`** — no other harness in this slice does.
2. `Module+Dependencies.swift` — the two `case` blocks.
3. `Module+Schemes.swift` — the app case in the feature-app scheme branch (the one whose `testAction` is `featureAppTestTargets`); both cases in the trailing empty-array branch; the `featureAppTestTargets` branch mapping the app to its tests.
4. `Module+InfoPlists.swift` — the app case in the shared harness branch that sets `CFBundleDisplayName` from `rawValue.replacingOccurrences(of: "App", with: "")`.
5. `Modules/<Name>App/` and `Modules/<Name>AppTests/` on disk.

---

## Task 1: Retire the `SettingsApp` harness

`SettingsJourneyTests` has covered `SettingsAppTests.testSettingsList` since `21e8dc9`; Plan 1 Task 7 wrote the journey but only deleted the *Tags* harness. This pair is duplicate coverage and needs no new test, which makes it the safest first exercise of the deletion recipe.

**Files:**
- Delete: `Modules/SettingsApp/`, `Modules/SettingsAppTests/`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`, `Module+InfoPlists.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing. Target topology only.

- [ ] **Step 1: Confirm the journey that replaces it passes**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 4 journeys — `OnboardingJourneyTests`, `SettingsJourneyTests`, `TagLifecycleJourneyTests`, `DocumentCustomFieldJourneyTests`. If `SettingsJourneyTests` does not pass, stop: nothing may be deleted until it does.

- [ ] **Step 2: Delete the module folders**

```bash
git rm -r Modules/SettingsApp Modules/SettingsAppTests
```

- [ ] **Step 3: Remove the Tuist entries**

In `Tuist/ProjectDescriptionHelpers/Module.swift`:

- Delete `case settingsApp = "SettingsApp"` and `case settingsAppTests = "SettingsAppTests"` from the enum.
- Delete `.settingsApp,` and `.settingsAppTests,` from the `false` branch of `codeCoverageTarget`.
- Delete `.settingsApp,` from the `.app` branch of `product`.
- Delete `.settingsAppTests,` from the `.uiTests` branch of `product`.
- Delete `.settingsApp,` from the `entitlements` case list. This one is unique to `SettingsApp` among the five harnesses in this plan — the remaining cases there are `.app`, `.serversApp`, `.shareApp` and `.shareExtension`, all of which stay.

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, delete both blocks:

```swift
        case .settingsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.sharing),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.settingsFeature),
            ]
        case .settingsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.settingsApp),
                .target(.settingsFeature),
            ]
```

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`:

- Delete `.settingsApp,` from the feature-app scheme branch (the `case .correspondentsApp, .customFieldsApp, …` list whose `testAction` is `featureAppTestTargets`).
- Delete `.settingsApp,` and `.settingsAppTests,` from the trailing branch that returns `[]`.
- Delete this `featureAppTestTargets` branch:

```swift
        case .settingsApp:
            [.testableTarget(target: .target(.settingsAppTests))]
```

In `Tuist/ProjectDescriptionHelpers/Module+InfoPlists.swift`, delete `.settingsApp,` from the harness-app case list (`case .correspondentsApp, .customFieldsApp, …`).

- [ ] **Step 4: Regenerate and verify the project builds**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist build "Less Paper" -d "iPhone 17 Pro"
```

Expected: Build Succeeded. A `switch must be exhaustive` error means an enum case was removed without removing one of its `switch` entries — the compiler names the file and the property.

- [ ] **Step 5: Verify the suite still passes**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, the same 4 journeys as Step 1. `SettingsFeatureTests` is untouched — only the harness app and its XCUITests are gone.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: retire the SettingsApp UI test harness"
```

---

## Task 2: `EntityListScreen`, replacing `TagListScreen`

The generalisation is mechanical: `TagListScreen`'s only entity-specific strings are `Add tag`, `Edit tag` and `Delete tag`, and the string catalog gives every entity the same three keys. This task changes no behaviour — `testTagLifecycle` must do exactly what `TagLifecycleJourneyTests` did — so a failure here is attributable before any new entity is added.

**Files:**
- Create: `Modules/UITestSupport/Screens/EntityListScreen.swift`
- Create: `Modules/AppUITests/EntityLifecycleJourneyTests.swift`
- Delete: `Modules/UITestSupport/Screens/TagListScreen.swift`, `Modules/AppUITests/TagLifecycleJourneyTests.swift`

**Interfaces:**
- Consumes: `UITestCase` (`app`, `timeout`, `user`, `launch(seedingServer:)`); `SettingsScreen(app:timeout:)` with `open()` and `openSection(_:)`; `XCUIApplication.tapSwipeAction(_:in:timeout:)`; `XCUIElement.waitUntilHittable(timeout:)`.
- Produces:
  - `EntityListScreen(app:entity:timeout:)`
  - `EntityListScreen.Entity` with `.correspondent`, `.documentType`, `.savedView`, `.storagePath`, `.tag`
  - `EntityListScreen.create(named:extras:) -> Bool` where `extras: (EntityListScreen) -> Void`
  - `EntityListScreen.edit(named:appending:) -> Bool`
  - `EntityListScreen.delete(named:) -> Bool`
  - `EntityListScreen.type(_:into:) -> Bool` — public so an `extras` closure can reach it
  - `EntityListScreen.row(named:) -> XCUIElement?` — public so journey 10 can assert a row survived

- [ ] **Step 1: Write the driver**

Create `Modules/UITestSupport/Screens/EntityListScreen.swift`:

```swift
import Foundation
import XCTest

@MainActor
public struct EntityListScreen {

    public struct Entity: Sendable {

        public static let correspondent = Self(
            add: "Add correspondent",
            delete: "Delete correspondent",
            edit: "Edit correspondent"
        )

        public static let documentType = Self(
            add: "Add document type",
            delete: "Delete document type",
            edit: "Edit document type"
        )

        public static let savedView = Self(
            add: "Add saved view",
            delete: "Delete saved view",
            edit: "Edit saved view"
        )

        public static let storagePath = Self(
            add: "Add storage path",
            delete: "Delete storage path",
            edit: "Edit storage path"
        )

        public static let tag = Self(
            add: "Add tag",
            delete: "Delete tag",
            edit: "Edit tag"
        )

        let add: String

        let delete: String

        let edit: String
    }

    public let app: XCUIApplication

    public let entity: Entity

    public let timeout: TimeInterval

    public init(
        app: XCUIApplication,
        entity: Entity,
        timeout: TimeInterval = 10.0
    ) {
        self.app = app
        self.entity = entity
        self.timeout = timeout
    }

    @discardableResult
    public func create(
        named name: String,
        extras: (Self) -> Void = { _ in }
    ) -> Bool {
        // The list renders a ProgressView until updateCache resolves, so the toolbar button does
        // not exist at launch and tapping straight away races that fetch.
        let addButton = app.buttons[entity.add].firstMatch
        guard addButton.waitForExistence(timeout: timeout) else {
            return false
        }
        addButton.tap()

        guard type(name, into: "Name") else {
            return false
        }
        extras(self)

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func delete(named name: String) -> Bool {
        guard let row = row(named: name) else {
            return false
        }
        app.tapSwipeAction(entity.delete, in: row, timeout: timeout)

        let confirm = app.buttons["Confirm"].firstMatch
        guard confirm.waitForExistence(timeout: timeout) else {
            return false
        }
        confirm.tap()
        return app.staticTexts[name].waitForNonExistence(timeout: timeout)
    }

    @discardableResult
    public func edit(
        named name: String,
        appending suffix: String
    ) -> Bool {
        guard let row = row(named: name) else {
            return false
        }
        app.tapSwipeAction(entity.edit, in: row, timeout: timeout)

        guard type(suffix, into: "Name") else {
            return false
        }

        app.buttons["Save"].tap()
        return app.buttons["Save"].waitForNonExistence(timeout: timeout)
    }

    public func row(named name: String) -> XCUIElement? {
        let row = app.cells.containing(.staticText, identifier: name).firstMatch
        guard row.waitForExistence(timeout: timeout) else {
            return nil
        }
        return row
    }

    @discardableResult
    public func type(
        _ text: String,
        into field: String
    ) -> Bool {
        let element = app.textFields[field]
        guard element.waitForExistence(timeout: timeout) else {
            return false
        }
        element.tap()
        app.typeText(text)
        return true
    }
}
```

- [ ] **Step 2: Write the journey file with the tag journey moved into it**

Create `Modules/AppUITests/EntityLifecycleJourneyTests.swift`. Only `testTagLifecycle` exists at this point; Tasks 3–6 each add one method.

```swift
import UITestSupport
import XCTest

@MainActor
final class EntityLifecycleJourneyTests: UITestCase {

    func testTagLifecycle() async throws {
        runLifecycle(for: .tag, section: "Tags")
    }

    // The test user owns nothing at start, so every list here opens empty and no method can see
    // another's rows.
    private func runLifecycle(
        for entity: EntityListScreen.Entity,
        section: String,
        extras: (EntityListScreen) -> Void = { _ in }
    ) {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection(section), "Could not open the \(section) section")

        let list = EntityListScreen(app: app, entity: entity, timeout: timeout)
        let name = "\(user.namespace)-\(section.lowercased().replacingOccurrences(of: " ", with: "-"))"

        XCTAssertTrue(list.create(named: name, extras: extras), "Could not create \(name)")
        XCTAssertTrue(
            app.staticTexts[name].waitForExistence(timeout: timeout),
            "The created \(name) never appeared in the list"
        )

        XCTAssertTrue(list.edit(named: name, appending: " Updated"), "Could not edit \(name)")
        XCTAssertTrue(
            app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout),
            "The renamed \(name) never appeared in the list"
        )

        XCTAssertTrue(list.delete(named: "\(name) Updated"), "Could not delete \(name)")
    }
}
```

- [ ] **Step 3: Delete the two files this replaces**

```bash
git rm Modules/UITestSupport/Screens/TagListScreen.swift Modules/AppUITests/TagLifecycleJourneyTests.swift
```

- [ ] **Step 4: Run to verify the moved journey passes**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 4 journeys — the same count as before, with `EntityLifecycleJourneyTests.testTagLifecycle` in place of `TagLifecycleJourneyTests.testCreateEditAndDeleteATag`. Anything else means the generalisation changed behaviour; fix it here rather than carrying it into Task 3.

- [ ] **Step 5: Commit**

```bash
git add -A Modules/UITestSupport Modules/AppUITests
git commit -m "refactor: generalise the tag list driver into EntityListScreen"
```

---

## Task 3: Journey 5 — correspondent lifecycle, and retire `CorrespondentsApp`

Replaces `CorrespondentsAppTests.testCreate`, `.testList`, `.testUpdate` and `.testDelete`. `.testDeleteFailure` is replaced by journey 10 in Task 7 — see this plan's Self-Review for why that ordering is safe.

The correspondent form has one field, `Name`, so no `extras` closure is needed. Confirmed against `CorrespondentsAppTests.testCreate`, which types into `app.textFields["Name"]` and nothing else.

**Files:**
- Modify: `Modules/AppUITests/EntityLifecycleJourneyTests.swift`
- Delete: `Modules/CorrespondentsApp/`, `Modules/CorrespondentsAppTests/`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`, `Module+InfoPlists.swift`

**Interfaces:**
- Consumes: `EntityListScreen.Entity.correspondent` and `runLifecycle(for:section:extras:)` (Task 2).
- Produces: nothing new.

- [ ] **Step 1: Write the failing journey**

Add to `EntityLifecycleJourneyTests`, above `testTagLifecycle`:

```swift
    func testCorrespondentLifecycle() async throws {
        runLifecycle(for: .correspondent, section: "Correspondents")
    }
```

- [ ] **Step 2: Run to verify it passes**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 5 journeys. This is the one place the plan expects a new test to pass first try — the correspondent list is the tag list with different labels. If it fails, record *how*: a missing element means an accessibility identifier is needed on `CorrespondentListView` or `CorrespondentFormView`; a visible error in the app means something real is broken. Add the identifier to the view, never an index-based query to the test.

- [ ] **Step 3: Commit the journey**

```bash
git add Modules/AppUITests/EntityLifecycleJourneyTests.swift
git commit -m "test: add the correspondent lifecycle journey"
```

- [ ] **Step 4: Delete the harness**

```bash
git rm -r Modules/CorrespondentsApp Modules/CorrespondentsAppTests
```

Then apply the five-place recipe from File Structure. In `Module.swift`: remove `case correspondentsApp` and `case correspondentsAppTests` from the enum; remove `.correspondentsApp,` and `.correspondentsAppTests,` from the `false` branch of `codeCoverageTarget`; remove `.correspondentsApp,` from the `.app` branch of `product` and `.correspondentsAppTests,` from the `.uiTests` branch. `CorrespondentsApp` does **not** appear in `entitlements`.

In `Module+Dependencies.swift`, delete both blocks:

```swift
        case .correspondentsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.correspondentsFeature)
            ]
        case .correspondentsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.correspondentsApp),
                .target(.correspondentsFeature),
                .target(.uiTestSupport),
            ]
```

In `Module+Schemes.swift`: remove `.correspondentsApp,` from the feature-app scheme branch, remove `.correspondentsApp,` and `.correspondentsAppTests,` from the trailing `[]` branch, and delete this `featureAppTestTargets` branch:

```swift
        case .correspondentsApp:
            [.testableTarget(target: .target(.correspondentsAppTests))]
```

In `Module+InfoPlists.swift`, remove `.correspondentsApp,` from the harness-app case list.

- [ ] **Step 5: Regenerate and verify**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 5 journeys. `CorrespondentsFeatureTests` is untouched.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: retire the CorrespondentsApp UI test harness"
```

---

## Task 4: Journey 6 — document type lifecycle, and retire `DocumentTypesApp`

Replaces `DocumentTypesAppTests.testCreate`, `.testList`, `.testUpdate` and `.testDelete`. One field, `Name`, confirmed against `DocumentTypesAppTests.testCreate`.

**Files:**
- Modify: `Modules/AppUITests/EntityLifecycleJourneyTests.swift`
- Delete: `Modules/DocumentTypesApp/`, `Modules/DocumentTypesAppTests/`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`, `Module+InfoPlists.swift`

**Interfaces:**
- Consumes: `EntityListScreen.Entity.documentType` and `runLifecycle(for:section:extras:)` (Task 2).
- Produces: nothing new.

- [ ] **Step 1: Write the journey**

Add to `EntityLifecycleJourneyTests`, in alphabetical position among the test methods:

```swift
    func testDocumentTypeLifecycle() async throws {
        runLifecycle(for: .documentType, section: "Document types")
    }
```

The section label is `Document types` — sentence case, as `SettingsJourneyTests` already asserts. `Document Types` will not match.

- [ ] **Step 2: Run to verify it passes**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 6 journeys.

- [ ] **Step 3: Commit the journey**

```bash
git add Modules/AppUITests/EntityLifecycleJourneyTests.swift
git commit -m "test: add the document type lifecycle journey"
```

- [ ] **Step 4: Delete the harness**

```bash
git rm -r Modules/DocumentTypesApp Modules/DocumentTypesAppTests
```

Then, following the same five-place recipe: in `Module.swift` remove `case documentTypesApp` and `case documentTypesAppTests` from the enum, from the `false` branch of `codeCoverageTarget`, and from the `.app` and `.uiTests` branches of `product` respectively. Not present in `entitlements`.

In `Module+Dependencies.swift`, delete both blocks:

```swift
        case .documentTypesApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.documentTypesFeature)
            ]
        case .documentTypesAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.documentTypesApp),
                .target(.documentTypesFeature),
                .target(.uiTestSupport),
            ]
```

Copy the exact contents from the file rather than trusting the block above verbatim — it is reproduced here so the shape is recognisable, and the two dependency lists differ slightly between harnesses.

In `Module+Schemes.swift`: remove `.documentTypesApp,` from the feature-app scheme branch, remove `.documentTypesApp,` and `.documentTypesAppTests,` from the trailing `[]` branch, and delete:

```swift
        case .documentTypesApp:
            [.testableTarget(target: .target(.documentTypesAppTests))]
```

In `Module+InfoPlists.swift`, remove `.documentTypesApp,` from the harness-app case list.

- [ ] **Step 5: Regenerate and verify**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 6 journeys.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: retire the DocumentTypesApp UI test harness"
```

---

## Task 5: Journey 7 — storage path lifecycle, and retire `StoragePathsApp`

Replaces `StoragePathsAppTests.testCreate`, `.testList`, `.testUpdate` and `.testDelete`. This is the first journey to use the `extras` closure: the storage path form has a second required field, `Path`, which `StoragePathsAppTests.testCreate` fills with `/home/paperless/new-storage-path`.

**Files:**
- Modify: `Modules/AppUITests/EntityLifecycleJourneyTests.swift`
- Delete: `Modules/StoragePathsApp/`, `Modules/StoragePathsAppTests/`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`, `Module+InfoPlists.swift`

**Interfaces:**
- Consumes: `EntityListScreen.Entity.storagePath`, `runLifecycle(for:section:extras:)` and `EntityListScreen.type(_:into:)` (Task 2); `UITestCase.user.namespace`.
- Produces: nothing new.

- [ ] **Step 1: Write the journey**

Add to `EntityLifecycleJourneyTests`:

```swift
    func testStoragePathLifecycle() async throws {
        runLifecycle(for: .storagePath, section: "Storage paths") { list in
            // Paperless rejects a storage path with no path, so this one is required rather than
            // decorative — create() returns false without it.
            list.type("/home/paperless/\(user.namespace)", into: "Path")
        }
    }
```

- [ ] **Step 2: Run to verify it passes**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 7 journeys. If `create` returns false, the likeliest cause is the `Path` field not being a plain `textFields` element — check `StoragePathFormView` and adjust `type(_:into:)`'s query, not the test.

- [ ] **Step 3: Commit the journey**

```bash
git add Modules/AppUITests/EntityLifecycleJourneyTests.swift
git commit -m "test: add the storage path lifecycle journey"
```

- [ ] **Step 4: Delete the harness**

```bash
git rm -r Modules/StoragePathsApp Modules/StoragePathsAppTests
```

Then the same five-place recipe for `storagePathsApp` and `storagePathsAppTests`: the enum, the `false` branch of `codeCoverageTarget`, the `.app` and `.uiTests` branches of `product` in `Module.swift`; both `case` blocks in `Module+Dependencies.swift`; the feature-app scheme branch, the trailing `[]` branch and the `featureAppTestTargets` branch in `Module+Schemes.swift`; the harness-app case list in `Module+InfoPlists.swift`. Not present in `entitlements`.

- [ ] **Step 5: Regenerate and verify**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 7 journeys.

- [ ] **Step 6: Commit**

```bash
git add -A
git commit -m "refactor: retire the StoragePathsApp UI test harness"
```

---

## Task 6: Journey 8 — saved view lifecycle, and retire `SavedViewsApp`

Replaces `SavedViewsAppTests.testCreate`, `.testList`, `.testUpdate` and `.testDelete`. The saved view form adds two switches rather than a text field: `Show in sidebar` and `Show on dashboard`. `SavedViewsAppTests.testCreate` taps both and then asserts the row carries matching images, which is worth keeping — it is the only per-entity assertion in this plan that goes beyond the name.

**Files:**
- Modify: `Modules/AppUITests/EntityLifecycleJourneyTests.swift`
- Delete: `Modules/SavedViewsApp/`, `Modules/SavedViewsAppTests/`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift`, `Module+Dependencies.swift`, `Module+Schemes.swift`, `Module+InfoPlists.swift`

**Interfaces:**
- Consumes: `EntityListScreen.Entity.savedView`, `runLifecycle(for:section:extras:)` and `EntityListScreen.row(named:)` (Task 2).
- Produces: nothing new.

- [ ] **Step 1: Write the journey**

This is the one entity that does **not** call `runLifecycle`. The badges must be asserted between creation and edit, and `runLifecycle` deletes the row at the end — so a check placed after it could only prove absence. Drive the steps directly instead of widening `runLifecycle` with a hook no other entity uses.

Add to `EntityLifecycleJourneyTests`:

```swift
    func testSavedViewLifecycle() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Saved views"), "Could not open the Saved views section")

        let list = EntityListScreen(app: app, entity: .savedView, timeout: timeout)
        let name = "\(user.namespace)-saved-view"

        XCTAssertTrue(
            list.create(named: name) {
                app.switches["Show in sidebar"].tap()
                app.switches["Show on dashboard"].tap()
            },
            "Could not create \(name)"
        )

        // The badges are the only per-entity detail any lifecycle journey asserts: both switches
        // were on at creation, so both images must be on the row.
        let row = try XCTUnwrap(list.row(named: name), "The created \(name) never appeared")
        XCTAssertTrue(row.images["Show in sidebar"].exists)
        XCTAssertTrue(row.images["Show on dashboard"].exists)

        XCTAssertTrue(list.edit(named: name, appending: " Updated"), "Could not edit \(name)")
        XCTAssertTrue(
            app.staticTexts["\(name) Updated"].waitForExistence(timeout: timeout),
            "The renamed \(name) never appeared in the list"
        )

        XCTAssertTrue(list.delete(named: "\(name) Updated"), "Could not delete \(name)")
    }
```

- [ ] **Step 2: Run to verify it passes**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 8 journeys. If the switches are not found as `app.switches`, check `SavedViewFormView` — `SavedViewsAppTests.testCreate` tapped them by exactly these labels, so a miss means the form changed since.

- [ ] **Step 3: Commit the journey**

```bash
git add Modules/AppUITests/EntityLifecycleJourneyTests.swift
git commit -m "test: add the saved view lifecycle journey"
```

- [ ] **Step 6: Delete the harness**

```bash
git rm -r Modules/SavedViewsApp Modules/SavedViewsAppTests
```

Then the same five-place recipe for `savedViewsApp` and `savedViewsAppTests`. Not present in `entitlements`.

- [ ] **Step 7: Regenerate and verify**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 8 journeys.

- [ ] **Step 8: Commit**

```bash
git add -A
git commit -m "refactor: retire the SavedViewsApp UI test harness"
```

---

## Task 7: Journey 10 — the stale-delete conflict

Replaces the `testDeleteFailure` tests retired in Tasks 3–6, and closes the tag one that Plan 1 left open when it retired `TagsApp`.

**Do not copy the old harness assertion.** All five expect an empty-state string — `No StoragePath matches the given query.` and siblings — that the app no longer renders; the list empty states are now `EmptyListView(title: .noTagsFound)`, rendering `No tags found`. Reading `TagListReducer+Effect.swift` instead: `runDeleteTag`'s `catch` sends `.error(error)` then `.isUpdating(id:isUpdating: false)`, and never `.tagDeleted(id)`. So the row **stays** and an error toast appears. That the row survives is the assertion worth having — it is the app declining to report a delete that failed.

The toast's text is `error.localizedDescription` from a paperless 404, too brittle to match on, and `ToastView` carries no identifier. It gets one — a view change, as the parent spec directs, not a brittle query.

**Files:**
- Modify: `Modules/Components/Toast/ToastView.swift`
- Modify: `Modules/UITestSupport/Fixtures.swift`
- Modify: `Modules/AppUITests/EntityLifecycleJourneyTests.swift`

**Interfaces:**
- Consumes: `withAdminDependencies` (public, `Modules/UITestSupport/TestUser.swift`); `TagsRepository.getTags(input:server:)` and `.deleteTag(id:server:)` (internal to `ApiImplementation`, reached through the existing `@testable import`); `GetTagsInput()`; `Server.testValue()`; `EntityListScreen.create(named:)` and `.row(named:)` (Task 2).
- Produces: `Fixtures.deleteTag(named: String) async throws`

- [ ] **Step 1: Give the toast an identifier**

Modify `Modules/Components/Toast/ToastView.swift` — add two modifiers to the end of the `HStack` chain in `body`, after `.frame(maxWidth: 600)`:

```swift
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("Toast")
```

`children: .contain` keeps the message text queryable as a descendant rather than flattening it into a single label, so a later journey can still assert on toast copy if it needs to.

- [ ] **Step 2: Add the fixture helper**

Add to `Modules/UITestSupport/Fixtures.swift`, inside `enum Fixtures`:

```swift
    // Deletes as admin: a superuser can remove an object the per-test user owns, and the test
    // knows the tag only by the name it typed into the form.
    public static func deleteTag(named name: String) async throws {
        try await withAdminDependencies {
            @Dependency(\.tagsRepository)
            var tagsRepository

            let tags = try await tagsRepository.getTags(
                input: GetTagsInput(),
                server: .testValue()
            ).results

            guard let tag = tags.first(where: { $0.name == name }) else {
                return
            }

            _ = try await tagsRepository.deleteTag(
                id: tag.id,
                server: .testValue()
            )
        }
    }
```

This reads one page, as `sweepOrphans` and `sweepOrphanedCustomFields` already do — `PAPERLESS_PAGE_SIZE` is 100 and the container holds roughly a dozen tags.

- [ ] **Step 3: Write the failing journey**

Add to `EntityLifecycleJourneyTests`:

```swift
    func testDeletingATagRemovedServerSideSurfacesTheConflict() async throws {
        launch()

        let settings = SettingsScreen(app: app, timeout: timeout)
        XCTAssertTrue(settings.open(), "Could not open the Settings tab")
        XCTAssertTrue(settings.openSection("Tags"), "Could not open the Tags section")

        let list = EntityListScreen(app: app, entity: .tag, timeout: timeout)
        let name = "\(user.namespace)-stale"

        XCTAssertTrue(list.create(named: name), "Could not create \(name)")
        let row = try XCTUnwrap(list.row(named: name), "The created \(name) never appeared")

        try await Fixtures.deleteTag(named: name)

        app.tapSwipeAction("Delete tag", in: row, timeout: timeout)
        let confirm = app.buttons["Confirm"].firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: timeout), "No delete confirmation appeared")
        confirm.tap()

        XCTAssertTrue(
            app.otherElements["Toast"].waitForExistence(timeout: timeout),
            "The failed delete surfaced no toast"
        )

        // The row must outlive the failed delete. Removing it optimistically would report a
        // success the server never granted.
        XCTAssertTrue(
            app.staticTexts[name].exists,
            "The row disappeared even though the delete failed"
        )
    }
```

- [ ] **Step 4: Run to verify it fails**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: FAIL on the toast assertion if Step 1 was skipped. Run it with Steps 1 and 2 in place and it should pass; if the toast is found but the row assertion fails, the reducer *is* removing the row optimistically and that is a genuine app bug — report it rather than relaxing the assertion.

- [ ] **Step 5: Run to verify it passes**

```bash
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 9 journeys.

- [ ] **Step 6: Verify no test user or tag leaked**

```bash
curl -s -u admin:'T0PS3CR3T!!123' 'http://localhost:9000/api/users/' \
  | python3 -c "import json,sys; print([u['username'] for u in json.load(sys.stdin)['results']])"
```

Expected: `['admin']`. Port 9000 is the `paperless-ci` instance the tests target; 8000 is the dev instance and would always look clean. Tags owned by a deleted user may remain — the parent spec's Task 5 recorded that deletion does not cascade, and it is invisible to later tests.

- [ ] **Step 7: Commit**

```bash
git add Modules/Components/Toast/ToastView.swift Modules/UITestSupport/Fixtures.swift Modules/AppUITests/EntityLifecycleJourneyTests.swift
git commit -m "test: add the stale-delete conflict journey"
```

---

## Task 8: Measure and record the runtime

Plan 1 recorded 29s / 11s / 44s for its three journeys. The suite is now nine. The parent spec's sequence step 7 — revisiting the `CI_UI_TESTS` gate — wants this number, and wants it again after the last harnesses go, so recording it here is the input to a later decision rather than the decision itself.

**Files:**
- Modify: `docs/superpowers/plans/2026-08-25-ui-testing-entity-lifecycles.md`

**Interfaces:**
- Consumes: nothing.
- Produces: nothing.

- [ ] **Step 1: Run the whole suite clean and time it**

```bash
mise run docker:start
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets AppUITests
```

Expected: PASS, 9 journeys — `OnboardingJourneyTests`, `SettingsJourneyTests`, `DocumentCustomFieldJourneyTests`, and the six in `EntityLifecycleJourneyTests`.

- [ ] **Step 2: Record the per-journey times**

Add an "Execution notes" section directly under this plan's **Scope** line, in the shape Plan 1 used — the measured per-journey durations, the total, and any command in this plan that turned out to be wrong, so the next slice does not repeat it.

- [ ] **Step 3: Verify the whole project still builds and the full suite passes**

```bash
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro"
```

Expected: PASS. This is the first run in this plan that includes every unit test target, not just `AppUITests` — it catches a `Module+*.swift` edit that broke a target no UI test builds.

- [ ] **Step 4: Commit**

```bash
git add docs/superpowers/plans/2026-08-25-ui-testing-entity-lifecycles.md
git commit -m "docs: record the entity lifecycle journey runtimes"
```

---

## Self-Review

**Spec coverage.** Spec sequence step 1 → Task 1. Step 2 → Task 2. Steps 3–6 → Tasks 3–6. Step 7 → Task 7. Step 8 → Task 8. The spec's `EntityListScreen` section is Task 2 Step 1, its `EntityLifecycleJourneyTests` section is Task 2 Step 2 plus one method per later task, and its journey 10 section is Task 7. The "five places a harness deletion touches" recipe is stated once in File Structure and referenced by each deletion task, with the per-entity dependency blocks spelled out where they differ.

**One correction the spec did not survive first contact with.** The spec as first written told journey 10 to expect `No Tag matches the given query.`, inherited from the harness tests. Reading `TagListView` and `TagListReducer+Effect.swift` showed the app renders `No tags found` and, more importantly, does not empty the list at all on a failed delete — it toasts and leaves the row. The spec was corrected before this plan was written and both now describe the toast-plus-surviving-row assertion. The consequence for Task 7 is one accessibility identifier on `ToastView`, the first the rework has needed.

**Task 6 is the one journey that does not call `runLifecycle`.** The saved view row carries `Show in sidebar` and `Show on dashboard` badges that must be asserted between creation and edit, and `runLifecycle` deletes the row at the end — a check after it could only prove absence. Widening `runLifecycle` with a mid-lifecycle hook that four of five entities pass empty would be worse than one journey driving its own steps, so Task 6 states the reason and drives them.

**Placeholder scan.** No TBD/TODO. Every code step carries its code. Task 8 Step 2 asks for measured numbers that do not exist until the step runs — that is a measurement, not a placeholder, and the step names exactly what to record and where.

**Type consistency.** `EntityListScreen(app:entity:timeout:)` is constructed identically in Tasks 2, 6 and 7. `Entity` values are defined once in Task 2 Step 1 and referenced as `.correspondent`, `.documentType`, `.savedView`, `.storagePath` and `.tag` in Tasks 3–7. `create(named:extras:)`, `edit(named:appending:)`, `delete(named:)`, `row(named:)` and `type(_:into:)` are defined in Task 2 and used with those exact signatures afterwards. Both `extras` closures take the screen — `create`'s is `(Self) -> Void` calling `extras(self)`, and `runLifecycle`'s is `(EntityListScreen) -> Void` passed straight through — so Task 5's closure reaches `type(_:into:)` without building a second screen. `runLifecycle(for:section:extras:)` is defined in Task 2 Step 2 and called in Tasks 3, 4 and 5. `Fixtures.deleteTag(named:)` is produced in Task 7 Step 2 and called in Task 7 Step 3. `SettingsScreen.open()` and `.openSection(_:)` match what is already in `Modules/UITestSupport/Screens/SettingsScreen.swift`.

**Section labels are the settings rows, verified against `SettingsJourneyTests`:** `Correspondents`, `Document types`, `Saved views`, `Storage paths`, `Tags` — sentence case throughout.

**Known gap, deliberately left.** Journey 10 runs on tags only. If the conflict surface turns out entity-specific, the four other entities lose coverage. The parent spec accepted this; the slice spec records that what is being retired asserts a string the app stopped rendering, so the coverage lost is smaller than the test names suggest.
