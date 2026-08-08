import ComposableArchitecture
import Dependencies
import DocumentsFeature
import SettingsFeature
import SwiftUI

struct MainView: View {

    var body: some View {
        TabView(selection: $store.selectedTab.sending(\.selectedTab)) {
            InboxView(
                store: store.scope(
                    state: \.inbox,
                    action: \.inbox
                )
            )
            .tabItem { Label(.inbox, systemImage: "tray.full") }
            .tag(AppTab.inbox)

            DocumentListView(
                store: store.scope(
                    state: \.documentList,
                    action: \.documentList
                )
            )
            .tabItem { Label(.documents, systemImage: "document.on.document.fill") }
            .tag(AppTab.documents)

            SettingListView(
                store: store.scope(
                    state: \.settingList,
                    action: \.settingList
                )
            )
            .tabItem { Label(.settings, systemImage: "gear") }
            .tag(AppTab.settings)
        }
    }

    @Bindable
    var store: StoreOf<MainReducer>
}
