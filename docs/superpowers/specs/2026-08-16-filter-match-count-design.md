# Match count in the filter sheet

## Context

The document list floats a capsule above its bottom edge reading "12 of 12 loaded", built by
`DocumentListStatusBarView` and attached with `.overlay(alignment: .bottom)` in both `DocumentListView`
and `InboxView`.

The filter sheet has no equivalent. Narrowing a filter is a guessing game until the sheet is closed,
and if the guess was wrong the sheet has to be reopened.

The number is already there for the taking. Every change inside the sheet ends in
`Effect.runFilterUpdated`, which sends `delegate(.filterUpdated)` to `DocumentListReducer`; that
sets `state.filter` and returns `runGetDocuments`, so **the list behind the sheet is already
re-querying on every keystroke and every tap**. `GetDocumentsOutput.count` is the match count. This
feature is about moving a number that already exists, not about fetching one.

## Design

### What it says

A new plural-aware `numberOfMatchingDocuments`: "77 documents", "1 document", "0 documents".

Not the list's `numberOfLoadedDocuments`. In the list, "25 of 77 loaded" describes paging the user
can see happening. In the sheet nothing is loading and the 25 is just `PageSize.configured` — the
only number that means anything while filtering is how many documents match. Zero is worth showing
rather than hiding: "0 documents" is exactly the feedback that stops the user closing the sheet onto
an empty list.

### Where the number comes from

The count lives in one unscoped in-memory shared key:

```swift
struct DocumentFilterMatchCount: Equatable, Sendable {
    var count: Int?
    var isRecalculating = false
}

extension SharedReaderKey where Self == InMemoryKey<DocumentFilterMatchCount>.Default {
    static var documentFilterMatchCount: Self { … }
}
```

`count == nil` means not yet known and hides the capsule.

**Why shared rather than child state.** The obvious design — `DocumentListReducer` writing two
fields into the filter sheet's `@Presents` state — does not survive contact with the pickers. Every
picker (`correspondentList`, `documentTypeList`, `storagePathList`, `tagList`, `date`) sends
`delegate(.filterUpdated)` on *every tap*, so the filter changes and the list re-queries while a
picker is on screen covering the sheet. The count therefore has to be visible in six sheets, not
one — and the pickers are handed a rule and a selection, never a `Server`, so a server-scoped key
could not reach them either.

The key is deliberately **not** scoped: only one filter flow exists at a time, and this is ephemeral
presentation state rather than data.

The payoff is that `DocumentFilterMatchCountView` reads `@Shared` **directly in the view**, so
putting the capsule on a sheet is one line with no reducer changes:

```swift
.safeAreaInset(edge: .bottom, spacing: .x0) {
    DocumentFilterMatchCountView()
}
```

`DocumentListReducer` writes at three points it already handles:

| Action | Write |
|---|---|
| `view(.filterButtonTapped)` | seed with `totalNumberOfDocuments` when `state.isLoaded`, otherwise `nil` |
| `destination(…documentFilter(.delegate(.filterUpdated)))` | `isRecalculating = true` |
| `replaceDocuments` / `error` | `count = output.count` / unchanged, and `isRecalculating = false` |

The middle row is the same action that triggers the refetch, so the flag is set exactly when the
request starts, with nothing to keep in sync.

The last two go through `State.updateFilterMatchCount`, which no-ops unless the filter sheet is
actually presented. Without that guard every list fetch would write a value nothing reads, and every
unrelated list test would have to assert it — which is how the need for the guard was found.

Rejected: a second count request from the sheet (`page_size=1`) doubles the traffic for a number
already in flight, and the two answers could disagree.

### The stale window

Between a change and the response the number belongs to the *previous* filter. Typing makes this
plainly visible: `runSearchDebounce` waits 400ms after the last keystroke before
`runFilterUpdated` even fires, then the request goes out, so the old count sits there for something
over half a second.

While `isRecalculating`, the capsule drops to 50% opacity and animates back to full when the count
lands. It reads as recalculating rather than as lag, and a stale number is never presented as
authoritative.

### The view

`DocumentFilterMatchCountView`, in the `DocumentFilter` folder, using the same treatment as the list's
status bar — `.capsule(backgroundColor: .m3Primary, font: .footnote, foregroundColor: .m3OnPrimary)`
with `.padding(.x3)` — plus the opacity above.

It goes on the filter sheet and on all five pickers that mutate the filter live.

Attached with `.safeAreaInset(edge: .bottom, spacing: .x0)`, **not** the `.overlay(alignment: .bottom)`
that `DocumentListView` and `InboxView` use for `DocumentListStatusBarView`.

An overlay floats the capsule without reserving room for it, so with the keyboard up the compressed
content puts the Sort field directly underneath — the capsule covers the last thing in the sheet, and
no amount of scrolling frees it. `safeAreaInset` floats it identically *and* insets the scrollable
content by its height, so the last field can always be scrolled clear. (The list has the same latent
defect with its own status bar; out of scope here.)

No shared component is extracted. Two call sites with different text, different state and different
behaviour share only the `.capsule` modifier, which is already shared.

### The keyboard

The sheet's content is a `ScrollView` and the search field sits at the top of it, so the keyboard is
up for exactly the interaction this feature exists to serve.

A bottom-aligned inset on a view that respects the safe area rides up with the keyboard on its own,
because the keyboard raises the bottom safe area inset. Measured rather than assumed, with a
temporary XCUITest against the seeded container: the capsule sits at y=806.8 on an 874pt screen with
the keyboard down and at y=511.3 with it up, against a keyboard top edge of 583. It rides up, so no
explicit keyboard handling is needed.

The same test also pins the collision `safeAreaInset` exists to prevent: with the keyboard up the
capsule spans y 511–527 and the Sort field 538–556, which do not intersect.

## Testing

- `DocumentListReducerTests` — the count seeds on open; `filterUpdated` sets `isRecalculating`;
  `replaceDocuments` lands the new count and clears the flag; `error` clears the flag too, so a failed
  refetch does not leave the capsule dimmed forever.
- `DocumentFilterViewTests` — snapshots for a known count, the recalculating state, the singular
  string, `nil` (the pre-existing `allDocuments` snapshot, which must stay capsule-free), and the
  capsule inside the tag picker. The `nil` snapshot also proves the in-memory shared storage is
  isolated per test rather than leaking from whichever test ran before it.
- A temporary XCUITest for the keyboard, as above, deleted once it has answered the question.

## Out of scope

- **`savedViewForm`** is the one sheet in the filter flow without a capsule: it is a name and
  permissions form and changes no filter, so there is nothing to count.
- **The Inbox tab** never presents this sheet, so nothing changes there.
- **No count without the list.** The sheet cannot be opened except from a loaded list, so there is no
  standalone-count path to build.
