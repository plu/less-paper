import Foundation

public enum MatchingAlgorithm: Int, CaseIterable, CustomStringConvertible, Codable, Equatable, Identifiable, Sendable {
    case none
    case anyWord
    case allWords
    case exactMatch
    case regularExpression
    case fuzzyWord
    case automatic

    public var description: String {
        switch self {
        case .none:
            String(localized: .matchingAlgorithmNone)
        case .anyWord:
            String(localized: .matchingAlgorithmAnyWord)
        case .allWords:
            String(localized: .matchingAlgorithmAllWords)
        case .exactMatch:
            String(localized: .matchingAlgorithmExactMatch)
        case .regularExpression:
            String(localized: .matchingAlgorithmRegularExpression)
        case .fuzzyWord:
            String(localized: .matchingAlgorithmFuzzyWord)
        case .automatic:
            String(localized: .matchingAlgorithmAutomatic)
        }
    }

    public var id: Int {
        rawValue
    }
}
