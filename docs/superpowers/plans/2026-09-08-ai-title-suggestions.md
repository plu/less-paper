# On-device Title Suggestions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add a button to the document edit form's title field that asks Apple's on-device model for three title suggestions and puts the chosen one into the field as a staged edit.

**Architecture:** A new `Intelligence` framework module holds a `TitleSuggestionClient` dependency client, the prompt, the truncation policy and the only `FoundationModels` import (wholly behind `@available(iOS 26, *)`). `DocumentsFeature` builds a plain-string context from state it already holds, presents a bottom sheet that streams suggestions, and writes the chosen one into `input.title`. `Components`' `TitleField` grows an optional trailing button.

**Tech Stack:** Swift 6, SwiftUI, The Composable Architecture, swift-dependencies (`@DependencyClient`), Apple `FoundationModels` (iOS 26), Tuist 4.206.0, swift-snapshot-testing, Swift Testing.

**Spec:** `docs/superpowers/specs/2026-09-08-ai-title-suggestions-design.md`

## Global Constraints

Read `AGENTS.md` before starting. These apply to every task:

- **Comment style:** `///` documents a declaration (one line, two at most); `//` explains a line inside a body. Never `/** ... */`. Skip the member whose name is already the whole story. Comment only when something is **exceptional** — a non-obvious constraint, a subtle trap, a decision that looks wrong until you know why.
- **Deployment target is iOS 18.0.** `FoundationModels` is iOS 26. Every use of it sits behind `@available(iOS 26, *)`, and `FoundationModels` is imported in exactly one file: `Modules/Intelligence/TitleSuggestionClient+Live.swift`.
- **Every module owns its strings.** A new user-facing string goes in `Modules/<Name>/Resources/Localizable.xcstrings` for the module that *displays* it, in both `en` and `de`, with `"extractionState": "manual"`, keys sorted alphabetically. Two modules both showing "Suggest title" each get their own key — the duplication is the design.
- **`@ViewAction` views send with `send`, never `store.send`.**
- **Never** `.confirmationDialog`, `.alert`, or `ConfirmationDialogState`.
- **Properties within a type are ordered alphabetically** (see any existing reducer).
- **Warnings are errors on CI only.** Reproduce with `TUIST_WARNINGS_AS_ERRORS=true tuist generate --no-open` — it is read at *generate* time, not run time.
- **Snapshot references:** a test with no reference writes one on the first run and fails; the second run passes against it. **Look at what was recorded before trusting it.** Use `mise run snapshots:diff`.
- After any change to `Tuist/ProjectDescriptionHelpers/**`, run `tuist generate --no-open` before building.

**Commands** (`tuist` is on `PATH`; `TEST_SIMULATOR`/`TEST_SIMULATOR_OS` are exported by mise):

```bash
tuist generate --no-open
tuist test <Scheme> -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
mise run format        # swiftformat + swiftlint --fix + attribute_blank_lines
mise run ci:lint       # five steps, set -eou pipefail — the FIRST failure hides the rest
```

---

### Task 1: The `Intelligence` module — context, error, client seam

Creates the module and everything in it that does not touch `FoundationModels`. The truncation and prompt policy is the part worth testing, and it is testable with no model in the loop.

**Files:**
- Create: `Modules/Intelligence/TitleSuggestionContext.swift`
- Create: `Modules/Intelligence/TitleSuggestionError.swift`
- Create: `Modules/Intelligence/TitleSuggestionClient.swift`
- Create: `Modules/Intelligence/Resources/.gitkeep` — **do NOT create a `Localizable.xcstrings` here.** This module has no user-facing text; an empty catalogue would put it back on the rebuild path for every string change in the project. (If an empty `Resources` directory is awkward, omit it entirely — the module needs no resources at all.)
- Create: `Modules/IntelligenceTests/TitleSuggestionContextTests.swift`
- Modify: `Tuist/ProjectDescriptionHelpers/Module.swift` (three places)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift` (two new blocks)
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift` (two places)

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `TitleSuggestionContext` with memberwise `init(archiveSerialNumber:content:correspondent:createdDate:customFields:documentType:storagePath:tags:title:)`, all defaulted; `var prompt: String`; `static let contentLimit = 2000`; nested `TitleSuggestionContext.CustomFieldValue(label:value:)`.
  - `TitleSuggestionError` — `.contextWindowExceeded`, `.failed(String)`, `.guardrailViolation`, `.unavailable`.
  - `TitleSuggestionClient` with `isAvailable: @Sendable () -> Bool` and `suggest: @Sendable (TitleSuggestionContext) -> AsyncThrowingStream<[String], any Error>`; `DependencyValues.titleSuggestion`.

- [ ] **Step 1: Add the module to the Tuist manifests**

In `Tuist/ProjectDescriptionHelpers/Module.swift`, add to the `Module` enum (alphabetical — after `case imageFeature` / `imageFeatureTests`, before `licensesFeature`):

```swift
    case intelligence = "Intelligence"
    case intelligenceTests = "IntelligenceTests"
```

In the same file, add `.intelligence,` to the `codeCoverageTarget` `true` case (after `.imageFeature,`) and to the `product` framework case (after `.imageFeature,`). Add `.intelligenceTests,` to the `product` `.unitTests` case (after `.imageFeatureTests,`).

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add two blocks. Place them after the `.imageFeatureTests` block:

```swift
        case .intelligence:
            [
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.logging),
            ]
        case .intelligenceTests:
            [
                .external(.dependenciesTestSupport),
                .target(.intelligence),
                .target(.testSupport),
            ]
```

In `Tuist/ProjectDescriptionHelpers/Module+Schemes.swift`, add `.intelligence,` to the framework-scheme case list (after `.imageFeature,`) and `.intelligenceTests,` to the empty `[]` case list (after `.imageFeatureTests,`).

- [ ] **Step 2: Write the failing tests**

Create `Modules/IntelligenceTests/TitleSuggestionContextTests.swift`:

```swift
@testable import Intelligence

import Testing

@Suite
struct TitleSuggestionContextTests {

    @Test
    func test_prompt_shortContent_isNotTruncated() {
        let context = TitleSuggestionContext(content: "A short invoice.")

        #expect(context.prompt.contains("A short invoice."))
        #expect(!context.prompt.contains("…"))
    }

    @Test
    func test_prompt_longContent_clipsAtAWordBoundary() throws {
        // 700 five-character words is 4200 characters, comfortably past the limit.
        let content = Array(repeating: "abcd", count: 700).joined(separator: " ")
        let context = TitleSuggestionContext(content: content)

        let clipped = try #require(
            context.prompt.split(separator: "\n").last.map(String.init)
        )

        #expect(clipped.hasSuffix("…"))
        #expect(clipped.count <= TitleSuggestionContext.contentLimit + 1)
        // A boundary cut never leaves a half word: dropping the ellipsis must leave whole words.
        #expect(!clipped.dropLast().hasSuffix(" "))
        #expect(clipped.dropLast().split(separator: " ").allSatisfy { $0 == "abcd" })
    }

    @Test
    func test_prompt_longContentWithNoSpaces_clipsHard() {
        let content = String(repeating: "x", count: 5000)
        let context = TitleSuggestionContext(content: content)

        #expect(context.prompt.contains(String(repeating: "x", count: TitleSuggestionContext.contentLimit)))
        #expect(context.prompt.hasSuffix("…"))
    }

    @Test
    func test_prompt_populatedFields_allAppear() {
        let context = TitleSuggestionContext(
            archiveSerialNumber: "412",
            content: "Electricity for August.",
            correspondent: "Stadtwerke München",
            createdDate: "17 August 2024",
            customFields: [.init(label: "Amount", value: "84.20 EUR")],
            documentType: "Invoice",
            storagePath: "Utilities",
            tags: ["Utilities", "Paid"],
            title: "scan_20240817_113052"
        )

        let prompt = context.prompt

        #expect(prompt.contains("scan_20240817_113052"))
        #expect(prompt.contains("Stadtwerke München"))
        #expect(prompt.contains("Invoice"))
        #expect(prompt.contains("Utilities, Paid"))
        #expect(prompt.contains("412"))
        #expect(prompt.contains("17 August 2024"))
        #expect(prompt.contains("Amount: 84.20 EUR"))
        #expect(prompt.contains("Electricity for August."))
    }

    @Test
    func test_prompt_emptyFields_areOmittedRatherThanNamed() {
        // Spending tokens to tell the model what the document is *not* is worse than saying nothing.
        let context = TitleSuggestionContext(content: "Body text.")

        let prompt = context.prompt

        #expect(!prompt.contains("Correspondent"))
        #expect(!prompt.contains("Document type"))
        #expect(!prompt.contains("Storage path"))
        #expect(!prompt.contains("Tags"))
        #expect(!prompt.contains("Archive serial number"))
        #expect(!prompt.contains("Current title"))
    }

    @Test
    func test_prompt_blankStringsCountAsEmpty() {
        let context = TitleSuggestionContext(
            content: "Body text.",
            correspondent: "   ",
            title: ""
        )

        #expect(!context.prompt.contains("Correspondent"))
        #expect(!context.prompt.contains("Current title"))
    }
}
```

- [ ] **Step 3: Run the tests to verify they fail**

```bash
tuist generate --no-open
tuist test Intelligence -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: compile failure — `cannot find 'TitleSuggestionContext' in scope`.

- [ ] **Step 4: Write `TitleSuggestionContext`**

Create `Modules/Intelligence/TitleSuggestionContext.swift`:

```swift
import Foundation

/// Everything the model is told about one document, as plain strings.
///
/// Deliberately not a `Document`: keeping the API-layer types out is what lets this module stay off
/// `ApiInterface`, and it is the caller's job to format dates and resolve entity names.
public struct TitleSuggestionContext: Equatable, Sendable {

    /// The model's context window is about 4k tokens and a scanned multi-page document runs to tens
    /// of thousands of characters, so something has to give. A document's identifying information is
    /// almost always on its first page.
    public static let contentLimit = 2000

    public struct CustomFieldValue: Equatable, Sendable {

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }

        public let label: String

        public let value: String
    }

    public init(
        archiveSerialNumber: String? = nil,
        content: String = "",
        correspondent: String? = nil,
        createdDate: String = "",
        customFields: [CustomFieldValue] = [],
        documentType: String? = nil,
        storagePath: String? = nil,
        tags: [String] = [],
        title: String = ""
    ) {
        self.archiveSerialNumber = archiveSerialNumber
        self.content = content
        self.correspondent = correspondent
        self.createdDate = createdDate
        self.customFields = customFields
        self.documentType = documentType
        self.storagePath = storagePath
        self.tags = tags
        self.title = title
    }

    public let archiveSerialNumber: String?

    public let content: String

    public let correspondent: String?

    public let createdDate: String

    public let customFields: [CustomFieldValue]

    public let documentType: String?

    public let storagePath: String?

    public let tags: [String]

    public let title: String

    /// The user prompt. Instructions live on the session, not here.
    public var prompt: String {
        var lines: [String] = []

        appendIfPresent(&lines, "Current title", title)
        appendIfPresent(&lines, "Correspondent", correspondent)
        appendIfPresent(&lines, "Document type", documentType)
        appendIfPresent(&lines, "Storage path", storagePath)
        appendIfPresent(&lines, "Tags", tags.isEmpty ? nil : tags.joined(separator: ", "))
        appendIfPresent(&lines, "Archive serial number", archiveSerialNumber)
        appendIfPresent(&lines, "Created", createdDate)

        for field in customFields {
            appendIfPresent(&lines, field.label, field.value)
        }

        lines.append("")
        lines.append("Document text:")
        lines.append(Self.truncated(content))

        return lines.joined(separator: "\n")
    }

    static func truncated(_ content: String) -> String {
        guard content.count > contentLimit else {
            return content
        }

        let clipped = content.prefix(contentLimit)

        guard let boundary = clipped.lastIndex(where: \.isWhitespace) else {
            // A single unbroken run of characters — OCR of a barcode, say. There is no boundary to
            // find, so a hard cut is the only option.
            return String(clipped) + "…"
        }

        return String(clipped[..<boundary]) + "…"
    }

    private func appendIfPresent(_ lines: inout [String], _ label: String, _ value: String?) {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        lines.append("\(label): \(value)")
    }
}
```

- [ ] **Step 5: Run the tests to verify they pass**

```bash
tuist test Intelligence -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: 6 tests PASS.

- [ ] **Step 6: Write `TitleSuggestionError` and `TitleSuggestionClient`**

Create `Modules/Intelligence/TitleSuggestionError.swift`:

```swift
/// Why a suggestion could not be produced.
///
/// The point of this type is that a caller never has to import `FoundationModels` — and so never has
/// to carry an `@available(iOS 26, *)` annotation of its own — just to tell two failures apart.
public enum TitleSuggestionError: Error, Equatable, Sendable {
    case contextWindowExceeded
    case failed(String)
    case guardrailViolation
    case unavailable
}
```

Create `Modules/Intelligence/TitleSuggestionClient.swift`:

```swift
import Dependencies
import DependenciesMacros

/// The on-device title suggester, as features see it.
@DependencyClient
public struct TitleSuggestionClient: Sendable {

    /// Whether the model can run at all here — the OS version, the hardware, whether Apple
    /// Intelligence is on, and whether the model has finished downloading, collapsed into one answer.
    /// The button is not rendered when this is false, so there is nothing to explain to the user.
    public var isAvailable: @Sendable () -> Bool = { false }

    /// Yields the whole list as it stands after each streamed snapshot, never a delta, so a caller
    /// replaces its state rather than accumulating into it.
    public var suggest: @Sendable (TitleSuggestionContext)
        -> AsyncThrowingStream<[String], any Error> = { _ in AsyncThrowingStream { $0.finish() } }
}

extension TitleSuggestionClient: TestDependencyKey {

    public static let previewValue = Self(
        isAvailable: { true },
        suggest: { _ in
            AsyncThrowingStream { continuation in
                continuation.yield([
                    "Electricity bill — August 2024",
                    "Stadtwerke München invoice 84.20 EUR",
                    "Utilities statement, August 2024",
                ])
                continuation.finish()
            }
        }
    )

    /// Unimplemented, unlike `LogClient`'s no-op: a test that reaches the model by accident should
    /// say so rather than quietly return nothing.
    public static let testValue = Self()
}

public extension DependencyValues {

    var titleSuggestion: TitleSuggestionClient {
        get { self[TitleSuggestionClient.self] }
        set { self[TitleSuggestionClient.self] = newValue }
    }
}
```

- [ ] **Step 7: Verify it all builds and passes**

```bash
tuist generate --no-open
tuist test Intelligence -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
mise run format
mise run ci:lint
```

Expected: tests PASS, `ci:lint` clean. If `tuist inspect dependencies --only implicit` names a target, add the missing `.target(...)` to `Module+Dependencies.swift` — it will not be caught by any test.

- [ ] **Step 8: Commit**

```bash
git add Modules/Intelligence Modules/IntelligenceTests Tuist/ProjectDescriptionHelpers
git commit -m "feat: an Intelligence module holding the title-suggestion seam"
```

---

### Task 2: The live `FoundationModels` implementation

The only file in the project that imports `FoundationModels`. There is no unit test: the model cannot be driven deterministically, and CI must not depend on Apple Intelligence being enabled on the runner. Verification is a compile plus the weak-link check.

**Files:**
- Create: `Modules/Intelligence/TitleSuggestionClient+Live.swift`

**Interfaces:**
- Consumes: `TitleSuggestionContext.prompt`, `TitleSuggestionError`, `TitleSuggestionClient` (Task 1); `DependencyValues.log` from `Logging`.
- Produces: `TitleSuggestionClient.liveValue`.

- [ ] **Step 1: Write the live client**

Create `Modules/Intelligence/TitleSuggestionClient+Live.swift`:

```swift
import Dependencies
import Foundation
import FoundationModels
import Logging

extension TitleSuggestionClient: DependencyKey {

    public static let liveValue = Self(
        isAvailable: {
            guard #available(iOS 26, *) else {
                return false
            }
            return TitleSuggestionSession.isAvailable
        },
        suggest: { context in
            guard #available(iOS 26, *) else {
                return AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.unavailable) }
            }
            return TitleSuggestionSession.stream(context)
        }
    )
}

@available(iOS 26, *)
private enum TitleSuggestionSession {

    /// Guardrails, not the default ones, and the choice is load-bearing. A personal archive is full
    /// of what `.default` refuses — medical letters, debt notices, accident paperwork — so under it
    /// the feature would fail on exactly the documents hardest to title by hand.
    /// `.permissiveContentTransformations` is Apple's setting for transforming content the user
    /// already holds, which is what a scan of their own paper is.
    static let model = SystemLanguageModel(guardrails: .permissiveContentTransformations)

    static var isAvailable: Bool {
        model.availability == .available
    }

    static func stream(_ context: TitleSuggestionContext) -> AsyncThrowingStream<[String], any Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                @Dependency(\.log)
                var log

                do {
                    let session = LanguageModelSession(model: model) {
                        instructions
                    }
                    // Sampling is random and unseeded so that Regenerate can return something
                    // different. Under the default greedy sampling a second call on an unchanged
                    // document reproduces the first exactly, and a button that reliably repeats
                    // itself is a button that lies.
                    let response = session.streamResponse(
                        to: context.prompt,
                        generating: SuggestedTitles.self,
                        options: GenerationOptions(sampling: .random(top: 50))
                    )

                    for try await snapshot in response {
                        continuation.yield(snapshot.content.titles ?? [])
                    }
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    let mapped = map(error)
                    log.error("Title suggestion failed: \(String(describing: mapped))", category: .app)
                    continuation.finish(throwing: mapped)
                }
            }

            continuation.onTermination = { _ in task.cancel() }
        }
    }

    static var instructions: String {
        """
        You name scanned documents in a personal document archive.

        Suggest exactly three distinct titles for the document described below.

        Rules:
        - Write each title in the same language as the document text. Do not translate.
        - At most 60 characters.
        - No file extensions, no quotation marks, no trailing punctuation.
        - Prefer concrete identifiers: sender, subject, reference or invoice number, period.
        - Do not repeat the current title verbatim.
        """
    }

    static func map(_ error: any Error) -> TitleSuggestionError {
        guard let error = error as? LanguageModelSession.GenerationError else {
            return .failed(error.localizedDescription)
        }

        return switch error {
        case .exceededContextWindowSize:
            // Should not survive truncation. If it does it must not masquerade as something else —
            // that is an afternoon spent looking at the wrong layer.
            .contextWindowExceeded
        case .guardrailViolation:
            .guardrailViolation
        default:
            .failed(error.localizedDescription)
        }
    }
}

@available(iOS 26, *)
@Generable
private struct SuggestedTitles {

    @Guide(description: "Three distinct titles, best first.", .count(3))
    var titles: [String]
}
```

- [ ] **Step 2: Verify it compiles**

```bash
tuist generate --no-open
tuist build Intelligence -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS"
```

Expected: build succeeds. If `LogCategory` has no `.app` case, use whichever case the enum in `Modules/Logging/LogCategory.swift` defines for general app errors — read the file rather than guessing.

- [ ] **Step 3: Verify FoundationModels is weak-linked**

This is the check with no test behind it. An iOS 26 framework hard-linked into an iOS 18 binary makes the app fail to launch on iOS 18 — and every simulator here runs 26.5, so nothing else would catch it.

```bash
BIN=$(find ~/Library/Developer/Xcode/DerivedData Derived -name "Intelligence" -type f -path "*Intelligence.framework*" 2>/dev/null | head -1)
otool -l "$BIN" | grep -A 2 -i foundationmodels
```

Expected: the load command is `LC_LOAD_WEAK_DYLIB`, **not** `LC_LOAD_DYLIB`. If it is `LC_LOAD_DYLIB`, stop and report it — the fix is an explicit `.sdk(name: "FoundationModels", type: .framework, status: .optional)` entry in the `.intelligence` dependency block, and it changes the plan.

- [ ] **Step 4: Run the existing tests, format, lint**

```bash
tuist test Intelligence -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
mise run format
mise run ci:lint
```

Expected: PASS and clean. The Task 1 tests still pass — nothing in this task changes them.

- [ ] **Step 5: Commit**

```bash
git add Modules/Intelligence/TitleSuggestionClient+Live.swift
git commit -m "feat: drive title suggestions through the on-device model"
```

---

### Task 3: The suggest button on `TitleField`

Independent of Tasks 1 and 2 — it can be done in any order relative to them.

**Files:**
- Modify: `Modules/Components/Field/Concrete/TitleField.swift`
- Modify: `Modules/Components/Resources/Localizable.xcstrings`
- Create: `Modules/ComponentsTests/Field/TitleFieldTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces: `TitleField(text:suggestButtonTapped:)`, where `suggestButtonTapped` is `(() -> Void)?` defaulting to `nil`.

- [ ] **Step 1: Add the string**

In `Modules/Components/Resources/Localizable.xcstrings`, add a `suggestTitle` key. Keys are sorted alphabetically — it goes between `scheme` and `suggestions`:

```json
    "suggestTitle" : {
      "extractionState" : "manual",
      "localizations" : {
        "de" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Titel vorschlagen"
          }
        },
        "en" : {
          "stringUnit" : {
            "state" : "translated",
            "value" : "Suggest title"
          }
        }
      }
    },
```

- [ ] **Step 2: Write the failing snapshot tests**

Create `Modules/ComponentsTests/Field/TitleFieldTests.swift`:

```swift
@testable import Components

import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct TitleFieldTests {

    // Without an action the field must render exactly as it did before the button existed, which is
    // what keeps the ShareFormView and bulk-edit references valid.
    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                TitleField(text: .constant(""))
                TitleField(text: .constant("Electricity bill — August 2024"))
            }
            .frame(width: 375)
            .padding(),
            as: .image(layout: .sizeThatFits)
        )
    }

    @Test
    func testSnapshot_withSuggestButton() async throws {
        assertSnapshot(
            of: VStack(alignment: .leading, spacing: 8) {
                TitleField(text: .constant(""), suggestButtonTapped: {})
                // The button stays once there is text: renaming a badly titled document is the case
                // this feature is for, unlike ASN, whose button hides for the opposite reason.
                TitleField(text: .constant("scan_20240817_113052"), suggestButtonTapped: {})
            }
            .frame(width: 375)
            .padding(),
            as: .image(layout: .sizeThatFits),
            named: "withSuggestButton"
        )
    }
}
```

- [ ] **Step 3: Run to verify it fails**

```bash
tuist generate --no-open
tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: compile failure — `extra argument 'suggestButtonTapped' in call`.

- [ ] **Step 4: Add the button to `TitleField`**

Replace `Modules/Components/Field/Concrete/TitleField.swift` with:

```swift
import SwiftUI

public struct TitleField: View {
    public var body: some View {
        // Two layouts rather than one with a hidden button: the no-action shape has to stay
        // byte-identical to what ShareFormView and bulk edit already render, and Field's padding
        // differs between them.
        if let suggestButtonTapped {
            Field(.title, padding: .x0) {
                HStack {
                    TextField(String(localized: .title), text: $text)
                        .padding(.leading, .x2 + .x3)
                        .textFieldStyle(.plain)
                    Spacer()
                    Button {
                        suggestButtonTapped()
                    } label: {
                        Image(systemName: "sparkles")
                            .accessibilityLabel(.suggestTitle)
                    }
                    .buttonStyle(.ghost())
                }
            }
        } else {
            Field(.title) {
                TextField(String(localized: .title), text: $text)
                    .textFieldStyle(.plain)
            }
        }
    }

    public init(text: Binding<String>, suggestButtonTapped: (() -> Void)? = nil) {
        _text = text
        self.suggestButtonTapped = suggestButtonTapped
    }

    private let suggestButtonTapped: (() -> Void)?

    @Binding
    private var text: String
}
```

- [ ] **Step 5: Run the tests, then look at what was recorded**

```bash
tuist test Components -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: **FAIL on the first run** — no reference exists yet, so swift-snapshot-testing writes one and fails. Run it a second time; it passes against what it just wrote.

**Then actually look at the two images** in `Snapshots/ComponentsTests/TitleFieldTests/`. A reference records whatever the code produced, bug included:

```bash
mise run snapshots:diff
```

Confirm: the plain field matches today's rendering; the button version shows a `sparkles` glyph at the trailing edge, vertically centred in the capsule, not clipped by it, and present in *both* the empty and the filled field.

- [ ] **Step 6: Verify the other three call sites are untouched**

```bash
tuist test ShareFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: PASS with no snapshot changes. A failure here means the no-action branch is not rendering identically and must be fixed rather than re-recorded.

- [ ] **Step 7: Format, lint, commit**

```bash
mise run format
mise run ci:lint
git add Modules/Components Modules/ComponentsTests Snapshots/ComponentsTests
git commit -m "feat: an optional suggest button on the title field"
```

---

### Task 4: `DocumentTitleSuggestionsReducer`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsReducer.swift`
- Create: `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsReducer+Effect.swift`
- Create: `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsReducer+TestValue.swift`
- Create: `Modules/DocumentsFeatureTests/DocumentTitleSuggestions/DocumentTitleSuggestionsReducerTests.swift`
- Modify: `Modules/DocumentsFeature/Resources/Localizable.xcstrings`
- Modify: `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`

**Interfaces:**
- Consumes: `TitleSuggestionClient`, `TitleSuggestionContext`, `TitleSuggestionError` (Task 1).
- Produces: `DocumentTitleSuggestionsReducer` with `State(context:)`, `Action.delegate(.titleSelected(String))`, and `State.testValue(context:error:isGenerating:suggestions:)`.

- [ ] **Step 1: Declare the dependency**

In `Tuist/ProjectDescriptionHelpers/Module+Dependencies.swift`, add `.target(.intelligence),` to **both** the `.documentsFeature` block (after `.target(.imageFeature),`) and the `.documentsFeatureTests` block. Without this, `tuist inspect dependencies --only implicit` fails in `ci:lint` — and nothing else will catch it, because the code compiles and the tests pass.

- [ ] **Step 2: Add the strings**

In `Modules/DocumentsFeature/Resources/Localizable.xcstrings`, add five keys, each in alphabetical position, with `"extractionState": "manual"` and both `en` and `de`:

| Key | en | de |
|---|---|---|
| `regenerate` | `Regenerate` | `Neu generieren` |
| `suggestTitle` | `Suggest title` | `Titel vorschlagen` |
| `titleSuggestionDeclined` | `The model declined to suggest a title for this document.` | `Das Modell hat für dieses Dokument keinen Titel vorgeschlagen.` |
| `titleSuggestionFailed` | `Titles could not be suggested.` | `Titel konnten nicht vorgeschlagen werden.` |
| `titleSuggestionTooLong` | `This document is too long to suggest a title for.` | `Dieses Dokument ist zu lang für einen Titelvorschlag.` |

`suggestTitle` is deliberately a second copy of the key added to `Components` in Task 3 — a module can only use strings in its own catalogue, and that duplication is the design.

- [ ] **Step 3: Write the failing tests**

Create `Modules/DocumentsFeatureTests/DocumentTitleSuggestions/DocumentTitleSuggestionsReducerTests.swift`:

```swift
@testable import DocumentsFeature

import ComposableArchitecture
import Intelligence
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies()
)
struct DocumentTitleSuggestionsReducerTests {

    @Test
    func test_view_onAppear_streamsSuggestions() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(["First"])
                    continuation.yield(["First", "Second"])
                    continuation.finish()
                }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        // Each snapshot carries the whole list, so state is replaced rather than appended to.
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["First"]
        }
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["First", "Second"]
        }
        await store.receive(\.generationFinished) {
            $0.isGenerating = false
        }
    }

    @Test
    func test_view_suggestionTapped_delegatesTheTitle() async throws {
        let store = TestStore(
            initialState: DocumentTitleSuggestionsReducer.State.testValue(suggestions: ["Chosen"])
        ) {
            DocumentTitleSuggestionsReducer()
        }

        await store.send(.view(.suggestionTapped("Chosen")))
        await store.receive(\.delegate.titleSelected)
    }

    @Test
    func test_view_regenerateButtonTapped_clearsTheOldRowsFirst() async throws {
        // Rows are keyed by index, so a new stream filling into a populated array would show a mix
        // of old and new titles while it ran.
        let store = TestStore(
            initialState: DocumentTitleSuggestionsReducer.State.testValue(suggestions: ["Old"])
        ) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(["New"])
                    continuation.finish()
                }
            }
        }

        await store.send(.view(.regenerateButtonTapped)) {
            $0.isGenerating = true
            $0.suggestions = []
        }
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["New"]
        }
        await store.receive(\.generationFinished) {
            $0.isGenerating = false
        }
    }

    @Test
    func test_generationFinished_guardrailViolation_saysTheModelDeclined() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.guardrailViolation) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        await store.receive(\.generationFinished) {
            $0.error = String(localized: .titleSuggestionDeclined)
            $0.isGenerating = false
        }
    }

    @Test
    func test_generationFinished_contextWindowExceeded_saysTheDocumentIsTooLong() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.contextWindowExceeded) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        await store.receive(\.generationFinished) {
            $0.error = String(localized: .titleSuggestionTooLong)
            $0.isGenerating = false
        }
    }

    @Test
    func test_generationFinished_otherError_fallsBackToTheGenericMessage() async throws {
        let store = TestStore(initialState: DocumentTitleSuggestionsReducer.State.testValue()) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { $0.finish(throwing: TitleSuggestionError.failed("boom")) }
            }
        }

        await store.send(.view(.onAppear)) {
            $0.isGenerating = true
        }
        await store.receive(\.generationFinished) {
            $0.error = String(localized: .titleSuggestionFailed)
            $0.isGenerating = false
        }
    }

    @Test
    func test_view_retryButtonTapped_clearsTheError() async throws {
        let store = TestStore(
            initialState: DocumentTitleSuggestionsReducer.State.testValue(
                error: String(localized: .titleSuggestionFailed)
            )
        ) {
            DocumentTitleSuggestionsReducer()
        } withDependencies: {
            $0.titleSuggestion.suggest = { _ in
                AsyncThrowingStream { continuation in
                    continuation.yield(["Recovered"])
                    continuation.finish()
                }
            }
        }

        await store.send(.view(.retryButtonTapped)) {
            $0.error = nil
            $0.isGenerating = true
            $0.suggestions = []
        }
        await store.receive(\.suggestionsUpdated) {
            $0.suggestions = ["Recovered"]
        }
        await store.receive(\.generationFinished) {
            $0.isGenerating = false
        }
    }
}
```

- [ ] **Step 4: Run to verify it fails**

```bash
tuist generate --no-open
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: compile failure — `cannot find 'DocumentTitleSuggestionsReducer' in scope`.

- [ ] **Step 5: Write the reducer**

Create `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsReducer.swift`:

```swift
import Components
import ComposableArchitecture
import Intelligence

@Reducer
public struct DocumentTitleSuggestionsReducer: Sendable {

    public enum Action: BindableAction, ViewAction {
        case binding(BindingAction<State>)
        case delegate(Delegate)
        case generationFinished(TitleSuggestionError?)
        case suggestionsUpdated([String])
        case view(View)

        @CasePathable
        public enum Delegate {
            case titleSelected(String)
        }

        public enum View {
            case closeButtonTapped
            case onAppear
            case regenerateButtonTapped
            case retryButtonTapped
            case suggestionTapped(String)
        }
    }

    @ObservableState
    public struct State: Equatable {

        let context: TitleSuggestionContext

        var error: String?

        var isGenerating = false

        var suggestions: [String] = []

        init(context: TitleSuggestionContext) {
            self.context = context
        }
    }

    public init() {}

    public var body: some ReducerOf<Self> {
        BindingReducer()
        Reduce { state, action in
            switch action {
            case let .generationFinished(error):
                state.isGenerating = false
                state.error = error.map(message(for:))
                return .none
            case let .suggestionsUpdated(suggestions):
                state.suggestions = suggestions
                return .none
            case let .view(viewAction):
                switch viewAction {
                case .closeButtonTapped:
                    return .runDismiss()
                case .onAppear:
                    guard state.suggestions.isEmpty, state.error == nil, !state.isGenerating else {
                        return .none
                    }
                    return start(&state)
                case .regenerateButtonTapped, .retryButtonTapped:
                    return start(&state)
                case let .suggestionTapped(title):
                    return .send(.delegate(.titleSelected(title)))
                }
            case .binding, .delegate:
                return .none
            }
        }
    }

    private func start(_ state: inout State) -> Effect<Action> {
        state.error = nil
        state.isGenerating = true
        // Cleared rather than left in place: rows are keyed by index, so a new stream filling into
        // a populated array would show a mix of the old titles and the new ones as it ran.
        state.suggestions = []
        return .runSuggest(context: state.context)
    }

    private func message(for error: TitleSuggestionError) -> String {
        switch error {
        case .contextWindowExceeded:
            String(localized: .titleSuggestionTooLong)
        case .guardrailViolation:
            String(localized: .titleSuggestionDeclined)
        case .failed, .unavailable:
            String(localized: .titleSuggestionFailed)
        }
    }
}
```

Create `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsReducer+Effect.swift`:

```swift
import ComposableArchitecture
import Intelligence

extension Effect where Action == DocumentTitleSuggestionsReducer.Action {

    static func runDismiss() -> Self {
        .run { _ in
            @Dependency(\.dismiss)
            var dismiss

            await dismiss()
        }
    }

    static func runSuggest(context: TitleSuggestionContext) -> Self {
        .run { send in
            @Dependency(\.titleSuggestion.suggest)
            var suggest

            for try await suggestions in suggest(context) {
                await send(.suggestionsUpdated(suggestions))
            }
            await send(.generationFinished(nil))
        } catch: { error, send in
            await send(.generationFinished(error as? TitleSuggestionError ?? .failed(error.localizedDescription)))
        }
        // Regenerate replaces the run in flight, and dismissing the sheet ends it, so a stream
        // cannot outlive the sheet that started it.
        .cancellable(id: CancelID.suggest, cancelInFlight: true)
    }
}

private enum CancelID {
    case suggest
}
```

Create `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsReducer+TestValue.swift`:

```swift
import Intelligence

extension DocumentTitleSuggestionsReducer.State {

    static func testValue(
        context: TitleSuggestionContext = TitleSuggestionContext(content: "Electricity for August."),
        error: String? = nil,
        isGenerating: Bool = false,
        suggestions: [String] = []
    ) -> Self {
        var state = Self(context: context)
        state.error = error
        state.isGenerating = isGenerating
        state.suggestions = suggestions
        return state
    }
}
```

- [ ] **Step 6: Run to verify the tests pass**

```bash
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: the 7 new tests PASS, and every existing `DocumentsFeature` test still passes.

- [ ] **Step 7: Format, lint, commit**

```bash
mise run format
mise run ci:lint
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Tuist/ProjectDescriptionHelpers
git commit -m "feat: a reducer that streams title suggestions"
```

---

### Task 5: `DocumentTitleSuggestionsView`

**Files:**
- Create: `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsView.swift`
- Create: `Modules/DocumentsFeatureTests/DocumentTitleSuggestions/DocumentTitleSuggestionsViewTests.swift`

**Interfaces:**
- Consumes: `DocumentTitleSuggestionsReducer` and its `State.testValue(context:error:isGenerating:suggestions:)` (Task 4).
- Produces: `DocumentTitleSuggestionsView(store:)`.

- [ ] **Step 1: Write the failing snapshot tests**

Create `Modules/DocumentsFeatureTests/DocumentTitleSuggestions/DocumentTitleSuggestionsViewTests.swift`:

```swift
@testable import DocumentsFeature

import ComposableArchitecture
import Dependencies
import Intelligence
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .dependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct DocumentTitleSuggestionsViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: view(
                state: .testValue(suggestions: [
                    "Electricity bill — August 2024",
                    "Stadtwerke München invoice 84.20 EUR",
                    "Utilities statement, August 2024",
                ])
            ),
            as: .image(layout: .device(config: .iPhone12))
        )
    }

    // Two rows in and still running: the state a user actually sees for most of the generation.
    @Test
    func testSnapshot_streaming() async throws {
        assertSnapshot(
            of: view(
                state: .testValue(
                    isGenerating: true,
                    suggestions: ["Electricity bill — August 2024", "Stadtwerke München invoice"]
                )
            ),
            as: .image(layout: .device(config: .iPhone12)),
            named: "streaming"
        )
    }

    @Test
    func testSnapshot_generating() async throws {
        assertSnapshot(
            of: view(state: .testValue(isGenerating: true)),
            as: .image(layout: .device(config: .iPhone12)),
            named: "generating"
        )
    }

    @Test
    func testSnapshot_error() async throws {
        assertSnapshot(
            of: view(state: .testValue(error: String(localized: .titleSuggestionFailed))),
            as: .image(layout: .device(config: .iPhone12)),
            named: "error"
        )
    }

    private func view(state: DocumentTitleSuggestionsReducer.State) -> some View {
        DocumentTitleSuggestionsView(
            store: Store(
                initialState: state,
                reducer: {
                    DocumentTitleSuggestionsReducer()
                }
            )
        )
    }
}
```

- [ ] **Step 2: Run to verify it fails**

```bash
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: compile failure — `cannot find 'DocumentTitleSuggestionsView' in scope`.

- [ ] **Step 3: Write the view**

Create `Modules/DocumentsFeature/DocumentTitleSuggestions/DocumentTitleSuggestionsView.swift`:

```swift
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentTitleSuggestionsReducer.self)
struct DocumentTitleSuggestionsView: View {
    var body: some View {
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(
                title: .suggestTitle,
                left: {
                    SheetCloseButton {
                        send(.closeButtonTapped)
                    }
                },
                right: {
                    Button {
                        send(.regenerateButtonTapped)
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .sheetHeaderTapTarget()
                            .accessibilityLabel(.regenerate)
                    }
                    .disabled(store.isGenerating)
                }
            )
        } content: {
            content()
                .presentationDetents([.sheet])
        }
        // On the Sheet, not on the populated list: `suggestions` is empty when the sheet opens, so
        // an onAppear inside the list branch would never fire and nothing would ever generate.
        .onAppear { send(.onAppear) }
    }

    @Bindable
    var store: StoreOf<DocumentTitleSuggestionsReducer>

    @ViewBuilder
    private func content() -> some View {
        if let error = store.error {
            EmptyListView(
                systemImage: "sparkles",
                title: .init(stringLiteral: error)
            ) {
                Button {
                    send(.retryButtonTapped)
                } label: {
                    Text(.retry)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.primary())
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if store.suggestions.isEmpty {
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            suggestions()
        }
    }

    @ViewBuilder
    private func suggestions() -> some View {
        List {
            // Keyed by offset, not by value: a row's text fills in as the model streams, and its
            // position is what stays constant.
            ForEach(Array(store.suggestions.enumerated()), id: \.offset) { _, suggestion in
                Button {
                    send(.suggestionTapped(suggestion))
                } label: {
                    Text(suggestion)
                        .font(.body)
                        .foregroundStyle(Color.m3OnSurface)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .listRowBackground(Color.m3Surface)
                .listRowInsets(EdgeInsets(top: .x4, leading: .x4, bottom: .x3, trailing: .x4))
                .listRowSeparator(.hidden)
            }

            if store.isGenerating {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.m3Surface)
                    .listRowSeparator(.hidden)
            }
        }
        .background(Color.m3Surface)
        .environment(\.defaultMinListRowHeight, 0)
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }
}
```

- [ ] **Step 4: Run twice, then look at the four references**

```bash
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

First run FAILS having written references; second run PASSES. Then:

```bash
mise run snapshots:diff
```

Confirm each of the four images differs from the others and shows what its name claims: `generating` a centred spinner with no rows; `streaming` two rows with a spinner beneath; the default three rows and no spinner; `error` the message with a Retry button. **Four references that are byte-identical to each other assert nothing** — if two match, the view is not rendering the state you think it is.

- [ ] **Step 5: Format, lint, commit**

```bash
mise run format
mise run ci:lint
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots/DocumentsFeatureTests
git commit -m "feat: a sheet that offers streamed title suggestions"
```

---

### Task 6: Wire the sheet into the document edit form

**Files:**
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift`
- Modify: `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift`
- Create: `Modules/DocumentsFeature/DocumentForm/DocumentFormInput+TitleSuggestionContext.swift`
- Modify: `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormReducerTests.swift`
- Modify: `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormViewTests.swift`

**Interfaces:**
- Consumes: `DocumentTitleSuggestionsReducer` (Task 4), `DocumentTitleSuggestionsView` (Task 5), `TitleField(text:suggestButtonTapped:)` (Task 3), `TitleSuggestionClient.isAvailable` (Task 1).
- Produces: nothing downstream.

- [ ] **Step 1: Write the failing reducer tests**

Append to `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormReducerTests.swift`, inside the existing suite:

```swift
    @Test
    func test_view_onAppear_modelUnavailable_hidesTheSuggestButton() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(content: "Body.")) {
            DocumentFormReducer()
        } withDependencies: {
            $0.titleSuggestion.isAvailable = { false }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))

        #expect(store.state.canSuggestTitle == false)
    }

    @Test
    func test_view_onAppear_modelAvailable_showsTheSuggestButton() async throws {
        let store = TestStore(initialState: DocumentFormReducer.State.testValue(content: "Body.")) {
            DocumentFormReducer()
        } withDependencies: {
            $0.titleSuggestion.isAvailable = { true }
        }
        store.exhaustivity = .off

        await store.send(.view(.onAppear))

        #expect(store.state.canSuggestTitle)
    }

    @Test
    func test_view_suggestTitleButtonTapped_carriesTheStagedFieldsIntoTheContext() async throws {
        // The staged input, not the saved document: a user who has just picked a correspondent
        // should get suggestions that know about it.
        var state = DocumentFormReducer.State.testValue(content: "Electricity for August.")
        state.input.title = "scan_20240817_113052"
        state.input.correspondent = .testValue(name: "Stadtwerke München")

        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        }
        store.exhaustivity = .off

        await store.send(.view(.suggestTitleButtonTapped))

        let context = try #require(store.state.destination?.titleSuggestions?.context)
        #expect(context.title == "scan_20240817_113052")
        #expect(context.correspondent == "Stadtwerke München")
        #expect(context.content == "Electricity for August.")
    }

    @Test
    func test_destination_titleSelected_stagesTheTitleWithoutSaving() async throws {
        var state = DocumentFormReducer.State.testValue(content: "Body.")
        state.destination = .titleSuggestions(.testValue(suggestions: ["Chosen title"]))

        let store = TestStore(initialState: state) {
            DocumentFormReducer()
        } withDependencies: {
            $0.updateDocument.execute = { _, _, _ in
                Issue.record("Choosing a suggestion stages a title; it must not save the document.")
                return .testValue()
            }
        }

        await store.send(.destination(.presented(.titleSuggestions(.delegate(.titleSelected("Chosen title")))))) {
            $0.destination = nil
            $0.input.title = "Chosen title"
        }

        #expect(store.state.isModified)
    }
```

- [ ] **Step 2: Run to verify it fails**

```bash
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: compile failure — `value of type 'DocumentFormReducer.State' has no member 'canSuggestTitle'`.

- [ ] **Step 3: Build the context from the form's state**

Create `Modules/DocumentsFeature/DocumentForm/DocumentFormInput+TitleSuggestionContext.swift`:

```swift
import ApiInterface
import Foundation
import Intelligence

extension DocumentFormInput {

    /// Content is passed in rather than read from the input, because the form holds it separately —
    /// `nil` until the full document lands, since the list payload truncates it.
    func titleSuggestionContext(content: String?, server: Server) -> TitleSuggestionContext {
        TitleSuggestionContext(
            archiveSerialNumber: archiveSerialNumber,
            content: content ?? "",
            correspondent: correspondent?.name,
            createdDate: DateFormatter.createdDate.string(from: createdDate),
            customFields: customFields.compactMap { row in
                // Resolved through the cache, matching how `DocumentFormInput` reads definitions
                // everywhere else.
                guard let field = row.id.get(server), let value = row.value.promptValue else {
                    return nil
                }
                return TitleSuggestionContext.CustomFieldValue(label: field.name, value: value)
            },
            documentType: documentType?.name,
            storagePath: storagePath?.name,
            tags: tags.map(\.name).sorted(),
            title: title
        )
    }
}
```

`Correspondent`, `DocumentType`, `StoragePath`, `Tag` and `CustomField` all expose `public let name: String` — verified. `DateFormatter.createdDate` is `public` in `ApiInterface` (`yyyy-MM-dd`), so it is visible here; `Components` declares a second one with the same name and format, which is why the `import ApiInterface` above matters.

`DocumentFormCustomFieldValue` has **no** string rendering — it offers only `json(field:)`. Add one in `Modules/DocumentsFeature/DocumentForm/CustomFields/DocumentFormCustomFieldValue.swift`, beside `isEditable`:

```swift
    /// What this value contributes to a title-suggestion prompt, or nil when it contributes nothing.
    ///
    /// Select options and document links are stored as ids rather than labels, so they would reach
    /// the model as bare numbers — noise that costs tokens and says nothing about the document.
    var promptValue: String? {
        switch self {
        case let .boolean(flag):
            String(flag)
        case let .date(date):
            date.map { DateFormatter.createdDate.string(from: $0) }
        case let .monetary(currency, amount):
            amount.isEmpty ? nil : "\(currency)\(amount)"
        case let .number(text):
            text.isEmpty ? nil : text
        case let .text(text):
            text.isEmpty ? nil : text
        case .documentLink, .select, .unsupported:
            nil
        }
    }
```

- [ ] **Step 4: Wire the reducer**

In `Modules/DocumentsFeature/DocumentForm/DocumentFormReducer.swift`:

Add `import Intelligence` at the top (alphabetical, after `DocumentTypesFeature`).

Add to `Destination`:

```swift
        case titleSuggestions(DocumentTitleSuggestionsReducer)
```

Add to `Action.View` (alphabetically, after `saveButtonTapped`):

```swift
            case suggestTitleButtonTapped
```

Add to `State` (alphabetically among the `var`s, after `canCreateTag`'s neighbours — put it with the other `can…` computed properties but as a stored `var`):

```swift
        /// Set on appearance rather than computed: reading model availability is a framework call,
        /// and a computed property would make it on every render.
        var canSuggestTitle = false
```

Add the dependency to the reducer, above `body`:

```swift
    @Dependency(\.titleSuggestion)
    private var titleSuggestion
```

In the `.onAppear` case, set the flag before the existing guard:

```swift
                case .onAppear:
                    state.canSuggestTitle = titleSuggestion.isAvailable()
                    let resolveLinked = Effect.runResolveLinkedCustomFieldDocuments(state)
```

Add the new view case:

```swift
                case .suggestTitleButtonTapped:
                    state.destination = .titleSuggestions(
                        DocumentTitleSuggestionsReducer.State(
                            context: state.input.titleSuggestionContext(
                                content: state.content,
                                server: state.server
                            )
                        )
                    )
                    return .none
```

Add the delegate handler beside the other `destination` cases:

```swift
            case let .destination(.presented(.titleSuggestions(.delegate(.titleSelected(title))))):
                state.destination = nil
                state.input.title = title
                return .none
```

Add the `Scope` for the child by including it in `Destination` — the `@Reducer enum Destination` macro handles this; no manual `Scope` is needed.

- [ ] **Step 5: Wire the view**

In `Modules/DocumentsFeature/DocumentForm/DocumentFormView.swift`, replace the `TitleField` line in `detailsSection()`:

```swift
            TitleField(
                text: $store.input.title,
                suggestButtonTapped: store.canSuggestTitle ? { send(.suggestTitleButtonTapped) } : nil
            )
            .sheet(
                item: $store.scope(
                    state: \.destination?.titleSuggestions,
                    action: \.destination.titleSuggestions
                )
            ) { store in
                DocumentTitleSuggestionsView(store: store)
            }
```

- [ ] **Step 6: Run the tests**

```bash
tuist test DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS" -- -testLanguage en -testRegion DE
```

Expected: the 4 new tests PASS and every existing form test still passes. The form's own snapshots are recorded with `canSuggestTitle == false` (its default, and `testValue` never sends `.onAppear`), so they should be unchanged. **If a form snapshot changed, look at it** — a changed reference here means the button is showing where the test never enabled it.

- [ ] **Step 7: Add a form snapshot with the button showing**

Append to `Modules/DocumentsFeatureTests/DocumentForm/DocumentFormViewTests.swift`, matching the `view(state:)` helper already in that file:

```swift
    @Test
    func testSnapshot_canSuggestTitle() async throws {
        var state = DocumentFormReducer.State.testValue(content: "Electricity for August.")
        state.canSuggestTitle = true

        assertSnapshot(
            of: view(state: state),
            as: .image(layout: .device(config: .iPhone12)),
            named: "canSuggestTitle"
        )
    }
```

Run twice (first writes, second passes), then `mise run snapshots:diff` and confirm the sparkles button appears in the title field and the rest of the form is unchanged from the default snapshot.

- [ ] **Step 8: Format, lint, commit**

```bash
mise run format
mise run ci:lint
git add Modules/DocumentsFeature Modules/DocumentsFeatureTests Snapshots/DocumentsFeatureTests
git commit -m "feat: suggest a document title from the edit form"
```

---

### Task 7: Whole-suite verification and the manual device check

**Files:** none — this task changes nothing.

- [ ] **Step 1: Run the full unit suite**

```bash
mise run ci:test:unit
```

Expected: PASS. This is broader than the per-scheme runs: it catches a target that compiles alone but breaks a consumer.

- [ ] **Step 2: Reproduce CI's warnings-as-errors**

Locally warnings are tolerated; on CI they are errors, and this branch adds a new module, a new macro-generated reducer and an availability-gated file — all easy sources of a warning nobody sees.

```bash
TUIST_WARNINGS_AS_ERRORS=true tuist generate --no-open
tuist build DocumentsFeature -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS"
tuist build Intelligence -d "$TEST_SIMULATOR" -o "$TEST_SIMULATOR_OS"
tuist generate --no-open
```

Expected: both builds succeed. The flag is read at *generate* time, so the final bare `tuist generate` is what puts the workspace back to warning-tolerant.

- [ ] **Step 3: Run the lint gate one more time**

```bash
mise run ci:lint
```

Expected: all five steps clean. Remember the first failure masks the rest — after fixing a formatting failure, run it again and expect a *second* failure rather than assuming you are done.

- [ ] **Step 4: Report what could not be verified**

The live path was never executed. State this plainly rather than implying the feature is proven:

- `TitleSuggestionClient+Live.swift` was compiled, not run. No test drives the real model.
- Prompt quality is unassessed: whether three titles come back genuinely distinct, whether the same-language instruction holds on a German document, whether `.permissiveContentTransformations` is in fact enough for medical or legal paperwork.
- Whether `Regenerate` produces different titles in practice — unseeded sampling is the mechanism, but only a real run shows whether the variation is meaningful.

These need a hands-on check on an Apple Intelligence-capable device before merge.

- [ ] **Step 5: Push**

```bash
GIT_TERMINAL_PROMPT=0 mise exec -- fnox exec -- git \
  -c 'credential.helper=!f(){ echo username=x-access-token; echo "password=$GH_TOKEN"; };f' \
  push -u origin feature/ai-title-suggestions
```

A PR title is a commit message — these are squash merged, so the title becomes the line in `git log origin/main`. Use `feat: suggest a document title with the on-device model`.
