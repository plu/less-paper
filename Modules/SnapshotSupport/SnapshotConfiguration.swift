#if DEBUG
import ApiInterface
import Foundation

// Screenshot mode. Detected the same way UITestConfiguration is - from the launch environment -
// but kept separate from it: a UI test asserts against a live server, and a screenshot run must
// never reach one.
public struct SnapshotConfiguration: Equatable, Sendable {

    public static let environmentKey = "SNAPSHOT_MODE"

    // Which corpus to show. German screenshots get German paperwork rather than English documents
    // behind translated chrome, so the language is a data decision as much as a display one.
    public enum Corpus: String, Sendable {
        case english = "en"
        case german = "de"

        // fastlane launches each locale with -AppleLanguages, so the corpus follows the language
        // the run already asked for rather than needing a second switch to keep in step.
        static func current(
            _ languages: [String] = Foundation.Locale.preferredLanguages
        ) -> Self {
            languages.first?.hasPrefix("de") == true ? .german : .english
        }
    }

    public let corpus: Corpus

    public init(corpus: Corpus) {
        self.corpus = corpus
    }

    public static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        guard environment[environmentKey] == "true" else {
            return nil
        }
        return Self(corpus: .current())
    }
}
#endif
