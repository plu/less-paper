import Foundation

public extension UserDefaults {

    // The suite both the app and the share extension read, so one import count and one review
    // cooldown exist rather than one per process. Falling back to `standard` rather than trapping:
    // a missing app group entitlement is a build configuration problem, and degrading to the old
    // per-process behaviour beats crashing on launch over something that only gates a prompt.
    // Computed rather than a stored `static let`, matching `AppGroup.cookieStorage` next door:
    // `UserDefaults` is not `Sendable`, so a stored global would need an unsafe opt-out instead.
    static var appGroup: UserDefaults {
        UserDefaults(suiteName: AppGroup.identifier) ?? .standard
    }
}
