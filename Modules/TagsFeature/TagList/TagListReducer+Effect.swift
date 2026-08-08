import ApiInterface
import ComposableArchitecture

extension Effect where Action == TagListReducer.Action {

    static func runDeleteTag(
        id: Tag.Id,
        server: Server
    ) -> Self {
        @Dependency(\.deleteTag.execute)
        var deleteTag

        return .run { send in
            await send(.isUpdating(id: id, isUpdating: true))
            try await deleteTag(id, server)
            await send(.tagDeleted(id), animation: .default)
        } catch: { error, send in
            await send(.error(error))
            await send(.isUpdating(id: id, isUpdating: false))
        }
        .cancellable(id: CancelID.deleteTag)
    }

    static func runGetTags(server: Server) -> Self {
        @Dependency(\.getTags.execute)
        var getTags

        return .run { send in
            try await send(.getTagsResult(getTags(server)), animation: .default)
            await send(.set(\.isLoaded, true))
        } catch: { error, send in
            await send(.error(error))
            await send(.set(\.isLoaded, true))
        }
        .cancellable(id: CancelID.getTags)
    }
}

private enum CancelID {
    case deleteTag
    case getTags
}
