// The point of this type is that a caller never has to import `FoundationModels` — and so never has
// to carry an `@available(iOS 26, *)` annotation of its own — just to tell two failures apart.
public enum TitleSuggestionError: Error, Equatable, Sendable {
    case contextWindowExceeded
    case failed(String)
    case guardrailViolation
    case unavailable
}
