import ProjectDescription

extension Product {
    func bundleId(name: String) -> String {
        switch self {
        case .app:
            // Bundle id from account before transferring app
            "com.aptumtek.app.Paperless"
        case .appExtension:
            // Needs same prefix as app bundle id
            "com.aptumtek.app.Paperless.\(name)"
        case .framework, .staticFramework:
            "com.plunien.framework.\(name)"
        case .unitTests:
            "com.plunien.test.\(name)"
        case .uiTests:
            "com.plunien.xcui.\(name)"
        default:
            preconditionFailure()
        }
    }
}
