import SwiftUI

public struct SheetCloseButton: View {

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "xmark")
                .sheetHeaderTapTarget()
                .accessibilityLabel(.close)
        }
    }

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    private let action: () -> Void
}
