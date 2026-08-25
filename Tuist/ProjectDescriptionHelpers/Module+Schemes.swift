import ProjectDescription

public extension Module {
    /**
     * Xcode schemes configuration for each module.
     *
     * This property defines the build schemes available for each module type,
     * including build actions, test configurations, and run actions. Different
     * module types have different scheme configurations:
     *
     * - App modules: Include comprehensive test coverage across all testable targets
     * - Feature modules: Include individual test suites with coverage reporting
     * - App feature modules: Include dedicated test targets for feature apps
     * - Test modules: No dedicated schemes (included in other module schemes)
     *
     * - Returns: An array of Scheme objects configured for the module type.
     */
    var schemes: [Scheme] {
        switch self {
        case .app:
            [
                .scheme(
                    name: "Less Paper",
                    buildAction: .buildAction(
                        targets: [.target(self)]
                    ),
                    testAction: .targets(
                        Module.allTestableTargets + [
                            .testableTarget(target: .target(.appUITests))
                        ],
                        arguments: .arguments(environmentVariables: .default),
                        options: .options(
                            language: .init(identifier: "en"),
                            region: "DE",
                            coverage: true,
                            codeCoverageTargets: Module.allCodeCoverageTargets
                        )
                    ),
                    runAction: .runAction()
                )
            ]
        case .shareExtension:
            [
                .scheme(
                    name: "ShareExtension",
                    buildAction: .buildAction(
                        targets: [.target(self)]
                    ),
                    runAction: .runAction(executable: .target(.app))
                )
            ]
        case .apiImplementation,
             .apiInterface,
             .appFeature,
             .certificatesFeature,
             .components,
             .correspondentsFeature,
             .customFieldsFeature,
             .documentTypesFeature,
             .documentsFeature,
             .imageFeature,
             .licensesFeature,
             .pdfPasswordsFeature,
             .permissionsFeature,
             .savedViewsFeature,
             .serversFeature,
             .settingsFeature,
             .shareFeature,
             .storagePathsFeature,
             .tagsFeature:
            [
                .scheme(
                    name: rawValue,
                    buildAction: .buildAction(
                        targets: [.target(self)]
                    ),
                    testAction: .targets(
                        testableTargets,
                        arguments: .arguments(environmentVariables: .default),
                        options: .options(
                            language: .init(identifier: "en"),
                            region: "DE",
                            coverage: true,
                            codeCoverageTargets: [.target(self)]
                        )
                    )
                )
            ]
        case .shareApp:
            [
                .scheme(
                    name: rawValue,
                    buildAction: .buildAction(
                        targets: [.target(self)]
                    ),
                    testAction: .targets(
                        featureAppTestTargets,
                        arguments: .arguments(environmentVariables: .default),
                        options: .options(
                            language: .init(identifier: "en"),
                            region: "DE",
                            coverage: true
                        )
                    ),
                    runAction: .runAction(
                        arguments: .arguments(environmentVariables: .default),
                    )
                )
            ]
        case .apiImplementationTests,
             .apiInterfaceTests,
             .apiTestSupport,
             .appFeatureTests,
             .appUITests,
             .certificatesFeatureTests,
             .componentsTests,
             .correspondentsFeatureTests,
             .customFieldsFeatureTests,
             .documentTypesFeatureTests,
             .documentsFeatureTests,
             .imageFeatureTests,
             .licensesFeatureTests,
             .pdfPasswordsFeatureTests,
             .permissionsFeatureTests,
             .savedViewsFeatureTests,
             .serversFeatureTests,
             .settingsFeatureTests,
             .shareAppTests,
             .shareFeatureTests,
             .storagePathsFeatureTests,
             .tagsFeatureTests,
             .testSupport,
             .uiTestSupport:
            []
        }
    }
}

extension Module {
    /**
     * Test targets for feature app modules.
     *
     * This private property maps each feature app module to its corresponding
     * test target. Used internally by the schemes configuration to set up
     * appropriate test actions for feature app schemes.
     *
     * - Returns: An array of TestableTarget objects for the feature app's tests.
     */
    private var featureAppTestTargets: [TestableTarget] {
        switch self {
        case .shareApp:
            [.testableTarget(target: .target(.shareAppTests))]
        default:
            []
        }
    }
}
