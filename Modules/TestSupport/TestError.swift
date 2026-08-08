import Foundation

public enum TestError: Error, Equatable {
    case someError
}

extension TestError: LocalizedError {
    public var errorDescription: String? {
        "TestError.someError"
    }
}
