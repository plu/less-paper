import Foundation

// The two sets Apple requires: a 6.9" iPhone, and a 13" iPad for an app that runs on iPad.
// Everything smaller is scaled from these by App Store Connect.
public enum MarketingDevice: String, CaseIterable, Sendable {
    case iPhone
    case iPad

    // Exact, because App Store Connect refuses anything else. Stated in pixels rather than points:
    // the renderer draws at scale 1, so these are the dimensions of the file.
    public var size: CGSize {
        switch self {
        case .iPhone:
            CGSize(width: 1320, height: 2868)
        case .iPad:
            CGSize(width: 2048, height: 2732)
        }
    }

    // How the capture files are named, which is the simulator the capture ran on.
    public var capturePrefix: String {
        switch self {
        case .iPhone:
            "iPhone 17 Pro Max"
        case .iPad:
            "iPad Pro 13-inch (M5)"
        }
    }
}
