import Components
import ComposableArchitecture
import SwiftUI

@ViewAction(for: TipListReducer.self)
public struct TipListView: View {

    public var body: some View {
        Group {
            if store.loadFailed {
                EmptyListView(
                    systemImage: "heart.slash",
                    title: .tipsUnavailable
                ) {
                    Button {
                        send(.retryButtonTapped)
                    } label: {
                        Text(.retry)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.primary())
                }
            } else {
                List {
                    Section {
                        ForEach(store.products) { product in
                            Button {
                                send(.tipButtonTapped(product.tip))
                            } label: {
                                HStack {
                                    Text(product.displayName)
                                        .foregroundStyle(Color.m3OnSurface)

                                    Spacer()

                                    if store.purchasingTip == product.tip {
                                        ProgressView()
                                    } else {
                                        Text(product.displayPrice)
                                            .foregroundStyle(Color.m3Outline)
                                    }
                                }
                            }
                            // One sheet at a time: StoreKit is already showing one for the row
                            // being bought.
                            .disabled(store.purchasingTip != nil)
                            // Explicit foreground colors above opt the label out of the system's
                            // own dimming, so a disabled row needs its own visible cue.
                            .opacity(store.purchasingTip == nil || store.purchasingTip == product.tip ? 1 : 0.5)
                            .listRowBackground(Color.m3SurfaceContainer)
                        }
                    } header: {
                        Text(.tipsExplanation)
                            .textCase(nil)
                    }
                }
            }
        }
        .navigationTitle(Text(.tips))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            // Only the very first appearance (or a retry, which sets this back to true) should
            // fetch. Without this guard, reappearing after an already-loaded or already-failed
            // state briefly wipes the screen back to a blank list while it re-fetches.
            guard store.isLoading else {
                return
            }
            await send(.onAppear).finish()
        }
    }

    public init(store: StoreOf<TipListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<TipListReducer>
}
