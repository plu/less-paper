import ComposableArchitecture
import CorrespondentsFeature
import CustomFieldsFeature
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
                    NavigationLink(
                        state: SettingListReducer.Path.State.correspondentList(CorrespondentListReducer.State(server: store.server))
                    ) {
                        Label(.correspondents, systemImage: "person")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.customFieldList(CustomFieldListReducer.State(server: store.server))
                    ) {
                        Label(.customFields, systemImage: "list.bullet.rectangle")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.documentTypeList(DocumentTypeListReducer.State(server: store.server))
                    ) {
                        Label(.documentTypes, systemImage: "document.badge.gearshape")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.pdfPasswordList(PdfPasswordListReducer.State())
                    ) {
                        Label(.pdfPasswords, systemImage: "key")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.savedViewList(SavedViewListReducer.State(server: store.server))
                    ) {
                        Label(.savedViews, systemImage: "line.3.horizontal.decrease")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.storagePathList(StoragePathListReducer.State(server: store.server))
                    ) {
                        Label(.storagePaths, systemImage: "folder")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

                    NavigationLink(
                        state: SettingListReducer.Path.State.tagList(TagListReducer.State(server: store.server))
                    ) {
                        Label(.tags, systemImage: "tag")
                    }
                    .listRowBackground(Color.m3SurfaceContainer)

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
            case let .trashList(store):
                TrashListView(store: store)
            case let .tagList(store):
                TagListView(store: store)
            case let .tipList(store):
                TipListView(store: store)
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
