import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: FileTaskListReducer.self)
public struct FileTaskListView: View {

    public var body: some View {
        // isScrollingEnabled off because the content is a List: swipe actions and pull to refresh
        // both need one, and a List inside the Sheet's ScrollView would nest two scroll views.
        Sheet(isScrollingEnabled: false, padding: .x0) {
            SheetHeader(title: {
                Text(.fileTasks)
            }, left: {
                SheetCloseButton {
                    send(.closeButtonTapped)
                }
            })
        } content: {
            VStack(spacing: .x0) {
                Picker(String(localized: .fileTasks), selection: $store.segment) {
                    // Not .allCases: the enum stays alphabetical per repo convention, but the
                    // spec's segment order is Failed, Complete, Started, Queued - matching the
                    // web's tabs, with the problem segment first.
                    ForEach(FileTaskListView.segments, id: \.self) { status in
                        Text(status.title).tag(status)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.x3)
                list()
            }
        } contentOverlay: {
            EmptyView()
        } bottom: {
            EmptyView()
        }
    }

    public init(store: StoreOf<FileTaskListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<FileTaskListReducer>

    private static let segments: [FileTaskStatus] = [.failed, .complete, .started, .queued]

    @ViewBuilder
    private func list() -> some View {
        // The list is always present with the empty state over it: a ContentUnavailableView on its
        // own does not scroll, so pull to refresh would be unavailable exactly when it is wanted.
        List {
            ForEach(store.tasks) { task in
                FileTaskRowView(
                    task: task,
                    canDismiss: store.canDismiss,
                    isDismissing: store.isDismissing.contains(task.id),
                    dismiss: { send(.dismissButtonTapped(task.id)) }
                )
                .contentShape(Rectangle())
                .onTapGesture { send(.rowTapped(task)) }
                .onAppear { send(.onRowAppear(task)) }
            }
            if store.isLoadingMore {
                HStack {
                    Spacer()
                    ProgressView()
                        .controlSize(.large)
                        .id(UUID())
                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .listStyle(.plain)
        .overlay(emptyView())
        .refreshable { await send(.onRefresh).finish() }
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
    }

    @ViewBuilder
    private func emptyView() -> some View {
        Group {
            if store.tasks.isEmpty, store.isLoaded {
                ContentUnavailableView {
                    EmptyListView(systemImage: "tray", title: .fileTasksEmpty) {
                        Text(.fileTasksEmptyDescription)
                            .font(.subheadline)
                            .foregroundStyle(Color.m3OnSurface)
                            .multilineTextAlignment(.center)
                    }
                }
            } else if store.tasks.isEmpty {
                // The first load, and every segment switch, which clears tasks and resets
                // isLoaded: without this branch the view spoke only once isLoaded was true, so a
                // slow fetch left the user looking at a blank list with no way to tell it apart
                // from an empty segment. Both states live here so the next reader finds them in
                // one place.
                ZStack {
                    ProgressView()
                        .controlSize(.large)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        // Without this the overlay swallows the scroll and pull to refresh stops working while
        // empty or loading, which is exactly when it is wanted.
        .allowsHitTesting(false)
    }
}

private extension FileTaskStatus {

    var title: LocalizedStringResource {
        switch self {
        case .complete:
            .fileTasksComplete
        case .failed:
            .fileTasksFailed
        case .queued:
            .fileTasksQueued
        case .started:
            .fileTasksStarted
        }
    }
}

#Preview {
    FileTaskListView(
        store: Store(
            initialState: .testValue(),
            reducer: {
                FileTaskListReducer()
            }
        )
    )
}
