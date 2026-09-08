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
