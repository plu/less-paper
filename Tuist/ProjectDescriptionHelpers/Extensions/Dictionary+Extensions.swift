import ProjectDescription

extension Dictionary where Key == String, Value == EnvironmentVariable {
    static let `default`: Self = [
        "SNAPSHOT_RECORD": .environmentVariable(
            value: "all",
            isEnabled: false
        )
    ]
}
