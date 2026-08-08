import Foundation

extension NSItemProvider {

    @objc
    func getURL(identifier: String = "com.adobe.pdf") async throws -> URL? {
        guard hasItemConformingToTypeIdentifier(identifier) else {
            return nil
        }

        return try await loadItem(forTypeIdentifier: identifier) as? URL
    }
}
