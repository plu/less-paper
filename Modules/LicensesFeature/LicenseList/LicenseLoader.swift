import Dependencies
import DependenciesMacros
import Foundation

@DependencyClient
struct LicenseLoader {

    var load: @Sendable () -> [License] = { [.testValue()] }
}

extension LicenseLoader: DependencyKey {

    static var liveValue: LicenseLoader {
        LicenseLoader(load: {
            do {
                return try FileManager.allLicenses().map { url in
                    License(
                        content: try String(contentsOf: url, encoding: .utf8),
                        name: url.lastPathComponent.replacingOccurrences(of: ".md", with: "")
                    )
                }
            } catch {
                return []
            }
        })
    }
}

extension LicenseLoader: TestDependencyKey {

    static var testValue: LicenseLoader {
        LicenseLoader(load: { [.testValue()] })
    }
}

extension DependencyValues {

    var licenseLoader: LicenseLoader {
        get { self[LicenseLoader.self] }
        set { self[LicenseLoader.self] = newValue }
    }
}
