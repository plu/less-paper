# UI Testing Last Harnesses Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Write journeys 2, 9, 11 and 12, retire the `ServersApp`, `CustomFieldsApp` and `DocumentsApp` pairs — seven targets — and settle the `CI_UI_TESTS` gate. After this, `ShareApp` is the only harness left.

**Architecture:** Journeys join the existing `AppUITests` files. `EntityListScreen` covers the custom-field list unchanged — the string catalog gives it the same `Add/Edit/Delete X` shape. Servers keep `ServerFormScreen`, which already drives their four-field form. Two new drivers: `CustomFieldFormScreen` for the option matrix and `DocumentListScreen` for browsing.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-sharing, Tuist 4.205.0, Swift Testing (unit), XCTest/XCUITest (UI), paperless-ngx 3.0.5.

**Spec:** [2026-08-26-ui-testing-rework-last-harnesses-design.md](../specs/2026-08-26-ui-testing-rework-last-harnesses-design.md)

**Parent spec:** [2026-08-24-ui-testing-rework-design.md](../specs/2026-08-24-ui-testing-rework-design.md)

## Global Constraints

- **Comments:** Only `//`. Never `///`, never `/** */`. Comment only when a future reader would otherwise stop and wonder why. (`AGENTS.md`)
- **Never run Docker.** Verify against the dev instance on the host — `export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000` before `tuist generate` *and* `tuist test`. (`AGENTS.md`)
- **Every `tuist test` needs `--no-selective-testing`**, or an unchanged target reports success having run nothing.
- **No UI test may mutate global server state**, and the document corpus is read-only — a test that modifies a document uploads its own first. (`AGENTS.md`)
- **Custom fields are global**: namespace by name, never assert on list totals. (`AGENTS.md`)
- **Typing into a pre-filled field** must go through `EntityListScreen.type`'s trailing-edge tap, never a bare `element.tap()`.
- **After any `Tuist/ProjectDescriptionHelpers/` change**, regenerate before building.
- The test scheme is `"Less Paper"`; the device is `iPhone 17 Pro`.

## The five places a harness deletion touches

Unchanged from Plan 2, and verified against it three times:

1. `Module.swift` — the two enum cases; their entries in the `false` branch of `codeCoverageTarget`; the app case in the `.app` branch of `product` and the test case in the `.uiTests` branch. **`ServersApp` additionally appears in `entitlements`.**
2. `Module+Dependencies.swift` — the two `case` blocks.
3. `Module+Schemes.swift` — the app case in the feature-app scheme branch; the test case in the trailing `[]` branch; the `featureAppTestTargets` branch.
4. `Module+InfoPlists.swift` — the app case in the shared harness branch.
5. `Modules/<Name>App/` and `Modules/<Name>AppTests/` on disk.

**Watch the case-list terminator.** Several of these lists end with the entry being removed (`… .shareApp, .storagePathsApp:`). Deleting the last line leaves the previous one ending in `,` with no colon. Promote it. `sed` line addresses refer to *input* numbering, so a delete and a substitution of a different line compose in one pass; deleting and substituting the *same* line does not.

---

## Task 1: Cover the custom-field cancel path

Parent sequence step 4 requires the blank-option assertions to be reducer tests before `CustomFieldsApp` dies. Most already are — see the spec. The gap is the cancel path: `cancelButtonTapped` and `closeButtonTapped` both run `dismiss()` and nothing sends either.

**Files:** Modify `Modules/CustomFieldsFeatureTests/CustomFieldForm/CustomFieldFormReducerTests.swift`

- [ ] **Step 1: Write the failing test**

Add a test that sends `.view(.cancelButtonTapped)` with a blank option present and asserts the dismissal runs — the shape `test_view_deleteOptionButtonTapped` already uses, with `@Dependency(\.dismiss)` overridden to record. Add the `closeButtonTapped` case alongside it if the assertion is one line.

- [ ] **Step 2: Run**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --test-targets CustomFieldsFeatureTests --no-selective-testing
```

Expected: PASS.

- [ ] **Step 3: Commit** — `test: cover the custom field form's cancel path`

---

## Task 2: Journey 2 — server management, and retire `ServersApp`

Replaces the rest of `ServersAppTests.testCRUD`. Journey 1 already adds the first server for real.

**Do not delete the journey's own server.** It is the server the app is running on; deleting it logs the app out, and the harness's `No servers found` empty state is unreachable from here. Add a *second* server, switch to it, edit its alias, delete it, and assert the first survives.

**Files:**
- Create: `Modules/AppUITests/ServerManagementJourneyTests.swift`
- Delete: `Modules/ServersApp/`, `Modules/ServersAppTests/`
- Modify: the four Tuist helpers

- [ ] **Step 1: Write the journey**

Settings → Servers. `ServerFormScreen.addServer(alias:url:username:password:)` already drives the form; it types into empty fields, so it needs no change. The second server points at the same URL with alias `<namespace>-second`.

Assert: the row appears with subtitle `admin @ <url>`; tapping it selects it (the checkmark moves); the swipe actions are `Edit server` and `Delete server`; after delete, the seeded row is still there.

Editing the alias types into a **pre-filled** field — use the trailing-edge tap, not `element.tap()`.

- [ ] **Step 2: Run and record what it needed**

Expected: PASS, 10 journeys. `ServerRowView` applies `.accessibilityElement()` with an `accessibilityValue`, which may flatten the alias out of `staticTexts` — the entity rows do the same and stayed queryable, so this is expected to work, but if the alias is not found, match on the row's `accessibilityValue` or add an identifier to the view. Never an index-based query.

- [ ] **Step 3: Commit the journey** — `test: add the server management journey`
- [ ] **Step 4: Delete the harness** — the five places; `ServersApp` **is** in `entitlements`.
- [ ] **Step 5: Regenerate, build, run.** Expected: PASS, 10 journeys.
- [ ] **Step 6: Commit** — `refactor: retire the ServersApp UI test harness`

---

## Task 3: Journey 9 — custom fields, and retire `CustomFieldsApp`

Replaces six of eight `CustomFieldsAppTests`; the two blank-option tests are covered by Task 1 plus what already exists.

Custom fields are global. Namespace every field `uit-<namespace>-<label>`, delete them in `tearDown`, and never assert on list totals.

**Files:**
- Create: `Modules/UITestSupport/Screens/CustomFieldFormScreen.swift`
- Create: `Modules/AppUITests/CustomFieldJourneyTests.swift`
- Delete: `Modules/CustomFieldsApp/`, `Modules/CustomFieldsAppTests/`
- Modify: the four Tuist helpers

- [ ] **Step 1: Write the driver**

`EntityListScreen` already covers the list — add `Entity.customField` (`Add custom field` / `Edit custom field` / `Delete custom field`). The form's extras go in `CustomFieldFormScreen`: choose a data type, add an option, read an option's value.

The data-type picker is a SwiftUI menu `Picker` **exposed as a button labelled with its current value** — `Text`, not `Data type`. That subtlety is recorded in the harness and must survive.

- [ ] **Step 2: Write the journey**

Two methods:

- `testTextCustomFieldLifecycle` — create, appears, delete.
- `testSelectCustomFieldRoundTripsItsOptions` — create with data type `Select`, add one option, save, reopen, assert the option persisted.

**Do not tap the new option row before typing.** It takes focus when it appears; a tap would hide a regression in that hand-off. This is the one place the harness's exact sequence matters.

- [ ] **Step 3: Run.** Expected: PASS, 12 journeys.
- [ ] **Step 4: Commit the journey** — `test: add the custom field journeys`
- [ ] **Step 5: Delete the harness.** Not in `entitlements`.
- [ ] **Step 6: Regenerate, run, commit** — `refactor: retire the CustomFieldsApp UI test harness`

---

## Task 4: Journey 11 — document browsing, and retire `DocumentsApp`

Replaces `DocumentsAppTests.testList`, expanded to open a document and view its PDF.

The corpus is unowned and shared. **Read only** — no upload, no edit, no delete.

**Files:**
- Create: `Modules/UITestSupport/Screens/DocumentListScreen.swift`
- Create: `Modules/AppUITests/DocumentBrowsingJourneyTests.swift`
- Delete: `Modules/DocumentsApp/`, `Modules/DocumentsAppTests/`
- Modify: the four Tuist helpers

- [ ] **Step 1: Write the driver and journey**

Filter by title through the `Filter` button and the `Title & content` field, then close. The harness slept 700ms for the debounce; **wait on the filtered result instead** — `waitForExistence` on the expected row, and on the `2 of 2 loaded` count.

Then open `Lego Duplo`, assert the PDF view appears, and go back to the list.

- [ ] **Step 2: Run.** Expected: PASS, 13 journeys. Document browsing is the screen the parent spec flagged as most likely to need identifiers — if a query is ambiguous inside the assembled navigation stack, add an identifier to the view.
- [ ] **Step 3: Commit the journey** — `test: add the document browsing journey`
- [ ] **Step 4: Delete the harness.** Not in `entitlements`.
- [ ] **Step 5: Regenerate, run, commit** — `refactor: retire the DocumentsApp UI test harness`

---

## Task 5: Journey 12 — document custom-field editing

The parent spec's journey 12: a document the test uploaded itself, because it modifies one. Joins `DocumentCustomFieldJourneyTests` rather than replacing the #192 guard already there.

**Files:**
- Modify: `Modules/UITestSupport/Fixtures.swift`, `Modules/AppUITests/DocumentCustomFieldJourneyTests.swift`

- [ ] **Step 1: Add the upload fixture**

`Fixtures.uploadDocument(titled:)` over `documentsRepository.createDocument`, using a PDF from `docker/data/`. Consumption took ~3s when the parent spec measured it, so poll for the document by title rather than sleeping, with a generous ceiling.

Upload as the **test user**, not admin — the document must be owned so it is invisible to other tests. That is the opposite of `deleteTag(named:)` and the reason to state it here.

- [ ] **Step 2: Write the journey**

Upload, open the document, attach a text custom field, type a value, save, reopen, assert the value persisted. Delete the document in `tearDown`.

- [ ] **Step 3: Run.** Expected: PASS, 14 journeys.
- [ ] **Step 4: Commit** — `test: add the document custom field editing journey`

---

## Task 6: Check the isolation contract in `AGENTS.md`

Parent sequence step 6. The second slice already wrote most of it; this checks it against the finished suite rather than assuming.

- [ ] **Step 1:** Re-read the "UI tests never mutate global server state" section against the twelve journeys now in the tree. Every claim it makes should be true of code that exists; anything it promises that no journey does should go.
- [ ] **Step 2:** Commit if it changed — `docs: check the UI test isolation contract against the suite`

---

## Task 7: Measure, and settle the `CI_UI_TESTS` gate

Parent sequence step 7 — the decision the rework has been deferring since the first slice. It wanted the number after the harnesses were gone. They are.

- [ ] **Step 1: Full clean run**

```bash
export TUIST_PAPERLESS_TEST_URL=http://192.168.64.1:8000
mise exec -- tuist install && mise exec -- tuist generate --no-open
mise exec -- tuist test "Less Paper" -d "iPhone 17 Pro" --no-selective-testing
```

Record: total tests, UI journey count, per-journey durations, wall clock.

- [ ] **Step 2: Compare against where the rework started**

The parent spec measured 37 harness tests across ten app builds at ~550s of test-case time, ~70% of total runtime, which is what put the gate there. Compare like for like: journeys now, builds now.

- [ ] **Step 3: Decide, and write the decision down**

Either drop the gate so UI tests run on every PR, or keep it with the number that justifies it. **Recommend, do not unilaterally change CI** — this touches `mise/tasks/ci/test` and the workflow, and the repo owner should agree before UI tests start running on every PR. Put the recommendation in the plan's execution notes and raise it.

- [ ] **Step 4: Record execution notes** in the shape the second slice used — per-journey durations, the total, and any command in this plan that turned out wrong.

- [ ] **Step 5: Commit** — `docs: record the final UI test runtimes`

---

## Self-Review

**Spec coverage.** Spec sequence step 1 → Task 1. Step 2 → Task 2. Step 3 → Task 3. Step 4 → Task 4. Step 5 → Task 5. Step 6 → Task 6. Step 7 → Task 7.

**The one judgement call.** Journey 2 does not assert the `No servers found` empty state that `ServersAppTests.testCRUD` did. It cannot: the app is running on the journey's own server. What replaces it — deleting a second server leaves the first untouched — is the assertion that carries over to real use. Recorded here so the lost assertion is a decision rather than an oversight.

**What could still need identifiers.** The custom-field option matrix and the document list are the two screens the parent spec named as the largest unknown, and they are both in this slice. Every journey step above says the same thing: add the identifier to the view, never an index-based query to the test.

**Placeholder scan.** No TBD. Task 7 Step 1 asks for numbers that do not exist until it runs; that is a measurement, and the step names what to record.
