import Foundation

// The three tips, in the order they are shown.
//
// The raw value is the App Store Connect product id, which can never be renamed or reused once the
// product exists. That is also why these name a rank rather than an amount: repricing later leaves
// small, medium and large true, where tip.5 would become a lie.
public enum Tip: String, CaseIterable, Equatable, Identifiable, Sendable {

    case small = "com.aptumtek.app.Paperless.tip.small"

    case medium = "com.aptumtek.app.Paperless.tip.medium"

    case large = "com.aptumtek.app.Paperless.tip.large"

    public var id: String { rawValue }
}
