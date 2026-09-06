import ApiInterface
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: ServerDetailReducer.self)
public struct ServerDetailView: View {

    public var body: some View {
        List {
            refreshFailedNote()
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

    // A failed refresh never replaces the screen and never clears a value - the last known numbers
    // are still the best answer available - so it says so quietly and stays out of the way. Only
    // the failure is rendered, not isRefreshing: onAppear fires on every appearance, and a spinner
    // that comes and goes would make every recorded reference a race.
    @ViewBuilder
    private func refreshFailedNote() -> some View {
        if store.refreshFailed {
            Section {
                Label {
                    Text(.refreshFailedNote)
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                }
                .font(.footnote)
                .foregroundStyle(Color.m3Outline)
                .listRowBackground(Color.m3SurfaceContainer)
            }
        }
    }

    @ViewBuilder
    private func serverSection() -> some View {
        Section {
            LabeledContent(String(localized: .alias)) {
                Text(verbatim: store.server.alias)
            }
            .listRowBackground(Color.m3SurfaceContainer)

            LabeledContent(String(localized: .url)) {
                Text(verbatim: stringValue(store.server.url.credentialFreeDisplayString))
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

    // The same glyphs this app already uses for these four actions elsewhere — plus on every list's
    // toolbar, square.and.pencil on edit, trash on delete, eye on preview — so the row reads as the
    // actions the user already knows rather than a private vocabulary. nil means no glyph, and the
    // caller falls back to the word.
    static func symbol(for action: String) -> String? {
        switch action {
        case "add": "plus"
        case "change": "square.and.pencil"
        case "delete": "trash"
        case "view": "eye"
        default: nil
        }
    }

    @ViewBuilder
    private func permissionsSection() -> some View {
        Section {
            if let permissions = store.permissions {
                ForEach(PermissionSummary.grouped(permissions), id: \.type) { summary in
                    LabeledContent(summary.type.capitalized) {
                        HStack(spacing: .x2) {
                            ForEach(summary.actions, id: \.self) { action in
                                if let symbol = Self.symbol(for: action) {
                                    Image(systemName: symbol)
                                } else {
                                    // An action this app has no glyph for still has to be readable:
                                    // paperless adding a fifth verb should degrade to its word
                                    // rather than vanish or show a placeholder.
                                    Text(verbatim: action.capitalized)
                                }
                            }
                        }
                        .foregroundStyle(Color.m3Outline)
                    }
                    // One utterance carrying the words, rather than four icons announced
                    // separately: the glyphs are for the eye, and this row is what VoiceOver reads.
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(
                        "\(summary.type.capitalized): \(summary.actions.map(\.capitalized).joined(separator: ", "))"
                    )
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

            // Not labelled "(Cached)" and not gated: favorites is a purely local store - records
            // are created by user action and refreshed only where they already exist - so an empty
            // array means the user has no favorites here, a fact that is known without ever asking
            // the server. It is the one count on this screen that cannot be stale.
            LabeledContent(String(localized: .favorites)) {
                Text(verbatim: String(favorites.count))
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

    // Three outcomes, not two. A user who belongs to no group is a fact worth stating; a user whose
    // group ids are all in hand but resolve to nothing is a lookup that failed - /api/groups/ 403s
    // on its own, and the cache is then empty - and reporting that as "no groups" would be the same
    // wrong-fact bug cachedCount exists to avoid. Neither may render as the blank row compactMap
    // used to produce, which is neither a value nor Unknown.
    private func groupNames() -> String {
        guard let currentUser = store.currentUser else {
            return String(localized: .unknownValue)
        }
        guard !currentUser.groups.isEmpty else {
            return String(localized: .noGroups)
        }
        let names = currentUser.groups
            .compactMap { store.groups[id: $0]?.name }
            .sorted()
        guard !names.isEmpty else {
            return String(localized: .unknownValue)
        }
        return names.joined(separator: ", ")
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

    // An empty @Shared array derived from a server-side list is ambiguous by construction, and
    // nothing on this screen can disambiguate it: it defaults to [] whether nothing has ever been
    // fetched, the server genuinely has none, or the fetch was refused. UpdateCacheUseCase catches
    // every list failure separately and never rethrows - that tolerance is deliberate, see the
    // comment there - so a completed refresh proves only that the function ran to the end, not that
    // /api/users/ answered. An account without view_user would otherwise be told the server has 0
    // users, which is the app reporting its own permission error as a fact about the server.
    //
    // So empty always reads Unknown. A non-empty count needs no gate - if the cache holds items, at
    // least that many exist regardless of which fetch succeeded.
    private func cachedCount(_ count: Int) -> String {
        guard count > 0 else {
            return String(localized: .unknownValue)
        }
        return String(count)
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
