# Document notes — implementation plan

Design: [2026-08-22-document-notes.md](../specs/2026-08-22-document-notes-design.md)

## 1. API interface

`Modules/ApiInterface/Notes/`

- `Note.swift` — `Note` + nested `Note.Author`, `Tagged` id, `testValue()` helpers for both.
- `CreateNoteInput.swift` — `public let note: String`, `Codable`/`Equatable`/`Sendable`,
  `testValue()`.
- `GetNotesUseCase.swift`, `CreateNoteUseCase.swift`, `DeleteNoteUseCase.swift` — `@DependencyClient`
  structs returning `[Note]`, each with `previewValue`, `testValue` and a `DependencyValues`
  accessor, following `GetDocumentUseCase` exactly.

Verify: `Note` decodes the probed payload, including the nested `user` object and the
`+02:00`-offset timestamp, through `JSONDecoder.apiDecoder`.

## 2. API implementation

`Modules/ApiImplementation/Notes/`

- `NotesRepository.swift` — `@DependencyClient` struct with `createNote`, `deleteNote`, `getNotes`;
  `previewValue`/`testValue`/`liveValue`; `DependencyValues` accessor. Live methods hit
  `/api/documents/{id}/notes/` with `.get`, `.post` (body `CreateNoteInput`) and `.delete`
  (`query: [("id", "\(noteId)")]`).
- Three use-case files delegating to the repository, matching
  `ApiImplementation/Documents/GetDocumentUseCase.swift`.

## 3. Notes reducer

`Modules/DocumentsFeature/DocumentNotes/`

- `DocumentNotesReducer.swift` — state per the design; actions `notesResult(Request, Result<[Note],
  Error>)`, `destination`, `view`, `binding`. `Request` is a private-ish enum `case create, delete,
  load` selecting which flag clears and whether `loadError` is set.
- `DocumentNotesReducer+Effect.swift` — `runCreateNote`, `runDeleteNote`, `runGetNotes`.
- `DocumentNotesReducer+ConfirmationDialogState.swift` — `confirmDelete(noteId:)`.
- `DocumentNotesReducer+TestValue.swift` — `State.testValue(...)`.

## 4. Views

- `DocumentNotesView.swift` — the four-state list.
- `DocumentNoteRowView.swift` — card row, swipe action, `.confirmationDialog` attached in
  `DocumentNotesView`.
- `DocumentNoteComposerView.swift` — growing field + add button.
- `Extensions/DateFormatter+Extensions.swift` — `noteCreated`.

## 5. Wire into the form

- `DocumentFormSection.swift` — `case notes` + `description`.
- `DocumentFormReducer.swift` — `var notes: DocumentNotesReducer.State` built in `init`, `case
  notes(DocumentNotesReducer.Action)`, `Scope(state: \.notes, action: \.notes)`.
- `DocumentFormView.swift` — `isScrollingEnabled: store.section == .details`, notes case in
  `content:`, composer in `bottom:`.
- `DocumentFormReducer+TestValue.swift` — pass through anything needed.

## 6. Strings

`Shared/Framework/Resources/Localizable.xcstrings` — `addNote`, `deleteNote`,
`deleteNoteConfirmation` (parameterised), `noNotesFound`, `notes`; en + de, `extractionState:
manual`, inserted in alphabetical order.

## 7. Tests

- `Modules/ApiImplementationTests/Notes/NotesRepositoryTests.swift` — integration round-trip.
- `Modules/DocumentsFeatureTests/DocumentNotes/DocumentNotesReducerTests.swift` — the list in the
  design's Testing section.
- `Modules/DocumentsFeatureTests/DocumentNotes/DocumentNotesViewTests.swift` — four snapshots.
- `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormViewTests.swift` — a `notes` snapshot.

## 8. Verify

`mise run generate`, build, run `DocumentsFeatureTests` and `ApiImplementationTests`, record the new
snapshots, re-run.
