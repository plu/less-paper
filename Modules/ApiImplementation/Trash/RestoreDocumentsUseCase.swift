import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing

extension RestoreDocumentsUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: { ids, server in
            @Dependency(\.trashRepository)
            var trashRepository

            @Dependency(\.updateCache.execute)
            var updateCache

            try await trashRepository.restoreDocuments(ids, server)

            // A restored document belongs back in the lists, and nothing else would put it there:
            // the document cache is only refilled by fetching.
            try await updateCache(server)
        }
    )
}
