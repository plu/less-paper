import Dependencies
import Foundation

// Exactly the web UI's choices.
enum DocumentShareLinksExpiry: CaseIterable, Identifiable {
    case oneDay
    case sevenDays
    case thirtyDays
    case never

    var id: Self { self }

    var localized: LocalizedStringResource {
        switch self {
        case .oneDay:
            .shareLinkExpiryOneDay
        case .sevenDays:
            .shareLinkExpirySevenDays
        case .thirtyDays:
            .shareLinkExpiryThirtyDays
        case .never:
            .shareLinkExpiryNever
        }
    }

    func expiration(from now: Date) -> Date? {
        @Dependency(\.calendar)
        var calendar

        let days: Int
        switch self {
        case .oneDay:
            days = 1
        case .sevenDays:
            days = 7
        case .thirtyDays:
            days = 30
        case .never:
            return nil
        }
        return calendar.date(byAdding: .day, value: days, to: now)
    }
}
