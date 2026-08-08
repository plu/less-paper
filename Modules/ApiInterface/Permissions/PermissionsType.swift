import Foundation

public enum PermissionsType: Codable, Equatable, Sendable {
    case correspondent(id: Correspondent.Id)
    case documentType(id: DocumentType.Id)
    case savedView(id: SavedView.Id)
    case storagePath(id: StoragePath.Id)
    case tag(id: Tag.Id)

    public var path: String {
        switch self {
        case let .correspondent(id: id):
            "/api/correspondents/\(id)/"
        case let .documentType(id: id):
            "/api/document_types/\(id)/"
        case let .savedView(id: id):
            "/api/saved_views/\(id)/"
        case let .storagePath(id: id):
            "/api/storage_paths/\(id)/"
        case let .tag(id: id):
            "/api/tags/\(id)/"
        }
    }
}

public extension Optional {

    func ifPresent<T>(_ action: (Wrapped) -> T) -> T? {
        guard let self else {
            return nil
        }

        return action(self)
    }
}
