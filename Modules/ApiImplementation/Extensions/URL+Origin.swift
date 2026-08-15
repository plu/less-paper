import Foundation

extension URL {

    // Keeps path, query and fragment, replacing only scheme, host and port. A nil port is
    // deliberate rather than skipped: it drops an internal :8000 the proxy would not expose.
    func movedToOrigin(of origin: URL) -> URL {
        guard var components = URLComponents(url: self, resolvingAgainstBaseURL: false),
              let originComponents = URLComponents(url: origin, resolvingAgainstBaseURL: false),
              originComponents.host != nil
        else {
            return self
        }

        components.scheme = originComponents.scheme
        components.host = originComponents.host
        components.port = originComponents.port

        return components.url ?? self
    }
}
