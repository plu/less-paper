import ProjectDescription

extension Module {
    /**
     * Target dependencies for each module in the project.
     *
     * This computed property defines the dependency graph for each module,
     * specifying which external packages and internal targets each module requires.
     * Dependencies are organized by module type and include both external packages
     * and internal module dependencies.
     *
     * - Returns: An array of TargetDependency objects representing the module's dependencies.
     */
    var dependencies: [TargetDependency] {
        switch self {
        case .app:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.appFeature),
                .target(.serversFeature),
                .target(.shareExtension),
                .target(.snapshotSupport),
            ]
        case .appFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.sharing),
                .target(.apiInterface),
                .target(.certificatesFeature),
                .target(.components),
                .target(.documentsFeature),
                .target(.favoritesFeature),
                .target(.forwardAuthFeature),
                .target(.serversFeature),
                .target(.settingsFeature),
                .target(.tipsFeature),
            ]
        case .appFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.dependenciesTestSupport),
                .target(.apiInterface),
                .target(.appFeature),
                .target(.components),
                .target(.favoritesFeature),
                .target(.serversFeature),
                .target(.settingsFeature),
                .target(.testSupport),
                .target(.tipsFeature),
            ]
        case .appSnapshots:
            [
                .target(.app),
                .target(.uiTestSupport),
            ]
        case .appUITests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.app),
                .target(.uiTestSupport),
            ]
        case .apiImplementation:
            [
                .external(.asyncAlgorithms),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.get),
                .external(.identifiedCollections),
                .external(.multipartFormDataKit),
                .external(.sharing),
                .external(.swiftSecurity),
                .target(.apiInterface),
                .target(.logging),
            ]
        case .apiImplementationTests:
            [
                .external(.asyncAlgorithms),
                .external(.customDump),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.dependenciesTestSupport),
                .external(.get),
                .external(.identifiedCollections),
                .external(.multipartFormDataKit),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.apiTestSupport),
                .target(.testSupport),
                .target(.logging),
            ]
        case .apiInterface:
            [
                .external(.asyncAlgorithms),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.identifiedCollections),
                .external(.sharing),
                .external(.tagged),
            ]
        case .apiInterfaceTests:
            [
                .external(.customDump),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.dependenciesTestSupport),
                .external(.identifiedCollections),
                .target(.apiInterface),
                .target(.testSupport),
            ]
        case .apiTestSupport:
            [
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.identifiedCollections),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.testSupport),
            ]
        case .certificatesFeature:
            [
                .external(.asyncAlgorithms),
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.identifiedCollections),
                .external(.sharing),
                .external(.x509),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .certificatesFeatureTests:
            [
                .external(.asyncAlgorithms),
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.x509),
                .target(.apiInterface),
                .target(.certificatesFeature),
                .target(.testSupport),
            ]
        case .components:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.issueReporting),
                .external(.swiftMessages),
                .target(.designTokens),
            ]
        case .componentsTests:
            [
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.components),
                .target(.testSupport),
            ]
        case .correspondentsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.permissionsFeature),
            ]
        case .correspondentsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.designTokens),
                .target(.testSupport),
            ]
        case .customFieldsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .customFieldsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.customFieldsFeature),
                .target(.testSupport),
            ]
        case .documentTypesFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.permissionsFeature),
            ]
        case .documentTypesFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.documentTypesFeature),
                .target(.testSupport),
            ]
        case .documentsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.customFieldsFeature),
                .target(.designTokens),
                .target(.documentTypesFeature),
                .target(.imageFeature),
                .target(.permissionsFeature),
                .target(.savedViewsFeature),
                .target(.shareFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
            ]
        case .documentsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.customFieldsFeature),
                .target(.designTokens),
                .target(.documentTypesFeature),
                .target(.documentsFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
                .target(.testSupport),
            ]
        case .favoritesFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.sharing),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.documentsFeature),
            ]
        case .favoritesFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.documentsFeature),
                .target(.favoritesFeature),
                .target(.testSupport),
            ]
        case .forwardAuthFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.certificatesFeature),
                .target(.components),
            ]
        case .forwardAuthFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.forwardAuthFeature),
                .target(.testSupport),
            ]
        case .imageFeature:
            [
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.nuke),
                .external(.nukeUI),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .imageFeatureTests:
            [
                .external(.dependenciesTestSupport),
                .external(.nuke),
                .external(.snapshotTesting),
                .target(.imageFeature),
                .target(.testSupport),
            ]
        case .logging:
            [
                .external(.dependencies),
                .external(.dependenciesMacros),
            ]
        case .loggingTests:
            [
                .external(.dependenciesTestSupport),
                .target(.logging),
                .target(.testSupport),
            ]
        case .designTokens:
            []
        case .diagnosticsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.components),
                .target(.designTokens),
                .target(.logging),
            ]
        case .diagnosticsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .target(.diagnosticsFeature),
                .target(.logging),
                .target(.testSupport),
            ]
        case .trashFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .trashFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .target(.apiInterface),
                .target(.apiTestSupport),
                .target(.testSupport),
                .target(.trashFeature),
            ]
        case .licensesFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.markdownUI),
                .target(.components),
                .target(.designTokens),
            ]
        case .licensesFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.licensesFeature),
                .target(.testSupport),
            ]
        case .marketingKit:
            [
                .target(.components),
            ]
        case .marketingKitTests:
            [
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.marketingKit),
                .target(.testSupport),
            ]
        case .pdfPasswordsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .pdfPasswordsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.pdfPasswordsFeature),
                .target(.testSupport),
            ]
        case .permissionsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .permissionsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.designTokens),
                .target(.permissionsFeature),
                .target(.testSupport),
            ]
        case .savedViewsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.permissionsFeature),
            ]
        case .savedViewsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.savedViewsFeature),
                .target(.testSupport),
            ]
        case .serversFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.sharing),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
            ]
        case .serversFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.serversFeature),
                .target(.testSupport),
            ]
        case .settingsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.customFieldsFeature),
                .target(.designTokens),
                .target(.diagnosticsFeature),
                .target(.documentTypesFeature),
                .target(.licensesFeature),
                .target(.pdfPasswordsFeature),
                .target(.savedViewsFeature),
                .target(.serversFeature),
                .target(.shareFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
                .target(.tipsFeature),
                .target(.trashFeature),
            ]
        case .settingsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.pdfPasswordsFeature),
                .target(.serversFeature),
                .target(.settingsFeature),
                .target(.tagsFeature),
                .target(.testSupport),
            ]
        case .shareApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.sharing),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.shareFeature)
            ]
        case .shareAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.apiTestSupport),
                .target(.shareApp),
                .target(.shareFeature),
            ]
        case .shareExtension:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.shareFeature)
            ]
        case .shareFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.sharing),
                .target(.apiInterface),
                .target(.certificatesFeature),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.designTokens),
                .target(.documentTypesFeature),
                .target(.logging),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
            ]
        case .shareFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .external(.sharing),
                .target(.apiInterface),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.customFieldsFeature),
                .target(.documentTypesFeature),
                .target(.shareFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
                .target(.testSupport),
            ]
        case .snapshotSupport:
            [
                .external(.dependencies),
                .external(.identifiedCollections),
                .external(.issueReporting),
                .external(.sharing),
                .target(.apiInterface),
                .target(.imageFeature),
            ]
        case .storagePathsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.permissionsFeature),
            ]
        case .storagePathsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.storagePathsFeature),
                .target(.testSupport),
            ]
        case .tagsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.permissionsFeature),
            ]
        case .tagsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.designTokens),
                .target(.tagsFeature),
                .target(.testSupport),
            ]
        case .testSupport:
            [
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
            ]
        case .tipsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.components),
                .target(.designTokens),
                .target(.logging),
            ]
        case .tipsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.components),
                .target(.logging),
                .target(.testSupport),
                .target(.tipsFeature),
            ]
        case .uiTestSupport:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
            ]
        }
    }
}
