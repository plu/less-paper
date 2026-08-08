import Foundation

public extension String {

    var boolValue: Bool {
        switch self {
        case "1",
             "true",
             "yes":
            true
        default:
            false
        }
    }
}
