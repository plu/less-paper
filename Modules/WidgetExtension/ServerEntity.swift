import ApiInterface
import AppIntents
import SwiftSharing

struct ServerEntity: AppEntity {

    static let defaultQuery = ServerEntityQuery()

    // Not `.serverEntityTypeName`: the ExtractAppIntentsMetadata build step statically parses
    // `TypeDisplayRepresentation(name:)` and requires a literal or a direct `LocalizedStringResource`
    // initializer call, not a catalog-generated static member access.
    static var typeDisplayRepresentation: TypeDisplayRepresentation {
        TypeDisplayRepresentation(name: LocalizedStringResource("serverEntityTypeName"))
    }

    // The alias is what the picker shows, because it is what the user named the server. The id is
    // what is stored, because an alias can be renamed and a placed control must survive that.
    let alias: String

    let id: String

    let server: Server

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(alias)")
    }

    init(server: Server) {
        self.alias = server.alias
        self.id = server.id
        self.server = server
    }
}

struct ServerEntityQuery: EntityQuery {

    func entities(for identifiers: [ServerEntity.ID]) async throws -> [ServerEntity] {
        servers()
            .filter { identifiers.contains($0.id) }
            .map(ServerEntity.init)
    }

    func suggestedEntities() async throws -> [ServerEntity] {
        servers().map(ServerEntity.init)
    }

    private func servers() -> [Server] {
        @Shared(.servers)
        var servers

        return servers.elements.sorted()
    }
}
