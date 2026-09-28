// swift-tools-version: 6.0
import PackageDescription

#if TUIST
import enum ProjectDescription.Environment
import struct ProjectDescription.PackageSettings
import enum ProjectDescriptionHelpers.Dependency

// CasePathsMacrosSupport arrived in swift-case-paths 1.9.0 as a plain library target that the
// CasePaths and SwiftNavigation macros link against. Tuist refuses a Swift Macro target that
// depends on a dynamic framework, so this one has to stay static.
let packageSettings = PackageSettings(
    productTypes: Dependency.productTypes.merging(["CasePathsMacrosSupport": .staticFramework]) { $1 },
    targetSettings: [
        "ComposableArchitecture": .settings(base: [
            "OTHER_SWIFT_FLAGS": ["-module-alias", "Sharing=SwiftSharing"]
        ]),
        "Sharing": .settings(base: [
            "PRODUCT_NAME": "SwiftSharing",
            "OTHER_SWIFT_FLAGS": ["-module-alias", "Sharing=SwiftSharing"]
        ])
    ]
)
#endif

let package = Package(
    name: "LessPaper",
    dependencies: [
        .package(url: "https://github.com/Kuniwak/MultipartFormDataKit", .upToNextMajor(from: "1.0.1")),
        .package(url: "https://github.com/SwiftKickMobile/SwiftMessages", .upToNextMajor(from: "10.0.2")),
        .package(url: "https://github.com/pointfreeco/swift-snapshot-testing", .upToNextMajor(from: "1.19.6")),
        .package(url: "https://github.com/apple/swift-async-algorithms", .upToNextMajor(from: "1.1.1")),
        .package(url: "https://github.com/apple/swift-certificates", .upToNextMajor(from: "1.17.0")),
        .package(url: "https://github.com/dm-zharov/swift-security", .upToNextMajor(from: "2.0.0")),
        .package(url: "https://github.com/gonzalezreal/swift-markdown-ui", .upToNextMajor(from: "2.4.1")),
        .package(url: "https://github.com/kean/Get", .upToNextMajor(from: "2.2.1")),
        .package(url: "https://github.com/kean/Nuke", .upToNextMajor(from: "13.2.0")),
        .package(url: "https://github.com/pointfreeco/swift-composable-architecture", .upToNextMajor(from: "1.22.3")),
        .package(url: "https://github.com/pointfreeco/swift-custom-dump", .upToNextMajor(from: "1.3.3")),
        .package(url: "https://github.com/pointfreeco/swift-dependencies", .upToNextMajor(from: "1.10.0")),
        .package(url: "https://github.com/pointfreeco/swift-overture", .upToNextMajor(from: "0.5.0")),
        .package(url: "https://github.com/pointfreeco/swift-sharing", .upToNextMajor(from: "2.7.4")),
        .package(url: "https://github.com/pointfreeco/swift-tagged", .upToNextMajor(from: "0.10.0")),
        .package(url: "https://github.com/pointfreeco/swift-url-routing", .upToNextMajor(from: "0.6.2")),
    ]
)
