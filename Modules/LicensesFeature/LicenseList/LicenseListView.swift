import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: LicenseListReducer.self)
public struct LicenseListView: View {
    public var body: some View {
        List {
            Section {
                ForEach(store.licenses) { license in
                    Button {
                        send(.licenseSelected(license))
                    } label: {
                        HStack {
                            Text(license.name)
                                .foregroundStyle(Color.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(.gray)
                                .imageScale(.small)
                        }
                        .contentShape(Rectangle())
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
                }
            }
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationTitle(.licenses)
        .navigationBarTitleDisplayMode(.inline)
        .scrollContentBackground(.hidden)
    }

    public init(store: StoreOf<LicenseListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<LicenseListReducer>
}

#Preview {
    NavigationStack {
        LicenseListView(store: Store(initialState: LicenseListReducer.State(), reducer: {
            LicenseListReducer()
        }))
    }
}
