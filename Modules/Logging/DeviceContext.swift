import Dependencies
import DependenciesMacros
import Foundation

// The facts every support thread opens by asking for. A dependency rather than free functions so a
// test can assert the line without its answer depending on the simulator it happens to run on.
@DependencyClient
public struct DeviceContext: Sendable {

    public var appName: @Sendable () -> String = { "LessPaper" }

    public var appVersion: @Sendable () -> String = { "0.0.0" }

    public var appBuild: @Sendable () -> String = { "0" }

    public var systemVersion: @Sendable () -> String = { "0.0" }

    public var deviceModel: @Sendable () -> String = { "unknown" }

    public var locale: @Sendable () -> String = { "en_US" }

    public var buildConfiguration: @Sendable () -> String = { "release" }

    public func launchLine() -> String {
        [
            "\(appName()) \(appVersion()) (\(appBuild()))",
            "iOS \(systemVersion())",
            deviceModel(),
            locale(),
            buildConfiguration(),
        ]
        .joined(separator: " · ")
    }
}

extension DeviceContext: DependencyKey {

    public static let liveValue = Self(
        appName: { Bundle.main.infoDictionary?["CFBundleName"] as? String ?? "LessPaper" },
        appVersion: { Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0" },
        appBuild: { Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0" },
        systemVersion: {
            let version = ProcessInfo.processInfo.operatingSystemVersion
            return "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        },
        deviceModel: { modelIdentifier() },
        locale: { Locale.current.identifier },
        buildConfiguration: {
            #if DEBUG
            "debug"
            #else
            "release"
            #endif
        }
    )

    // The raw identifier, not UIDevice.model - which answers "iPhone" for every iPhone ever made -
    // and not a marketing-name lookup table, which goes stale every September.
    private static func modelIdentifier() -> String {
        // A simulator's uname reports the host architecture, so the identifier of the device being
        // simulated has to come from the environment instead.
        if let simulated = ProcessInfo.processInfo.environment["SIMULATOR_MODEL_IDENTIFIER"] {
            return simulated
        }

        var info = utsname()
        uname(&info)
        // The size has to be captured before the exclusive access below starts, or reading
        // info.machine again inside the closure conflicts with it.
        let size = MemoryLayout.size(ofValue: info.machine)
        return withUnsafePointer(to: &info.machine) { pointer in
            pointer.withMemoryRebound(to: CChar.self, capacity: size) {
                String(cString: $0)
            }
        }
    }
}

extension DeviceContext: TestDependencyKey {

    public static let previewValue = testValue

    public static let testValue = Self(
        appName: { "LessPaper" },
        appVersion: { "1.0.0" },
        appBuild: { "1" },
        systemVersion: { "26.0" },
        deviceModel: { "iPhone17,2" },
        locale: { "en_US" },
        buildConfiguration: { "debug" }
    )
}

public extension DependencyValues {

    var deviceContext: DeviceContext {
        get { self[DeviceContext.self] }
        set { self[DeviceContext.self] = newValue }
    }
}
