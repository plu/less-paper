import Foundation

// The four tips. The raw value is the App Store Connect product id, which can never be renamed or
// reused once the product exists. That is also why these name a rank rather than an amount:
// repricing later leaves small, medium and large true, where tip.5 would become a lie.
//
// Declaration order is smallest first, but it is not what the list shows: TipJar sorts by the price
// actually charged, and falls back on this order only to break a tie.
public enum Tip: String, CaseIterable, Equatable, Identifiable, Sendable {

    case tiny = "com.aptumtek.app.Paperless.tip.tiny"

    case small = "com.aptumtek.app.Paperless.tip.small"

    case medium = "com.aptumtek.app.Paperless.tip.medium"

    case large = "com.aptumtek.app.Paperless.tip.large"

    public var id: String { rawValue }

    // Position in allCases, used to break a price tie into a fixed order.
    var rank: Int { Self.allCases.firstIndex(of: self) ?? 0 }
}
