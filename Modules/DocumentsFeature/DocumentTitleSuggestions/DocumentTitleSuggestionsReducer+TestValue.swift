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
