import Dependencies
import DependenciesMacros

// Something the app just watched the user do that might be worth asking them to review it for.
public enum ReviewMoment: Equatable, Sendable {
    case documentImported
    case tipReceived
}

@DependencyClient
public struct ReviewPrompt: Sendable {

    // Records the moment, and asks for a review if it qualifies. Fire and forget: whether anything
    // appears is this client's business, and after that StoreKit's.
    public var record: @Sendable (_ moment: ReviewMoment) async -> Void
}

extension ReviewPrompt: TestDependencyKey {

    // A no-op rather than the usual unimplemented closure. This hangs off ordinary success paths in
    // more than one feature, so an unimplemented one would fail tests that have nothing to do with
    // reviews; the tests that care override it with a recorder.
    public static let previewValue = Self(record: { _ in })

    public static let testValue = Self(record: { _ in })
}

public extension DependencyValues {

    var reviewPrompt: ReviewPrompt {
        get { self[ReviewPrompt.self] }
        set { self[ReviewPrompt.self] = newValue }
    }
}
