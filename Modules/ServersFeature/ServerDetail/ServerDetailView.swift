import ApiInterface
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: ServerDetailReducer.self)
public struct ServerDetailView: View {

    public var body: some View {
        List {
            serverSection()
            versionsSection()
            userSection()
            permissionsSection()
            contentSection()
        }
        .background(Color.m3SurfaceContainerLowest)
        .navigationBarTitleDisplayMode(.inline)
        .navigationTitle(.serverDetails)
        .scrollContentBackground(.hidden)
        .task { await send(.onAppear).finish() }
    }

    public init(store: StoreOf<ServerDetailReducer>) {
        self.store = store
        _favorites = Shared(wrappedValue: [], .favorites(store.server))
    }

    public var store: StoreOf<ServerDetailReducer>

    // Read directly rather than through State: favorites has nothing to do with the refresh this
    // screen triggers, and threading it through the reducer would make ServerDetailReducer own a
    // cache no other part of it touches.
    @Shared
    private var favorites: IdentifiedArrayOf<FavoriteDocument>

    @ViewBuilder
    private func serverSection() -> some View {
        Section {
            LabeledContent(String(localized: .alias)) {
                Text(verbatim: store.server.alias)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .url)) {
                Text(verbatim: store.server.url.absoluteString)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .serverId)) {
                Text(verbatim: store.server.id)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .authMode)) {
                Text(verbatim: authMode)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            // Never the value: a header can carry an API key or a bearer token, and this row's
            // whole job is to prove that no future field on this screen can print one by accident.
            ForEach(store.server.headers) { header in
                LabeledContent(header.name) {
                    Text(verbatim: "••••")
                }
                .listRowBackground(Color.m3SurfaceContainer)
            }
        } header: {
            Text(.server)
        }
    }

    @ViewBuilder
    private func versionsSection() -> some View {
        Section {
            LabeledContent(String(localized: .paperlessNgx)) {
                Text(verbatim: stringValue(store.paperlessVersion))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .apiVersion)) {
                Text(verbatim: count(store.apiVersion))
            }
            .listRowBackground(Color.m3SurfaceContainer)
        } header: {
            Text(.versions)
        }
    }

    @ViewBuilder
    private func userSection() -> some View {
        Section {
            LabeledContent(String(localized: .username)) {
                Text(verbatim: stringValue(store.currentUser?.username))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .superuser)) {
                Text(boolValue(store.currentUser?.isSuperuser))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .staff)) {
                Text(boolValue(store.currentUser?.isStaff))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .groups)) {
                Text(verbatim: groupNames())
            }
            .listRowBackground(Color.m3SurfaceContainer)
        } header: {
            Text(.user)
        }
    }

    @ViewBuilder
    private func permissionsSection() -> some View {
        Section {
            if let permissions = store.permissions {
                ForEach(PermissionSummary.grouped(permissions), id: \.type) { summary in
                    LabeledContent(summary.type.capitalized) {
                        Text(verbatim: summary.actions.map(\.capitalized).joined(separator: ", "))
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
                }
            } else {
                LabeledContent(String(localized: .permissions)) {
                    Text(.unknownValue)
                }
                .listRowBackground(Color.m3SurfaceContainer)
            }
        } header: {
            Text(.permissions)
        }
    }

    @ViewBuilder
    private func contentSection() -> some View {
        Section {
            LabeledContent(String(localized: .documents)) {
                Text(verbatim: count(store.statistics?.documentsTotal))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .inbox)) {
                Text(verbatim: count(store.statistics?.documentsInbox))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .characters)) {
                Text(verbatim: count(store.statistics?.characterCount))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .currentAsn)) {
                Text(verbatim: count(store.statistics?.currentAsn))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            fileTypesRows()

            LabeledContent(String(localized: .tags)) {
                Text(verbatim: count(store.statistics?.tagCount))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .correspondents)) {
                Text(verbatim: count(store.statistics?.correspondentCount))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .documentTypes)) {
                Text(verbatim: count(store.statistics?.documentTypeCount))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .storagePaths)) {
                Text(verbatim: count(store.statistics?.storagePathCount))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(cachedLabel(.customFields)) {
                Text(verbatim: cachedCount(store.customFields.count))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(cachedLabel(.savedViews)) {
                Text(verbatim: cachedCount(store.savedViews.count))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(cachedLabel(.users)) {
                Text(verbatim: cachedCount(store.users.count))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(cachedLabel(.groups)) {
                Text(verbatim: cachedCount(store.groups.count))
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(cachedLabel(.favorites)) {
                Text(verbatim: cachedCount(favorites.count))
            }
            .listRowBackground(Color.m3SurfaceContainer)
        } header: {
            Text(.content)
        } footer: {
            Text(.cachedCountsFooter)
        }
    }

    @ViewBuilder
    private func fileTypesRows() -> some View {
        if let statistics = store.statistics {
            ForEach(statistics.documentFileTypeCounts, id: \.mimeType) { fileType in
                LabeledContent(fileType.mimeType) {
                    Text(verbatim: String(fileType.mimeTypeCount))
                }
                .listRowBackground(Color.m3SurfaceContainer)
            }
        } else {
            LabeledContent(String(localized: .fileTypes)) {
                Text(.unknownValue)
            }
            .listRowBackground(Color.m3SurfaceContainer)
        }
    }

    private var authMode: String {
        switch store.hasToken {
        case .some(true):
            "token"
        case .some(false):
            "remote-user"
        case .none:
            String(localized: .unknownValue)
        }
    }

    private func groupNames() -> String {
        guard let currentUser = store.currentUser else {
            return String(localized: .unknownValue)
        }
        return currentUser.groups
            .compactMap { store.groups[id: $0]?.name }
            .sorted()
            .joined(separator: ", ")
    }

    private func boolValue(_ value: Bool?) -> LocalizedStringResource {
        switch value {
        case .some(true):
            .yes
        case .some(false):
            .no
        case .none:
            .unknownValue
        }
    }

    // "0 tags" and "we have never asked" are different facts, and telling them apart is the point
    // of this screen. statistics is nil until the first refresh returns.
    private func count(_ value: Int?) -> String {
        value.map(String.init) ?? String(localized: .unknownValue)
    }

    private func stringValue(_ value: String?) -> String {
        value ?? String(localized: .unknownValue)
    }

    // The label itself carries the distinction rather than a section footer: a reader glancing at
    // one row - not the whole section - has to be able to tell a cached count from a fresh one, so
    // that a cache lagging behind a fresh statistic reads as staleness rather than as a bug.
    private func cachedLabel(_ title: LocalizedStringResource) -> String {
        "\(String(localized: title)) (\(String(localized: .cached)))"
    }

    // An empty @Shared array is ambiguous by construction - it defaults to [] whether nothing has
    // ever been fetched or the server genuinely has none - so a bare count cannot tell the two
    // apart on its own. This screen can: store.statistics is the signal that this screen's own
    // refresh has completed successfully at least once (set only by .statisticsLoaded, which
    // follows a successful updateCache + getStatistics chain), so it doubles as "the caches this
    // refresh populates are now trustworthy". A non-zero count needs no such gate - if the cache
    // holds items, at least that many exist regardless of whether a refresh has ever run.
    private func cachedCount(_ count: Int) -> String {
        guard count == 0 else {
            return String(count)
        }
        guard store.statistics != nil else {
            return String(localized: .unknownValue)
        }
        return "0"
    }
}

#Preview {
    NavigationStack {
        ServerDetailView(
            store: Store(
                initialState: .testValue(),
                reducer: {
                    ServerDetailReducer()
                }
            )
        )
    }
}
