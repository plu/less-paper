import Foundation

public extension Data {

    static func testValue(
        named name: String = "Puky.pdf"
    ) throws -> Data {
        try Data(contentsOf: URL.projectRoot
            .appendingPathComponent("docker")
            .appendingPathComponent("data")
            .appendingPathComponent(name))
    }
}
