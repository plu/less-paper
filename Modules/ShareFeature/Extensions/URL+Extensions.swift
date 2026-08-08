import Foundation

extension URL {

    var documentTitle: String {
        let name = lastPathComponent.removingPercentEncoding ?? lastPathComponent
        return name.replacingOccurrences(of: ".pdf", with: "", options: .caseInsensitive)
    }

    static func testPDF(named name: String) -> URL {
        URL.projectRoot
            .appendingPathComponent("docker")
            .appendingPathComponent("data")
            .appendingPathComponent(name)
    }

    func temporaryCopy(fileManager: FileManager = .default) throws -> URL {
        let temporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryFile = temporaryDirectory.appendingPathComponent(lastPathComponent)
        if fileManager.fileExists(atPath: temporaryFile.path) {
            try fileManager.removeItem(at: temporaryFile)
        }
        try fileManager.copyItem(at: self, to: temporaryFile)
        return temporaryFile
    }
}
