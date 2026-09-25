import ApiInterface
import Dependencies
import DependenciesMacros
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RemoveOfflineDocumentUseCase: @retroactive DependencyKey {
    public static let liveValue = Self(execute: execute(id:server:))
}

private extension RemoveOfflineDocumentUseCase {

    static func execute(id: Document.Id, server: Server) async throws {
        @Dependency(\.offlineStore) var store

        @Shared(.offlineDocuments(server)) var offlineDocuments: IdentifiedArrayOf<OfflineDocument> = []

        // The record goes first. Deleting the file first leaves a window in which a refresh's
        // save, already past its download, still sees the record, writes it, and strands the PDF
        // it wrote when this remove drops the record a moment later. Dropping the record first
        // means that save fails its own membership check and cleans up after itself instead.
        _ = $offlineDocuments.withLock { $0.remove(id: id) }

        try await store.deletePDF(id, server)
    }
}
