// The point of this type is that a caller never has to import `FoundationModels` — and so never has
// to carry an `@available(iOS 26, *)` annotation of its own — just to tell two failures apart.
public enum TitleSuggestionError: Error, Equatable, Sendable {
    case contextWindowExceeded
    case failed(String)
    case guardrailViolation
    case unavailable

    // Never the associated value: `.failed`'s payload is a `localizedDescription` of unknown
    // provenance, and this reaches the log the app invites the user to email to support. No
    // `default` branch, so a new case must be given a label explicitly rather than falling back to
    // printing whatever it carries.
    var logLabel: String {
        switch self {
        case .contextWindowExceeded:
            "contextWindowExceeded"
        case .failed:
            "failed"
        case .guardrailViolation:
            "guardrailViolation"
        case .unavailable:
            "unavailable"
        }
    }
}
