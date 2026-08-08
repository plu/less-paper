import SwiftUI

public extension View {

    @ViewBuilder
    func frame(size: CGSize) -> some View {
        frame(width: size.width, height: size.height)
    }
}
