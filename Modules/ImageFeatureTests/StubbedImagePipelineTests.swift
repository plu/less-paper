@testable import ImageFeature

import ApiInterface
import Dependencies
import Foundation
import Nuke
import Testing
import TestSupport

@Suite(
    .testDependencies {
        $0.apiSessionDelegate = ApiSessionDelegate()
    }
)
struct StubbedImagePipelineTests {

    @Test
    func servesBytesForKnownURLs() async {
        let loader = dataLoader { url in
            url.absoluteString.contains("known") ? Data("bytes".utf8) : nil
        }

        let (data, error) = await load(with: loader)

        #expect(error == nil)
        #expect(data == Data("bytes".utf8))
    }

    @Test
    func reportsUnknownURLsAsMissingFiles() async {
        let loader = dataLoader { _ in nil }

        let (data, error) = await load(with: loader)

        #expect(data.isEmpty)
        #expect((error as? URLError)?.code == .fileDoesNotExist)
    }

    private func dataLoader(data: @escaping @Sendable (URL) -> Data?) -> any Nuke.DataLoading {
        withDependencies {
            $0.useStubbedImagePipeline(data: data)
        } operation: {
            @Dependency(\.imagePipeline) var provider
            return provider.build(.testValue()).configuration.dataLoader
        }
    }

    private func load(with loader: any Nuke.DataLoading) async -> (Data, Error?) {
        await withCheckedContinuation { continuation in
            let state = LoadState()
            _ = loader.loadData(
                with: URLRequest(url: URL(string: "https://paperless.example.com/api/documents/known/thumb/")!),
                didReceiveData: { data, _ in state.append(data) },
                completion: { error in continuation.resume(returning: (state.data, error)) }
            )
        }
    }
}

private final class LoadState: @unchecked Sendable {

    var data: Data {
        lock.withLock { _data }
    }

    func append(_ data: Data) {
        lock.withLock { _data.append(data) }
    }

    private let lock = NSLock()

    private var _data = Data()
}
