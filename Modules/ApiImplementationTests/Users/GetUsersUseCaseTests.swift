@testable import ApiImplementation

import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import SwiftSharing
import Testing

@Suite
struct GetUsersUseCaseTests {

    @Test
    func execute() async throws {
        #expect(cache == [])

        try await withDependencies {
            $0.usersRepository.getUsers = { input, _ in
                switch input.url?.absoluteString {
                case "http://page/2":
                    return .testValue(next: .testValue(string: "http://page/3"), results: [.testValue(id: 2)])
                case "http://page/3":
                    return .testValue(next: nil, results: [.testValue(id: 3)])
                default:
                    return .testValue(next: .testValue(string: "http://page/2"), results: [.testValue(id: 1)])
                }
            }
        } operation: {
            let useCase = GetUsersUseCase.liveValue

            let users = try await useCase.execute(
                server: .testValue()
            )

            #expect(users == [
                .testValue(id: 1),
                .testValue(id: 2),
                .testValue(id: 3)
            ])
        }

        #expect(cache == [
            .testValue(id: 1),
            .testValue(id: 2),
            .testValue(id: 3)
        ])
    }

    @Shared(.users(.testValue()))
    private var cache: IdentifiedArrayOf<User> = []
}
