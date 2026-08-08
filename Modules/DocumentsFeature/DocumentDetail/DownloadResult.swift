import Foundation

public enum DownloadResult: Equatable {
    case failure(String)
    case success(data: Data, url: URL)
}

public extension DownloadResult {
    var value: (data: Data, url: URL)? {
        switch self {
        case .failure:
            nil
        case let .success(data, url):
            (data: data, url: url)
        }
    }
}

public extension DownloadResult {
    static func testValue() -> Self {
        do {
            return try .success(data: .testValue(), url: .testValue())
        } catch {
            return .failure(error.localizedDescription)
        }
    }
}
