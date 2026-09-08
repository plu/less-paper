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
    func test_prompt_isTheDocumentTextAlone() {
        // EXPERIMENT (2026-09-08): the prompt carries the document text and nothing else. The
        // metadata is still populated on the type — only `prompt` ignores it — so these assertions
        // are what pins that, and they go back to the previous three tests when the experiment is
        // reverted.
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

        #expect(context.prompt == "Electricity for August.")
    }
}
