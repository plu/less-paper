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
struct ImageLoaderTests {

    @Test
    func loadData_sendsTokenAndHeadersToTheServersHost() async throws {
        let server = Server.testValue(headers: [
            .testValue(id: "1", name: "X-Custom", value: "custom-value")
        ])
        let url = server.url.appending(path: "/api/documents/1/thumb/")
        let loader = ImageLoader(
            dataLoader: DataLoader(configuration: .ephemeralWithStub),
            server: server
        )

        let body = await withDependencies {
            $0.authenticationProvider.getToken = { _ in "the-token" }
        } operation: {
            await loadBody(with: loader, url: url)
        }

        #expect(body == Data("thumbnail".utf8))

        let request = try await request(to: url)
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Token the-token")
        #expect(request.value(forHTTPHeaderField: "X-Custom") == "custom-value")
    }

    // Remote-user mode stores no token: the forward-auth cookie authenticates the request, and a
    // bare `Token ` header would be rejected. Same rule ApiClientDelegate applies to every other
    // API call.
    @Test
    func loadData_omitsAuthorizationWithoutAToken() async throws {
        let server = Server.testValue()
        let url = server.url.appending(path: "/api/documents/2/thumb/")
        let loader = ImageLoader(
            dataLoader: DataLoader(configuration: .ephemeralWithStub),
            server: server
        )

        await withDependencies {
            $0.authenticationProvider.getToken = { _ in nil }
        } operation: {
            _ = await loadBody(with: loader, url: url)
        }

        let request = try await request(to: url)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
    }

    @Test
    func loadData_sendsNeitherHeadersNorTokenToAnotherHost() async throws {
        let server = Server.testValue(headers: [
            .testValue(id: "1", name: "X-Custom", value: "custom-value")
        ])
        let url = URL(string: "https://other.example.com/api/documents/3/thumb/")!
        let loader = ImageLoader(
            dataLoader: DataLoader(configuration: .ephemeralWithStub),
            server: server
        )

        await withDependencies {
            $0.authenticationProvider.getToken = { _ in "the-token" }
        } operation: {
            _ = await loadBody(with: loader, url: url)
        }

        let request = try await request(to: url)
        #expect(request.value(forHTTPHeaderField: "Authorization") == nil)
        #expect(request.value(forHTTPHeaderField: "X-Custom") == nil)
    }

    @Test
    func loadData_cancellingStopsTheRequest() async throws {
        let server = Server.testValue()
        let url = server.url.appending(path: "/api/documents/4/thumb/")
        let loader = ImageLoader(
            dataLoader: DataLoader(configuration: .ephemeralWithStub),
            server: server
        )

        await withDependencies {
            $0.authenticationProvider.getToken = { _ in "the-token" }
        } operation: {
            let cancellable = loader.loadData(
                with: URLRequest(url: url),
                didReceiveData: { _, _ in },
                completion: { _ in }
            )

            #expect(cancellable is AnyCancellable)
            cancellable.cancel()

            // Cancelling parks the Task; the handler that releases the inner request runs when
            // the Task observes it, which is a turn later rather than inside cancel().
            try? await Task.sleep(for: .milliseconds(200))
        }
    }

    private func loadBody(with loader: ImageLoader, url: URL) async -> Data {
        await withCheckedContinuation { continuation in
            let finished = FinishedFlag()
            _ = loader.loadData(
                with: URLRequest(url: url),
                didReceiveData: { data, _ in
                    if finished.take() {
                        continuation.resume(returning: data)
                    }
                },
                completion: { _ in }
            )
        }
    }

    private func request(to url: URL) async throws -> URLRequest {
        for _ in 0 ..< 100 {
            if let recorded = ImageStubProtocol.recorded.first(where: { $0.url == url }) {
                return recorded
            }
            await Task.yield()
        }

        throw AwaitTimedOut()
    }

    private struct AwaitTimedOut: Error {}
}

private extension URLSessionConfiguration {

    static var ephemeralWithStub: URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [ImageStubProtocol.self]
        return configuration
    }
}

// Answers true once: the stub delivers its nine bytes in a single call, but resuming a
// continuation twice traps, so the guard is what makes the helper safe rather than lucky.
private final class FinishedFlag: @unchecked Sendable {

    func take() -> Bool {
        lock.withLock {
            guard !taken else {
                return false
            }
            taken = true
            return true
        }
    }

    private let lock = NSLock()

    private var taken = false
}

/// Answers every request with nine bytes of thumbnail instead of the network, recording what was
/// asked so the header tests can read it back. Filtered by URL at the call site: every test asks
/// for its own document id, so parallel tests cannot mistake each other's requests.
private class ImageStubProtocol: URLProtocol, @unchecked Sendable {

    static var recorded: [URLRequest] {
        lock.withLock { _recorded }
    }

    override class func canInit(with _: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }

        Self.lock.withLock { Self._recorded.append(request) }

        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: [:])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("thumbnail".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    private static let lock = NSLock()

    private nonisolated(unsafe) static var _recorded: [URLRequest] = []
}
