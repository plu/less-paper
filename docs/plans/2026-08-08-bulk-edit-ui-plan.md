# Bulk Edit UI Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the correspondent, document type and storage path buttons in `DocumentListBottomToolbar` a working bulk-edit sheet, backed by the already-shipped `selection_data` and `bulk_edit` API layers.

**Architecture:** One generic TCA reducer `DocumentBulkEditGenericValueReducer<Value>` plus one generic view, parameterised by a small local protocol `DocumentBulkEditGenericValue` that supplies the four things that differ per type (title, confirmation strings, which `selection_data` array to read, which `BulkEditDocumentsInput.Method` to build). Presented as three `Destination` cases on `DocumentListReducer`, exactly as `DocumentFilterGenericValueListReducer<Value>` already is on `DocumentFilterReducer`.

**Tech Stack:** Swift, SwiftUI, The Composable Architecture, `swift-dependencies`, Swift Testing, swift-snapshot-testing, Tuist-generated Xcode project.

**Full design context:** See `docs/plans/2026-08-08-bulk-edit-ui.md` for the investigation and rationale — this plan implements that design directly.

## Global Constraints

- **Test command:** `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`.

  Every part of that command matters. **`--no-selective-testing` is required** — plain `tuist test` can silently report "no tests to run, finishing early" due to Tuist's test-impact cache, giving false confidence that a new test ran when it didn't. This was discovered the hard way during the bulk-edit API work; don't drop it.

  **`-d "iPhone 17 Pro" --os 26.4` and `-- -testLanguage en -testRegion DE` are equally required.** The committed snapshot references were recorded in that exact environment (it is what `mise/tasks/ci/test` uses). On any other simulator or locale, all 11 snapshot suites in this module fail wholesale — a misleading red that has nothing to do with your change. Worse, Tasks 4 and 5 *record* new references: recording them on the wrong simulator or locale commits references that then fail in CI forever. Verified during Task 1: the full module is green on iPhone 17 Pro / 26.4 with these locale arguments, and 11 suites fail without them.

  **Known flake:** the first `tuist test` run after files change often dies with `error: clang importer creation failed` / `unable to handle compilation, expected exactly one compiler job`. It is transient and unrelated to your code — just run the same command again. Do not go debugging it, and do not treat it as a test failure.
- Tuist globs sources from `Modules/<TargetName>/**`, so new files are picked up automatically — but `tuist test` regenerates the project, so always run the full command rather than building in an already-open Xcode.
- **Before every commit** run `mise run format` (swiftlint --fix + swiftformat). Commit the formatted result.
- Doc comments follow `.claude/CLAUDE.md`: `///` for single-line, `/** */` with `- Parameters:` for multiline. Match the surrounding files — most types in `DocumentsFeature` carry no doc comments at all, so don't add them where neighbours have none.
- Property and case declarations in this codebase are alphabetically ordered within their visibility group, and stored properties are separated by blank lines. Follow the exact layout of `DocumentFilterGenericValueListReducer` when in doubt.
- Use `Tagged` id types (`Correspondent.Id`, `DocumentType.Id`, `StoragePath.Id`, `Document.Id`) throughout — never raw `Int`.
- New localized strings go in `Shared/Framework/Resources/Localizable.xcstrings` with `"extractionState" : "manual"` and both `de` and `en` localizations, in Xcode's formatting style (2-space indent steps, `" : "` key separator). Keys are stored alphabetically.
- Snapshot tests use `record: .environment`, which defaults to `.missing` — the **first** run after adding a new snapshot test records the reference and *fails* with "No reference was found on disk"; the **second** run passes. Both runs are steps in this plan. Never set `SNAPSHOT_RECORD` to re-record existing snapshots unless a step says to.
- Scope: correspondent, document type and storage path only. The `editTags` toolbar button stays a no-op.

---

## Task 1: `DocumentBulkEditGenericValue` protocol, three conformances, and localization

**Files:**
- Modify: `Shared/Framework/Resources/Localizable.xcstrings`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue+Correspondent.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue+DocumentType.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue+StoragePath.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueTests.swift`

**Interfaces:**
- Consumes: `GetSelectionDataOutput` and `SelectionDataItem<Id>` (`Modules/ApiInterface/Documents/GetSelectionDataOutput.swift`, already exists), `BulkEditDocumentsInput.Method` (`Modules/ApiInterface/Documents/BulkEditDocumentsInput.swift`, already exists), the existing string keys `editCorrespondent` / `editDocumentType` / `editStoragePath`.
- Produces: `protocol DocumentBulkEditGenericValue` with `static var editTitle: LocalizedStringResource`, `static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource`, `static func confirmationRemove(documentCount: Int) -> LocalizedStringResource`, `static func documentCounts(selectionData: GetSelectionDataOutput) -> [ID: Int]`, `static func method(id: ID?) -> BulkEditDocumentsInput.Method`; conformances on `Correspondent`, `DocumentType`, `StoragePath`. Tasks 2–6 all constrain their generic parameter to this protocol.

- [ ] **Step 1: Add the eight new localized strings**

In `Shared/Framework/Resources/Localizable.xcstrings`, insert each block below into the `"strings"` object at its alphabetical position. The two plain strings go next to their neighbours (`confirm` and `confirmAssignment` sort between `close` and `correspondent`); each `<entity>BulkEditConfirmation*` pair sorts immediately after the bare `correspondent` / `documentType` / `storagePath` key and before its plural (`correspondents` / `documentTypes` / `storagePaths`).

The plural blocks are copied from the shipped old app (`../paperless-ios/PaperlessKit/Sources/PaperlessAssets/Resources/Localizable.xcstrings`, keys `Type.<T>.bulkEditConfirmationReplace` / `Remove`), preserving the mixed `%1$@`/`%2$ld` positional-argument structure — that shape is what generates a two-argument Swift symbol.

**One deliberate change from the old app:** the integer specifiers are `%ld`, not `%d` (`%2$ld` in the assign strings, `%ld` in the remove strings). `%d` generates an `Int32` parameter, which forces an `Int32(documentCount)` cast at all six call sites; `%ld` generates `Int`, which matches both the `documentCount: Int` signature and the existing `numberOfDocuments` (`%ld`) key in this same catalog. Verified during Task 1: with `%ld` the conformances compile with no casts.

```json
    "confirm" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Bestätigen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Confirm"
          }
        }
      }
    },
    "confirmAssignment" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Zuweisung bestätigen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Confirm assignment"
          }
        }
      }
    },
```

```json
    "correspondentBulkEditConfirmationAssign" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird dem ausgewählten Dokument den Korrespondenten „%1$@“ zuweisen."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird %2$ld ausgewählten Dokumenten den Korrespondenten „%1$@“ zuweisen."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will assign the correspondent \"%1$@\" to the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will assign the correspondent \"%1$@\" to %2$ld selected documents."
                }
              }
            }
          }
        }
      }
    },
    "correspondentBulkEditConfirmationRemove" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird bei dem ausgewählten Dokument den Korrespondent entfernen."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird bei %ld ausgewählten Dokumenten den Korrespondent entfernen."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will remove the correspondent from the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will remove the correspondent from %ld selected documents."
                }
              }
            }
          }
        }
      }
    },
```

```json
    "documentTypeBulkEditConfirmationAssign" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird dem ausgewählten Dokument den Dokumenttyp „%1$@“ zuweisen."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird %2$ld ausgewählten Dokumenten den Dokumenttyp „%1$@“ zuweisen."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will assign the document type \"%1$@\" to the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will assign the document type \"%1$@\" to %2$ld selected documents."
                }
              }
            }
          }
        }
      }
    },
    "documentTypeBulkEditConfirmationRemove" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird bei dem ausgewählten Dokument den Dokumenttyp entfernen."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird bei %ld ausgewählten Dokumenten den Dokumenttyp entfernen."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will remove the document type from the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will remove the document type from %ld selected documents."
                }
              }
            }
          }
        }
      }
    },
```

```json
    "storagePathBulkEditConfirmationAssign" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird dem ausgewählten Dokument den Speicherpfad „%1$@“ zuweisen."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird %2$ld ausgewählten Dokumenten den Speicherpfad „%1$@“ zuweisen."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will assign the storage path \"%1$@\" to the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will assign the storage path \"%1$@\" to %2$ld selected documents."
                }
              }
            }
          }
        }
      }
    },
    "storagePathBulkEditConfirmationRemove" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird bei dem ausgewählten Dokument den Speicherpfad entfernen."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "Diese Aktion wird bei %ld ausgewählten Dokumenten den Speicherpfad entfernen."
                }
              }
            }
          }
        },
        "en" : {
          "variations" : {
            "plural" : {
              "one" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will remove the storage path from the selected document."
                }
              },
              "other" : {
                "stringUnit" : {
                  "state" : "translated",
                  "value" : "This operation will remove the storage path from %ld selected documents."
                }
              }
            }
          }
        }
      }
    },
```

- [ ] **Step 2: Verify the catalog still parses**

Run:

```bash
python3 -c "import json; d=json.load(open('Shared/Framework/Resources/Localizable.xcstrings')); print(len(d['strings']))"
```

Expected: prints `165` (157 before, 8 added) with no `JSONDecodeError`.

- [ ] **Step 3: Write the failing conformance test**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Foundation
import Testing
import TestSupport

@Suite
struct DocumentBulkEditGenericValueTests {

    @Test
    func test_correspondent_documentCounts() async throws {
        let counts = Correspondent.documentCounts(selectionData: .testValue(
            selectedCorrespondents: [
                .init(documentCount: 2, id: 1),
                .init(documentCount: 5, id: 7)
            ]
        ))

        #expect(counts == [1: 2, 7: 5])
    }

    @Test
    func test_correspondent_method() async throws {
        #expect(Correspondent.method(id: 42) == .setCorrespondent(.init(correspondent: 42)))
        #expect(Correspondent.method(id: nil) == .setCorrespondent(.init(correspondent: nil)))
    }

    @Test
    func test_documentType_documentCounts() async throws {
        let counts = DocumentType.documentCounts(selectionData: .testValue(
            selectedDocumentTypes: [
                .init(documentCount: 3, id: 2),
                .init(documentCount: 1, id: 9)
            ]
        ))

        #expect(counts == [2: 3, 9: 1])
    }

    @Test
    func test_documentType_method() async throws {
        #expect(DocumentType.method(id: 43) == .setDocumentType(.init(documentType: 43)))
        #expect(DocumentType.method(id: nil) == .setDocumentType(.init(documentType: nil)))
    }

    @Test
    func test_storagePath_documentCounts() async throws {
        let counts = StoragePath.documentCounts(selectionData: .testValue(
            selectedStoragePaths: [
                .init(documentCount: 4, id: 3),
                .init(documentCount: 6, id: 8)
            ]
        ))

        #expect(counts == [3: 4, 8: 6])
    }

    @Test
    func test_storagePath_method() async throws {
        #expect(StoragePath.method(id: 44) == .setStoragePath(.init(storagePath: 44)))
        #expect(StoragePath.method(id: nil) == .setStoragePath(.init(storagePath: nil)))
    }
}
```

Each test pins the one thing that would silently break if the three conformances were copy-pasted carelessly: reading the wrong `selected*` array, or building the wrong `Method` case.

- [ ] **Step 4: Run the test to verify it fails**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — build error, `type 'Correspondent' has no member 'documentCounts'`.

- [ ] **Step 5: Write the protocol**

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue.swift`:

```swift
import ApiInterface
import Foundation

protocol DocumentBulkEditGenericValue: CustomStringConvertible, Hashable, Identifiable, Sendable where ID: Sendable {

    static var editTitle: LocalizedStringResource { get }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource

    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource

    static func documentCounts(selectionData: GetSelectionDataOutput) -> [ID: Int]

    static func method(id: ID?) -> BulkEditDocumentsInput.Method
}
```

The `where ID: Sendable` refinement is what lets the reducer's `State` and its effects stay `Sendable` in Task 2.

- [ ] **Step 6: Write the three conformances**

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue+Correspondent.swift`:

```swift
import ApiInterface
import Foundation

extension Correspondent: DocumentBulkEditGenericValue {

    static var editTitle: LocalizedStringResource {
        .editCorrespondent
    }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .correspondentBulkEditConfirmationAssign(name, documentCount)
    }

    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .correspondentBulkEditConfirmationRemove(documentCount)
    }

    static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedCorrespondents.map { ($0.id, $0.documentCount) }
        )
    }

    static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setCorrespondent(.init(correspondent: id))
    }
}
```

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue+DocumentType.swift`:

```swift
import ApiInterface
import Foundation

extension DocumentType: DocumentBulkEditGenericValue {

    static var editTitle: LocalizedStringResource {
        .editDocumentType
    }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .documentTypeBulkEditConfirmationAssign(name, documentCount)
    }

    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .documentTypeBulkEditConfirmationRemove(documentCount)
    }

    static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedDocumentTypes.map { ($0.id, $0.documentCount) }
        )
    }

    static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setDocumentType(.init(documentType: id))
    }
}
```

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValue+StoragePath.swift`:

```swift
import ApiInterface
import Foundation

extension StoragePath: DocumentBulkEditGenericValue {

    static var editTitle: LocalizedStringResource {
        .editStoragePath
    }

    static func confirmationAssign(name: String, documentCount: Int) -> LocalizedStringResource {
        .storagePathBulkEditConfirmationAssign(name, documentCount)
    }

    static func confirmationRemove(documentCount: Int) -> LocalizedStringResource {
        .storagePathBulkEditConfirmationRemove(documentCount)
    }

    static func documentCounts(selectionData: GetSelectionDataOutput) -> [Id: Int] {
        Dictionary(
            uniqueKeysWithValues: selectionData.selectedStoragePaths.map { ($0.id, $0.documentCount) }
        )
    }

    static func method(id: Id?) -> BulkEditDocumentsInput.Method {
        .setStoragePath(.init(storagePath: id))
    }
}
```

All three types already conform to `CustomStringConvertible`, `Hashable`, `Identifiable` and `Sendable` in `ApiInterface`, and their `Id` typealias is `Tagged<Self, Int>`, which satisfies `ID: Sendable` — so only the five new members are needed.

- [ ] **Step 7: Run the test to verify it passes**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, including all six `DocumentBulkEditGenericValueTests` tests.

- [ ] **Step 8: Format and commit**

```bash
mise run format
git add Shared/Framework/Resources/Localizable.xcstrings Modules/DocumentsFeature/DocumentBulkEdit Modules/DocumentsFeatureTests/DocumentBulkEdit
git commit -m "feat: add DocumentBulkEditGenericValue protocol and conformances"
```

---

## Task 2: Reducer core — state, tap logic, reset

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer+TestValue.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentBulkEditGenericValue` (Task 1), `Document.Id` and `Server` from `ApiInterface`, `@Dependency(\.dismiss)`.
- Produces: `DocumentBulkEditGenericValueReducer<Value>` with nested `Operation` (`.assign(Value.ID)` / `.remove`); `State` with stored `documentCounts: [Value.ID: Int]`, `documents: Set<Document.Id>`, `isLoading: Bool`, `isSaving: Bool`, `operation: Operation?`, `searchText: String`, `server: Server`, `values: IdentifiedArrayOf<Value>` (memberwise init in exactly that order) and computed `filteredValues`, `isEdited`, `systemImage(for:)`; `Action` with `.binding`, `.delegate(.documentsUpdated)`, `.view(.closeButtonTapped / .resetButtonTapped / .valueTapped(Value))`. Tasks 3 and 4 add `.applyConfirmed`, `.error`, `.selectionDataLoaded` and the `.view(.applyButtonTapped / .onAppear)` cases; Task 5 renders this state; Task 6 constructs `State(documents:server:values:)` and observes `.delegate(.documentsUpdated)`.

- [ ] **Step 1: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentBulkEditGenericValueReducerTests {

    @Test
    func test_filteredValues() async throws {
        let store = TestStore(initialState: .testValue(
            searchText: "Off",
            values: [
                .testValue(id: 1, name: "Bank"),
                .testValue(id: 2, name: "Tax Office")
            ]
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        #expect(store.state.filteredValues == [.testValue(id: 2, name: "Tax Office")])
    }

    @Test
    func test_view_closeButtonTapped() async throws {
        var isDismissed = false
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.dismiss = .init { isDismissed = true }
        }

        await store.send(.view(.closeButtonTapped))
        #expect(isDismissed == true)
    }

    @Test
    func test_view_valueTapped_assignsWhenPartiallyApplied() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11]
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operation = .assign(1)
        }
    }

    @Test
    func test_view_valueTapped_removesWhenAppliedToAll() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 2],
            documents: [10, 11]
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operation = .remove
        }
    }

    @Test
    func test_view_valueTapped_reassignsToDifferentValue() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11],
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 2)))) {
            $0.operation = .assign(2)
        }
    }

    @Test
    func test_view_valueTapped_togglesAssignedValueToRemove() async throws {
        let store = TestStore(initialState: .testValue(
            documentCounts: [1: 1],
            documents: [10, 11],
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.valueTapped(.testValue(id: 1)))) {
            $0.operation = .remove
        }
    }

    @Test
    func test_view_resetButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        }

        await store.send(.view(.resetButtonTapped)) {
            $0.operation = nil
        }
    }

    @Test
    func test_systemImage() async throws {
        let state = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11]
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "checkmark.circle.fill")
        #expect(state.systemImage(for: .testValue(id: 2)) == "minus.circle")
        #expect(state.systemImage(for: .testValue(id: 3)) == "circle")
    }

    @Test
    func test_systemImage_whenEdited() async throws {
        let state = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documentCounts: [1: 2, 2: 1],
            documents: [10, 11],
            operation: .assign(2)
        )

        #expect(state.systemImage(for: .testValue(id: 1)) == "circle")
        #expect(state.systemImage(for: .testValue(id: 2)) == "checkmark.circle.fill")
    }
}
```

The four `valueTapped` tests are the four transitions of the ported toggle logic; `test_systemImage` covers the three unedited states (all / some / none) and `test_systemImage_whenEdited` covers the pending-operation override.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — build error, `cannot find 'DocumentBulkEditGenericValueReducer' in scope`.

- [ ] **Step 3: Write the reducer**

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import Foundation

@Reducer
public struct DocumentBulkEditGenericValueReducer<Value: DocumentBulkEditGenericValue>: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case view(View)

        @CasePathable
        public enum Delegate {
            case documentsUpdated
        }

        public enum View {
            case closeButtonTapped
            case resetButtonTapped
            case valueTapped(Value)
        }
    }

    public enum Operation: Equatable, Sendable {
        case assign(Value.ID)
        case remove
    }

    @ObservableState
    public struct State: Equatable {

        var documentCounts: [Value.ID: Int] = [:]

        let documents: Set<Document.Id>

        var filteredValues: IdentifiedArrayOf<Value> {
            if searchText.isEmpty {
                values
            } else {
                values.filter { $0.description.localizedCaseInsensitiveContains(searchText) }
            }
        }

        var isEdited: Bool {
            operation != nil
        }

        var isLoading = false

        var isSaving = false

        var operation: Operation?

        var searchText = ""

        let server: Server

        let values: IdentifiedArrayOf<Value>

        func systemImage(for value: Value) -> String {
            switch operation {
            case let .assign(id):
                return id == value.id ? "checkmark.circle.fill" : "circle"
            case .remove:
                return "circle"
            case nil:
                let count = documentCounts[value.id] ?? 0
                if count == documents.count {
                    return "checkmark.circle.fill"
                }
                if count > 0 {
                    return "minus.circle"
                }
                return "circle"
            }
        }
    }

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .run { _ in
                        @Dependency(\.dismiss)
                        var dismiss

                        await dismiss()
                    }
                case .resetButtonTapped:
                    state.operation = nil
                    return .none
                case let .valueTapped(value):
                    let count = state.documentCounts[value.id] ?? 0
                    if state.operation == nil, count == state.documents.count {
                        state.operation = .remove
                    } else if case let .assign(id) = state.operation, id == value.id {
                        state.operation = .remove
                    } else {
                        state.operation = .assign(value.id)
                    }
                    return .none
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    public init() {}
}
```

Note the stored-property order — `documentCounts`, `documents`, `isLoading`, `isSaving`, `operation`, `searchText`, `server`, `values` — is what the synthesized memberwise init uses, and Task 6 relies on being able to call `State(documents:server:values:)` with the others defaulted.

- [ ] **Step 4: Write the test value**

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer+TestValue.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation
import IdentifiedCollections

extension DocumentBulkEditGenericValueReducer.State where Value == Correspondent {

    static func testValue(
        documentCounts: [Value.ID: Int] = [:],
        documents: Set<Document.Id> = [10, 11],
        isLoading: Bool = false,
        isSaving: Bool = false,
        operation: DocumentBulkEditGenericValueReducer<Value>.Operation? = nil,
        searchText: String = "",
        server: Server = .testValue(),
        values: IdentifiedArrayOf<Correspondent> = [
            .testValue(id: 1, name: "C1"),
            .testValue(id: 2, name: "C2")
        ]
    ) -> Self {
        .init(
            documentCounts: documentCounts,
            documents: documents,
            isLoading: isLoading,
            isSaving: isSaving,
            operation: operation,
            searchText: searchText,
            server: server,
            values: values
        )
    }
}
```

Only the `Correspondent` instantiation gets a test value — it's the only one exercised by tests, matching how `DocumentFilterGenericValueListReducer`'s tests only drive `Correspondent`.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, including all nine `DocumentBulkEditGenericValueReducerTests` tests.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit Modules/DocumentsFeatureTests/DocumentBulkEdit
git commit -m "feat: add DocumentBulkEditGenericValueReducer core state and tap logic"
```

---

## Task 3: Load selection data

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducerTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.getSelectionData.execute)` with signature `(GetSelectionDataInput, Server) async throws -> GetSelectionDataOutput` (`Modules/ApiInterface/Documents/GetSelectionDataUseCase.swift`), `Effect.toast(_:)` (`Modules/Components/Extensions/Effect+Toast.swift`), Task 1's `Value.documentCounts(selectionData:)`, Task 2's `State`.
- Produces: `Action.error(Error)`, `Action.selectionDataLoaded(GetSelectionDataOutput)`, `Action.View.onAppear`, and `Effect.runGetSelectionData<Value>(documents:server:)`. Task 4 adds two more effects to the same file and reuses `.error`; Task 5's view sends `.view(.onAppear)` from `.task`.

- [ ] **Step 1: Write the failing tests**

Add to `DocumentBulkEditGenericValueReducerTests`, after `test_view_closeButtonTapped`:

```swift
    @Test
    func test_view_onAppear() async throws {
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                .testValue(selectedCorrespondents: [.init(documentCount: 2, id: 1)])
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.selectionDataLoaded) {
            $0.documentCounts = [1: 2]
            $0.isLoading = false
        }
    }

    @Test
    func test_view_onAppear_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.getSelectionData.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.error) {
            $0.isLoading = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }
```

`ApiError.testValue()` (whose `localizedDescription` is "Something went wrong") is the error this codebase's reducer tests throw. **Stubbing `$0.toastPresenter.present` is mandatory** — `ToastPresenter` is a `@DependencyClient` whose `testValue` is unimplemented, so any test that reaches `.toast(error)` without the stub fails with an "unimplemented" issue. This mirrors `test_selectAllMatchingButtonTapped_error` in `DocumentSelectionReducerTests`.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — build error, `type 'DocumentBulkEditGenericValueReducer<Correspondent>.Action.View' has no member 'onAppear'`.

- [ ] **Step 3: Write the effect**

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer+Effect.swift`:

```swift
import ApiInterface
import ComposableArchitecture
import Foundation

extension Effect {

    static func runGetSelectionData<Value: DocumentBulkEditGenericValue>(
        documents: Set<Document.Id>,
        server: Server
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
        @Dependency(\.getSelectionData.execute)
        var getSelectionData

        let input = GetSelectionDataInput(documents: Array(documents))

        return .run { send in
            await send(.selectionDataLoaded(try await getSelectionData(input, server)))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.getSelectionData)
    }
}

private enum CancelID {
    case getSelectionData
}
```

`Value` is unbound at extension scope, so the constraint lives on the method rather than on the extension — unlike the non-generic `extension Effect where Action == …` used elsewhere in this module. Swift infers `Value` at the call site from the expected `Action` type.

- [ ] **Step 4: Wire the actions into the reducer**

In `DocumentBulkEditGenericValueReducer.swift`, add to `Action` (alphabetically, `error` before `view`, `selectionDataLoaded` after `delegate`):

```swift
        case error(Error)
```
```swift
        case selectionDataLoaded(GetSelectionDataOutput)
```

Add to `Action.View`, before `resetButtonTapped`:

```swift
            case onAppear
```

Add these cases to the `Reduce` switch, before `case let .view(viewAction)`:

```swift
            case let .error(error):
                state.isLoading = false
                state.isSaving = false
                return .toast(error)
            case let .selectionDataLoaded(output):
                state.documentCounts = Value.documentCounts(selectionData: output)
                state.isLoading = false
                return .none
```

Add to the inner `viewAction` switch, before `case .resetButtonTapped`:

```swift
                case .onAppear:
                    state.isLoading = true
                    return .runGetSelectionData(
                        documents: state.documents,
                        server: state.server
                    )
```

Both loading flags are cleared unconditionally in `.error`: only one request can be in flight at a time, and it keeps the handler a single case regardless of which effect failed.

- [ ] **Step 5: Run the tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, including `test_view_onAppear` and `test_view_onAppear_error`.

- [ ] **Step 6: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit Modules/DocumentsFeatureTests/DocumentBulkEdit
git commit -m "feat: load selection data into the bulk edit reducer"
```

---

## Task 4: Apply flow — confirmation popup and bulk edit request

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationView.swift`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducer+Effect.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueReducerTests.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/DocumentBulkEditConfirmationViewTests.swift`

**Interfaces:**
- Consumes: `@Dependency(\.popupPresenter)` with `present: (@escaping @Sendable @MainActor () -> any View) async -> Void` and `dismiss: () async -> Void` (`Modules/Components/Popup/PopupPresenter.swift`), `@Dependency(\.bulkEditDocuments.execute)` with signature `(BulkEditDocumentsInput, Server) async throws -> Void`, Task 1's `Value.confirmationAssign/confirmationRemove/method`, Task 2's `Operation`.
- Produces: `DocumentBulkEditConfirmationView(message:cancel:confirm:)`; `Action.applyConfirmed`; `Action.View.applyButtonTapped`; `State.confirmationMessage: LocalizedStringResource?`; `Effect.runConfirmApply<Value>(message:)` and `Effect.runBulkEdit<Value>(documents:id:server:)`. Task 5's view sends `.view(.applyButtonTapped)`; Task 6 observes the resulting `.delegate(.documentsUpdated)`.

- [ ] **Step 1: Write the failing reducer tests**

Add to `DocumentBulkEditGenericValueReducerTests`, after `test_view_resetButtonTapped`:

```swift
    @Test
    func test_view_applyButtonTapped_presentsConfirmation() async throws {
        let presentationCount = LockIsolated(0)
        let store = TestStore(initialState: .testValue(
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.popupPresenter.present = { _ in presentationCount.setValue(presentationCount.value + 1) }
        }

        await store.send(.view(.applyButtonTapped))
        #expect(presentationCount.value == 1)
    }

    @Test
    func test_view_applyButtonTapped_doesNothingWhenUnedited() async throws {
        let presentationCount = LockIsolated(0)
        let store = TestStore(initialState: .testValue()) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.popupPresenter.present = { _ in presentationCount.setValue(presentationCount.value + 1) }
        }

        await store.send(.view(.applyButtonTapped))
        #expect(presentationCount.value == 0)
    }

    @Test
    func test_applyConfirmed_assign() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operation: .assign(2)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        let sent = try #require(input.value)
        #expect(sent.documents.sorted() == [10, 11])
        #expect(sent.method == .setCorrespondent(.init(correspondent: 2)))
    }

    @Test
    func test_applyConfirmed_remove() async throws {
        let input = LockIsolated<BulkEditDocumentsInput?>(nil)
        let store = TestStore(initialState: .testValue(
            documents: [10, 11],
            operation: .remove
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { bulkEditInput, _ in input.setValue(bulkEditInput) }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.delegate.documentsUpdated)

        let sent = try #require(input.value)
        #expect(sent.method == .setCorrespondent(.init(correspondent: nil)))
    }

    @Test
    func test_applyConfirmed_error() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(initialState: .testValue(
            operation: .assign(1)
        )) {
            DocumentBulkEditGenericValueReducer<Correspondent>()
        } withDependencies: {
            $0.bulkEditDocuments.execute = { _, _ in
                throw ApiError.testValue()
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.applyConfirmed) {
            $0.isSaving = true
        }
        await store.receive(\.error) {
            $0.isSaving = false
        }
        #expect(toasts.value == [.error("Something went wrong")])
    }

    @Test
    func test_confirmationMessage() async throws {
        let assign = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documents: [10, 11],
            operation: .assign(1)
        )
        #expect(assign.confirmationMessage == .correspondentBulkEditConfirmationAssign("C1", 2))

        let remove = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
            documents: [10, 11],
            operation: .remove
        )
        #expect(remove.confirmationMessage == .correspondentBulkEditConfirmationRemove(2))

        let unedited = DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue()
        #expect(unedited.confirmationMessage == nil)
    }
```

`sent.documents.sorted()` is needed because `documents` is a `Set` and the request's array order is therefore unspecified.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — build error, `type '…Action' has no member 'applyConfirmed'`.

- [ ] **Step 3: Write the confirmation view**

Create `Modules/DocumentsFeature/DocumentBulkEdit/DocumentBulkEditConfirmationView.swift`:

```swift
import Components
import SwiftUI

struct DocumentBulkEditConfirmationView: View {
    var body: some View {
        Sheet {
            Text(.confirmAssignment)
        } content: {
            Text(message)
                .font(.body)
                .foregroundStyle(Color.m3OnSurface)
                .frame(
                    maxWidth: .infinity,
                    maxHeight: .infinity,
                    alignment: .topLeading
                )
        } bottom: {
            AdaptiveStack {
                Button {
                    cancel()
                } label: {
                    Text(.cancel)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.secondary())
                .frame(maxWidth: .infinity)

                Button {
                    confirm()
                } label: {
                    Text(.confirm)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
        }
        .background(Color.m3Surface)
        .clipShape(RoundedRectangle(cornerRadius: Constants.cornerRadius))
        .padding(.x4)
        .frame(maxWidth: 600)
    }

    init(
        message: LocalizedStringResource,
        cancel: @escaping () -> Void,
        confirm: @escaping () -> Void
    ) {
        self.message = message
        self.cancel = cancel
        self.confirm = confirm
    }

    private let message: LocalizedStringResource
    private let cancel: () -> Void
    private let confirm: () -> Void
}

extension DocumentBulkEditConfirmationView {

    static func testValue(
        message: LocalizedStringResource = .correspondentBulkEditConfirmationAssign("C1", 3),
        cancel: @escaping () -> Void = {},
        confirm: @escaping () -> Void = {}
    ) -> Self {
        .init(
            message: message,
            cancel: cancel,
            confirm: confirm
        )
    }
}
```

This mirrors `Modules/CertificatesFeature/CertificateApproval/CertificateApprovalView.swift` — the one existing consumer of `PopupPresenter` — down to the background/clip/padding/frame chain that gives the popup its card shape.

- [ ] **Step 4: Add the two effects**

Add to `DocumentBulkEditGenericValueReducer+Effect.swift`, inside `extension Effect` after `runGetSelectionData`:

```swift
    static func runBulkEdit<Value: DocumentBulkEditGenericValue>(
        documents: Set<Document.Id>,
        id: Value.ID?,
        server: Server
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
        @Dependency(\.bulkEditDocuments.execute)
        var bulkEditDocuments

        let input = BulkEditDocumentsInput(
            documents: Array(documents),
            method: Value.method(id: id)
        )

        return .run { send in
            try await bulkEditDocuments(input, server)
            await send(.delegate(.documentsUpdated))
        } catch: { error, send in
            await send(.error(error))
        }
        .cancellable(id: CancelID.bulkEdit)
    }

    static func runConfirmApply<Value: DocumentBulkEditGenericValue>(
        message: LocalizedStringResource
    ) -> Self where Action == DocumentBulkEditGenericValueReducer<Value>.Action {
        .run { send in
            @Dependency(\.popupPresenter)
            var popupPresenter

            await popupPresenter.present {
                DocumentBulkEditConfirmationView(
                    message: message,
                    cancel: {
                        Task {
                            await popupPresenter.dismiss()
                        }
                    },
                    confirm: {
                        Task {
                            await popupPresenter.dismiss()
                            await send(.applyConfirmed)
                        }
                    }
                )
            }
        }
    }
```

Extend `CancelID` at the bottom of the same file:

```swift
private enum CancelID {
    case bulkEdit
    case getSelectionData
}
```

Also add `import Components` and `import SwiftUI` to the file's import block (alphabetically: `ApiInterface`, `Components`, `ComposableArchitecture`, `Foundation`, `SwiftUI`) — `Components` for `PopupPresenter`, `SwiftUI` for `LocalizedStringResource` in the signature.

Unlike `CertificateApprovalReducer`, which needs an async channel because its popup is triggered from a `URLSession` delegate outside the store, this one originates inside the store — so the confirm closure captures `send` directly.

- [ ] **Step 5: Wire the actions into the reducer**

In `DocumentBulkEditGenericValueReducer.swift`, add to `Action` as the first case (alphabetically before `binding`):

```swift
        case applyConfirmed
```

Add to `Action.View` as the first case:

```swift
            case applyButtonTapped
```

Add `confirmationMessage` to `State`, alphabetically between `documents` and `filteredValues`:

```swift
        var confirmationMessage: LocalizedStringResource? {
            switch operation {
            case let .assign(id):
                guard let value = values[id: id] else {
                    return nil
                }
                return Value.confirmationAssign(name: value.description, documentCount: documents.count)
            case .remove:
                return Value.confirmationRemove(documentCount: documents.count)
            case nil:
                return nil
            }
        }
```

Add to the `Reduce` switch, as the first case:

```swift
            case .applyConfirmed:
                guard let operation = state.operation else {
                    return .none
                }
                state.isSaving = true
                return .runBulkEdit(
                    documents: state.documents,
                    id: {
                        if case let .assign(id) = operation {
                            return id
                        }
                        return nil
                    }(),
                    server: state.server
                )
```

Add to the inner `viewAction` switch, as the first case:

```swift
                case .applyButtonTapped:
                    guard let message = state.confirmationMessage else {
                        return .none
                    }
                    return .runConfirmApply(message: message)
```

- [ ] **Step 6: Run the reducer tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, including the six new apply-flow tests.

- [ ] **Step 7: Write the confirmation view snapshot test**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/DocumentBulkEditConfirmationViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentBulkEditConfirmationViewTests {

    @Test
    func testSnapshot_assign() async throws {
        assertSnapshot(
            of: DocumentBulkEditConfirmationView.testValue(
                message: .correspondentBulkEditConfirmationAssign("C1", 3)
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "assign"
        )
    }

    @Test
    func testSnapshot_remove() async throws {
        assertSnapshot(
            of: DocumentBulkEditConfirmationView.testValue(
                message: .correspondentBulkEditConfirmationRemove(3)
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "remove"
        )
    }
}
```

- [ ] **Step 8: Run to record the snapshots (expected to fail)**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL for the two new snapshot tests with "No reference was found on disk. Automatically recorded snapshot". Two new PNGs appear under `Snapshots/DocumentsFeatureTests/DocumentBulkEditConfirmationViewTests/`.

- [ ] **Step 9: Inspect the recorded snapshots, then re-run to verify they pass**

Open the two PNGs and confirm they show a card with the "Confirm assignment" header bar, the sentence, and Cancel / Confirm buttons. If they look wrong, fix the view and delete the PNGs before re-recording.

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, all tests including both snapshot tests.

- [ ] **Step 10: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit Modules/DocumentsFeatureTests/DocumentBulkEdit Snapshots/DocumentsFeatureTests/DocumentBulkEditConfirmationViewTests
git commit -m "feat: add bulk edit apply flow with confirmation popup"
```

---

## Task 5: The bulk edit sheet view

**Files:**
- Create: `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueView.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueViewTests.swift`

**Interfaces:**
- Consumes: everything from Tasks 1–4 — `Value.editTitle`, `State.filteredValues`, `State.isEdited`, `State.isLoading`, `State.isSaving`, `State.documentCounts`, `State.systemImage(for:)`, and the `.view(.applyButtonTapped / .closeButtonTapped / .onAppear / .resetButtonTapped / .valueTapped)` actions. Components: `Sheet`, `SheetHeader`, `Searchable`, `EmptyListView`, `AdaptiveStack`, `.buttonStyle(.primary(isLoading:))` / `.secondary()`.
- Produces: `DocumentBulkEditGenericValueView<Value>(store:)`. Task 6 presents it from three `.sheet` modifiers.

- [ ] **Step 1: Write the view**

Create `Modules/DocumentsFeature/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueView.swift`:

```swift
import ApiInterface
import Components
import ComposableArchitecture
import SwiftUI

struct DocumentBulkEditGenericValueView<Value: DocumentBulkEditGenericValue>: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: Value.editTitle,
                left: leftHeader
            )
        } content: {
            list()
        } bottom: {
            buttons()
        }
        .task { await store.send(.view(.onAppear)).finish() }
    }

    @Bindable
    var store: StoreOf<DocumentBulkEditGenericValueReducer<Value>>

    @ViewBuilder
    private func buttons() -> some View {
        AdaptiveStack {
            Button {
                store.send(.view(.resetButtonTapped))
            } label: {
                Text(.reset)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.secondary())
            .disabled(!store.isEdited)

            Button {
                store.send(.view(.applyButtonTapped))
            } label: {
                Text(.apply)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.primary(isLoading: $store.isSaving))
            .disabled(!store.isEdited)
        }
    }

    @ViewBuilder
    private func emptyListView() -> some View {
        if store.filteredValues.isEmpty, !store.isLoading {
            ContentUnavailableView {
                EmptyListView(systemImage: "tray")
            }
        }
    }

    @ViewBuilder
    private func leftHeader() -> some View {
        Button {
            store.send(.view(.closeButtonTapped))
        } label: {
            Image(systemName: "xmark")
                .accessibilityLabel(.close)
        }
    }

    @ViewBuilder
    private func list() -> some View {
        Searchable {
            List(store.filteredValues) { value in
                Button {
                    store.send(.view(.valueTapped(value)))
                } label: {
                    HStack(spacing: .x4) {
                        Image(systemName: store.state.systemImage(for: value))
                            .font(.title2)
                            .fontWeight(.medium)
                            .foregroundStyle(Color.m3Outline)
                        Text(value.description)
                            .font(.body)
                            .foregroundStyle(Color.m3OnSurface)
                        Spacer()
                        Text(String(store.documentCounts[value.id] ?? 0))
                            .font(.caption2)
                            .foregroundStyle(Color.m3OnSurface)
                    }
                }
                .foregroundStyle(Color.m3OnSurface)
                .id(value.id)
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                .listRowSeparator(.hidden)
            }
            .background(Color.m3Surface)
            .environment(\.defaultMinListRowHeight, 0)
            .listStyle(.plain)
            .navigationBarHidden(true)
            .overlay(emptyListView())
            .overlay(loadingView())
            .presentationDetents([.sheet])
            .scrollContentBackground(.hidden)
            .searchable(text: $store.searchText)
        }
    }

    @ViewBuilder
    private func loadingView() -> some View {
        if store.isLoading {
            ProgressView()
                .controlSize(.large)
        }
    }
}
```

Three things worth flagging:

- `store.state.systemImage(for:)` goes through `.state` because `Store`'s dynamic member lookup forwards properties, not methods.
- There is deliberately **no** `@ViewAction(for:)` macro here, and actions are sent as `store.send(.view(…))`. `DocumentFilterGenericValueListView` — the generic view this one mirrors — does the same; the macro is used only on the non-generic views in this module.
- The list/row chain is copied from `DocumentFilterGenericValueListView` so both sheets look identical; the trailing count `Text` is the one addition.

- [ ] **Step 2: Write the snapshot test**

Create `Modules/DocumentsFeatureTests/DocumentBulkEdit/GenericValue/DocumentBulkEditGenericValueViewTests.swift`:

```swift
@testable import DocumentsFeature

import ApiInterface
import ComposableArchitecture
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentBulkEditGenericValueViewTests {

    @Test
    func testSnapshot_unedited() async throws {
        assertSnapshot(
            of: DocumentBulkEditGenericValueView<Correspondent>(
                store: Store(
                    initialState: DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
                        documentCounts: [1: 2, 2: 1],
                        documents: [10, 11]
                    ),
                    reducer: {
                        DocumentBulkEditGenericValueReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "unedited"
        )
    }

    @Test
    func testSnapshot_edited() async throws {
        assertSnapshot(
            of: DocumentBulkEditGenericValueView<Correspondent>(
                store: Store(
                    initialState: DocumentBulkEditGenericValueReducer<Correspondent>.State.testValue(
                        documentCounts: [1: 2, 2: 1],
                        documents: [10, 11],
                        operation: .assign(2)
                    ),
                    reducer: {
                        DocumentBulkEditGenericValueReducer()
                    }
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "edited"
        )
    }
}
```

The unedited snapshot is the interesting one: C1 has all 2 documents so it renders `checkmark.circle.fill`, C2 has 1 of 2 so it renders `minus.circle`, and Reset/Apply are disabled. The edited one shows the pending assign and enabled buttons.

- [ ] **Step 3: Run to record the snapshots (expected to fail)**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL for the two new snapshot tests with "No reference was found on disk. Automatically recorded snapshot". Two new PNGs appear under `Snapshots/DocumentsFeatureTests/DocumentBulkEditGenericValueViewTests/`.

- [ ] **Step 4: Inspect the recorded snapshots, then re-run to verify they pass**

Open both PNGs. Confirm: teal header bar reading "Edit correspondent" with an ✕ on the left; rows "C1 … 2" and "C2 … 1" with the tick and minus icons respectively; Reset and Apply at the bottom, greyed out in `unedited` and enabled in `edited`. If they look wrong, fix the view and delete the PNGs before re-recording.

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, all tests.

- [ ] **Step 5: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentBulkEdit Modules/DocumentsFeatureTests/DocumentBulkEdit Snapshots/DocumentsFeatureTests/DocumentBulkEditGenericValueViewTests
git commit -m "feat: add bulk edit sheet view"
```

---

## Task 6: Wire the sheets into the document list

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`
- Test: `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`

**Interfaces:**
- Consumes: `DocumentBulkEditGenericValueReducer<Correspondent/DocumentType/StoragePath>` and its `State(documents:server:values:)` (Tasks 2–4), `DocumentBulkEditGenericValueView` (Task 5), `Effect.runGetDocuments(filterRules:server:sortDirection:sortField:)` (`DocumentListReducer+Effect.swift`, already exists), `SharedReaderKey.correspondents(_:)` / `.documentTypes(_:)` / `.storagePaths(_:)` (`Modules/ApiInterface/Extensions/SharedReaderKey+Extensions.swift`, already exist).
- Produces: three new `DocumentListReducer.Destination` cases, three new `Action.View` cases, and the wired toolbar. Nothing depends on this task.

- [ ] **Step 1: Write the failing tests**

Add to `Modules/DocumentsFeatureTests/DocumentList/DocumentListReducerTests.swift`, following the file's existing ordering and style:

```swift
    @Test
    func test_view_editCorrespondentButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editCorrespondentButtonTapped)) {
            $0.destination = .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.correspondents
            ))
        }
    }

    @Test
    func test_view_editDocumentTypeButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editDocumentTypeButtonTapped)) {
            $0.destination = .bulkEditDocumentType(DocumentBulkEditGenericValueReducer<DocumentType>.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.documentTypes
            ))
        }
    }

    @Test
    func test_view_editStoragePathButtonTapped() async throws {
        let store = TestStore(initialState: .testValue(
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        }

        await store.send(.view(.editStoragePathButtonTapped)) {
            $0.destination = .bulkEditStoragePath(DocumentBulkEditGenericValueReducer<StoragePath>.State(
                documents: [1, 2],
                server: $0.server,
                values: $0.storagePaths
            ))
        }
    }

    @Test
    func test_destination_bulkEditCorrespondent_documentsUpdated() async throws {
        let store = TestStore(initialState: .testValue(
            destination: .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>.State(
                documents: [1, 2],
                server: .testValue(),
                values: []
            )),
            documentSelection: .testValue(
                isActive: true,
                selectedDocuments: [1, 2]
            )
        )) {
            DocumentListReducer()
        } withDependencies: {
            $0.getDocuments.execute = { _, _ in
                .testValue(
                    count: 77,
                    results: [.testValue()]
                )
            }
        }

        await store.send(.destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated))))) {
            $0.destination = nil
        }
        await store.receive(\.replaceDocuments, .testValue(
            count: 77,
            results: [.testValue()]
        )) {
            $0.documents = [.testValue()]
            $0.documentSelection.allLoadedDocuments = [1]
            $0.totalNumberOfDocuments = 77
        }
        await store.receive(\.binding, .set(\.isLoaded, true)) {
            $0.isLoaded = true
        }

        #expect(store.state.documentSelection.isActive == true)
        #expect(store.state.documentSelection.selectedDocuments == [1, 2])
    }
```

The last test is the important one: it pins that the delegate dismisses the sheet, triggers a refetch, and leaves selection mode and the selection untouched. Its `getDocuments` stub and the two `receive` assertions are copied verbatim from `test_view_allDocumentsButtonTapped` in the same file — including the trailing `.binding(.set(\.isLoaded, true))` that every `runGetDocuments` emits and that is easy to forget.

- [ ] **Step 2: Run the tests to verify they fail**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: FAIL — build error, `type 'DocumentListReducer.Action.View' has no member 'editCorrespondentButtonTapped'`.

- [ ] **Step 3: Add the destinations and shared collections**

In `Modules/DocumentsFeature/DocumentList/DocumentListReducer.swift`, replace the `Destination` enum body so the three new cases sort before `documentFilter`:

```swift
    @Reducer
    public enum Destination {
        case bulkEditCorrespondent(DocumentBulkEditGenericValueReducer<Correspondent>)
        case bulkEditDocumentType(DocumentBulkEditGenericValueReducer<DocumentType>)
        case bulkEditStoragePath(DocumentBulkEditGenericValueReducer<StoragePath>)
        case documentFilter(DocumentFilterReducer)
    }
```

Add three `@Shared` properties to `State`, alongside the existing `@Shared var savedViews` and matching its formatting (`correspondents` and `documentTypes` before `savedViews`, `storagePaths` after):

```swift
        @Shared

        var correspondents: IdentifiedArrayOf<Correspondent>
```
```swift
        @Shared

        var documentTypes: IdentifiedArrayOf<DocumentType>
```
```swift
        @Shared

        var storagePaths: IdentifiedArrayOf<StoragePath>
```

And initialise them in `init`, next to the existing `self._savedViews = …` line:

```swift
            self._correspondents = Shared(wrappedValue: [], .correspondents(server))
            self._documentTypes = Shared(wrappedValue: [], .documentTypes(server))
            self._storagePaths = Shared(wrappedValue: [], .storagePaths(server))
```

- [ ] **Step 4: Add the view actions and the delegate handler**

In the same file, add to `Action.View`, keeping alphabetical order (after `allDocumentsButtonTapped`, before `filterButtonTapped`):

```swift
            case editCorrespondentButtonTapped
            case editDocumentTypeButtonTapped
            case editStoragePathButtonTapped
```

Add the shared delegate handler to the `Reduce` switch, before the existing `case let .destination(.presented(.documentFilter(…)))`:

```swift
            case .destination(.presented(.bulkEditCorrespondent(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditDocumentType(.delegate(.documentsUpdated)))),
                 .destination(.presented(.bulkEditStoragePath(.delegate(.documentsUpdated)))):
                state.destination = nil
                return .runGetDocuments(
                    filterRules: state.filter.input.filterRules,
                    server: state.server,
                    sortDirection: state.filter.input.sort.direction,
                    sortField: state.filter.input.sort.field
                )
```

Add the three view actions to the inner `viewAction` switch, after `case .allDocumentsButtonTapped`:

```swift
                case .editCorrespondentButtonTapped:
                    state.destination = .bulkEditCorrespondent(DocumentBulkEditGenericValueReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.correspondents
                    ))
                    return .none
                case .editDocumentTypeButtonTapped:
                    state.destination = .bulkEditDocumentType(DocumentBulkEditGenericValueReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.documentTypes
                    ))
                    return .none
                case .editStoragePathButtonTapped:
                    state.destination = .bulkEditStoragePath(DocumentBulkEditGenericValueReducer.State(
                        documents: state.documentSelection.selectedDocuments,
                        server: state.server,
                        values: state.storagePaths
                    ))
                    return .none
```

- [ ] **Step 5: Run the reducer tests to verify they pass**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS, including the four new `DocumentListReducerTests` tests.

- [ ] **Step 6: Wire the toolbar buttons and sheets**

Rewrite `Modules/DocumentsFeature/DocumentList/DocumentListBottomToolbar.swift`'s private modifier. Two structural changes beyond wiring: `store` becomes `@Bindable` (required for `$store.scope`), and each button gets `.disabled(store.documentSelection.selectedDocuments.isEmpty)`:

```swift
import ApiInterface
import ComposableArchitecture
import SwiftUI

extension View {

    func documentListBottomToolbar(
        store: StoreOf<DocumentListReducer>,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) -> some View {
        modifier(
            DocumentListBottomToolbar(
                store: store,
                viewAction: viewAction
            )
        )
    }
}

private struct DocumentListBottomToolbar: ViewModifier {
    func body(content: Content) -> some View {
        content
            .toolbarVisibility(store.documentSelection.tabBarVisibility, for: .tabBar)
            .toolbar {
                ToolbarItem(placement: .bottomBar) {
                    if store.documentSelection.isActive {
                        selectActionsMenu
                    }
                }
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditCorrespondent,
                    action: \.destination.bulkEditCorrespondent
                )
            ) { store in
                DocumentBulkEditGenericValueView(store: store)
                    .presentationDetents([.sheet])
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditDocumentType,
                    action: \.destination.bulkEditDocumentType
                )
            ) { store in
                DocumentBulkEditGenericValueView(store: store)
                    .presentationDetents([.sheet])
            }
            .sheet(
                item: $store.scope(
                    state: \.destination?.bulkEditStoragePath,
                    action: \.destination.bulkEditStoragePath
                )
            ) { store in
                DocumentBulkEditGenericValueView(store: store)
                    .presentationDetents([.sheet])
            }
    }

    init(
        store: StoreOf<DocumentListReducer>,
        viewAction: @escaping (DocumentListReducer.Action.View) -> StoreTask
    ) {
        self.store = store
        self.viewAction = viewAction
    }

    @ViewBuilder
    private var selectActionsMenu: some View {
        HStack(spacing: .x5) {
            Button {
                send(.editCorrespondentButtonTapped)
            } label: {
                Label(.editCorrespondent, systemImage: "person")
            }

            Button {
                send(.editDocumentTypeButtonTapped)
            } label: {
                Label(.editDocumentType, systemImage: "document.badge.gearshape")
            }

            Button {
                send(.editStoragePathButtonTapped)
            } label: {
                Label(.editStoragePath, systemImage: "folder")
            }

            Button {} label: {
                Label(.editTags, systemImage: "tag")
            }
        }
        .disabled(store.documentSelection.selectedDocuments.isEmpty)
        .font(.title3)
        .padding(.horizontal, .x4)
    }

    @discardableResult
    private func send(_ action: DocumentListReducer.Action.View) -> StoreTask {
        viewAction(action)
    }

    @Bindable
    private var store: StoreOf<DocumentListReducer>

    private let viewAction: (DocumentListReducer.Action.View) -> StoreTask
}
```

The tags button keeps its empty action — it is out of scope for this plan.

- [ ] **Step 7: Run the full suite**

Run: `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE`
Expected: PASS. If `DocumentListViewTests`' snapshots changed because of the `.disabled` modifier, inspect the diff (`mise run snapshots diff`) and re-record only if the change is the expected greying-out of an empty selection.

- [ ] **Step 8: Format and commit**

```bash
mise run format
git add Modules/DocumentsFeature/DocumentList Modules/DocumentsFeatureTests/DocumentList
git commit -m "feat: wire bulk edit sheets into the document list toolbar"
```

- [ ] **Step 9: Verify in the simulator**

Build and run the app, select two documents whose correspondents differ, and tap the person icon. Confirm: the sheet lists correspondents with counts and tri-state icons, Reset/Apply start disabled, tapping a value enables them, Apply raises the confirmation popup, Confirm dismisses both and refreshes the list, and selection mode is still active with the same documents selected afterwards. Repeat for document type and storage path.

---

## Definition of Done

- `tuist test DocumentsFeature -d "iPhone 17 Pro" --os 26.4 --no-selective-testing -- -testLanguage en -testRegion DE` passes in full.
- Tapping the correspondent, document type and storage path buttons in the selection toolbar each opens a working bulk-edit sheet; the tags button remains a no-op.
- The confirmation popup appears before any `bulk_edit` request, and cancelling it makes no request.
- After a successful apply the sheet closes, the list refetches, and selection mode plus the selection survive so a second bulk edit can be chained.
- All four new snapshot references are committed under `Snapshots/DocumentsFeatureTests/`.
- `mise run format` produces no further changes.
