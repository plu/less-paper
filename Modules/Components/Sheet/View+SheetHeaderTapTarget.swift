import SwiftUI

public extension View {

    // Apply this inside a button's or menu's label, never around it: the tap target is the label,
    // so the 60pt slot SheetHeader provides does nothing on its own — an icon alone is barely 15pt.
    func sheetHeaderTapTarget() -> some View {
        frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}
