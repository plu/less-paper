import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchResultsView: View {

    var body: some View {
        // Only a first search spins. A re-search keeps the previous results on screen rather than
        // emptying the list under the user while the next response is in flight.
        if store.isLoading, store.results == nil {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if let error = store.error, store.results == nil {
            // Guarded on `results == nil` for the same reason the spinner is: the reducer leaves
            // `results` standing when a request fails, so an unguarded branch would replace
            // results the user is reading with an error line the moment a re-search failed.
            //
            // Inline rather than as a toast. While the field has focus this overlay is all that
            // is on screen, and a first search has nothing to fall back on — so a failure that
            // says nothing here looks exactly like not having searched.
            Text(error)
                .foregroundStyle(Color.m3Outline)
        } else if let results = store.results {
            if results.isEmpty, store.hasQuery, !store.isLoading {
                Text(.searchNoResults)
                    .foregroundStyle(Color.m3Outline)
            } else {
                // Each section is guarded rather than left to empty out on its own. An empty
                // `ForEach` drops the rows but the `Section` still draws its header, and a typical
                // query matches one or two types — which left five captions standing over blank
                // background. `testSnapshot_partiallyPopulated` is the regression test.
                //
                // No client-side truncation, though: the server already caps each list through
                // PAPERLESS_GLOBAL_SEARCH_MAX_RESULTS, and a second cap here would hide results
                // the server chose to send.
                if !results.documents.isEmpty {
                    Section(String(localized: .searchSectionDocuments)) {
                        ForEach(results.documents) { document in
                            Button {
                                send(.documentTapped(document))
                            } label: {
                                DocumentSearchRowView(
                                    caption: document.created.formatted(date: .numeric, time: .omitted),
                                    systemImage: "document",
                                    title: document.title
                                )
                            }
                        }
                    }
                }
                if !results.savedViews.isEmpty {
                    Section(String(localized: .searchSectionSavedViews)) {
                        ForEach(results.savedViews) { savedView in
                            Button {
                                send(.savedViewTapped(savedView))
                            } label: {
                                DocumentSearchRowView(
                                    systemImage: "line.3.horizontal.decrease",
                                    title: savedView.name
                                )
                            }
                        }
                    }
                }
                if !results.tags.isEmpty {
                    Section(String(localized: .searchSectionTags)) {
                        ForEach(results.tags) { tag in
                            Button {
                                send(.tagTapped(tag))
                            } label: {
                                DocumentSearchRowView(systemImage: "tag", tag: tag)
                            }
                        }
                    }
                }
                if !results.correspondents.isEmpty {
                    Section(String(localized: .searchSectionCorrespondents)) {
                        ForEach(results.correspondents) { correspondent in
                            Button {
                                send(.correspondentTapped(correspondent))
                            } label: {
                                DocumentSearchRowView(systemImage: "person", title: correspondent.name)
                            }
                        }
                    }
                }
                if !results.documentTypes.isEmpty {
                    Section(String(localized: .searchSectionDocumentTypes)) {
                        ForEach(results.documentTypes) { documentType in
                            Button {
                                send(.documentTypeTapped(documentType))
                            } label: {
                                DocumentSearchRowView(
                                    systemImage: "document.badge.gearshape",
                                    title: documentType.name
                                )
                            }
                        }
                    }
                }
                if !results.storagePaths.isEmpty {
                    Section(String(localized: .searchSectionStoragePaths)) {
                        ForEach(results.storagePaths) { storagePath in
                            Button {
                                send(.storagePathTapped(storagePath))
                            } label: {
                                DocumentSearchRowView(systemImage: "folder", title: storagePath.name)
                            }
                        }
                    }
                }
                if !results.customFields.isEmpty {
                    Section(String(localized: .searchSectionCustomFields)) {
                        ForEach(results.customFields) { customField in
                            Button {
                                send(.customFieldTapped(customField))
                            } label: {
                                DocumentSearchRowView(
                                    systemImage: "list.bullet.rectangle",
                                    title: customField.name
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    init(store: StoreOf<DocumentSearchReducer>) {
        self.store = store
    }

    let store: StoreOf<DocumentSearchReducer>
}
