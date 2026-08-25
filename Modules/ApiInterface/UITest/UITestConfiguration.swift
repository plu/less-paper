import Foundation

public struct UITestConfiguration: Codable, Equatable, Sendable {

    public static let environmentKey = "UI_TEST_CONFIGURATION"

    public struct Seed: Codable, Equatable, Sendable {

        public let password: String

        public let server: Server

        public let token: String

        public init(
            password: String,
            server: Server,
            token: String
        ) {
            self.password = password
            self.server = server
            self.token = token
        }
    }

    // A nil seed still swaps storage to memory — it just leaves the app with no server, which is
    // the only way to reach the add-server flow deterministically. Launching with no configuration
    // at all would inherit whatever servers.json the simulator happens to hold.
    public let seed: Seed?

    public init(
        seed: Seed? = nil
    ) {
        self.seed = seed
    }
}

public extension UITestConfiguration {

    static func fromEnvironment(
        _ environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Self? {
        guard let value = environment[environmentKey],
              let data = value.data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder.apiDecoder.decode(Self.self, from: data)
    }

    func environmentValue() throws -> String {
        String(
            decoding: try JSONEncoder.apiEncoder.encode(self),
            as: UTF8.self
        )
    }
}
