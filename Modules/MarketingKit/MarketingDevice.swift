import Foundation

// The sets Apple requires: a 6.9" iPhone, and a 13" iPad for an app that runs on iPad. Everything
// smaller is scaled from these by App Store Connect - except the iPhone Duo, whose sizes match no
// other class and so need a set of their own.
public enum MarketingDevice: String, CaseIterable, Sendable {
    case iPhone
    case iPad
    case iPhoneDuo

    // Exact, because App Store Connect refuses anything else. Stated in pixels rather than points:
    // the renderer draws at scale 1, so these are the dimensions of the file.
    public var size: CGSize {
        switch self {
        case .iPhone:
            CGSize(width: 1320, height: 2868)
        case .iPad:
            CGSize(width: 2048, height: 2732)
        // The outer display. App Store Connect also takes the inner one's 2007x2853, but the
        // simulator's main screen - which is what the capture photographs - is the outer.
        case .iPhoneDuo:
            CGSize(width: 1398, height: 2034)
        }
    }

    // How the capture files are named, which is the simulator the capture ran on.
    public var capturePrefix: String {
        switch self {
        case .iPhone:
            "iPhone 17 Pro Max"
        case .iPad:
            "iPad Pro 13-inch (M5)"
        case .iPhoneDuo:
            "iPhone Duo"
        }
    }
}
