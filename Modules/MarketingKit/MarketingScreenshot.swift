import Components
import SwiftUI

// One App Store screenshot: the captured screen on the app's own dark ground, under a caption.
//
// No device bezel. Dropping it returns about a fifth of the canvas height, which is what the
// document rows need to stay legible at the size the App Store actually shows a screenshot.
//
// Every dimension is a fraction of the canvas height rather than a point value, because the same
// layout renders at 1320x2868 and at 2048x2732 and has to look like itself at both.
public struct MarketingScreenshot: View {

    public var body: some View {
        GeometryReader { proxy in
            let unit = proxy.size.height / 100

            ZStack {
                LinearGradient(
                    colors: [.marketingGroundTop, .marketingGroundBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                VStack(spacing: unit * 3) {
                    Text(screen.caption)
                        .font(.system(size: unit * 4.2, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        // A caption that will not fit in two lines at this size is a copy problem,
                        // and the snapshot test should show it rather than shrink it away.
                        .minimumScaleFactor(0.75)
                        .padding(.horizontal, unit * 6)
                        .padding(.top, unit * 6)

                    // Expands into whatever the caption leaves, rather than taking its natural
                    // size and leaving a dead band underneath.
                    capture
                        .resizable()
                        .scaledToFit()
                        .clipShape(RoundedRectangle(cornerRadius: unit * 2.2))
                        .shadow(color: .black.opacity(0.35), radius: unit * 1.2, y: unit * 0.6)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, unit * 7)
                        .padding(.bottom, unit * 6)
                }
            }
        }
    }

    public init(
        capture: Image,
        screen: MarketingScreen,
        device: MarketingDevice
    ) {
        self.capture = capture
        self.screen = screen
        self.device = device
    }

    private let capture: Image
    private let device: MarketingDevice
    private let screen: MarketingScreen
}

private extension Color {

    // Darker than m3Primary so white type sits comfortably on it, and out of the same family so the
    // marketing art and the product look related.
    static let marketingGroundTop = Color(red: 0, green: 0.31, blue: 0.30)
    static let marketingGroundBottom = Color(red: 0, green: 0.19, blue: 0.18)
}
