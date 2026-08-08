import Foundation
import ProjectDescription

// MARK: - Public

/**
 * Represents all modules in the project architecture.
 *
 * This enum defines the modular structure of the Less Paper iOS application,
 * organizing code into distinct modules for better separation of concerns,
 * testability, and maintainability. The architecture follows a feature-based
 * modular approach with clear dependencies between layers.
 *
 * ## Module Types
 * - **App modules**: Main app and feature-specific app targets
 * - **Feature modules**: Business logic and UI for specific features
 * - **Interface modules**: API contracts and shared interfaces
 * - **Implementation modules**: Concrete implementations of interfaces
 * - **Support modules**: Shared utilities and testing support
 * - **Test modules**: Unit and UI tests for corresponding modules
 */
public enum Module: String, CaseIterable {
    case apiImplementation = "ApiImplementation"
    case apiImplementationTests = "ApiImplementationTests"
    case apiInterface = "ApiInterface"
    case apiInterfaceTests = "ApiInterfaceTests"
    case apiTestSupport = "ApiTestSupport"
    case app = "App"
    case appFeature = "AppFeature"
    case appFeatureTests = "AppFeatureTests"
    case certificatesFeature = "CertificatesFeature"
    case certificatesFeatureTests = "CertificatesFeatureTests"
    case components = "Components"
    case componentsTests = "ComponentsTests"
    case correspondentsApp = "CorrespondentsApp"
    case correspondentsAppTests = "CorrespondentsAppTests"
    case correspondentsFeature = "CorrespondentsFeature"
    case correspondentsFeatureTests = "CorrespondentsFeatureTests"
    case documentTypesApp = "DocumentTypesApp"
    case documentTypesAppTests = "DocumentTypesAppTests"
    case documentTypesFeature = "DocumentTypesFeature"
    case documentTypesFeatureTests = "DocumentTypesFeatureTests"
    case documentsApp = "DocumentsApp"
    case documentsAppTests = "DocumentsAppTests"
    case documentsFeature = "DocumentsFeature"
    case documentsFeatureTests = "DocumentsFeatureTests"
    case imageFeature = "ImageFeature"
    case imageFeatureTests = "ImageFeatureTests"
    case licensesFeature = "LicensesFeature"
    case licensesFeatureTests = "LicensesFeatureTests"
    case permissionsFeature = "PermissionsFeature"
    case permissionsFeatureTests = "PermissionsFeatureTests"
    case savedViewsApp = "SavedViewsApp"
    case savedViewsAppTests = "SavedViewsAppTests"
    case savedViewsFeature = "SavedViewsFeature"
    case savedViewsFeatureTests = "SavedViewsFeatureTests"
    case serversApp = "ServersApp"
    case serversAppTests = "ServersAppTests"
    case serversFeature = "ServersFeature"
    case serversFeatureTests = "ServersFeatureTests"
    case settingsApp = "SettingsApp"
    case settingsAppTests = "SettingsAppTests"
    case settingsFeature = "SettingsFeature"
    case settingsFeatureTests = "SettingsFeatureTests"
    case shareApp = "ShareApp"
    case shareAppTests = "ShareAppTests"
    case shareExtension = "ShareExtension"
    case shareFeature = "ShareFeature"
    case shareFeatureTests = "ShareFeatureTests"
    case storagePathsApp = "StoragePathsApp"
    case storagePathsAppTests = "StoragePathsAppTests"
    case storagePathsFeature = "StoragePathsFeature"
    case storagePathsFeatureTests = "StoragePathsFeatureTests"
    case tagsApp = "TagsApp"
    case tagsAppTests = "TagsAppTests"
    case tagsFeature = "TagsFeature"
    case tagsFeatureTests = "TagsFeatureTests"
    case testSupport = "TestSupport"
}

extension Module {
    /**
     * Buildable folders for the module's source files.
     *
     * Specifies the folder locations that Xcode should monitor for changes
     * and include in the build process for this module.
     *
     * - Returns: An array of BuildableFolder objects pointing to the module's source directories.
     */
    var buildableFolders: [ProjectDescription.BuildableFolder] {
        [
            .folder(.relativeToRoot("\(rootFolder)"))
        ]
    }

    /**
     * Bundle identifier for the module.
     *
     * Generates the appropriate bundle identifier for each module type.
     * The main app uses a specific bundle ID for App Store distribution,
     * while other modules use a standardized format.
     *
     * - Returns: A string representing the module's bundle identifier.
     */
    var bundleId: String {
        // Bundle id from account before transferring app
        switch self {
        case .app:
            "com.aptumtek.app.Paperless"
        default:
            "com.aptumtek.app.Paperless.\(rawValue)"
        }
    }

    /**
     * Indicates whether this module should be included in code coverage reports.
     *
     * Feature modules and implementation modules are included in coverage analysis,
     * while test modules, apps, and support modules are excluded to focus coverage
     * metrics on the core business logic and implementation code.
     *
     * - Returns: `true` if the module should be included in code coverage, `false` otherwise.
     */
    var codeCoverageTarget: Bool {
        switch self {
        case .apiInterface,
             .apiImplementation,
             .appFeature,
             .certificatesFeature,
             .components,
             .correspondentsFeature,
             .documentTypesFeature,
             .documentsFeature,
             .imageFeature,
             .licensesFeature,
             .permissionsFeature,
             .savedViewsFeature,
             .serversFeature,
             .settingsFeature,
             .shareFeature,
             .storagePathsFeature,
             .tagsFeature:
            true
        case .apiInterfaceTests,
             .apiImplementationTests,
             .apiTestSupport,
             .app,
             .appFeatureTests,
             .certificatesFeatureTests,
             .componentsTests,
             .correspondentsApp,
             .correspondentsAppTests,
             .correspondentsFeatureTests,
             .documentTypesApp,
             .documentTypesAppTests,
             .documentTypesFeatureTests,
             .documentsApp,
             .documentsAppTests,
             .documentsFeatureTests,
             .imageFeatureTests,
             .licensesFeatureTests,
             .permissionsFeatureTests,
             .savedViewsApp,
             .savedViewsAppTests,
             .savedViewsFeatureTests,
             .serversApp,
             .serversAppTests,
             .serversFeatureTests,
             .settingsApp,
             .settingsAppTests,
             .settingsFeatureTests,
             .shareApp,
             .shareAppTests,
             .shareExtension,
             .shareFeatureTests,
             .storagePathsApp,
             .storagePathsAppTests,
             .storagePathsFeatureTests,
             .tagsApp,
             .tagsAppTests,
             .tagsFeatureTests,
             .testSupport:
            false
        }
    }

    /**
     * Entitlements configuration for modules that require special permissions.
     *
     * Defines the entitlements required for modules that need access to system
     * resources like keychain access. Most modules don't require entitlements,
     * but app modules need keychain access for secure credential storage.
     *
     * - Returns: An Entitlements object if the module requires special permissions, `nil` otherwise.
     */
    var entitlements: ProjectDescription.Entitlements? {
        switch self {
        case .app,
             .serversApp,
             .settingsApp,
             .shareApp,
             .shareExtension:
            .dictionary([
                "com.apple.security.application-groups": .array(["group.com.plunien.app.Paperless"]),
                "keychain-access-groups": .array(["$(AppIdentifierPrefix)com.aptumtek.app.Paperless"]),
            ])
        default:
            nil
        }
    }

    /**
     * The product type for this module.
     *
     * Determines how the module should be built and packaged:
     * - Apps are built as executable applications
     * - Frameworks provide reusable code libraries (static or dynamic based on environment)
     * - Unit tests provide automated testing for modules
     * - UI tests provide end-to-end testing for app modules
     *
     * - Returns: A Product enum value specifying the module's build output type.
     */
    var product: Product {
        switch self {
        case .app,
             .correspondentsApp,
             .documentTypesApp,
             .documentsApp,
             .savedViewsApp,
             .serversApp,
             .settingsApp,
             .shareApp,
             .storagePathsApp,
             .tagsApp:
            .app
        case .apiImplementation,
             .apiInterface,
             .apiTestSupport,
             .appFeature,
             .certificatesFeature,
             .components,
             .correspondentsFeature,
             .documentTypesFeature,
             .documentsFeature,
             .imageFeature,
             .licensesFeature,
             .permissionsFeature,
             .savedViewsFeature,
             .serversFeature,
             .settingsFeature,
             .shareFeature,
             .storagePathsFeature,
             .tagsFeature,
             .testSupport:
            Environment.staticFrameworks.getBoolean(default: false) ? .staticFramework : .framework
        case .apiImplementationTests,
             .apiInterfaceTests,
             .appFeatureTests,
             .certificatesFeatureTests,
             .componentsTests,
             .correspondentsFeatureTests,
             .documentTypesFeatureTests,
             .documentsFeatureTests,
             .imageFeatureTests,
             .licensesFeatureTests,
             .permissionsFeatureTests,
             .savedViewsFeatureTests,
             .serversFeatureTests,
             .settingsFeatureTests,
             .shareFeatureTests,
             .storagePathsFeatureTests,
             .tagsFeatureTests:
            .unitTests
        case .correspondentsAppTests,
             .documentTypesAppTests,
             .documentsAppTests,
             .savedViewsAppTests,
             .serversAppTests,
             .settingsAppTests,
             .shareAppTests,
             .storagePathsAppTests,
             .tagsAppTests:
            .uiTests
        case .shareExtension:
            .appExtension
        }
    }

    /**
     * The root folder path for the module's source files.
     *
     * Defines the directory structure within the Modules folder where
     * this module's source code is located. Used by the build system
     * to locate and organize module files.
     *
     * - Returns: A string path relative to the project root pointing to the module's directory.
     */
    var rootFolder: String {
        "Modules/\(targetName)"
    }

    /**
     * Build settings configuration for the module.
     *
     * Provides the build settings that should be applied to this module.
     * Currently uses default settings for all modules, but can be customized
     * per module if specific build configurations are needed.
     *
     * - Returns: A Settings object containing the module's build configuration.
     */
    var settings: Settings {
        .settings()
    }

    /**
     * The target name used by Xcode for this module.
     *
     * Provides the display name that Xcode will use for this target in the
     * project navigator and build system. Typically matches the raw value
     * of the module enum case.
     *
     * - Returns: A string representing the target's display name in Xcode.
     */
    var targetName: String {
        rawValue
    }
}
