@testable import ApiInterface

import Foundation
import Testing

@Suite
struct ApiSessionDelegateRedirectTests {

    // A proxy sends the user to its portal on a different name. That is the bounce we must catch.
    @Test
    func foreignHostRedirect_isRefused() async {
        let delegate = ApiSessionDelegate()
        let original = URLRequest(url: URL(string: "https://paperless.example.com/api/documents/")!)
        let task = URLSession.shared.dataTask(with: original)
        let response = HTTPURLResponse(
            url: original.url!,
            statusCode: 302,
            httpVersion: nil,
            headerFields: ["Location": "https://auth.example.com/login"]
        )!
        let newRequest = URLRequest(url: URL(string: "https://auth.example.com/login")!)

        let handed = await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: newRequest,
                completionHandler: { request in continuation.resume(returning: request) }
            )
        }

        #expect(handed == nil)
    }

    // http → https on the same host is paperless behaving legitimately - a proxy terminating TLS
    // answers with an https URL for an http request all the time. Follow it.
    @Test
    func sameHostSchemeUpgrade_isFollowed() async {
        let delegate = ApiSessionDelegate()
        let original = URLRequest(url: URL(string: "http://paperless.example.com/api/documents/")!)
        let task = URLSession.shared.dataTask(with: original)
        let response = HTTPURLResponse(
            url: original.url!,
            statusCode: 301,
            httpVersion: nil,
            headerFields: ["Location": "https://paperless.example.com/api/documents/"]
        )!
        let newRequest = URLRequest(url: URL(string: "https://paperless.example.com/api/documents/")!)

        let handed = await withCheckedContinuation { continuation in
            delegate.urlSession(
                URLSession.shared,
                task: task,
                willPerformHTTPRedirection: response,
                newRequest: newRequest,
                completionHandler: { request in continuation.resume(returning: request) }
            )
        }

        #expect(handed?.url == newRequest.url)
    }
}
