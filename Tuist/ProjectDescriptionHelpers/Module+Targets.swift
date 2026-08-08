import ProjectDescription

public extension Module {
    var targets: [Target] {
        [
            target
        ]
    }
}

extension Module {
    var target: Target {
        var debugSettings: ProjectDescription.SettingsDictionary = [
            "OTHER_LDFLAGS": "$(inherited) -ObjC -all_load"
        ]
        var releaseSettings: ProjectDescription.SettingsDictionary = [
            "OTHER_LDFLAGS": "$(inherited) -ObjC -all_load"
        ]

        if case .app = self {
            debugSettings["PRODUCT_NAME"] = "LessPaper"
            releaseSettings["PRODUCT_NAME"] = "LessPaper"
            debugSettings.set(Environment.appProvisioningProfile, forKey: "PROVISIONING_PROFILE_SPECIFIER")
            releaseSettings.set(Environment.appProvisioningProfile, forKey: "PROVISIONING_PROFILE_SPECIFIER")
        }

        if case .shareExtension = self {
            debugSettings.set(Environment.shareExtensionProvisioningProfile, forKey: "PROVISIONING_PROFILE_SPECIFIER")
            releaseSettings.set(Environment.shareExtensionProvisioningProfile, forKey: "PROVISIONING_PROFILE_SPECIFIER")
        }

        if case .app = product, self != .app {
            debugSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "TestAppIcon"
            releaseSettings["ASSETCATALOG_COMPILER_APPICON_NAME"] = "TestAppIcon"
        }

        if case .app = product {
            debugSettings.set(Environment.codeSignIdentity, forKey: "CODE_SIGN_IDENTITY")
            releaseSettings.set(Environment.codeSignIdentity, forKey: "CODE_SIGN_IDENTITY")
        }

        if case .testSupport = self {
            debugSettings["ENABLE_TESTING_SEARCH_PATHS"] = "YES"
            releaseSettings["ENABLE_TESTING_SEARCH_PATHS"] = "YES"
        }

        let settings = Settings.settings(
            base: settings.base,
            configurations: [
                .debug(
                    name: "Debug",
                    settings: debugSettings,
                    xcconfig: nil
                ),
                .release(
                    name: "Release",
                    settings: releaseSettings,
                    xcconfig: nil
                )
            ]
        )

        // Resources for demo/test apps
        var resources: ProjectDescription.ResourceFileElements?
        switch product {
        case .app:
            resources = .resources([.glob(pattern: .relativeToRoot("Shared/App/Resources/**"))])
        case .framework, .staticFramework:
            resources = .resources([.glob(pattern: .relativeToRoot("Shared/Framework/Resources/**"))])
        default:
            break
        }

        return .target(
            name: targetName,
            destinations: [.iPhone, .iPad],
            product: product,
            bundleId: bundleId,
            deploymentTargets: .iOS("18.0"),
            infoPlist: infoPlist,
            resources: resources,
            buildableFolders: buildableFolders,
            entitlements: entitlements,
            dependencies: dependencies,
            settings: settings
        )
    }

    var testableTargets: [TestableTarget] {
        guard let module = Module(rawValue: "\(rawValue)Tests") else {
            return []
        }

        return [.testableTarget(target: .target(module.rawValue))]
    }

    // MARK: -

    static var allCodeCoverageTargets: [TargetReference] {
        allCases
            .filter(\.codeCoverageTarget)
            .map { .target($0.rawValue) }
    }

    static var allTestableTargets: [TestableTarget] {
        allCases
            .filter { $0.product == .unitTests }
            .map { .testableTarget(target: .target($0)) }
    }
}
