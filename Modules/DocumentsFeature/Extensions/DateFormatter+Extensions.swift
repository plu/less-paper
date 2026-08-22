import Dependencies
import Foundation

extension DateFormatter {

    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
    }

    static let createdDate: DateFormatter = .init(dateFormat: "yyyy-MM-dd")

    // A fixed format rather than a locale-aware style, and an explicit time zone rather than the
    // system one: the test trait pins `timeZone` but not `locale`, so anything else would make
    // snapshots machine-dependent.
    static let noteCreated: DateFormatter = {
        let formatter = DateFormatter(dateFormat: "yyyy-MM-dd HH:mm")
        formatter.timeZone = Dependency(\.timeZone).wrappedValue
        return formatter
    }()
}
