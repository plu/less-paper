import Foundation

// A path addresses a node in the tree by the child index taken at each level: `[]` is the root,
// `[1, 0]` is the first child of the root's second child. A negation has exactly one child, so the
// only index it accepts is 0.
public extension CustomFieldQuery {

    typealias Path = [Int]

    subscript(path: Path) -> CustomFieldQuery? {
        get {
            guard let index = path.first else {
                return self
            }
            guard let child = children?[safe: index] else {
                return nil
            }
            return child[Array(path.dropFirst())]
        }
        set {
            guard let newValue else {
                remove(at: path)
                return
            }
            guard let index = path.first else {
                self = newValue
                return
            }
            guard var children, children.indices.contains(index) else {
                return
            }
            children[index][Array(path.dropFirst())] = newValue
            replaceChildren(with: children)
        }
    }

    var children: [CustomFieldQuery]? {
        switch self {
        case .atom:
            nil
        case let .group(_, children):
            children
        case let .negation(child):
            [child]
        }
    }

    mutating func append(_ query: CustomFieldQuery, to path: Path) {
        guard case let .group(logicalOperator, children) = self[path] else {
            return
        }
        self[path] = .group(logicalOperator, children + [query])
    }

    // Removing the root leaves nothing to address, so it is a no-op; a caller that wants an empty
    // builder sets its query to nil instead. Removing a negation's only child removes the
    // negation too, since `["NOT"]` with no child is not a query.
    mutating func remove(at path: Path) {
        guard let index = path.last else {
            return
        }
        let parentPath = Path(path.dropLast())

        switch self[parentPath] {
        case let .group(logicalOperator, children):
            guard children.indices.contains(index) else {
                return
            }
            var remaining = children
            remaining.remove(at: index)
            self[parentPath] = .group(logicalOperator, remaining)
        case .negation:
            remove(at: parentPath)
        default:
            return
        }
    }

    private mutating func replaceChildren(with children: [CustomFieldQuery]) {
        switch self {
        case .atom:
            return
        case let .group(logicalOperator, _):
            self = .group(logicalOperator, children)
        case .negation:
            guard let child = children.first else {
                return
            }
            self = .negation(child)
        }
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
