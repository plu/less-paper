import ProjectDescription

// swiftlint:disable identifier_name

/**
 * External dependencies available to modules in the project.
 *
 * This enum defines all external Swift Package Manager dependencies that can be
 * used by modules in the project. Each case corresponds to a specific external
 * library with its package identifier.
 */
public enum Dependency: String, CaseIterable {
    case _certificateInternals = "_CertificateInternals"
    case asyncAlgorithms = "AsyncAlgorithms"
    case cCryptoBoringSSL = "CCryptoBoringSSL"
    case cCryptoBoringSSLShims = "CCryptoBoringSSLShims"
    case casePaths = "CasePaths"
    case casePathsCore = "CasePathsCore"
    case clocks = "Clocks"
    case combineSchedulers = "CombineSchedulers"
    case composableArchitecture = "ComposableArchitecture"
    case concurrencyExtras = "ConcurrencyExtras"
    case crypto = "Crypto"
    case cryptoBoringWrapper = "CryptoBoringWrapper"
    case cryptoExtras = "CryptoExtras"
    case customDump = "CustomDump"
    case dependencies = "Dependencies"
    case dependenciesMacros = "DependenciesMacros"
    case dependenciesTestSupport = "DependenciesTestSupport"
    case dequeModule = "DequeModule"
    case get = "Get"
    case identifiedCollections = "IdentifiedCollections"
    case internalCollectionsUtilities = "InternalCollectionsUtilities"
    case issueReporting = "IssueReporting"
    case issueReportingPackageSupport = "IssueReportingPackageSupport"
    case issueReportingTestSupport = "IssueReportingTestSupport"
    case markdownUI = "MarkdownUI"
    case multipartFormDataKit = "MultipartFormDataKit"
    case networkImage = "NetworkImage"
    case nuke = "Nuke"
    case nukeUI = "NukeUI"
    case orderedCollections = "OrderedCollections"
    case perception = "Perception"
    case perceptionCore = "PerceptionCore"
    case sharing = "Sharing"
    case snapshotTesting = "SnapshotTesting"
    case swiftASN1 = "SwiftASN1"
    case swiftMessages = "SwiftMessages"
    case swiftNavigation = "SwiftNavigation"
    case swiftSecurity = "SwiftSecurity"
    case swiftUINavigation = "SwiftUINavigation"
    case tagged = "Tagged"
    case uikitNavigation = "UIKitNavigation"
    case urlRouting = "URLRouting"
    case x509 = "X509"
    case xcTestDynamicOverlay = "XCTestDynamicOverlay"
}

public extension Dependency {
    static var productTypes: [String: ProjectDescription.Product] {
        if Environment.staticFrameworks.getBoolean(default: false) {
            return [:]
        }
        return Dictionary(
            uniqueKeysWithValues: allCases.map { ($0.rawValue, .framework) }
        )
    }
}
