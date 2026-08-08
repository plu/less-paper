import Dependencies
import Foundation

public extension DateFormatter {

    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
        self.timeZone = Dependency(\.timeZone).wrappedValue
    }

    static let createdDate: DateFormatter = .init(dateFormat: "yyyy-MM-dd")
}
