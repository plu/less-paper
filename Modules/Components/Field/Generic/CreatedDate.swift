import Foundation

public struct CreatedDate {

    public let date: Date

    public init(date: Date) {
        self.date = date
    }
}

extension CreatedDate: Identifiable {

    public var id: String {
        DateFormatter.createdDate.string(from: date)
    }
}
