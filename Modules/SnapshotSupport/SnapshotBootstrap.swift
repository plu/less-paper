#if DEBUG
import ApiInterface
import Dependencies
import Foundation
import IdentifiedCollections
import ImageFeature
import SwiftSharing

// Called from the app's initialiser, the same place prepareUITestDependencies is called from.
//
// Screenshot mode overrides the use cases rather than hand-building navigation state: the app then
// boots through its own bootstrap path, and every list, badge and picker fills the way it does
// against a real server. The one thing it cannot do is reach the network.
public func prepareSnapshotDependencies(
    _ configuration: SnapshotConfiguration
) {
    let server = Server.snapshot

    prepareDependencies {
        $0.applySnapshotConfiguration(configuration)
    }
    seedSnapshotSharedState(configuration, server: server)
}

public extension DependencyValues {

    mutating func applySnapshotConfiguration(
        _ configuration: SnapshotConfiguration
    ) {
        let corpus = configuration.corpus
        let documents = SnapshotFixtures.documents()
        let featured = corpus.documentIds.compactMap { id in documents.first { $0.id == id } }

        defaultAppStorage = .inMemory
        defaultFileStorage = .inMemory

        // The caches are seeded directly below, so the fan-out only has to succeed, not fetch.
        updateCache.execute = { _ in }

        // The inbox is not a flag on the request - DocumentFilter.inbox turns it into a tag rule -
        // so the inbox list is recognised by the tag it filters on.
        let inboxTag = SnapshotFixtures.tags(in: corpus).first(where: \.isInboxTag)?.id
        getDocuments.execute = { input, _ in
            let isInbox = input.filterRules.contains { rule in
                guard let inboxTag,
                      rule.ruleType == .hasTagsAny || rule.ruleType == .hasTagsAll
                else {
                    return false
                }
                return rule.value?.split(separator: ",").contains("\(inboxTag.rawValue)") == true
            }
            let results = isInbox
                ? corpus.inboxDocumentIds.compactMap { id in documents.first { $0.id == id } }
                : featured
            return GetDocumentsOutput(count: results.count, next: nil, results: results)
        }

        getDocument.execute = { id, _ in
            guard let document = documents.first(where: { $0.id == id }) else {
                throw SnapshotFixtureMissing()
            }
            return document
        }

        // The two featured documents have a real PDF in docker/data. Read from the repository
        // rather than bundled, for the same reason the fixtures are.
        downloadDocument.execute = { id, _ in
            guard let document = documents.first(where: { $0.id == id }),
                  let data = try? Data(contentsOf: URL.snapshotDocument(named: document.title))
            else {
                throw SnapshotFixtureMissing()
            }
            return data
        }

        // A favorite row renders page one of the file the store wrote, so the screenshot needs a
        // real PDF where that file would be. The same documents downloadDocument reads, addressed
        // the same way — nothing is written to disk, the row simply reads the repository copy.
        favoritesStore.pdfURL = { id, _ in
            guard let document = documents.first(where: { $0.id == id }) else {
                return URL(filePath: NSTemporaryDirectory())
            }
            return .snapshotDocument(named: document.title)
        }

        // Settings reports the space the favorites take. Summing the real files keeps that figure
        // honest rather than photographing a zero.
        favoritesStore.totalByteCount = { _ in
            corpus.favoriteDocumentIds
                .compactMap { id in documents.first { $0.id == id } }
                .reduce(0) { $0 + Int.snapshotDocumentByteCount(named: $1.title) }
        }

        getStatistics.execute = { _ in
            .testValue(
                documentsInbox: corpus.inboxDocumentIds.count,
                documentsTotal: featured.count,
                inboxTag: inboxTag?.rawValue,
                inboxTags: [inboxTag?.rawValue].compactMap(\.self)
            )
        }

        useStubbedImagePipeline(data: SnapshotThumbnails.data(for:))
    }
}

// The caches every list reads from. Seeding them is what UpdateCacheUseCase would otherwise do,
// and writing them here keeps the stubs above free of cache bookkeeping.
public func seedSnapshotSharedState(
    _ configuration: SnapshotConfiguration,
    server: Server = .snapshot
) {
    let corpus = configuration.corpus

    @Shared(.servers)
    var servers

    @Shared(.selectedServer)
    var selectedServer

    @Shared(.correspondents(server))
    var correspondents: IdentifiedArrayOf<Correspondent> = []

    @Shared(.documentTypes(server))
    var documentTypes: IdentifiedArrayOf<DocumentType> = []

    @Shared(.favorites(server))
    var favorites: IdentifiedArrayOf<FavoriteDocument> = []

    @Shared(.savedViews(server))
    var savedViews: IdentifiedArrayOf<SavedView> = []

    @Shared(.storagePaths(server))
    var storagePaths: IdentifiedArrayOf<StoragePath> = []

    @Shared(.tags(server))
    var tags: IdentifiedArrayOf<Tag> = []

    @Shared(.inboxDocumentCount(server))
    var inboxDocumentCount

    // DocumentFilter.inbox builds its tag rule from this, and the inbox empty state reports "No
    // inbox tag configured" without it - so the inbox screenshot depends on it entirely.
    @Shared(.inboxTags(server))
    var inboxTags

    $servers.withLock { $0 = [server] }
    $selectedServer.withLock { $0 = server }
    $correspondents.withLock { $0 = IdentifiedArray(uniqueElements: SnapshotFixtures.correspondents()) }
    $documentTypes.withLock { $0 = IdentifiedArray(uniqueElements: SnapshotFixtures.documentTypes(in: corpus)) }
    $favorites.withLock { $0 = IdentifiedArray(uniqueElements: snapshotFavorites(in: corpus)) }
    $savedViews.withLock { $0 = IdentifiedArray(uniqueElements: SnapshotFixtures.savedViews()) }
    $storagePaths.withLock { $0 = IdentifiedArray(uniqueElements: SnapshotFixtures.storagePaths(in: corpus)) }
    $tags.withLock { $0 = IdentifiedArray(uniqueElements: SnapshotFixtures.tags(in: corpus)) }
    $inboxDocumentCount.withLock { $0 = corpus.inboxDocumentIds.count }
    $inboxTags.withLock { $0 = SnapshotFixtures.tags(in: corpus).filter(\.isInboxTag).map(\.id) }
}

// The records a real favoriting would have written, minus the download that wrote the file: the
// PDF is already in the repository and `favoritesStore.pdfURL` points the row straight at it.
//
// `storedAt` is fixed rather than `Date()` because it keys the row's thumbnail render — a moving
// value would re-render on every launch and give the capture something new to wait for.
private func snapshotFavorites(
    in corpus: SnapshotConfiguration.Corpus
) -> [FavoriteDocument] {
    let documents = SnapshotFixtures.documents()
    return corpus.favoriteDocumentIds
        .compactMap { id in documents.first { $0.id == id } }
        .map { document in
            FavoriteDocument(
                document: document,
                metadata: nil,
                notes: [],
                pdfByteCount: .snapshotDocumentByteCount(named: document.title),
                storedAt: Date(timeIntervalSince1970: 1_756_290_271),
                syncedModified: document.modified
            )
        }
}

struct SnapshotFixtureMissing: Error {}

public extension Server {

    // Alias and username show up in Settings, so they are chosen to read well in a screenshot
    // rather than to look like a test fixture.
    static let snapshot = Self(
        alias: "Home",
        headers: [],
        id: "snapshot",
        username: "you",
        url: URL(string: "https://paperless.example.com")!
    )
}

private extension URL {

    static func snapshotDocument(named title: String) -> Self {
        .projectRoot.appending(path: "docker/data/\(title).pdf")
    }
}

private extension Int {

    // Attributes rather than reading the file: this only ever needs the size, and the two featured
    // manuals are megabytes each.
    static func snapshotDocumentByteCount(named title: String) -> Self {
        let values = try? URL.snapshotDocument(named: title).resourceValues(forKeys: [.fileSizeKey])
        return values?.fileSize ?? 0
    }
}
#endif
