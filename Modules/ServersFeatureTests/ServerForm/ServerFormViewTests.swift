@testable import ServersFeature

import ApiInterface
import ComposableArchitecture
import DesignTokens
import SwiftUI
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies(),
    .snapshots(record: .environment),
    .tags(.snapshotTests)
)
struct ServerFormViewTests {

    @Test
    func testSnapshot() async throws {
        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(url: .testValue(string: "http://localhost:8000"))
                        ),
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12))
        )

        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(url: .testValue(string: "http://localhost:8000"))
                        ),
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .environment(\.sizeCategory, .accessibilityLarge)
            .frame(width: 375)
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "accessibilityLarge"
        )

        var advancedState = ServerFormReducer.State.testValue(
            input: .testValue(
                headers: [
                    .testValue(id: "1", name: "Accept", value: "application/json; version=9"),
                    .testValue(id: "2", name: "X-Custom", value: "some-value")
                ],
                url: .testValue(string: "http://localhost:8000")
            )
        )
        advancedState.section = .advanced

        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: advancedState,
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "advanced"
        )
    }

    // What a server offering single sign-on looks like. The buttons only exist when the server says
    // so, so the reference with none of them is the one that proves the form is unchanged for every
    // server that does not.
    @Test
    func testSnapshot_withProviders() async throws {
        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(url: .testValue(string: "http://localhost:8000")),
                            providers: [
                                OIDCProvider.testValue(id: "authentik", name: "Authentik"),
                                OIDCProvider.testValue(clientId: "second", id: "keycloak", name: "Keycloak")
                            ]
                        ),
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "withProviders"
        )
    }

    // What editing a server stored without a password looks like: no credential fields, so
    // the alias and address are editable without anything to trade a token refresh with.
    @Test
    func testSnapshot_passwordlessEdit() async throws {
        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(
                                password: "",
                                url: .testValue(string: "http://localhost:8000"),
                                username: ""
                            ),
                            isPasswordlessEdit: true
                        ),
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "passwordlessEdit"
        )
    }

    @Test
    func testSnapshot_withProvidersAccessibilityLarge() async throws {
        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: .testValue(
                            input: .testValue(url: .testValue(string: "http://localhost:8000")),
                            providers: [OIDCProvider.testValue(id: "authentik", name: "Authentik")]
                        ),
                        reducer: {
                            ServerFormReducer()
                        }
                    )
                )
            }
            .environment(\.sizeCategory, .accessibilityLarge)
            .frame(width: 375)
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "withProvidersAccessibilityLarge"
        )
    }

    @Test
    func testSnapshot_withSelectedProvider() async throws {
        var selected = ServerFormReducer.State.testValue(
            input: .testValue(alias: "", password: "", url: .testValue(string: "http://localhost:8000"), username: ""),
            providers: [OIDCProvider.testValue(id: "authentik", name: "Authentik")]
        )
        selected.selectedProvider = OIDCProvider.testValue(id: "authentik", name: "Authentik")
        assertSnapshot(
            of: ScrollView {
                ServerFormView(
                    store: Store(
                        initialState: selected,
                        reducer: { ServerFormReducer() }
                    )
                )
            }
            .background(Color.m3Surface),
            as: .image(layout: .device(config: .iPhone12)),
            named: "withSelectedProvider"
        )
    }
}
