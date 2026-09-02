import Components
import DesignTokens
import SwiftUI

/// What the detail column shows on iPad before anything is picked.
///
/// Only ever visible in the split layout: on iPhone the list fills the screen and there is no
/// second column to fill.
struct DocumentDetailPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            // The description goes in `content` rather than a new `subtitle` parameter: one caller
            // is not a reason to widen a component every other empty state already shares.
            EmptyListView(systemImage: "document", title: .noDocumentSelected) {
                Text(.noDocumentSelectedDescription)
                    .font(.subheadline)
                    .foregroundStyle(Color.m3OnSurface)
                    .multilineTextAlignment(.center)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
    }
}
