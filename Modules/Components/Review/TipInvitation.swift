import Dependencies
import DependenciesMacros

@DependencyClient
public struct TipInvitation: Sendable {

    // Called on every foreground. Counts at most one day per day.
    public var recordActiveDay: @Sendable () async -> Void

    // Whether the invitation should be on screen right now.
    public var isEligible: @Sendable () async -> Bool = { false }

    // Answered, by either route. Nothing ever unsets this.
    public var settle: @Sendable () async -> Void
}

extension TipInvitation: TestDependencyKey {

    // No-ops rather than the usual unimplemented closures, for the reason ReviewPrompt gives: this
    // hangs off the document list, which a great many tests render for reasons that have nothing to
    // do with tips. The tests that care override these.
    public static let previewValue = Self(
        recordActiveDay: {},
        isEligible: { false },
        settle: {}
    )

    public static let testValue = Self(
        recordActiveDay: {},
        isEligible: { false },
        settle: {}
    )
}

public extension DependencyValues {

    var tipInvitation: TipInvitation {
        get { self[TipInvitation.self] }
        set { self[TipInvitation.self] = newValue }
    }
}
