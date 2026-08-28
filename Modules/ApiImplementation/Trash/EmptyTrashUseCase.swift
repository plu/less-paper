import ApiInterface
import Dependencies
import Foundation

extension EmptyTrashUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: { ids, server in
            @Dependency(\.trashRepository)
            var trashRepository

            // No cache to update: these documents were already gone from every list when they were
            // moved to the trash. This only makes it permanent.
            try await trashRepository.emptyTrash(ids, server)
        }
    )
}
