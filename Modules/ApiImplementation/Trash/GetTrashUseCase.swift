import ApiInterface
import Dependencies
import Foundation

extension GetTrashUseCase: @retroactive DependencyKey {

    public static let liveValue = Self(
        execute: { server in
            @Dependency(\.trashRepository)
            var trashRepository

            return try await trashRepository.getTrash(server)
        }
    )
}
