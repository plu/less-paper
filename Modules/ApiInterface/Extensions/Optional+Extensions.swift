import Foundation

public enum OptionalError: Error {
    case empty(String)
}

public extension Optional {
    var value: Wrapped? {
        switch self {
        case .none:
            nil
        case let .some(value):
            value
        }
    }

    func get() throws -> Wrapped {
        switch self {
        case .none:
            throw OptionalError.empty(String(describing: Wrapped.self))
        case let .some(value):
            value
        }
    }
}

public extension Optional where Wrapped == String {

    var boolValue: Bool {
        switch self {
        case .none:
            false
        case let .some(value):
            value.boolValue
        }
    }

    func ids(separator: String = ",") -> [Int] {
        self?
            .components(separatedBy: separator)
            .compactMap(Int.init) ?? []
    }
}
