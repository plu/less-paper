@testable import ApiInterface

import Foundation
import Testing

@Suite
struct UserDefaultsAppGroupTests {

    // The whole point of the accessor is that two separately opened handles land on the same
    // backing store, which is what makes the app and the share extension agree. Asserting on
    // instance identity would not do: Foundation never documents that UserDefaults(suiteName:)
    // returns a cached instance, so == could fail for a correct implementation. A round trip
    // across two handles proves the store, not the pointer.
    @Test
    func appGroup_isReadableThroughASeparatelyOpenedHandle() throws {
        let key = "app-group-round-trip-\(UUID().uuidString)"
        let other = try #require(UserDefaults(suiteName: AppGroup.identifier))

        UserDefaults.appGroup.set(7, forKey: key)
        defer { UserDefaults.appGroup.removeObject(forKey: key) }

        #expect(other.integer(forKey: key) == 7)
    }

    // The fallback is deliberate rather than a bug, but it must never be what a developer machine
    // silently gets, because it is indistinguishable from working.
    @Test
    func appGroup_isNotTheStandardSuite() {
        let key = "app-group-isolation-\(UUID().uuidString)"

        UserDefaults.appGroup.set(7, forKey: key)
        defer { UserDefaults.appGroup.removeObject(forKey: key) }

        #expect(UserDefaults.standard.object(forKey: key) == nil)
    }
}
