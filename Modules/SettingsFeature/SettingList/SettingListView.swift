import ComposableArchitecture
import CorrespondentsFeature
import CustomFieldsFeature
import DesignTokens
import DiagnosticsFeature
import DocumentTypesFeature
import LicensesFeature
import PdfPasswordsFeature
import SavedViewsFeature
import ServersFeature
import ShareFeature
import StoragePathsFeature
import SwiftUI
import TagsFeature
import TipsFeature
import TrashFeature
import VisionKit

@ViewAction(for: SettingListReducer.self)
public struct SettingListView: View {

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            List {
                Section {
                    NavigationLink(
                        state: SettingListReducer.Path.State.serverList(ServerListReducer.State())
                    ) {
                        Label(.servers, systemImage: "server.rack")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
                } footer: {
                    Text([store.server.username, store.server.alias].joined(separator: "@"))
                }

                Section {
                    if store.permissions.can(.viewCorrespondent) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.correspondentList(CorrespondentListReducer.State(server: store.server))
                        ) {
                            Label(.correspondents, systemImage: "person")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }

                    if store.permissions.can(.viewCustomField) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.customFieldList(CustomFieldListReducer.State(server: store.server))
                        ) {
                            Label(.customFields, systemImage: "list.bullet.rectangle")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }

                    if store.permissions.can(.viewDocumentType) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.documentTypeList(DocumentTypeListReducer.State(server: store.server))
                        ) {
                            Label(.documentTypes, systemImage: "document.badge.gearshape")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }

                    NavigationLink(
                        state: SettingListReducer.Path.State.pdfPasswordList(PdfPasswordListReducer.State())
                    ) {
                        Label(.pdfPasswords, systemImage: "key")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    if store.permissions.can(.viewSavedView) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.savedViewList(SavedViewListReducer.State(server: store.server))
                        ) {
                            Label(.savedViews, systemImage: "line.3.horizontal.decrease")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }

                    if store.permissions.can(.viewStoragePath) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.storagePathList(StoragePathListReducer.State(server: store.server))
                        ) {
                            Label(.storagePaths, systemImage: "folder")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }

                    if store.permissions.can(.viewTag) {
                        NavigationLink(
                            state: SettingListReducer.Path.State.tagList(TagListReducer.State(server: store.server))
                        ) {
                            Label(.tags, systemImage: "tag")
                        }
                        .listRowBackground(Color.m3SurfaceContainer)
                    }

                    NavigationLink(
                        state: SettingListReducer.Path.State.trashList(TrashListReducer.State(server: store.server))
                    ) {
                        Label(.trash, systemImage: "trash")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
                }

                Section {
                    Button {
                        send(.importButtonTapped)
                    } label: {
                        Label {
                            Text(.import)
                                .foregroundStyle(Color.m3OnSurface)
                        } icon: {
                            Image(systemName: "doc.badge.plus")
                        }
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    Button {
                        send(.scanButtonTapped)
                    } label: {
                        Label {
                            Text(.scan)
                                .foregroundStyle(Color.m3OnSurface)
                        } icon: {
                            Image(systemName: "camera")
                        }
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
                }

                // A-Z by English title, matching the section above. German sorts differently and is
                // left alone: reordering per locale would give the two languages different
                // screenshots for no reader's benefit.
                Section {
                    NavigationLink(
                        state: SettingListReducer.Path.State.diagnosticsList(DiagnosticsListReducer.State())
                    ) {
                        Label(.diagnostics, systemImage: "stethoscope")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.favoriteSettings(FavoriteSettingsReducer.State(server: store.server))
                    ) {
                        Label(.favorites, systemImage: "heart")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    Link(destination: Self.repositoryUrl) {
                        Label {
                            Text(.github)
                                .foregroundStyle(Color.m3OnSurface)
                        } icon: {
                            Image(systemName: "chevron.left.forwardslash.chevron.right")
                        }
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.licenseList(LicenseListReducer.State())
                    ) {
                        Label(.licenses, systemImage: "rosette")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    Link(destination: Self.reviewUrl) {
                        Label {
                            Text(.rate)
                                .foregroundStyle(Color.m3OnSurface)
                        } icon: {
                            Image(systemName: "star")
                        }
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.tipList(TipListReducer.State())
                    ) {
                        Label(.tips, systemImage: "cup.and.saucer")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)
                } footer: {
                    HStack {
                        Spacer()
                        Text(store.appVersion)
                            .font(.caption)
                            .foregroundStyle(Color.m3Outline)
                        Spacer()
                    }
                }
            }
            .background(Color.m3SurfaceContainerLowest)
            .navigationBarTitleDisplayMode(.inline)
            .navigationTitle(.settings)
            .scrollContentBackground(.hidden)
        } destination: { store in
            switch store.case {
            case let .correspondentList(store):
                CorrespondentListView(store: store)
            case let .customFieldList(store):
                CustomFieldListView(store: store)
            case let .diagnosticsList(store):
                DiagnosticsListView(store: store)
            case let .documentTypeList(store):
                DocumentTypeListView(store: store)
            case let .favoriteSettings(store):
                FavoriteSettingsView(store: store)
            case let .license(license):
                LicenseView(license: license)
            case let .licenseList(store):
                LicenseListView(store: store)
            case let .pdfPasswordList(store):
                PdfPasswordListView(store: store)
            case let .savedViewList(store):
                SavedViewListView(store: store)
            case let .serverList(store):
                ServerListView(store: store)
            case let .storagePathList(store):
                StoragePathListView(store: store)
            case let .tagList(store):
                TagListView(store: store)
            case let .tipList(store):
                TipListView(store: store)
            case let .trashList(store):
                TrashListView(store: store)
            }
        }
        .documentImport(
            store: store.scope(state: \.documentImport, action: \.documentImport)
        )
    }

    public init(store: StoreOf<SettingListReducer>) {
        self.store = store
    }

    @Bindable
    public var store: StoreOf<SettingListReducer>

    // Opens the App Store rather than asking StoreKit for the review prompt. That prompt is
    // rate-limited and silent - iOS shows it at most three times a year and says nothing when it
    // declines - so a row that appears to do nothing is the ordinary outcome rather than the rare
    // one. It also shares its four-month cooldown with the ask that follows an import or a tip, and
    // tapping here must not spend that.
    //
    // `action=write-review` is what opens the review sheet; without it the link lands on the
    // description page.
    static let reviewUrl = URL(string: "https://apps.apple.com/app/id6464425056?action=write-review")!

    private static let repositoryUrl = URL(string: "https://github.com/plu/less-paper")!
}

#Preview {
    List {
        SettingListView(
            store: Store(
                initialState: SettingListReducer.State(server: .testValue()),
                reducer: {
                    SettingListReducer()
                }
            )
        )
    }
}
