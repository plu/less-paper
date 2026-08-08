import ApiInterface
import IdentifiedCollections

struct PermissionsFormOptions: Equatable, Sendable {

    var groups: IdentifiedArrayOf<Group> = []

    var users: IdentifiedArrayOf<User> = []
}
