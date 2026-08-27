@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import Logging
import Testing

@Suite
struct LoggingJSONDecoderTests {

    private struct Document: Decodable {
        let id: Int
        let title: String
    }

    // The reported gap: a 200 carrying JSON the app cannot read produced no log line at all, because
    // decoding happens after validateResponse and throws where the delegate never sees it.
    @Test
    func test_decode_logsAMalformedBody() throws {
        let recorded = LockIsolated<[String]>([])

        withDependencies {
            $0.log.record = { message, _, _ in recorded.withValue { $0.append(message) } }
            $0.timeZone = TimeZone(identifier: "UTC")!
        } operation: {
            let decoder = LoggingJSONDecoder(path: "/api/documents/")
            decoder.configureForApi()
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(Document.self, from: Data(#"{"id": "not a number"}"#.utf8))
            }
        }

        let message = try #require(recorded.value.first)
        #expect(message.contains("/api/documents/"))
        #expect(message.contains("Document"))
    }

    @Test
    func test_decode_namesTheMissingKey() throws {
        let recorded = LockIsolated<[String]>([])

        withDependencies {
            $0.log.record = { message, _, _ in recorded.withValue { $0.append(message) } }
            $0.timeZone = TimeZone(identifier: "UTC")!
        } operation: {
            let decoder = LoggingJSONDecoder(path: "/api/documents/")
            decoder.configureForApi()
            #expect(throws: (any Error).self) {
                _ = try decoder.decode(Document.self, from: Data(#"{"id": 1}"#.utf8))
            }
        }

        // "The data couldn't be read because it isn't in the correct format" is true of every
        // decoding error and useful for none, so the message has to name the key.
        #expect(try #require(recorded.value.first).contains("title"))
    }

    @Test
    func test_decode_recordsNothingWhenTheBodyIsFine() throws {
        let recorded = LockIsolated<[String]>([])

        let document: Document = try withDependencies {
            $0.log.record = { message, _, _ in recorded.withValue { $0.append(message) } }
            $0.timeZone = TimeZone(identifier: "UTC")!
        } operation: {
            let decoder = LoggingJSONDecoder(path: "/api/documents/")
            decoder.configureForApi()
            return try decoder.decode(Document.self, from: Data(#"{"id": 1, "title": "Puky"}"#.utf8))
        }

        #expect(document.title == "Puky")
        #expect(recorded.value.isEmpty)
    }
}
