import ComposableArchitecture
import SwiftUI

// Reads the count straight from shared storage rather than taking it from a store, so any sheet in
// the filter flow can show it with one line and no state plumbing. The pickers change the filter on
// every tap, so the count moves while they are on screen — it has to be visible there too.
struct DocumentFilterMatchCountView: View {

    var body: some View {
        if let count = matchCount.count {
            Text(.numberOfMatchingDocuments(count))
                .capsule(
                    backgroundColor: .m3Primary,
                    font: .footnote,
                    foregroundColor: .m3OnPrimary
                )
                // Dimmed rather than hidden while the list re-queries: the number on screen belongs
                // to the previous filter for the ~600ms a debounced keystroke takes, and hiding it
                // would flicker on every change.
                .opacity(matchCount.isRecalculating ? 0.5 : 1)
                .animation(.default, value: matchCount.isRecalculating)
                .padding(.x3)
        }
    }

    @Shared(.documentFilterMatchCount)
    private var matchCount
}
