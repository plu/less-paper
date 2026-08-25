# UI testing rework — the last harnesses

Third and final slice of [2026-08-24-ui-testing-rework-design.md](2026-08-24-ui-testing-rework-design.md).
That spec stands; this one narrows it to what is left and records what the second slice learned.

## Where the rework stands

[Plan 1](../plans/2026-08-24-ui-testing-rework.md) landed journeys 1, 3 and 4 and retired `TagsApp`.
[Plan 2](../plans/2026-08-25-ui-testing-entity-lifecycles.md) landed journeys 5–8 and 10, retired
five more pairs, and generalised the tag driver into `EntityListScreen`.

| | Today |
|---|---|
| Journeys in `AppUITests` | 9 |
| Harness pairs remaining | 4 — CustomFields, Documents, Servers, **Share** |
| Harness tests remaining | 10, of which `ShareAppTests.testImport` is permanent |
| Journeys unwritten | 2, 9, 11, 12 |

This slice writes those four and retires the three non-permanent pairs. After it, `ShareApp` is the
only harness left and the parent spec's sequence is complete but for its last step, the `CI_UI_TESTS`
gate.

## Scope

Journeys 2, 9, 11 and 12, and the retirement of `ServersApp`, `CustomFieldsApp` and `DocumentsApp` —
seven targets.

## What the second slice learned

Three findings shape this one.

**No accessibility identifier was needed for any entity list.** Seven journeys now match on existing
labels; only `ToastView` needed one, for the conflict journey. The parent spec named identifier work
as the largest unknown, and for list-shaped screens it has not materialised. The screens in *this*
slice are the ones it actually warned about — the custom-field matrix and document browsing inside an
assembled navigation stack, where `"Name"` and `"Documents"` are no longer unambiguous.

**`--no-selective-testing` is mandatory on every verification run.** Tuist skips test targets whose
hashes are unchanged, so a re-run of an untouched `AppUITests` reports success having executed
nothing.

**Typing into a pre-filled field is caret-sensitive.** `EntityListScreen.type` taps the trailing edge
because a centre tap lands mid-text. Journey 2 edits a server alias and journey 9 edits an option
label — both type into pre-filled fields and must use the same approach rather than a bare `tap()`.

## The CustomFields assertions the parent spec moves down

Parent sequence step 4 requires `testCancelWithBlankOption` and `testDeleteBlankOption` to be
reducer tests before `CustomFieldsApp` dies. **Most of that migration already happened**, as part of
fixing the bugs they guard:

- `CustomFieldFormView` iterates values and addresses each row by `id` — never `ForEach($binding)` —
  with a comment recording the index-based crash `testDeleteBlankOption` was written for.
- `CustomFieldFormReducerTests.test_view_optionLabelChanged_forRemovedOption_isIgnored` covers the
  write-back from a removed row, which is the mechanism behind *both* harness tests.
- `test_view_deleteOptionButtonTapped` and `_clearsFocusWhenItHeldIt` cover deletion by id.
- `CustomFieldFormViewTests.testSnapshot_selectWithBlankOption` covers the render.

One gap is real: **nothing covers the cancel path.** `cancelButtonTapped` and `closeButtonTapped`
both run `dismiss()`, and no test sends either. This slice adds that test before the harness dies.

The harness comment also cites `testNoPresentationWarningOnCancel` "in the log capture" as the
partner assertion. **No such test exists anywhere in the tree.** Whatever log-capture suite it lived
in is gone, so the comment describes coverage that is not there — worth knowing before treating the
harness test as the only thing standing between the app and that regression.

## Journeys

### Journey 2 — server management

Replaces the rest of `ServersAppTests.testCRUD`. Journey 1 already drives adding the first server
for real; this one starts from the seeded server and covers what follows: add a second, switch to
it, edit an alias, delete.

The harness asserted `admin @ <url>` as the row subtitle and `No servers found` as the empty state.
Both are still worth asserting, but the empty state is not reachable here — the journey's own server
is what the app is running on, and deleting it mid-journey logs the app out. So the journey deletes
only the **second** server and asserts the first survives, which is the assertion that matters:
deleting one server does not disturb another.

### Journey 9 — custom fields

Replaces six of the eight `CustomFieldsAppTests`. Custom fields are global — no owner — so the
journey namespaces by name (`uit-<id>-<label>`) and never asserts on list totals, per `AGENTS.md`.

Two shapes in one journey: a text field created and deleted, and a select field created with an
option, saved, reopened, and its option asserted to have persisted. The select path is where the
value is: it is the only form in the app with a nested collection, and reopening proves the round
trip through `extra_data`.

The harness's "no tap on the new option row" subtlety must survive the move — the row takes focus
when it appears, and tapping it would hide a regression in that hand-off.

### Journey 11 — document browsing

Replaces `DocumentsAppTests.testList`, expanded. List the corpus, filter by title, open a document,
view its PDF, and go back. The corpus is unowned and read-only, so this journey may read it freely
and must not modify it.

The harness slept 700ms for the search debounce. A journey waits on the filtered result instead —
`AGENTS.md` has no rule about it, but a fixed sleep is the flake this suite has been removing
everywhere else.

### Journey 12 — document custom-field editing

The parent spec's journey 12 wants a document the test uploaded itself, because it *modifies* one.
`DocumentCustomFieldJourneyTests` arrived separately in `e1b3dff` as the #192 regression guard: it
attaches a field to a corpus document but never saves, so it does not violate the corpus rule and it
is not journey 12.

Journey 12 uploads its own PDF via `documentsRepository.createDocument`, waits for consumption
(~3s, measured in the parent spec), sets a custom field value, saves, reopens and asserts the value
persisted. It joins the existing file rather than replacing that test.

## Sequence

One commit per journey, deletion second, as before.

1. The cancel-path reducer test in `CustomFieldsFeatureTests`. No journey, nothing deleted.
2. Journey 2, then retire `ServersApp`.
3. Journey 9, then retire `CustomFieldsApp`.
4. Journey 11, then retire `DocumentsApp`.
5. Journey 12 and the upload fixture.
6. Record the isolation contract in `AGENTS.md` — parent sequence step 6. Mostly written already by
   the second slice; this checks it against the finished suite rather than assuming.
7. Measure, and decide the `CI_UI_TESTS` gate — parent sequence step 7, the decision the whole
   rework has been deferring.

## Out of scope

- **`ShareApp`**, permanently, for the reason the parent spec gives.
- **Parallel workers.** `OrphanSweep` still deletes every `uit-*` user regardless of age, which is
  safe only serially. Enabling parallelism is its own piece of work and this slice does not start it.
