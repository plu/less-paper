# On-device title suggestions

A button in the document edit form's title field that asks Apple's on-device model for three titles
built from everything the app already knows about the document, and puts the chosen one into the
field as a staged edit.

## Context

Titling a scanned document by hand is the tedious part of using paperless. The consumer names a
document from its filename, so an archive fills up with `scan_20240817_113052`, `Dokument (3)` and
`IMG_4471`. Renaming means opening the document, reading enough of it to know what it is, and typing
a title — for every document.

The app is already holding everything needed to do better. By the time the edit form is on screen,
`DocumentFormReducer` has the full OCR content in `state.content` (loaded by `runGetDocument` on
`.onAppear`, because the list payload truncates it) and every staged field in `state.input` —
correspondent, document type, storage path, tags, ASN, created date, custom fields and the current
title. That is a rich description of the document, sitting in memory, doing nothing.

iOS 26's `FoundationModels` runs a language model on the device. Nothing leaves the phone, there is
no account, no key and no per-request cost — which is what makes this feature possible in an app
whose whole premise is that the user's paperwork is their own. A cloud model would mean shipping the
contents of someone's medical letters to a third party to save them some typing, and that trade is
not worth making.

The constraint is that the app deploys to iOS 18.0 and this framework is iOS 26. There is no
`@available(iOS 26` anywhere in the repository today; this feature introduces the first one.

## Decisions

**Unavailable means invisible.** On iOS 18–25, on hardware that is not Apple Intelligence eligible,
with Apple Intelligence switched off, or while the model is still downloading, the button is not
rendered and the title field looks exactly as it does today. The form already does this with
permissions — a picker the account cannot use is absent rather than disabled, because a control that
looks interactive and does nothing is worse than no control. The same reasoning applies to a
capability the device does not have. It also means no string is needed to explain any of the three
`UnavailableReason` cases, and no screen has to teach the user what Apple Intelligence is.

**The button also waits for the document text.** `canSuggestTitle` is the model's availability *and*
`content != nil`, so the button is absent until `runGetDocument` lands and stays absent when the load
failed. Without the second half, tapping during the load would build a context whose document text is
empty and let the model title the document from its own `scan_20240817` filename — the exact case the
feature exists to fix, failing silently and looking like a bad model rather than a missing input.

**A stream that finishes having yielded nothing is a failure.** It sets the same
`titleSuggestionFailed` message rather than leaving `isGenerating` false with an empty list, which
renders as a spinner that never stops and puts Retry — which lives in the error branch — out of
reach.

**Guardrails are permissive, deliberately.** The session is built with
`SystemLanguageModel(guardrails: .permissiveContentTransformations)` rather than the default. A
personal archive is full of exactly what default guardrails refuse: medical letters, legal
correspondence, debt notices, accident paperwork, insurance claims. Under `.default` the model would
decline on those and the user would see a failure on precisely the documents that are hardest to
title by hand — the ones they most wanted help with. `.permissiveContentTransformations` is Apple's
setting for transforming content the user already possesses, which is what this is: the text was on
their own paper, scanned by them, into their own archive.

**Titles are written in the document's language, not the app's.** A German invoice gets a German
title on an English phone. An archive is read as a list, and a list where a third of the entries have
been translated into the phone's language reads worse than one that matches the paper. The
instruction says so explicitly; nothing about the app's locale enters the prompt.

**Three suggestions, streamed.** `streamResponse(to:generating:)` yields partial snapshots, so rows
appear and fill in rather than the sheet sitting blank for the several seconds a first, cold
generation takes. Three because on-device quality falls off past the first few, and because three
rows fit without scrolling.

**Sampling is random and unseeded, so Regenerate can differ.** Each `suggest` call builds its own
session and passes `GenerationOptions(sampling: .random(top: 50))` with no seed. Under the default
greedy sampling, a second call on an unchanged document returns the same three titles, and a
Regenerate button that reliably reproduces its own output is a button that lies. A fresh session per
call rather than a retained one keeps the client a plain function and keeps the prompt the only
input — at the cost that the model cannot see its previous answer and so is not explicitly steered
away from it. Unseeded sampling is what supplies the variation instead.

**Notes are not part of the context.** Notes are the only piece of document context the form does not
already hold: `DocumentNotesReducer` fetches them when its own section appears, so on the common path
they are absent. Including them would mean either a fetch on every form open — paid by everyone,
used by the few who tap suggest — or a wait inside the sheet. They are user commentary rather than
document text and their absence costs the prompt little. This was considered and dropped; the whole
context is therefore synchronous, and generation starts the moment the sheet appears.

**A selected title is staged, never saved.** Tapping a suggestion writes `state.input.title` and
closes the sheet. Reset and Save then behave exactly as they do for a hand-typed title. The model
gets no privileged path to the server.

**The capability lives in its own module with no UI and no strings.** `Intelligence` holds the
client, the availability gate, the prompt and the truncation policy, and nothing else. It has no
string catalogue, matching `Logging`, `ImageFeature` and the other modules with no user-facing text —
adding an empty one would put the module back on the rebuild path for every string change in the
project.

## Architecture

```
Intelligence                                                                    [new module]
  TitleSuggestionClient         @DependencyClient: isAvailable, suggest
  TitleSuggestionContext        plain Sendable struct; owns truncation + prompt rendering
  TitleSuggestionError          four cases, so callers need no FoundationModels import
  TitleSuggestionClient+Live    the only file importing FoundationModels; wholly @available(iOS 26)
                                depends on Logging; every failure is logged here
        ^
        |
DocumentsFeature
  DocumentTitleSuggestionsReducer   streams, selects, regenerates                [new]
  DocumentTitleSuggestionsView      the bottom sheet                             [new]
  DocumentFormReducer               canSuggestTitle, a destination, a delegate   [changed]
  DocumentFormView                  passes the action into TitleField            [changed]

Components
  TitleField                        optional trailing suggest button             [changed]
```

`TitleSuggestionContext` is a struct of `String`s rather than a `Document`, which is what keeps
`Intelligence` off `ApiInterface`. `DocumentsFeature` builds the context; `Intelligence` never learns
what a paperless document is.

## Changes

### `Intelligence`

```swift
@DependencyClient
public struct TitleSuggestionClient: Sendable {
    public var isAvailable: @Sendable () -> Bool = { false }
    public var suggest: @Sendable (TitleSuggestionContext)
        -> AsyncThrowingStream<[String], any Error> = { _ in .init { $0.finish() } }
}
```

`suggest` yields the whole array as it stands after each snapshot, not deltas, so the reducer
replaces `state.suggestions` and has no accumulation to get wrong. `testValue.suggest` stays
unimplemented — unlike `LogClient`, whose no-op default exists because logging is incidental to what
any test asserts. Here a test that reaches the model by accident should fail loudly. `testValue.isAvailable`
is the exception: it is a synchronous, side-effect-free capability read, not a call into the model, so
it defaults to `false` — both the safe default and the one that matches `canSuggestTitle`'s own
default, so a test that never mentions this dependency renders exactly as if the feature did not
exist.

`isAvailable` is a single synchronous read of `SystemLanguageModel.availability` on the same instance
the session is built from, so the button's visibility and the session's behaviour cannot disagree.

Generation is guided rather than parsed out of prose:

```swift
@Generable
struct SuggestedTitles {
    @Guide(description: "Three distinct titles, best first.", .count(3))
    var titles: [String]
}
```

Instructions are set on the session, which lives for one `suggest` call: three distinct titles; at
most 60 characters; no file extensions, no quotation marks; prefer concrete identifiers — sender,
subject, reference or invoice number, period; write in the same language as the document text.

`TitleSuggestionContext` renders the prompt and owns the truncation policy, which is the part worth
testing without a model in the loop. Content is clipped to **2000 characters**, cut back to the last
word boundary at or before that point and suffixed with an ellipsis; the model's context window is
about 4k tokens and a scanned multi-page document runs to tens of thousands of characters, so
something must give, and a document's identifying information is almost always on its first page.
Empty fields are omitted from the rendered prompt rather than emitted as `Correspondent: (none)`,
which would spend tokens teaching the model what the document is not.

### `Components/TitleField`

```swift
public init(text: Binding<String>, suggestButtonTapped: (() -> Void)? = nil)
```

With `nil` the view renders exactly as today, so `ShareFormView` (two call sites) and
`DocumentBulkEditTitleView` are untouched and their snapshot references stay valid. With an action it
takes `ASNField`'s shape — `Field(.title, padding: .x0)`, the `TextField` with a compensating leading
inset, a trailing `.ghost` button — using a `sparkles` icon.

Unlike ASN's, the button does **not** hide once the field has text. ASN's does because a serial
number the user already typed needs no successor; a title, by contrast, is most worth suggesting when
the document currently carries a bad one, which is the whole `scan_20240817` case.

The accessibility label is a string in **Components'** catalogue; the sheet's strings are in
**DocumentsFeature's**. Two `suggestTitle` keys is the intended outcome of the module-owns-its-strings
rule, not an oversight.

### `DocumentTitleSuggestionsReducer`

```swift
@ObservableState
public struct State: Equatable {
    var context: TitleSuggestionContext
    var suggestions: [String] = []
    var isGenerating = false
    var error: String?
}
```

`onAppear` starts the stream under a cancellation id. Regenerate cancels the in-flight stream, clears
`suggestions` and starts another; dismissing cancels it too, so a stream cannot outlive the sheet.
Clearing rather than leaving the old rows in place matters because rows are keyed by index — a new
stream writing into a populated array would otherwise show a mix of old and new titles while it
filled in.

Rows are keyed by index. During streaming a row's text fills in while its position stays put, so
value-keyed identity would tear the list apart on every snapshot for no benefit.

Three view states, all reusing shapes this form already has: a `ProgressView` while generating with
nothing yet; the list once rows exist; `EmptyListView` with a Retry button on error, the same
construction `DocumentFormView.contentSection()` uses for a failed content load. Tapping a row sends
`delegate(.titleSelected)`.

The sheet is a `Sheet` with a `SheetHeader` — close on the left, regenerate on the right — presented
with `presentationDetents([.sheet])`, matching `SingleSelectOptions`.

### `DocumentFormReducer`

Four additions: `canSuggestTitle`, set in `.onAppear` from `titleSuggestion.isAvailable()`; a
`suggestTitleButtonTapped` view action that builds the context from `state` and presents the
destination; a `titleSuggestions` case on `Destination`; and a delegate handler that writes
`state.input.title` and clears the destination.

### Errors

`TitleSuggestionError` has four cases so that each failure says something true:

| Case | Shown as |
|---|---|
| `guardrailViolation` | the model declined this document |
| `contextWindowExceeded` | the document is too long |
| `unavailable` | the model is not available |
| `failed` | generic, with Retry |

`contextWindowExceeded` should not survive truncation, but if it does it must not masquerade as a
network failure — that is an afternoon spent looking at the wrong layer.

**Only the case name is logged, never the payload.** `.failed` carries a `localizedDescription` from
an error of unknown provenance, and the log is a file the app invites the user to email to a
stranger; the repo's standing rule is that bodies are never written. `TitleSuggestionError.logLabel`
is an exhaustive switch returning the bare case name, so a case added later cannot silently start
printing a payload. Nothing is lost: the reducer collapses `.failed` and `.unavailable` into one
message, so the payload has no consumer.

Logging happens in `Intelligence`'s live client, where the error originates, not in
`DocumentsFeature`. `DocumentsFeature` does not depend on `Logging` today and should not start:
`Intelligence` takes that dependency instead, one call at the single place every failure passes
through. So "suggestions never work for me" still arrives with something shareable attached, without
widening the graph around the app's largest module.

## Testing

| Target | Covers |
|---|---|
| `IntelligenceTests` [new] | truncation at a word boundary, empty fields omitted, prompt shape — no model involved |
| `DocumentTitleSuggestionsReducerTests` [new] | streaming snapshots replacing state, selection to delegate, regenerate cancelling the in-flight stream, each error to its message |
| `DocumentTitleSuggestionsViewTests` [new] | snapshots: generating, populated, error |
| `DocumentFormReducerTests` | button absent when `isAvailable()` is false; delegate writes `input.title` and leaves it staged |
| `ComponentsTests/Field/TitleFieldTests` [new] | snapshot with and without the button; the without-button reference must match today's rendering |

Every test stubs `TitleSuggestionClient`. Nothing in CI reaches the real model, and no test depends
on Apple Intelligence being enabled on the runner — which matters, because whether the simulator
offers the model at all varies with the host machine's own Apple Intelligence state.

Verification is `mise run ci:lint` — five steps under `set -eou pipefail`, so the first failure hides
every one after it — plus the unit schemes for `Intelligence`, `Components` and `DocumentsFeature`.

The new module is five edits across three files, none of them `Module+Targets.swift`, which is
generic and needs nothing: `Module.swift` gains the two cases and lists `intelligence` in both
`codeCoverageTarget` and `product`; `Module+Dependencies.swift` gains the two dependency blocks;
`Module+Schemes.swift` lists `intelligence` in the framework-scheme case and `intelligenceTests` in
the empty case. `tuist inspect dependencies --only implicit` is the step that catches a target
reaching a module it did not declare, and it is the one tests cannot substitute for.

One check has no test and must be done by hand: `FoundationModels` is an iOS 26 framework linked
into an iOS 18 binary, so it **must** be weak-linked or the app will not launch on iOS 18. The
linker does this automatically from the SDK's availability data, but "automatically" is worth
confirming once — `otool -l` on the built framework should show `LC_LOAD_WEAK_DYLIB`, not
`LC_LOAD_DYLIB`, for FoundationModels.

## Out of scope

- **The share extension and bulk edit.** `ShareFormView` has no OCR content at share time, only a
  filename, so it needs a different prompt and a different judgement about whether the result is
  worth showing. Bulk edit's title field is a template with placeholders across many documents, not
  one document's title. Both keep passing no action and are unchanged.
- **Suggesting anything but a title.** Correspondent, document type and tags are all plausible next
  steps and all need their own thinking about matching against existing entities rather than
  inventing new ones.
- **Automatic suggestion.** Nothing generates without a tap. Running a model on every form open would
  spend battery on documents nobody was going to rename.
- **A settings toggle.** The button is only present where the model is available, and it does nothing
  until tapped. There is nothing to switch off.

## Risks

**This is the repository's first runtime availability gate, and the compiler only half-checks it.**
`@available(iOS 26, *)` on the live implementation is enforced, but the discipline of keeping
`FoundationModels` out of every other file is not — an import added to `DocumentsFeature` later would
compile and then fail to launch on iOS 18. `TitleSuggestionError` exists so that no caller ever has a
reason to add one.

**The live path cannot be exercised in this development environment.** Claude works from an Apple
Virtual Machine, so the on-device model is very unlikely to be reachable here. Everything except
`TitleSuggestionClient+Live.swift` is covered by tests against a stubbed client; that one file will
be compiled and not run, and needs a hands-on check on real hardware before merge. Prompt quality in
particular — whether three titles are actually distinct, whether the language instruction holds on a
German document — cannot be assessed from a test suite.

**Truncation is a quality decision disguised as a technical one.** Clipping to the first 2000
characters is right for an invoice and wrong for a document whose subject only becomes clear on page
four. The number is a starting point to be revisited against real documents, not a constant to be
defended.
