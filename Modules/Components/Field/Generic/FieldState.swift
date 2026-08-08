import Foundation

public struct FieldState<Value: Equatable & Sendable>: Equatable, Sendable {

    public var error: String?

    public var focused: Bool

    public var value: Value

    public init(
        error: String? = nil,
        focused: Bool = false,
        value: Value
    ) {
        self.error = error
        self.focused = focused
        self.value = value
    }
}
