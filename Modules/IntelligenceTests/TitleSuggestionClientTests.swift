@testable import Intelligence

import Testing

// Guards a split that today is guaranteed only by how `@DependencyClient` generates per-endpoint
// storage: `isAvailable` defaults to `false` with no reporting, `suggest` reports an issue when
// reached. A swift-dependencies bump could silently change either half.
@Suite
struct TitleSuggestionClientTests {

    @Test
    func test_testValue_isAvailable_defaultsToFalseWithoutReportingAnIssue() {
        #expect(TitleSuggestionClient.testValue.isAvailable() == false)
    }

    @Test
    func test_testValue_suggest_reportsAnIssueWhenReached() async throws {
        await withKnownIssue {
            for try await _ in TitleSuggestionClient.testValue.suggest(TitleSuggestionContext(content: "Body.")) {
                // Draining the stream rather than only calling `suggest`: whichever point the
                // macro-generated default reports its issue at, iterating covers it.
            }
        }
    }
}
