import Foundation

extension DateFormatter {

    convenience init(dateFormat: String) {
        self.init()
        self.dateFormat = dateFormat
    }

    static let createdDate: DateFormatter = .init(dateFormat: "yyyy-MM-dd")
}
