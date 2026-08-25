import ApiInterface
import XCTest

@MainActor
open class UITestCase: XCTestCase {

    public let app = XCUIApplication()

    public let timeout = 10.0

    public private(set) var user: TestUser!

    // Both paths pass a configuration, so storage is always in memory. Skipping it entirely would
    // let the app read whatever servers.json the simulator already holds, which is how a developer
    // machine and a clean CI runner end up disagreeing.
    open func launch(seedingServer: Bool = true) {
        let configuration = seedingServer ? user.configuration : UITestConfiguration()

        if let value = try? configuration.environmentValue() {
            app.launchEnvironment[UITestConfiguration.environmentKey] = value
        }
        app.launch()
    }

    override open func setUp() async throws {
        try await super.setUp()

        continueAfterFailure = false
        await OrphanSweep.shared.runIfNeeded()
        user = try await TestUser.create()
    }

    override open func tearDown() async throws {
        try? await user?.delete()
        user = nil

        try await super.tearDown()
    }
}

// Runs once per suite, not once per test: a crashed run leaves a user and its namespaced custom
// fields behind, and the container outlives the run.
//
// This deletes every uit-* user regardless of age, which is safe only while tests run serially.
// Before parallel workers are enabled it has to learn to skip users a sibling worker is still
// using, or one worker will delete another's account mid-test.
private actor OrphanSweep {

    static let shared = OrphanSweep()

    func runIfNeeded() async {
        guard !hasRun else {
            return
        }
        hasRun = true

        try? await TestUser.sweepOrphans()
        try? await Fixtures.sweepOrphanedCustomFields()
    }

    private var hasRun = false
}
