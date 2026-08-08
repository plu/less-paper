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
                .target(.serversFeature),
                .target(.settingsFeature),
            ]
        case .appFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.dependenciesTestSupport),
                .target(.apiInterface),
                .target(.appFeature),
                .target(.serversFeature),
                .target(.settingsFeature),
                .target(.testSupport),
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
            ]
        case .apiImplementationTests:
            [
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
            ]
        case .componentsTests:
            [
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.components),
                .target(.testSupport),
            ]
        case .correspondentsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.correspondentsFeature)
            ]
        case .correspondentsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.correspondentsApp),
                .target(.correspondentsFeature),
            ]
        case .correspondentsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
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
                .target(.testSupport),
            ]
        case .documentTypesApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.documentTypesFeature)
            ]
        case .documentTypesAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.documentTypesApp),
                .target(.documentTypesFeature),
            ]
        case .documentTypesFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.permissionsFeature),
            ]
        case .documentTypesFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.documentTypesFeature),
                .target(.testSupport),
            ]
        case .documentsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.documentsFeature)
            ]
        case .documentsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.documentsApp),
                .target(.documentsFeature),
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
                .target(.documentTypesFeature),
                .target(.documentsFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
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
            ]
        case .imageFeatureTests:
            [
                .external(.dependenciesTestSupport),
                .external(.nuke),
                .external(.snapshotTesting),
                .target(.imageFeature),
                .target(.testSupport),
            ]
        case .licensesFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.markdownUI),
                .target(.components),
            ]
        case .licensesFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.licensesFeature),
                .target(.testSupport),
            ]
        case .permissionsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.components),
            ]
        case .permissionsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.permissionsFeature),
                .target(.testSupport),
            ]
        case .savedViewsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.savedViewsFeature)
            ]
        case .savedViewsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.savedViewsApp),
                .target(.savedViewsFeature),
            ]
        case .savedViewsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.permissionsFeature),
            ]
        case .savedViewsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.savedViewsFeature),
                .target(.testSupport),
            ]
        case .serversApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.serversFeature),
            ]
        case .serversAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.serversApp),
                .target(.serversFeature),
            ]
        case .serversFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.sharing),
                .target(.apiInterface),
                .target(.components),
            ]
        case .serversFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.serversFeature),
                .target(.testSupport),
            ]
        case .settingsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.sharing),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.settingsFeature),
            ]
        case .settingsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.settingsApp),
                .target(.settingsFeature),
            ]
        case .settingsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .target(.apiInterface),
                .target(.components),
                .target(.correspondentsFeature),
                .target(.documentTypesFeature),
                .target(.licensesFeature),
                .target(.savedViewsFeature),
                .target(.serversFeature),
                .target(.shareFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
            ]
        case .settingsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
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
                .target(.documentTypesFeature),
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
                .target(.documentTypesFeature),
                .target(.shareFeature),
                .target(.storagePathsFeature),
                .target(.tagsFeature),
                .target(.testSupport),
            ]
        case .storagePathsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.storagePathsFeature)
            ]
        case .storagePathsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.storagePathsApp),
                .target(.storagePathsFeature),
            ]
        case .storagePathsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.permissionsFeature),
            ]
        case .storagePathsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.storagePathsFeature),
                .target(.testSupport),
            ]
        case .tagsApp:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.tagsFeature)
            ]
        case .tagsAppTests:
            [
                .external(.dependencies),
                .target(.apiImplementation),
                .target(.apiInterface),
                .target(.tagsApp),
                .target(.tagsFeature),
            ]
        case .tagsFeature:
            [
                .external(.composableArchitecture),
                .external(.dependencies),
                .external(.dependenciesMacros),
                .external(.tagged),
                .target(.apiInterface),
                .target(.components),
                .target(.permissionsFeature),
            ]
        case .tagsFeatureTests:
            [
                .external(.composableArchitecture),
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
                .target(.apiInterface),
                .target(.components),
                .target(.tagsFeature),
                .target(.testSupport),
            ]
        case .testSupport:
            [
                .external(.dependenciesTestSupport),
                .external(.snapshotTesting),
            ]
        }
    }
}
