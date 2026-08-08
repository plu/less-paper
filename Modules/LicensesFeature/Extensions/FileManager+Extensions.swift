import Foundation

extension FileManager {

    static func allLicenses() -> [URL] {
        guard let directory = Bundle(for: BundleFinder.self).resourceURL else {
            return []
        }
        return (
            try? FileManager.default
                .contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "md" }
                .sorted { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
        ) ?? []
    }
}

private final class BundleFinder {}
