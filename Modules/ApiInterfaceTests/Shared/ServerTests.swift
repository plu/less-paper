@testable import ApiInterface

import CustomDump
import Foundation
import Testing

@Suite(
    .dependencies()
)
struct ServerTests {

    @Test
    func decode_withHeaders() async throws {
        let json = """
        {
          "alias": "dev",
          "headers": [
            {
              "id": "9E2B1B2E-2F0B-4C9E-8B0E-1B2E2F0B4C9E",
              "name": "Accept",
              "value": "application/json; version=10"
            }
          ],
          "id": "71A73DC6-74A7-4707-A6D9-873D3B2DE9C4",
          "username": "admin",
          "url": "\(URL.testValue().absoluteString)"
        }
        """

        let server = try JSONDecoder.apiDecoder.decode(Server.self, from: #require(json.data(using: .utf8)))

        expectNoDifference(server, .testValue(headers: [.testValue()]))
    }

    @Test
    func encode_decode_roundTrip() async throws {
        let server = Server.testValue(headers: [.testValue()])

        let data = try JSONEncoder.apiEncoder.encode(server)
        let decoded = try JSONDecoder.apiDecoder.decode(Server.self, from: data)

        expectNoDifference(decoded, server)
    }

    @Test
    func comparable_ordersCaseInsensitively() async throws {
        let apple = Server.testValue(alias: "apple", id: "1")
        let banana = Server.testValue(alias: "Banana", id: "2")

        #expect(apple < banana)
        #expect(!(banana < apple))
    }

    @Test
    func comparable_ordersNumerically() async throws {
        let second = Server.testValue(alias: "Server 2", id: "1")
        let tenth = Server.testValue(alias: "Server 10", id: "2")

        #expect(second < tenth)
        #expect(!(tenth < second))
    }
}
