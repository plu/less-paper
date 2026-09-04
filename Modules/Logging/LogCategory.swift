import Foundation

/// Where a log line came from.
///
/// An enum rather than a string, so a typo cannot invent a category that appears in exactly one
/// user's log and matches nothing when you go looking for it.
public enum LogCategory: String, CaseIterable, Sendable {
    case app
    case api
    case documents
    case server
    case share
    case storage
    case tips
}
