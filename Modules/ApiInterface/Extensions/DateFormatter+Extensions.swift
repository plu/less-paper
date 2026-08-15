import Dependencies
import Foundation

public extension DateFormatter {

    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
        self.timeZone = Dependency(\.timeZone).wrappedValue
    }

    static let createdDate: DateFormatter = .init(dateFormat: "yyyy-MM-dd")

    /// The date format Paperless expects in filter rule values.
    ///
    /// Separate from `createdDate` despite the identical format: that one is for display and could
    /// reasonably be localised one day, while this one is wire format and must not be.
    static let filterRule: DateFormatter = .init(dateFormat: "yyyy-MM-dd")
}
