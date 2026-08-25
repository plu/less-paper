import ProjectDescription

extension Module {
    var infoPlist: InfoPlist {
        switch self {
        case .app:
            .extendingDefault(with: [
                "CFBundleDisplayName": "Less Paper",
                "CFBundleShortVersionString": .string(.marketingVersion),
                "CFBundleURLTypes": [
                    [
                        "CFBundleTypeRole": "Editor",
                        "CFBundleURLSchemes": [
                            "atlp",
                        ]
                    ]
                ],
                "CFBundleLocalizations": [
                    "en",
                    "de",
                ],
                "CFBundleVersion": .string(.buildNumber),
                "ITSAppUsesNonExemptEncryption": false,
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true,
                ],
                "PAPERLESS_PAGE_SIZE": .string(Environment.paperlessPageSize.getString(default: "100")),
                "PAPERLESS_TEST_URL": .string(Environment.paperlessTestUrl.getString(default: "http://localhost:9000")),
                "UIApplicationSceneManifest": [
                    "UIApplicationSupportsMultipleScenes": false,
                    "UISceneConfigurations": [:],
                ],
                "UILaunchScreen": [
                    "UIColorName": "LaunchScreenBackground"
                ],
                "UIPrefersShowingLanguageSettings": true,
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                    "UIInterfaceOrientationPortrait",
                ]
            ])
        case .shareExtension:
            .extendingDefault(with: [
                "CFBundleDisplayName": "Less Paper",
                "CFBundleShortVersionString": .string(.marketingVersion),
                "CFBundleLocalizations": [
                    "en",
                    "de",
                ],
                "CFBundleVersion": .string(.buildNumber),
                "NSAppTransportSecurity": [
                    "NSAllowsArbitraryLoads": true,
                ],
                "NSExtension": [
                    "NSExtensionAttributes": [
                        "NSExtensionActivationRule": """
                        SUBQUERY (
                            extensionItems,
                            $extensionItem,
                            SUBQUERY (
                                $extensionItem.attachments,
                                $attachment,
                                ANY $attachment.registeredTypeIdentifiers UTI-CONFORMS-TO "com.adobe.pdf"
                            ).@count == $extensionItem.attachments.@count
                        ).@count == 1
                        """,
                    ],
                    "NSExtensionPointIdentifier": "com.apple.share-services",
                    "NSExtensionPrincipalClass": "$(PRODUCT_MODULE_NAME).ShareViewController",
                ],
            ])
        case .customFieldsApp,
             .documentsApp,
             .savedViewsApp,
             .serversApp,
             .shareApp:
            .extendingDefault(with: [
                "CFBundleDisplayName": .string(rawValue.replacingOccurrences(of: "App", with: "")),
                "CFBundleLocalizations": [
                    "en",
                    "de",
                ],
                "PAPERLESS_PAGE_SIZE": .string(Environment.paperlessPageSize.getString(default: "100")),
                "PAPERLESS_TEST_URL": .string(Environment.paperlessTestUrl.getString(default: "http://localhost:9000")),
                "UILaunchScreen": [:],
                "UIPrefersShowingLanguageSettings": true,
                "UISupportedInterfaceOrientations": [
                    "UIInterfaceOrientationLandscapeLeft",
                    "UIInterfaceOrientationLandscapeRight",
                    "UIInterfaceOrientationPortrait",
                ]
            ])
        default:
            .extendingDefault(with: [
                "CFBundleLocalizations": [
                    "en",
                    "de",
                ],
                "PAPERLESS_PAGE_SIZE": .string(Environment.paperlessPageSize.getString(default: "100")),
                "PAPERLESS_TEST_URL": .string(Environment.paperlessTestUrl.getString(default: "http://localhost:9000")),
            ])
        }
    }
}
