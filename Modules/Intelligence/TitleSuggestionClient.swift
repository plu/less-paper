import Dependencies
import DependenciesMacros

// The on-device title suggester, as features see it.
@DependencyClient
public struct TitleSuggestionClient: Sendable {

    // Whether the model can run at all here — the OS version, the hardware, whether Apple
    // Intelligence is on, and whether the model has finished downloading, collapsed into one answer.
    // The button is not rendered when this is false, so there is nothing to explain to the user.
    public var isAvailable: @Sendable () -> Bool = { false }

    // Yields the whole list as it stands after each streamed snapshot, never a delta, so a caller
    // replaces its state rather than accumulating into it.
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

    // Unimplemented, unlike `LogClient`'s no-op: a test that reaches the model by accident should
    // say so rather than quietly return nothing.
    public static let testValue = Self()
}

public extension DependencyValues {

    var titleSuggestion: TitleSuggestionClient {
        get { self[TitleSuggestionClient.self] }
        set { self[TitleSuggestionClient.self] = newValue }
    }
}
