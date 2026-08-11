import ComposableArchitecture
import SwiftUI

@ViewAction(for: DocumentImportReducer.self)
struct DocumentImportViewModifier: ViewModifier {
    @Bindable var store: StoreOf<DocumentImportReducer>

    func body(content: Content) -> some View {
        content
            .fileImporter(
                isPresented: $store.isPresentingFileImporter,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: true,
                onCompletion: {
                    send(.fileImporterResult($0))
                }
            )
            .fullScreenCover(
                isPresented: $store.isPresentingDocumentScanner
            ) {
                DocumentScannerView {
                    send(.fileImporterResult($0))
                }
                .ignoresSafeArea(.all)
            }
            .sheet(
                item: $store.scope(state: \.destination?.shareExtension, action: \.destination.shareExtension)
            ) { store in
                ShareExtensionView(store: store)
                    .presentationDetents([.large])
            }
    }
}

public extension View {

    func documentImport(
        store: StoreOf<DocumentImportReducer>
    ) -> some View {
        modifier(DocumentImportViewModifier(store: store))
    }
}
