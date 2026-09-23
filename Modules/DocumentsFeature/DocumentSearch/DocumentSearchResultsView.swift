import ApiInterface
import Components
import ComposableArchitecture
import DesignTokens
import SwiftUI

@ViewAction(for: DocumentSearchReducer.self)
struct DocumentSearchResultsView: View {

    var body: some View {
        // The three status branches take a clear row background and no separator: a spinner or a
        // one-line message is not a row anyone can tap, and a card behind it would read as an
        // empty result.
        //
        // Only a first search spins. A re-search keeps the previous results on screen rather than
        // emptying the list under the user while the next response is in flight.
        if store.isLoading, store.results == nil {
            statusRow {
                ProgressView()
            }
        } else if let error = store.error, store.results == nil {
            // Guarded on `results == nil` for the same reason the spinner is: the reducer leaves
            // `results` standing when a request fails, so an unguarded branch would replace
            // results the user is reading with an error line the moment a re-search failed.
            //
            // Inline rather than as a toast. A first search has nothing to fall back on, so a
            // failure that says nothing here looks exactly like not having searched.
            statusRow {
                Text(error)
                    .foregroundStyle(Color.m3OnSurfaceVariant)
            }
        } else if let results = store.results {
            if results.isEmpty, store.hasQuery, !store.isLoading {
                statusRow {
                    Text(.searchNoResults)
                        .foregroundStyle(Color.m3OnSurfaceVariant)
                }
            } else {
                // No client-side truncation: the server already caps each list through
                // PAPERLESS_GLOBAL_SEARCH_MAX_RESULTS, and a second cap here would hide results
                // the server chose to send.
                resultCard(.searchSectionDocuments, results.documents) {
                    send(.documentTapped($0))
                } row: { document in
                    DocumentSearchRowView(
                        caption: document.created.formatted(date: .numeric, time: .omitted),
                        systemImage: "document",
                        title: document.title
                    )
                }
                resultCard(.searchSectionSavedViews, results.savedViews) {
                    send(.savedViewTapped($0))
                } row: { savedView in
                    DocumentSearchRowView(
                        systemImage: "line.3.horizontal.decrease",
                        title: savedView.name
                    )
                }
                resultCard(.searchSectionTags, results.tags) {
                    send(.tagTapped($0))
                } row: { tag in
                    DocumentSearchRowView(systemImage: "tag", tag: tag)
                }
                resultCard(.searchSectionCorrespondents, results.correspondents) {
                    send(.correspondentTapped($0))
                } row: { correspondent in
                    DocumentSearchRowView(systemImage: "person", title: correspondent.name)
                }
                resultCard(.searchSectionDocumentTypes, results.documentTypes) {
                    send(.documentTypeTapped($0))
                } row: { documentType in
                    DocumentSearchRowView(
                        systemImage: "document.badge.gearshape",
                        title: documentType.name
                    )
                }
                resultCard(.searchSectionStoragePaths, results.storagePaths) {
                    send(.storagePathTapped($0))
                } row: { storagePath in
                    DocumentSearchRowView(systemImage: "folder", title: storagePath.name)
                }
                resultCard(.searchSectionCustomFields, results.customFields) {
                    send(.customFieldTapped($0))
                } row: { customField in
                    DocumentSearchRowView(
                        systemImage: "list.bullet.rectangle",
                        title: customField.name
                    )
                }
            }
        }
    }

    init(store: StoreOf<DocumentSearchReducer>) {
        self.store = store
    }

    let store: StoreOf<DocumentSearchReducer>

    // The inset-grouped chrome the settings lists get from the platform, drawn by hand.
    //
    // It cannot be had the usual way. The documents list is `.listStyle(.plain)` because its rows
    // are full-bleed cards, and `listStyle` takes a concrete type — so switching it for search
    // mode means branching into two `List`s, which changes the view's identity and tears the
    // search field down mid-keystroke. That was measured, not assumed: with the branch in place,
    // clearing the field with its own `X` dropped the keyboard, which is exactly what the `X` is
    // supposed not to do. So the card is built inside the plain list instead: one list row per
    // group, its separators and background suppressed, holding a header and a rounded container
    // of rows with its own dividers.
    //
    // Empty groups draw nothing at all. A typical query matches one or two types, and a `Section`
    // renders its header even when the `ForEach` inside it produces no rows —
    // `testSnapshot_partiallyPopulated` is the regression test for the five captions that left
    // standing over blank background.
    @ViewBuilder
    private func resultCard<Item: Identifiable, Row: View>(
        _ title: LocalizedStringResource,
        _ items: [Item],
        tapped: @escaping (Item) -> Void,
        @ViewBuilder row: @escaping (Item) -> Row
    ) -> some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: .x3) {
                Text(title)
                    .font(.footnote)
                    .foregroundStyle(Color.m3OnSurfaceVariant)
                    .padding(.leading, .x3 + .x2)
                VStack(spacing: .x0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        Button {
                            tapped(item)
                        } label: {
                            row(item)
                                .padding(.horizontal, .x3 + .x2)
                                .padding(.vertical, .x3 + .x1)
                        }
                        .buttonStyle(.plain)
                        if index < items.count - 1 {
                            Divider()
                                .padding(.leading, .x5 + .x2)
                                .padding(.trailing, .x3)
                        }
                    }
                }
                .background(Color.m3SurfaceContainer)
                .clipShape(RoundedRectangle(cornerRadius: .x3 + .x1, style: .continuous))
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            .padding(.bottom, .x4)
            .padding(.horizontal, .x4 + .x2)
        }
    }

    @ViewBuilder
    private func statusRow(@ViewBuilder content: () -> some View) -> some View {
        HStack {
            Spacer()
            content()
            Spacer()
        }
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .padding(.top, .x4)
    }
}
