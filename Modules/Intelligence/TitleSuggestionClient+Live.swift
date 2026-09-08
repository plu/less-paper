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

    // Guardrails, not the default ones, and the choice is load-bearing. A personal archive is full
    // of what `.default` refuses — medical letters, debt notices, accident paperwork — so under it
    // the feature would fail on exactly the documents hardest to title by hand.
    // `.permissiveContentTransformations` is Apple's setting for transforming content the user
    // already holds, which is what a scan of their own paper is.
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
                    log.error("Title suggestion failed: \(mapped.logLabel)", category: .app)
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
