@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(.dependencies())
struct ProviderLoadingTests {

    @Test
    func test_changingTheUrl_asksTheServerWhatItOffers() async {
        let clock = TestClock()
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.continuousClock = clock
            $0.oidcClient.providers = { _ in [.testValue()] }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.binding(.set(\.input.url, URL(string: "http://paperless.example.com")!)))
        await clock.advance(by: .milliseconds(600))

        await store.receive(\.loadProviders)
        await store.receive(\.providersLoaded) {
            $0.providers = [.testValue()]
        }
    }

    @Test
    func test_providersLoaded_logsTheCountOnce() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([.testValue(), .testValue(id: "other")]))

        #expect(messages.value == ["OIDC discovery: 2 providers"])
    }

    @Test
    func test_providersLoaded_logsNoneOnTheFirstEmptyResult() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([]))

        #expect(messages.value == ["OIDC discovery: none"])
    }

    // Typing an address passes through several settled prefixes, each of which fails discovery the
    // same way. One line is the answer; six is noise that pushes real evidence out of the file.
    @Test
    func test_providersLoaded_doesNotRepeatAnUnchangedOutcome() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([]))
        await store.send(.providersLoaded([]))
        await store.send(.providersLoaded([]))

        #expect(messages.value == ["OIDC discovery: none"])
    }

    @Test
    func test_providersLoaded_logsAgainWhenTheOutcomeChanges() async {
        let messages = LockIsolated<[String]>([])
        let store = TestStore(initialState: ServerFormReducer.State.testValue()) {
            ServerFormReducer()
        } withDependencies: {
            $0.log.record = { message, _, _ in
                messages.withValue { $0.append(message) }
            }
        }
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.providersLoaded([]))
        await store.send(.providersLoaded([.testValue()]))

        #expect(messages.value == ["OIDC discovery: none", "OIDC discovery: 1 provider"])
    }
}
