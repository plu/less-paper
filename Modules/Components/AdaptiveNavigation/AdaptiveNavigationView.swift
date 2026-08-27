import ComposableArchitecture
import SwiftUI

/// A list that pushes on iPhone and sits beside its detail on iPad.
///
/// Both layouts are driven by the same `StackState` path, because navigation here is data: a row
/// tap sends an action, the reducer appends to the path, and whichever column owns the stack
/// renders the result. Nothing about the reducer changes between the two.
///
/// The size class is read rather than left to `NavigationSplitView`'s own collapsing. Collapsing
/// would put the compact layout on a code path it does not use today, and the phone layout is what
/// every UI journey and snapshot reference is written against.
public struct AdaptiveNavigationView<
    PathState: ObservableState,
    PathAction,
    List: View,
    Destination: View,
    Placeholder: View
>: View {

    public var body: some View {
        if isCompact {
            NavigationStack(path: path) {
                list
            } destination: { store in
                destination(store)
            }
        } else {
            NavigationSplitView(columnVisibility: .constant(.doubleColumn)) {
                // Its own stack, so the list keeps the title and toolbars it already declares.
                NavigationStack {
                    list
                }
            } detail: {
                NavigationStack(path: path) {
                    placeholder
                } destination: { store in
                    destination(store)
                }
            }
            // Without this the split view narrows the sidebar to a master-detail proportion better
            // suited to a settings screen than to document rows carrying a thumbnail and tags.
            .navigationSplitViewStyle(.balanced)
        }
    }

    public init(
        path: Binding<Store<StackState<PathState>, StackAction<PathState, PathAction>>>,
        @ViewBuilder list: () -> List,
        @ViewBuilder destination: @escaping (Store<PathState, PathAction>) -> Destination,
        @ViewBuilder placeholder: () -> Placeholder
    ) {
        self.path = path
        self.list = list()
        self.destination = destination
        self.placeholder = placeholder()
    }

    private var isCompact: Bool {
        horizontalSizeClass == .compact
    }

    @Environment(\.horizontalSizeClass)
    private var horizontalSizeClass

    private let path: Binding<Store<StackState<PathState>, StackAction<PathState, PathAction>>>

    private let list: List

    private let destination: (Store<PathState, PathAction>) -> Destination

    private let placeholder: Placeholder
}
