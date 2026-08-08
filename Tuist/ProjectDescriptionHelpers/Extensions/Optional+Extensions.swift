import Foundation
import ProjectDescription

extension Optional where Wrapped == ProjectDescription.Environment.Value {
    func getString() -> String? {
        switch self {
        case .none:
            nil
        case .some(let wrapped):
            switch wrapped {
            case .string(let string):
                string
            @unknown default:
                nil
            }
        }
    }
}

extension Optional {
    func unwrap<T>(_ perform: (Wrapped) -> T) -> T? {
        guard let self else {
            return nil
        }

        return perform(self)
    }
}
