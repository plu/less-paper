@testable import DocumentsFeature

import ApiInterface
import Components
import ComposableArchitecture
import Foundation
import Testing
import TestSupport

@MainActor
@Suite(
    .testDependencies()
)
struct DocumentShareLinksReducerTests {

    @Test
    func test_onAppear_loadsLinks() async throws {
        let links = [ShareLink.testValue()]
        let store = TestStore(initialState: DocumentShareLinksReducer.State.testValue()) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.getShareLinks.execute = { _, _ in links }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.linksResult) {
            $0.isLoading = false
            $0.links = IdentifiedArray(uniqueElements: links)
        }
    }

    @Test
    func test_onAppear_alreadyLoaded_doesNotRefetch() async throws {
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(links: [])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.getShareLinks.execute = { _, _ in
                Issue.record("Links must load once per sheet.")
                return []
            }
        }

        await store.send(.view(.onAppear))
    }

    @Test
    func test_onAppear_failure_setsLoadError() async throws {
        let links = [ShareLink.testValue()]
        let attempts = LockIsolated(0)
        let store = TestStore(initialState: DocumentShareLinksReducer.State.testValue()) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.getShareLinks.execute = { _, _ in
                let attempt = attempts.withValue {
                    $0 += 1
                    return $0
                }
                if attempt == 1 {
                    throw TestError.someError
                }
                return links
            }
            $0.toastPresenter.present = { _ in }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.linksResult) {
            $0.isLoading = false
            $0.loadError = TestError.someError.localizedDescription
        }
        #expect(store.state.links == nil)

        await store.send(.view(.retryButtonTapped)) {
            $0.isLoading = true
            $0.loadError = nil
        }
        await store.receive(\.linksResult) {
            $0.isLoading = false
            $0.links = IdentifiedArray(uniqueElements: links)
        }
    }

    @Test
    func test_create_sevenDaysArchive_sendsInput() async throws {
        @Dependency(\.date.now)
        var now

        let existing = ShareLink.testValue(id: 1, slug: "old")
        let created = ShareLink.testValue(id: 2, slug: "new")
        let input = LockIsolated<CreateShareLinkInput?>(nil)
        let state = DocumentShareLinksReducer.State.testValue(
            documentId: 7,
            links: [existing]
        )
        let store = TestStore(initialState: state) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.createShareLink.execute = { value, _ in
                input.setValue(value)
                return created
            }
        }

        await store.send(.view(.createButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.createResult) {
            $0.isCreating = false
            $0.links = [created, existing]
            $0.shareItem = ShareItem(url: created.url(server: .testValue())!)
        }

        let expected = Calendar(identifier: .gregorian).date(byAdding: .day, value: 7, to: now)
        #expect(
            input.value == CreateShareLinkInput(
                document: 7,
                expiration: expected,
                fileVersion: .archive
            )
        )
        #expect(store.state.expiry == .sevenDays)
        #expect(store.state.shareArchiveVersion)
    }

    @Test
    func test_create_never_sendsNil() async throws {
        let input = LockIsolated<CreateShareLinkInput?>(nil)
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(expiry: .never, links: [])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.createShareLink.execute = { value, _ in
                input.setValue(value)
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.createButtonTapped))
        await store.receive(\.createResult)

        #expect(input.value?.expiration == nil)
        #expect(input.value != nil)
    }

    @Test
    func test_create_noArchive_sendsOriginal() async throws {
        let input = LockIsolated<CreateShareLinkInput?>(nil)
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(
                hasArchiveVersion: false,
                links: [],
                shareArchiveVersion: true
            )
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.createShareLink.execute = { value, _ in
                input.setValue(value)
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.createButtonTapped))
        await store.receive(\.createResult)

        #expect(input.value?.fileVersion == .original)
    }

    @Test
    func test_create_archiveToggledOff_sendsOriginal() async throws {
        let input = LockIsolated<CreateShareLinkInput?>(nil)
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(
                links: [],
                shareArchiveVersion: false
            )
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.createShareLink.execute = { value, _ in
                input.setValue(value)
                return .testValue()
            }
        }
        store.exhaustivity = .off

        await store.send(.view(.createButtonTapped))
        await store.receive(\.createResult)

        #expect(input.value?.fileVersion == .original)
    }

    @Test
    func test_create_whileCreating_isIgnored() async throws {
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(isCreating: true)
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.createShareLink.execute = { _, _ in
                Issue.record("A second tap must not post a second link.")
                return .testValue()
            }
        }

        await store.send(.view(.createButtonTapped))
    }

    @Test
    func test_create_failure_toasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let existing = ShareLink.testValue()
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(links: [existing])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.createShareLink.execute = { _, _ in throw TestError.someError }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.createButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.createResult) {
            $0.isCreating = false
        }
        await store.finish()
        #expect(toasts.value == [.error(TestError.someError.localizedDescription)])
        #expect(store.state.links == [existing])
        #expect(store.state.shareItem == nil)
    }

    @Test
    func test_delete_cancelled_keepsLink() async throws {
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(links: [.testValue()])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in false }
            $0.deleteShareLink.execute = { _, _ in
                Issue.record("A cancelled confirmation must not delete.")
            }
        }

        await store.send(.view(.deleteButtonTapped(1)))
    }

    @Test
    func test_delete_confirmed_removesLink() async throws {
        let link = ShareLink.testValue(id: 1, slug: "aB3x9Q")
        let other = ShareLink.testValue(id: 2, slug: "other")
        let names = LockIsolated<[String]>([])
        let deleted = LockIsolated<[ShareLink.Id]>([])
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(links: [link, other])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, name in
                names.withValue { $0.append(name) }
                return true
            }
            $0.deleteShareLink.execute = { id, _ in
                deleted.withValue { $0.append(id) }
            }
        }

        await store.send(.view(.deleteButtonTapped(1)))
        await store.receive(\.deleteConfirmed)
        await store.receive(\.deleteResult) {
            $0.links = [other]
        }
        #expect(names.value == ["aB3x9Q"])
        #expect(deleted.value == [1])
    }

    @Test
    func test_delete_failure_keepsLinkAndToasts() async throws {
        let toasts = LockIsolated<[Toast]>([])
        let link = ShareLink.testValue()
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(links: [link])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in true }
            $0.deleteShareLink.execute = { _, _ in throw TestError.someError }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.deleteButtonTapped(1)))
        await store.receive(\.deleteConfirmed)
        await store.receive(\.deleteResult)
        await store.finish()
        #expect(toasts.value == [.error(TestError.someError.localizedDescription)])
        #expect(store.state.links == [link])
    }

    @Test
    func test_delete_withoutPermission_isIgnored() async throws {
        let server = Server.testValue()

        @Shared(.permissions(server)) var permissions: [Permission]?
        @Shared(.currentUser(server)) var currentUser: User?
        $currentUser.withLock { $0 = .testValue(isSuperuser: false) }
        $permissions.withLock { $0 = [.addShareLink] }

        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(
                links: [.testValue()],
                server: server
            )
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.deleteConfirmation.present = { _, _ in
                Issue.record("Without the permission the popup must not open.")
                return true
            }
        }

        #expect(!store.state.canDelete)
        await store.send(.view(.deleteButtonTapped(1)))
    }

    @Test
    func test_copy_writesPasteboardAndToastsSuccess() async throws {
        let link = ShareLink.testValue(slug: "aB3x9Q")
        let copied = LockIsolated<[String]>([])
        let toasts = LockIsolated<[Toast]>([])
        let store = TestStore(
            initialState: DocumentShareLinksReducer.State.testValue(links: [link])
        ) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.pasteboard.copy = { value in
                copied.withValue { $0.append(value) }
            }
            $0.toastPresenter.present = { value in
                toasts.withValue { $0.append(value) }
            }
        }

        await store.send(.view(.copyButtonTapped(1)))
        await store.finish()

        #expect(copied.value == [link.url(server: .testValue())!.absoluteString])
        #expect(toasts.value.count == 1)
        guard case .success = toasts.value.first else {
            Issue.record("The copy confirmation is a success toast.")
            return
        }
    }

    @Test
    func test_onAppear_linksUnloaded_whenListRefused_formStillCreates() async throws {
        let created = ShareLink.testValue(id: 5)
        let store = TestStore(initialState: DocumentShareLinksReducer.State.testValue()) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.getShareLinks.execute = { _, _ in throw TestError.someError }
            $0.createShareLink.execute = { _, _ in created }
            $0.toastPresenter.present = { _ in }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.receive(\.linksResult) {
            $0.isLoading = false
            $0.loadError = TestError.someError.localizedDescription
        }
        await store.send(.view(.createButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.createResult) {
            $0.isCreating = false
            $0.links = [created]
            $0.shareItem = ShareItem(url: created.url(server: .testValue())!)
        }
    }

    @Test
    func test_create_whileLoadInFlight_keepsCreatedLink() async throws {
        let created = ShareLink.testValue(id: 2, slug: "new")
        let loaded = ShareLink.testValue(id: 1, slug: "old")
        let gate = AsyncStream<Void>.makeStream()
        let store = TestStore(initialState: DocumentShareLinksReducer.State.testValue()) {
            DocumentShareLinksReducer()
        } withDependencies: {
            $0.getShareLinks.execute = { _, _ in
                for await _ in gate.stream {
                    break
                }
                return [loaded]
            }
            $0.createShareLink.execute = { _, _ in created }
        }

        await store.send(.view(.onAppear)) {
            $0.isLoading = true
        }
        await store.send(.view(.createButtonTapped)) {
            $0.isCreating = true
        }
        await store.receive(\.createResult) {
            $0.isCreating = false
            $0.links = [created]
            $0.shareItem = ShareItem(url: created.url(server: .testValue())!)
        }

        gate.continuation.yield()
        await store.receive(\.linksResult) {
            $0.isLoading = false
            $0.links = [created, loaded]
        }
    }

    @Test
    func test_closeButtonTapped_sendsDelegateClose() async throws {
        let store = TestStore(initialState: DocumentShareLinksReducer.State.testValue()) {
            DocumentShareLinksReducer()
        }

        await store.send(.view(.closeButtonTapped))
        await store.receive(\.delegate.close)
    }
}
